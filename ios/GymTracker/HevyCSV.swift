import Foundation
import CryptoKit

struct ImportPreview {
    var sessions: [WorkoutSession]
    var exercises: [Exercise]
    var warnings: [String]
    var summary: String {
        "\(sessions.count) entrenamientos · \(sessions.reduce(0) { $0 + $1.completedSets }) series · \(exercises.count) ejercicios nuevos" + (warnings.isEmpty ? "" : " · \(warnings.count) avisos")
    }
}

enum HevyCSV {
    private struct Record { var fields: [String]; var line: Int; var error: String? }
    private struct BlockState { var name: String; var superset: String?; var setIndex: Int; var index: Int }

    static func preview(_ text: String, catalog: [Exercise]) throws -> ImportPreview {
        guard text.utf8.count <= 50 * 1024 * 1024 else { throw GymError.invalid("El CSV supera 50 MB.") }
        let content = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let records = parseRecords(content, delimiter: detectDelimiter(content))
        guard let first = records.first, first.error == nil else { throw GymError.invalid("El archivo está vacío o su cabecera no es válida.") }
        let header = first.fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard Set(header).count == header.count else { throw GymError.invalid("La cabecera contiene columnas duplicadas.") }
        let required = ["title", "start_time", "exercise_title", "set_index"]
        let missing = required.filter { !header.contains($0) }
        guard missing.isEmpty else { throw GymError.invalid("Faltan columnas obligatorias: \(missing.joined(separator: ", ")).") }
        guard ["reps", "duration_seconds", "distance_km", "distance_miles", "distance_meters"].contains(where: header.contains) else { throw GymError.invalid("Faltan columnas de repeticiones, distancia o duración.") }
        let indices = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
        var preview = ImportPreview(sessions: [], exercises: [], warnings: [])
        var states: [String: BlockState] = [:]
        var occurrences: [String: Int] = [:]

        for row in records.dropFirst() {
            guard row.error == nil, row.fields.count == header.count else {
                preview.warnings.append("Fila \(row.line) omitida: \(row.error ?? "número de columnas incorrecto").")
                continue
            }
            func raw(_ name: String) -> String { indices[name].map { row.fields[$0] } ?? "" }
            func value(_ name: String) -> String { raw(name).trimmingCharacters(in: .whitespacesAndNewlines) }
            do {
                func number(_ name: String) throws -> Double? {
                    let source = value(name)
                    guard !source.isEmpty else { return nil }
                    guard let parsed = Double(source.replacingOccurrences(of: ",", with: ".")), parsed.isFinite, parsed >= 0 else { throw GymError.invalid("\(name) debe ser un número finito mayor o igual a cero") }
                    return parsed
                }
                func integer(_ name: String) throws -> Int? {
                    guard let parsed = try number(name) else { return nil }
                    guard parsed.rounded(.towardZero) == parsed, parsed < Double(Int32.max) else { throw GymError.invalid("\(name) debe ser un entero válido") }
                    return Int(parsed)
                }
                guard let start = parseDate(value("start_time")) else { throw GymError.invalid("start_time no es una fecha válida") }
                let endText = value("end_time")
                let end = endText.isEmpty ? nil : parseDate(endText)
                guard endText.isEmpty || end != nil else { throw GymError.invalid("end_time no es una fecha válida") }
                guard end == nil || end! >= start else { throw GymError.invalid("end_time es anterior a start_time") }
                guard let setIndex = try integer("set_index") else { throw GymError.invalid("falta set_index") }
                let name = value("exercise_title")
                guard !name.isEmpty else { throw GymError.invalid("falta el ejercicio") }
                let reps = try integer("reps") ?? 0
                let kg = try number("weight_kg")
                let lbs = try number("weight_lbs")
                let weight = kg ?? (lbs.map { $0 * 0.45359237 }) ?? 0
                let km = try number("distance_km")
                let miles = try number("distance_miles")
                let meters = try number("distance_meters")
                let distance = km ?? miles.map { $0 * 1.609344 } ?? meters.map { $0 / 1000 }
                let seconds = try integer("duration_seconds")
                let rpe = try number("rpe")
                guard weight.isFinite, distance?.isFinite ?? true, (rpe ?? 0) <= 10 else { throw GymError.invalid("carga, distancia o RPE fuera de rango") }
                guard reps <= 1_000_000, weight <= 1_000_000, (distance ?? 0) <= 1_000_000, (seconds ?? 0) <= 31_536_000 else { throw GymError.invalid("las métricas exceden el intervalo admitido") }
                guard reps > 0 || (distance ?? 0) > 0 || (seconds ?? 0) > 0 else { throw GymError.invalid("la serie necesita repeticiones, distancia o duración") }
                guard let type = setType(value("set_type")) else { throw GymError.invalid("set_type desconocido: \(value("set_type"))") }
                let title = value("title").isEmpty ? "Entrenamiento importado" : value("title")
                let canonicalStart = canonicalLocalDate(start, source: value("start_time"))
                let sessionKey = canonicalKey([title, canonicalStart], prefix: "session")
                let superset = value("superset_id").isEmpty ? nil : value("superset_id")
                let previous = states[sessionKey]
                let blockIndex: Int
                if let previous = previous {
                    blockIndex = previous.name != name || previous.superset != superset || setIndex <= previous.setIndex ? previous.index + 1 : previous.index
                } else { blockIndex = 0 }
                states[sessionKey] = BlockState(name: name, superset: superset, setIndex: setIndex, index: blockIndex)
                let available = catalog + preview.exercises
                let exercise: Exercise
                if let known = available.first(where: { exactName($0.name) == exactName(name) }) { exercise = known }
                else {
                    // No fuzzy matching: different equipment or translated names remain distinct.
                    exercise = Exercise(id: canonicalKey([exactName(name)], prefix: "hevy-exercise"), name: name, equipment: "Importado", category: "Importado")
                    preview.exercises.append(exercise)
                }
                if !preview.sessions.contains(where: { $0.importKey == sessionKey }) {
                    preview.sessions.append(WorkoutSession(id: sessionKey, importKey: sessionKey, title: title,
                        startedAt: start, endedAt: end, notes: raw("description")))
                }
                let sessionIndex = preview.sessions.firstIndex(where: { $0.importKey == sessionKey })!
                let blockId = "\(sessionKey):\(blockIndex):\(exercise.id)"
                if !preview.sessions[sessionIndex].exercises.contains(where: { $0.id == blockId }) {
                    preview.sessions[sessionIndex].exercises.append(WorkoutExercise(id: blockId, exerciseId: exercise.id, exerciseName: name,
                        notes: raw("exercise_notes"), supersetId: superset, sets: []))
                }
                let blockPosition = preview.sessions[sessionIndex].exercises.firstIndex(where: { $0.id == blockId })!
                let setFields = [title, canonicalStart, name, String(blockIndex), String(setIndex), type, javaDouble(weight), String(reps),
                                 rpe.map(javaDouble) ?? "", distance.map(javaDouble) ?? "", seconds.map(String.init) ?? "", raw("exercise_notes"), superset ?? ""]
                let baseKey = canonicalKey(setFields, prefix: "set")
                let occurrence = occurrences[baseKey, default: 0]
                occurrences[baseKey] = occurrence + 1
                let key = "\(baseKey):\(occurrence)"
                preview.sessions[sessionIndex].exercises[blockPosition].sets.append(WorkoutSet(id: key, importKey: key,
                    reps: reps, weightKg: weight, setType: type, rpe: rpe, distanceKm: distance, durationSeconds: seconds, completed: true))
            } catch {
                preview.warnings.append("Fila \(row.line) omitida: \(error.localizedDescription).")
            }
        }
        if records.count == 1 { preview.warnings.append("El archivo contiene una cabecera, pero ninguna serie.") }
        return preview
    }

