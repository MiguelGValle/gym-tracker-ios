import Foundation
import Combine

@MainActor
final class GymStore: ObservableObject {
    @Published private(set) var data: GymData
    @Published var errorMessage: String?
    private let directory: URL
    private var needsRestore = false
    private var currentFileIsValid = false
    private var file: URL { directory.appendingPathComponent("gym-data.json") }
    private var previousFile: URL { directory.appendingPathComponent("gym-data.previous.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GymTracker", isDirectory: true)
        data = ExerciseSeed.initialData
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            data = try BackupCodec.decode(Data(contentsOf: file))
            currentFileIsValid = true
        } catch {
            // Preserve the exact damaged bytes before any future write can replace the primary file.
            do {
                let recovery = self.directory.appendingPathComponent("gym-data.corrupt-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: file, to: recovery)
                data = try BackupCodec.decode(Data(contentsOf: previousFile))
                errorMessage = "Se recuperó la última copia válida. El archivo dañado se ha conservado para recuperación."
            } catch {
                needsRestore = true
                errorMessage = "No se pudo abrir el almacenamiento. Se conservan los archivos originales. Restaura una copia de seguridad para continuar: \(error.localizedDescription)"
            }
        }
    }

    func mutate(_ change: (inout GymData) -> Void) {
        var candidate = data
        change(&candidate)
        do { try commit(candidate) } catch { errorMessage = error.localizedDescription }
    }

