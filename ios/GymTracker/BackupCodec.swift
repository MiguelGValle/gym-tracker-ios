import Foundation
import CoreFoundation

enum BackupCodec {
    static func encode(_ value: GymData) throws -> Data {
        try GymValidation.validate(value)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    static func decode(_ raw: Data) throws -> GymData {
        guard raw.count <= 100 * 1024 * 1024 else { throw GymError.invalid("La copia supera 100 MB.") }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { throw GymError.invalid("La copia debe ser un documento JSON.") }
        let format = try document.string("format")
        let value: GymData
        if format == "gymtracker-ios" {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            value = try decoder.decode(GymData.self, from: raw)
        } else if format == "ember-gym-backup" {
            value = try android(document)
        } else { throw GymError.invalid("Formato de copia no reconocido.") }
        try GymValidation.validate(value)
        return value
    }

    private static func android(_ document: [String: Any]) throws -> GymData {
        let version = try document.integer("databaseVersion")
        guard try document.integer("version") == 1, (3...6).contains(version),
              let tables = document["tables"] as? [String: Any] else { throw GymError.invalid("Versión Android no compatible.") }
        func rows(_ table: String, optional: Bool = false) throws -> [[String: Any]] {
            if optional && tables[table] == nil { return [] }
            guard let value = tables[table] as? [[String: Any]] else { throw GymError.invalid("Falta la tabla \(table) o está dañada.") }
            return value
        }
        var result = GymData()
        let muscles = try rows("exercise_muscles")
        result.exercises = try rows("exercises").map { row in
            let id = try row.string("id")
            var shares: [String: Int] = [:]
            for entry in muscles where (entry["exercise_id"] as? String) == id {
                let muscle = try entry.string("muscle")
                guard shares[muscle] == nil else { throw GymError.invalid("Músculos duplicados en \(id).") }
                shares[muscle] = try entry.integer("percentage")
            }
            return Exercise(id: id, name: try row.string("name"), equipment: try row.string("equipment"),
                            category: try row.string("category"), movement: try row.string("movement"),
                            technogym: try row.integer("technogym") != 0, archived: try row.integer("archived") != 0,
                            notes: try row.string("notes"), muscles: shares)
        }
        let exerciseIds = Set(result.exercises.map(\.id))
        for entry in muscles where !exerciseIds.contains(try entry.string("exercise_id")) { throw GymError.invalid("Distribución muscular sin ejercicio.") }
        let sets = try rows("set_entries")
        result.sessions = try rows("workout_sessions").map { row in
            let id = try row.string("id")
            let startText = try row.string("started_at")
            let startedAt = startText.isEmpty ? try row.epochDate() : try validDate(startText)
            let endText = try row.string("ended_at")
            var session = WorkoutSession(id: id, importKey: try row.optionalString("import_key"),
                                         title: try row.string("title"), startedAt: startedAt,
                                         endedAt: endText.isEmpty ? nil : try validDate(endText), notes: try row.string("notes"))
            let sessionSets = try sets.filter { try $0.string("session_id") == id }.sorted {
                let left = ($0["exercise_index"] as? NSNumber)?.intValue ?? 0
                let right = ($1["exercise_index"] as? NSNumber)?.intValue ?? 0
                if left != right { return left < right }
                return (($0["set_number"] as? NSNumber)?.intValue ?? 0) < (($1["set_number"] as? NSNumber)?.intValue ?? 0)
            }
            for entry in sessionSets {
                let exerciseId = try entry.string("exercise_id")
                let rawBlock = try entry.string("exercise_block_id", default: "")
                let blockId = rawBlock.isEmpty ? exerciseId : rawBlock
                if !session.exercises.contains(where: { $0.id == blockId }) {
                    let name = try entry.string("original_exercise_name", default: "")
                    session.exercises.append(WorkoutExercise(id: blockId, exerciseId: exerciseId,
                        exerciseName: name.isEmpty ? result.exercises.first(where: { $0.id == exerciseId })?.name ?? "Ejercicio" : name,
                        notes: try entry.string("exercise_notes", default: ""),
                        restSeconds: try entry.integer("rest_seconds", default: 90),
                        supersetId: try entry.optionalString("superset_id"), sets: []))
                }
                let blockIndex = session.exercises.firstIndex(where: { $0.id == blockId })!
                guard session.exercises[blockIndex].exerciseId == exerciseId else { throw GymError.invalid("Bloque Android con ejercicios incompatibles.") }
                session.exercises[blockIndex].sets.append(WorkoutSet(id: try entry.string("id"), importKey: try entry.optionalString("import_key"),
                    reps: try entry.integer("reps"), weightKg: try entry.number("weight_kg"),
                    setType: try entry.string("set_type", default: try entry.integer("warmup", default: 0) != 0 ? "warmup" : "normal"),
                    rpe: try entry.optionalNumber("rpe"), distanceKm: try entry.optionalNumber("distance_km"),
                    durationSeconds: try entry.optionalInteger("duration_seconds"), completed: true))
            }
            return session
        }
        let sessionIds = Set(result.sessions.map(\.id))
        for entry in sets where !sessionIds.contains(try entry.string("session_id")) { throw GymError.invalid("Serie Android sin entrenamiento.") }
        result.folders = try rows("routine_folders").map { RoutineFolder(id: try $0.string("id"), name: try $0.string("name")) }
        result.routines = try rows("routines").map { row in
            let raw = try row.string("exercises_json")
            guard let bytes = raw.data(using: .utf8), let blocks = try JSONSerialization.jsonObject(with: bytes) as? [[String: Any]] else { throw GymError.invalid("Ejercicios de rutina dañados.") }
            return Routine(id: try row.string("id"), name: try row.string("name"), folderId: try row.optionalString("folder_id"),
                           notes: try row.string("notes"), exercises: try blocks.map { try androidBlock($0, catalog: result.exercises) })
        }
        let drafts = try rows("workout_drafts")
        guard drafts.count <= 1 else { throw GymError.invalid("La copia contiene varios entrenamientos activos.") }
        if let draftRow = drafts.first {
            let payload = try draftRow.string("payload")
            guard let bytes = payload.data(using: .utf8), let row = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  let blocks = row["exercises"] as? [[String: Any]] else { throw GymError.invalid("Borrador Android dañado.") }
            result.draft = WorkoutSession(id: try row.string("id"), title: try row.string("title"), startedAt: try validDate(row.string("startedAt")),
                notes: try row.string("notes"), routineId: try row.optionalString("routineId"),
                exercises: try blocks.map { try androidBlock($0, catalog: result.exercises) })
        }
        result.nutrition = try rows("nutrition_logs").map { row in
            NutritionLog(date: try row.epochDate(), calories: try row.integer("calories"), protein: try row.integer("protein"), notes: try row.string("notes"))
        }
        result.measurements = try rows("body_measurements").map { row in
            let json = try row.string("values_json", default: "{}")
            guard let bytes = json.data(using: .utf8), let values = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw GymError.invalid("Medidas Android dañadas.") }
            var measurements: [String: Double] = [:]
            for key in values.keys { measurements[key] = try values.number(key) }
            return BodyMeasurement(date: try row.epochDate(), weightKg: try row.number("weight_kg"), heightCm: try row.number("height_cm"), values: measurements)
        }
        let photoRows = try rows("progress_photos", optional: version < 5)
        let attachments = (document["photoAttachments"] as? [String: [String: Any]]) ?? [:]
        result.photos = try photoRows.map { row in
            let id = try row.string("id")
            guard let attachment = attachments[id], let encoded = attachment["data"] as? String,
                  let image = Data(base64Encoded: encoded), !image.isEmpty else {
                throw GymError.invalid("La foto \(id) no está incluida. Exporta una copia desde la versión Android actual con sus fotos accesibles.")
            }
            return ProgressPhoto(id: id, date: try row.epochDate(), imageData: image, notes: try row.string("notes"))
        }
        if let profile = document["profile"] as? [String: Any] {
            guard let male = profile["male"] as? Bool else { throw GymError.invalid("Perfil Android dañado.") }
            result.profile = UserProfile(male: male, age: try profile.integer("age"), heightCm: try profile.number("heightCm"),
                                         activityFactor: try profile.number("activityFactor"), goal: try profile.string("goal"))
        }
        return result
    }