    static func exactName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func canonicalKey(_ fields: [String], prefix: String) -> String {
        let input = fields.map { "\($0.utf16.count):\($0)" }.joined()
        return "\(prefix):sha256:" + SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func javaDouble(_ value: Double) -> String {
        // Java and Swift use the same shortest-round-trip form for normal decimal training values.
        let raw = String(value)
        if !raw.lowercased().contains("e") && (abs(value) < 1e7 && (abs(value) >= 1e-3 || value == 0)) { return raw }
        if let range = raw.range(of: "e", options: .caseInsensitive) {
            var mantissa = String(raw[..<range.lowerBound])
            if !mantissa.contains(".") { mantissa += ".0" }
            let exponent = Int(raw[range.upperBound...]) ?? 0
            return "\(mantissa)E\(exponent)"
        }
        // Java switches to scientific notation below 1e-3 and at 1e7.
        let negative = raw.hasPrefix("-")
        let unsigned = negative ? String(raw.dropFirst()) : raw
        let decimalPosition = unsigned.firstIndex(of: ".").map { unsigned.distance(from: unsigned.startIndex, to: $0) } ?? unsigned.count
        let digits = Array(unsigned.filter { $0 != "." })
        guard let first = digits.firstIndex(where: { $0 != "0" }) else { return negative ? "-0.0" : "0.0" }
        let exponent = decimalPosition - first - 1
        var significant = String(digits[first...])
        while significant.last == "0" { significant.removeLast() }
        let head = significant.removeFirst()
        return (negative ? "-" : "") + String(head) + "." + (significant.isEmpty ? "0" : significant) + "E\(exponent)"
    }

    private static func setType(_ raw: String) -> String? {
        let value = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[ _-]", with: "", options: .regularExpression)
        switch value {
        case "", "normal": return "normal"
        case "warmup", "calentamiento", "aproximacion": return "warmup"
        case "failure", "fallo": return "failure"
        case "dropset", "descendente": return "dropset"
        default: return nil
        }
    }

    static func parseDate(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{00A0}", with: " ")
        guard !value.isEmpty else { return nil }
        let iso = value.replacingOccurrences(of: "^(\\d{4}-\\d{2}-\\d{2})\\s+", with: "$1T", options: .regularExpression)
        if iso.range(of: "^\\d{4}-\\d{2}-\\d{2}", options: .regularExpression) != nil && !validISOCalendarDay(iso) { return nil }
        if iso.range(of: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}(?::\\d{2}(?:\\.\\d{1,9})?)?(?:Z|[+-]\\d{2}:?\\d{2})$", options: .regularExpression) != nil {
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = parser.date(from: iso), validRange(date) { return date }
            parser.formatOptions = [.withInternetDateTime]
            if let date = parser.date(from: iso), validRange(date) { return date }
        }
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd", "d/M/yyyy H:mm:ss", "d/M/yyyy H:mm", "yyyy/M/d H:mm:ss", "yyyy/M/d H:mm"]
        let numericPattern = "^(?:\\d{4}-\\d{2}-\\d{2}(?:T\\d{2}:\\d{2}(?::\\d{2}(?:\\.\\d{1,9})?)?)?|\\d{1,4}/\\d{1,2}/\\d{1,4} \\d{1,2}:\\d{2}(?::\\d{2})?)$"
        if iso.range(of: numericPattern, options: .regularExpression) != nil {
            for format in formats {
                let parser = DateFormatter()
                parser.locale = Locale(identifier: "en_US_POSIX")
                parser.calendar = Calendar(identifier: .gregorian)
                parser.isLenient = false
                parser.dateFormat = format
                if let date = parser.date(from: iso), validRange(date) { return date }
            }
        }
        let normalized = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let pattern = "^(\\d{1,2})\\s+([a-z.]+)\\s+(\\d{4}),?\\s*(\\d{1,2}):(\\d{2})(?::(\\d{2}))?(?:\\s*([ap])\\.?m\\.?)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) else { return nil }
        func group(_ index: Int) -> String { Range(match.range(at: index), in: normalized).map { String(normalized[$0]) } ?? "" }
        guard let month = monthAliases[group(2).trimmingCharacters(in: CharacterSet(charactersIn: "."))],
              let day = Int(group(1)), let year = Int(group(3)), var hour = Int(group(4)), let minute = Int(group(5)) else { return nil }
        if !group(7).isEmpty {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (group(7) == "p" ? 12 : 0)
        }
        let second = Int(group(6)) ?? 0
        guard (1900...2200).contains(year), (1...31).contains(day), (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day, resolved.hour == hour, resolved.minute == minute, resolved.second == second else { return nil }
        return date
    }

    private static func validRange(_ date: Date) -> Bool { (-2208988800...7258118400).contains(date.timeIntervalSince1970) }

    private static func validISOCalendarDay(_ text: String) -> Bool {
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...2200).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return false }
        let resolved = calendar.dateComponents([.year, .month, .day], from: day)
        return resolved.year == parts[0] && resolved.month == parts[1] && resolved.day == parts[2]
    }

    private static func canonicalLocalDate(_ date: Date, source: String) -> String {
        // Android's identity hashes LocalDateTime.toString(), which omits :00 seconds.
        let pattern = "^(\\d{4}-\\d{2}-\\d{2})[T ](\\d{2}:\\d{2})(?::(\\d{2})(?:\\.(\\d{1,9}))?)?"
        if let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           let dayRange = Range(match.range(at: 1), in: source), let timeRange = Range(match.range(at: 2), in: source) {
            let second = Range(match.range(at: 3), in: source).map { String(source[$0]) } ?? "00"
            let fraction = Range(match.range(at: 4), in: source).map { String(source[$0]) } ?? ""
            var base = "\(source[dayRange])T\(source[timeRange])"
            if second != "00" || !fraction.isEmpty { base += ":\(second)" }
            if !fraction.isEmpty {
                let padded = fraction.padding(toLength: 9, withPad: "0", startingAt: 0)
                let length = padded.hasSuffix("000000") ? 3 : padded.hasSuffix("000") ? 6 : 9
                if Int(padded) != 0 { base += "." + padded.prefix(length) }
                else if second == "00" { base = "\(source[dayRange])T\(source[timeRange])" }
            }
            return base
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let base = formatter.string(from: date)
        formatter.dateFormat = "ss"
        let seconds = formatter.string(from: date)
        return seconds == "00" ? base : base + ":" + seconds
    }

    private static let monthAliases: [String: Int] = {
        let names = ["jan january ene enero", "feb february febrero", "mar march marzo", "apr april abr abril", "may mayo", "jun june junio", "jul july julio", "aug august ago agosto", "sep sept september septiembre", "oct october octubre", "nov november noviembre", "dec december dic diciembre"]
        var result: [String: Int] = [:]
        for (index, aliases) in names.enumerated() { for alias in aliases.split(separator: " ") { result[String(alias)] = index + 1 } }
        return result
    }()

    private static func detectDelimiter(_ text: String) -> Character {
        let first = text.split(whereSeparator: \.isNewline).first ?? ""
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        var quoted = false
        for character in first {
            if character == "\"" { quoted.toggle() }
            else if !quoted && counts[character] != nil { counts[character, default: 0] += 1 }
        }
        return [Character(","), Character(";"), Character("\t")].max { counts[$0, default: 0] < counts[$1, default: 0] } ?? ","
    }

    private static func parseRecords(_ text: String, delimiter: Character) -> [Record] {
        let characters = Array(text)
        var records: [Record] = []
        var fields: [String] = []
        var current = ""
        var quoted = false
        var quoteClosed = false
        var error: String?
        var line = 1
        var recordLine = 1
        func finishField() { fields.append(current); current = ""; quoteClosed = false }
        func finishRecord() {
            finishField()
            if fields.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) || error != nil { records.append(Record(fields: fields, line: recordLine, error: error)) }
            fields = []; error = nil
        }
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" && quoted && index + 1 < characters.count && characters[index + 1] == "\"" {
                current.append("\""); index += 1
            } else if character == "\"" && quoted { quoted = false; quoteClosed = true }
            else if character == "\"" && current.trimmingCharacters(in: .whitespaces).isEmpty && !quoteClosed { current = ""; quoted = true }
            else if character == delimiter && !quoted { finishField() }
            else if character == "\r" || character == "\n" || character == "\r\n" {
                // Swift treats CRLF as one grapheme; support lone CR and LF too.
                if quoted { current.append(character) } else { finishRecord() }
                line += 1
                if !quoted { recordLine = line }
            } else if quoteClosed && !character.isWhitespace { error = "hay texto después de cerrar las comillas" }
            else if quoteClosed { /* whitespace between quote and delimiter */ }
            else if character == "\"" { error = "hay comillas dentro de un campo sin entrecomillar"; current.append(character) }
            else { current.append(character) }
            index += 1
        }
        if quoted { error = "faltan comillas de cierre" }
        if !current.isEmpty || !fields.isEmpty || error != nil { finishRecord() }
        return records
    }
}