    private func commit(_ candidate: GymData, restoring: Bool = false) throws {
        guard !needsRestore || restoring else { throw GymError.invalid("El almacenamiento necesita restaurarse antes de guardar cambios.") }
        try GymValidation.validate(candidate)
        let encoded = try BackupCodec.encode(candidate)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if currentFileIsValid {
            try BackupCodec.encode(data).write(to: previousFile, options: .atomic)
        } else if needsRestore && FileManager.default.fileExists(atPath: file.path) {
            // An explicit restore must also preserve a corrupt original when startup could not copy it.
            let recovery = directory.appendingPathComponent("gym-data.corrupt-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: file, to: recovery)
        }
        try encoded.write(to: file, options: .atomic)
        currentFileIsValid = true
        needsRestore = false
        data = candidate
        errorMessage = nil
    }

    func startWorkout(routine: Routine? = nil) {
        guard data.draft == nil else { return }
        var workout = WorkoutSession(title: routine?.name ?? "Entrenamiento", routineId: routine?.id)
        workout.exercises = (routine?.exercises ?? []).map { source in
            var block = source
            block.id = UUID().uuidString
            block.sets = source.sets.map { original in
                var set = original
                set.id = UUID().uuidString
                set.importKey = nil
                set.completed = false
                return set
            }
            return block
        }
        mutate { $0.draft = workout }
    }

    func finishWorkout(_ workout: WorkoutSession, routine: Routine? = nil) throws {
        var finished = workout
        finished.endedAt = finished.endedAt ?? Date()
        finished.exercises = finished.exercises.compactMap { original in
            var block = original
            block.sets.removeAll { !$0.completed }
            return block.sets.isEmpty ? nil : block
        }
        guard finished.completedSets > 0 else { throw GymError.invalid("Completa al menos una serie antes de terminar.") }
        var candidate = data
        if let index = candidate.sessions.firstIndex(where: { $0.id == finished.id }) { candidate.sessions[index] = finished }
        else { candidate.sessions.append(finished) }
        if candidate.draft?.id == finished.id { candidate.draft = nil }
        if let routine {
            if let index = candidate.routines.firstIndex(where: { $0.id == routine.id }) { candidate.routines[index] = routine }
            else { candidate.routines.append(routine) }
        }
        try commit(candidate)
    }

    func previousSet(exerciseId: String, index: Int) -> WorkoutSet? {
        guard index >= 0 else { return nil }
        for session in data.sessions.sorted(by: { $0.startedAt > $1.startedAt }) {
            for block in session.exercises where block.exerciseId == exerciseId {
                let sets = block.sets.filter(\.completed)
                if sets.indices.contains(index) { return sets[index] }
            }
        }
        return nil
    }

    func exerciseName(_ id: String) -> String { data.exercises.first { $0.id == id }?.name ?? "Ejercicio" }
    var weightUnit: String { data.profile.usePounds ? "lb" : "kg" }
    func displayWeight(_ kg: Double) -> Double { data.profile.usePounds ? kg / 0.45359237 : kg }
    func kgWeight(_ displayed: Double) -> Double { data.profile.usePounds ? displayed * 0.45359237 : displayed }
    func backupData() throws -> Data {
        guard !needsRestore else { throw GymError.invalid("Restaura el almacenamiento antes de exportar una copia.") }
        return try BackupCodec.encode(data)
    }
    func previewImport(_ raw: Data) throws -> GymData { try BackupCodec.decode(raw) }

    func restore(_ incoming: GymData) throws {
        guard data.draft == nil else { throw GymError.invalid("Termina o descarta el entrenamiento activo antes de restaurar.") }
        try GymValidation.validate(incoming)
        var candidate = needsRestore ? GymData() : data
        candidate.exercises = merge(candidate.exercises, incoming.exercises, key: \.id)
        candidate.folders = merge(candidate.folders, incoming.folders, key: \.id)
        candidate.routines = merge(candidate.routines, incoming.routines, key: \.id)
        candidate.sessions = Self.mergeSessions(candidate.sessions, incoming.sessions)
        candidate.nutrition = merge(candidate.nutrition, incoming.nutrition, key: \.id)
        candidate.measurements = merge(candidate.measurements, incoming.measurements, key: \.id)
        candidate.photos = merge(candidate.photos, incoming.photos, key: \.id)
        candidate.profile = incoming.profile
        candidate.draft = incoming.draft
        try commit(candidate, restoring: true)
    }

    func previewHevyCSV(_ text: String) throws -> ImportPreview { try HevyCSV.preview(text, catalog: data.exercises) }
    func importHevy(_ preview: ImportPreview) throws {
        guard data.draft == nil else { throw GymError.invalid("Termina o descarta el entrenamiento activo antes de importar.") }
        guard !preview.sessions.isEmpty else { throw GymError.invalid("El archivo no contiene series válidas para importar.") }
        var candidate = data
        candidate.exercises = merge(candidate.exercises, preview.exercises, key: \.id)
        candidate.sessions = Self.mergeSessions(candidate.sessions, preview.sessions, preserveImportedSets: true)
        try commit(candidate)
    }

    private func merge<T>(_ old: [T], _ new: [T], key: KeyPath<T, String>) -> [T] {
        var result = old
        for item in new {
            if let index = result.firstIndex(where: { $0[keyPath: key] == item[keyPath: key] }) { result[index] = item }
            else { result.append(item) }
        }
        return result
    }

    private static func mergeSessions(_ old: [WorkoutSession], _ incoming: [WorkoutSession], preserveImportedSets: Bool = false) -> [WorkoutSession] {
        var result = old
        for var session in incoming {
            guard let index = result.firstIndex(where: { $0.id == session.id || (session.importKey != nil && $0.importKey == session.importKey) }) else {
                result.append(session); continue
            }
            let existing = result[index]
            if existing.id == session.id && !preserveImportedSets { result[index] = session; continue }
            // Separate Android installations assign random UUIDs to the same imported Hevy rows.
            session.id = existing.id
            var blocks = existing.exercises
            var seen = Set(existing.exercises.flatMap(\.sets).map { $0.importKey ?? $0.id })
            for var block in session.exercises {
                block.sets = block.sets.filter { seen.insert($0.importKey ?? $0.id).inserted }
                if !block.sets.isEmpty {
                    if let blockIndex = blocks.firstIndex(where: { $0.id == block.id && $0.exerciseId == block.exerciseId }) { blocks[blockIndex].sets.append(contentsOf: block.sets) }
                    else {
                        if blocks.contains(where: { $0.id == block.id }) { block.id = UUID().uuidString }
                        blocks.append(block)
                    }
                }
            }
            session.exercises = blocks
            result[index] = session
        }
        return result
    }
}

enum GymValidation {
    static func validate(_ data: GymData) throws {
        guard data.format == "gymtracker-ios", data.version == 1 else { throw GymError.invalid("Versión de copia no compatible.") }
        try unique(data.exercises.map(\.id), "ejercicios")
        try unique(data.routines.map(\.id), "rutinas")
        try unique(data.folders.map(\.id), "carpetas")
        try unique(data.sessions.map(\.id), "entrenamientos")
        try unique(data.nutrition.map(\.id), "registros de nutrición")
        try unique(data.measurements.map(\.id), "medidas")
        try unique(data.photos.map(\.id), "fotos")
        let exercises = Set(data.exercises.map(\.id))
        let folders = Set(data.folders.map(\.id))
        for exercise in data.exercises {
            guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  exercise.muscles.allSatisfy({ !$0.key.isEmpty && (0...100).contains($0.value) }),
                  exercise.muscles.isEmpty || exercise.muscles.values.reduce(0, +) == 100 else { throw GymError.invalid("Nombre o distribución muscular inválida.") }
        }
        for folder in data.folders where folder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw GymError.invalid("La carpeta necesita un nombre.") }
        for routine in data.routines {
            guard !routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  routine.folderId == nil || folders.contains(routine.folderId!) else { throw GymError.invalid("Rutina o carpeta de rutina inválida.") }
            try blocks(routine.exercises, exercises: exercises)
        }
        for session in data.sessions + (data.draft.map { [$0] } ?? []) {
            try date(session.startedAt)
            if let end = session.endedAt {
                try date(end)
                guard end >= session.startedAt else { throw GymError.invalid("El fin no puede ser anterior al inicio.") }
            }
            try blocks(session.exercises, exercises: exercises)
        }
        for entry in data.nutrition {
            try date(entry.date)
            guard entry.calories >= 0, entry.protein >= 0 else { throw GymError.invalid("Calorías o proteína inválidas.") }
        }
        for entry in data.measurements {
            try date(entry.date)
            guard entry.weightKg.isFinite, entry.weightKg >= 0, entry.heightCm.isFinite, entry.heightCm >= 0,
                  entry.values.allSatisfy({ !$0.key.isEmpty && $0.value.isFinite && $0.value >= 0 }),
                  (entry.values["bodyFatPercent"] ?? 0) <= 100 else { throw GymError.invalid("Medidas corporales inválidas.") }
        }
        for photo in data.photos { try date(photo.date); guard !photo.imageData.isEmpty else { throw GymError.invalid("La copia contiene una foto vacía.") } }
        guard data.photos.reduce(0, { $0 + $1.imageData.count }) <= 20 * 1024 * 1024 else { throw GymError.invalid("Las fotos superan el límite de 20 MB.") }
        let profile = data.profile
        guard (1...120).contains(profile.age), profile.heightCm.isFinite, profile.heightCm > 0,
              profile.activityFactor.isFinite, (1...3).contains(profile.activityFactor),
              profile.calorieGoal >= 0, profile.proteinGoal >= 0 else { throw GymError.invalid("Perfil inválido.") }
    }