    private static func androidBlock(_ row: [String: Any], catalog: [Exercise]) throws -> WorkoutExercise {
        let id = try row.string("exerciseId")
        guard let sets = row["sets"] as? [[String: Any]] else { throw GymError.invalid("Series Android dañadas.") }
        return WorkoutExercise(id: try row.string("id"), exerciseId: id,
            exerciseName: try row.string("exerciseName", default: catalog.first(where: { $0.id == id })?.name ?? "Ejercicio"),
            notes: try row.string("notes"), restSeconds: try row.integer("restSeconds"), supersetId: try row.optionalString("supersetId"),
            sets: try sets.map { set in
                WorkoutSet(id: try set.string("id"), reps: try set.integer("reps"), weightKg: try set.number("weightKg"),
                           setType: try set.string("setType"), rpe: try set.optionalNumber("rpe"), distanceKm: try set.optionalNumber("distanceKm"),
                           durationSeconds: try set.optionalInteger("durationSeconds"), completed: (set["completed"] as? Bool) ?? false)
            })
    }

    private static func validDate(_ text: String) throws -> Date {
        guard let date = HevyCSV.parseDate(text) else { throw GymError.invalid("Fecha Android inválida: \(text)") }
        return date
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String, default fallback: String? = nil) throws -> String {
        if let value = self[key] as? String { return value }
        if self[key] == nil, let fallback = fallback { return fallback }
        throw GymError.invalid("Campo de texto inválido: \(key).")
    }
    func optionalString(_ key: String) throws -> String? {
        if self[key] == nil || self[key] is NSNull { return nil }
        return try string(key)
    }
    func number(_ key: String) throws -> Double {
        guard let value = self[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { throw GymError.invalid("Número inválido: \(key).") }
        return value.doubleValue
    }
    func integer(_ key: String, default fallback: Int? = nil) throws -> Int {
        if self[key] == nil, let fallback = fallback { return fallback }
        let value = try number(key)
        guard value >= Double(Int.min), value < Double(Int.max), value.rounded(.towardZero) == value else { throw GymError.invalid("Entero inválido: \(key).") }
        return Int(value)
    }
    func optionalNumber(_ key: String) throws -> Double? {
        if self[key] == nil || self[key] is NSNull { return nil }
        return try number(key)
    }
    func optionalInteger(_ key: String) throws -> Int? {
        if self[key] == nil || self[key] is NSNull { return nil }
        return try integer(key)
    }
    func epochDate() throws -> Date {
        let day = try integer("date_epoch_day")
        guard (-25567...84006).contains(day) else { throw GymError.invalid("Fecha Android fuera del intervalo admitido.") }
        return GymDate.fromEpochDay(day)
    }
}
