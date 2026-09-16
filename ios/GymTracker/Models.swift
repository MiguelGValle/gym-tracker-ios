import Foundation

struct Exercise: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = "Nuevo ejercicio"
    var equipment = "Otro"
    var category = "Mixto"
    var movement = ""
    var technogym = false
    var archived = false
    var notes = ""
    var muscles: [String: Int] = [:]
}

struct WorkoutSet: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var importKey: String? = nil
    var reps = 10
    var weightKg = 0.0
    var setType = "normal"
    var rpe: Double? = nil
    var distanceKm: Double? = nil
    var durationSeconds: Int? = nil
    var completed = false
    var volume: Double { setType == "warmup" ? 0 : weightKg * Double(reps) }
    var estimatedOneRM: Double { reps > 0 && reps <= 12 && setType != "warmup" ? (reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)) : 0 }
}

struct WorkoutExercise: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var exerciseId: String
    var exerciseName = ""
    var notes = ""
    var restSeconds = 90
    var supersetId: String? = nil
    var sets: [WorkoutSet] = [WorkoutSet()]
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var importKey: String? = nil
    var title = "Entrenamiento"
    var startedAt = Date()
    var endedAt: Date? = nil
    var notes = ""
    var routineId: String? = nil
    var exercises: [WorkoutExercise] = []
    var volume: Double { exercises.flatMap(\.sets).filter(\.completed).reduce(0) { $0 + $1.volume } }
    var completedSets: Int { exercises.flatMap(\.sets).filter(\.completed).count }
    var duration: TimeInterval { max(0, (endedAt ?? Date()).timeIntervalSince(startedAt)) }
}

struct Routine: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = "Nueva rutina"
    var folderId: String? = nil
    var notes = ""
    var exercises: [WorkoutExercise] = []
}

struct RoutineFolder: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = "Nueva carpeta"
}

struct NutritionLog: Codable, Identifiable, Equatable {
    private(set) var civilDate: String
    var calories: Int
    var protein: Int
    var notes: String
    var date: Date {
        get { GymDate.localDate(fromCivilDay: civilDate) ?? .distantPast }
        set { civilDate = GymDate.dayKey(newValue) }
    }
    var id: String { civilDate }

    init(date: Date = Date(), calories: Int = 0, protein: Int = 0, notes: String = "") {
        civilDate = GymDate.dayKey(date)
        self.calories = calories
        self.protein = protein
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey { case civilDate, date, calories, protein, notes }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.civilDate) {
            civilDate = try container.decode(String.self, forKey: .civilDate)
        } else {
            // Legacy files have no original time zone; migrate their displayed local day once.
            civilDate = GymDate.dayKey(try container.decode(Date.self, forKey: .date))
        }
        guard GymDate.localDate(fromCivilDay: civilDate) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .civilDate, in: container, debugDescription: "Fecha civil inválida; se esperaba un día real YYYY-MM-DD.")
        }
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Int.self, forKey: .protein)
        notes = try container.decode(String.self, forKey: .notes)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(civilDate, forKey: .civilDate)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(notes, forKey: .notes)
    }
}

struct BodyMeasurement: Codable, Identifiable, Equatable {
    private(set) var civilDate: String
    var weightKg: Double
    var heightCm: Double
    var values: [String: Double]
    var date: Date {
        get { GymDate.localDate(fromCivilDay: civilDate) ?? .distantPast }
        set { civilDate = GymDate.dayKey(newValue) }
    }
    var id: String { civilDate }

    init(date: Date = Date(), weightKg: Double = 0, heightCm: Double = 0, values: [String: Double] = [:]) {
        civilDate = GymDate.dayKey(date)
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.values = values
    }

    private enum CodingKeys: String, CodingKey { case civilDate, date, weightKg, heightCm, values }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.civilDate) {
            civilDate = try container.decode(String.self, forKey: .civilDate)
        } else {
            civilDate = GymDate.dayKey(try container.decode(Date.self, forKey: .date))
        }
        guard GymDate.localDate(fromCivilDay: civilDate) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .civilDate, in: container, debugDescription: "Fecha civil inválida; se esperaba un día real YYYY-MM-DD.")
        }
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        heightCm = try container.decode(Double.self, forKey: .heightCm)
        values = try container.decode([String: Double].self, forKey: .values)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(civilDate, forKey: .civilDate)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(values, forKey: .values)
    }
}

struct UserProfile: Codable, Equatable {
    var male = true
    var age = 30
    var heightCm = 175.0
    var activityFactor = 1.55
    var goal = "RECOMP"
    var usePounds = false
    var calorieGoal = 2200
    var proteinGoal = 140
}

struct ProgressPhoto: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var date = Date()
    var imageData: Data
    var notes = ""
}

struct GymData: Codable, Equatable {
    var format = "gymtracker-ios"
    var version = 1
    var exercises: [Exercise] = []
    var routines: [Routine] = []
    var folders: [RoutineFolder] = []
    var sessions: [WorkoutSession] = []
    var draft: WorkoutSession? = nil
    var nutrition: [NutritionLog] = []
    var measurements: [BodyMeasurement] = []
    var photos: [ProgressPhoto] = []
    var profile = UserProfile()
}

enum GymDate {
    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = NSTimeZone.default
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    /// A day is stored without an offset. Local noon avoids midnight DST transitions.
    /// Compare the resolved components so Calendar cannot silently turn February 30 into March 2.
    static func localDate(fromCivilDay value: String) -> Date? {
        guard value.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...2200).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.default
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        guard actual.year == parts[0], actual.month == parts[1], actual.day == parts[2] else { return nil }
        return date
    }
    static func fromEpochDay(_ value: Int) -> Date {
        let utc = Date(timeIntervalSince1970: Double(value) * 86400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var parts = calendar.dateComponents([.year, .month, .day], from: utc)
        parts.hour = 12
        calendar.timeZone = NSTimeZone.default
        return calendar.date(from: parts) ?? utc
    }
}

extension Double {
    var gymNumber: String { formatted(.number.precision(.fractionLength(0...1))) }
}

enum GymError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