    static func blocks(_ blocks: [WorkoutExercise], exercises: Set<String>) throws {
        try unique(blocks.map(\.id), "bloques de ejercicios")
        try unique(blocks.flatMap(\.sets).map(\.id), "series")
        for block in blocks {
            guard exercises.contains(block.exerciseId), (0...86400).contains(block.restSeconds) else { throw GymError.invalid("Ejercicio o descanso inválido (máximo 24 horas).") }
            for set in block.sets {
                guard (0...1_000_000).contains(set.reps), set.weightKg.isFinite, (0...1_000_000).contains(set.weightKg), set.volume.isFinite,
                      ["normal", "warmup", "failure", "dropset"].contains(set.setType),
                      set.rpe.map({ $0.isFinite && (0...10).contains($0) }) ?? true,
                      set.distanceKm.map({ $0.isFinite && (0...1_000_000).contains($0) }) ?? true,
                      set.durationSeconds.map({ (0...31_536_000).contains($0) }) ?? true else { throw GymError.invalid("Repeticiones, carga, RPE, distancia o duración inválidas.") }
                if set.completed && set.reps == 0 && (set.distanceKm ?? 0) == 0 && (set.durationSeconds ?? 0) == 0 { throw GymError.invalid("Una serie completada necesita repeticiones, distancia o duración.") }
            }
        }
    }
    static func unique(_ ids: [String], _ name: String) throws {
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else { throw GymError.invalid("Identificadores vacíos o duplicados en \(name).") }
    }
    static func date(_ date: Date) throws {
        guard date.timeIntervalSince1970.isFinite, (-2208988800...7258118400).contains(date.timeIntervalSince1970) else { throw GymError.invalid("Fecha fuera del intervalo admitido (1900–2200).") }
    }
}
