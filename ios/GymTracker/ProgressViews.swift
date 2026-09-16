import SwiftUI
import Charts

enum OneRMFormula: String, CaseIterable, Identifiable {
    case epley = "Epley", brzycki = "Brzycki", lombardi = "Lombardi"
    var id: String { rawValue }

    func estimate(weight: Double, reps: Int) -> Double {
        guard weight.isFinite, weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        let result: Double
        switch self {
        case .epley: result = weight * (1 + Double(reps) / 30)
        case .brzycki: result = reps >= 37 ? weight : weight * 36 / (37 - Double(reps))
        case .lombardi: result = weight * pow(Double(reps), 0.1)
        }
        return result.isFinite ? result : 0
    }
}

struct TrainingPoint: Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

struct PerformanceEntry: Identifiable {
    var sessionID: String
    var date: Date
    var exerciseID: String
    var exerciseName: String
    var set: WorkoutSet
    var id: String { "\(sessionID)-\(set.id)" }
}

enum TrainingMetrics {
    static func workingEntries(_ sessions: [WorkoutSession]) -> [PerformanceEntry] {
        sessions.flatMap { session in
            session.exercises.flatMap { exercise in
                exercise.sets.filter { $0.completed && $0.setType.lowercased() != "warmup" }.map {
                    PerformanceEntry(sessionID: session.id, date: session.startedAt,
                                     exerciseID: exercise.exerciseId, exerciseName: exercise.exerciseName, set: $0)
                }
            }
        }
    }

    static func dailyVolume(_ sessions: [WorkoutSession], calendar: Calendar = .current) -> [TrainingPoint] {
        Dictionary(grouping: sessions, by: { calendar.startOfDay(for: $0.startedAt) })
            .map { TrainingPoint(date: $0.key, value: $0.value.reduce(0) { $0 + $1.volume }) }
            .sorted { $0.date < $1.date }
    }

    static func oneRMHistory(_ entries: [PerformanceEntry], formula: OneRMFormula,
                             calendar: Calendar = .current) -> [TrainingPoint] {
        Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) }).compactMap { date, sets in
            let value = sets.map { formula.estimate(weight: $0.set.weightKg, reps: $0.set.reps) }.max() ?? 0
            return value > 0 ? TrainingPoint(date: date, value: value) : nil
        }.sorted { $0.date < $1.date }
    }

    /// A week counts once, starts on Monday, and the unfinished current week is allowed to be empty.
    static func weeklyStreak(_ sessions: [WorkoutSession], today: Date = Date(),
                             calendar: Calendar = .current) -> (current: Int, longest: Int) {
        func monday(_ date: Date) -> Date {
            let day = calendar.startOfDay(for: date)
            let offset = (calendar.component(.weekday, from: day) + 5) % 7
            return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        let weeks = Set(sessions.filter { $0.startedAt < tomorrow }.map { monday($0.startedAt) })
        var cursor = monday(today)
        if !weeks.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -7, to: cursor) ?? cursor }
        var current = 0
        while weeks.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -7, to: cursor), previous < cursor else { break }
            cursor = previous
        }
        var longest = 0
        var run = 0
        var previous: Date?
        for week in weeks.sorted() {
            run = previous.flatMap { calendar.date(byAdding: .day, value: 7, to: $0) } == week ? run + 1 : 1
            longest = max(longest, run)
            previous = week
        }
        return (current, longest)
    }

    static func muscleDistribution(_ sessions: [WorkoutSession], exercises: [Exercise]) -> [(name: String, sets: Double)] {
        let catalogue = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        var totals: [String: Double] = [:]
        for entry in workingEntries(sessions) {
            for (muscle, share) in catalogue[entry.exerciseID]?.muscles ?? [:] where share > 0 {
                totals[muscle, default: 0] += Double(share) / 100
            }
        }
        return totals.map { (name: $0.key, sets: $0.value) }.sorted { $0.sets > $1.sets }
    }
}

private enum ProgressPeriod: String, CaseIterable, Identifiable {
    case month = "30 días", quarter = "90 días", year = "1 año", all = "Todo"
    var id: String { rawValue }
    func includes(_ date: Date, today: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? today
        guard date < end else { return false }
        let from: Date?
        switch self {
        case .month: from = calendar.date(byAdding: .day, value: -29, to: start)
        case .quarter: from = calendar.date(byAdding: .day, value: -89, to: start)
        case .year: from = calendar.date(byAdding: .year, value: -1, to: start)
        case .all: from = nil
        }
        return from.map { date >= $0 } ?? true
    }
}

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: GymStore
    @State private var period = ProgressPeriod.month
    @State private var formula = OneRMFormula.epley
    @State private var selectedExercise = ""

    private var sessions: [WorkoutSession] { store.data.sessions.filter { period.includes($0.startedAt) } }
    private var entries: [PerformanceEntry] { TrainingMetrics.workingEntries(sessions) }
    private var exerciseIDs: [String] {
        Set(entries.map(\.exerciseID)).sorted { store.exerciseName($0).localizedStandardCompare(store.exerciseName($1)) == .orderedAscending }
    }
    private var activeExercise: String { exerciseIDs.contains(selectedExercise) ? selectedExercise : (exerciseIDs.first ?? "") }
    private var selectedEntries: [PerformanceEntry] { entries.filter { $0.exerciseID == activeExercise } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Periodo", selection: $period) {
                        ForEach(ProgressPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    summary
                    if sessions.isEmpty {
                        EmptyState(title: "Tu progreso empieza aquí", message: "Finaliza un entrenamiento para ver tus estadísticas en este periodo.", symbol: "chart.xyaxis.line")
                    } else {
                        volumeCard
                        consistencyCard
                        if !exerciseIDs.isEmpty { recordsCard }
                        muscleCard
                    }
                }.padding()
            }
            .background(Theme.background)
            .navigationTitle("Progreso")
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Entrenamientos", value: "\(sessions.count)", symbol: "dumbbell.fill")
            MetricTile(title: "Días activos", value: "\(Set(sessions.map { GymDate.dayKey($0.startedAt) }).count)", symbol: "calendar")
            MetricTile(title: "Series efectivas", value: "\(entries.count)", symbol: "checkmark.circle")
            MetricTile(title: "Volumen · \(store.weightUnit)", value: store.displayWeight(sessions.reduce(0) { $0 + $1.volume }).gymNumber, symbol: "scalemass")
        }
    }

    private var volumeCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Volumen por día").font(.headline)
                Chart(TrainingMetrics.dailyVolume(sessions)) { point in
                    BarMark(x: .value("Fecha", point.date, unit: .day), y: .value(store.weightUnit, store.displayWeight(point.value)))
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(store.displayWeight(point.value).gymNumber) \(store.weightUnit)")
                }.frame(height: 200)
                Text("Peso × repeticiones de las series completadas. No incluye calentamientos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var consistencyCard: some View {
        let streak = TrainingMetrics.weeklyStreak(store.data.sessions)
        return GymCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Constancia", systemImage: "flame.fill").font(.headline)
                HStack {
                    VStack(alignment: .leading) { Text("\(streak.current)").font(.title.bold()); Text("semanas actuales").font(.caption) }
                    Spacer()
                    VStack(alignment: .trailing) { Text("\(streak.longest)").font(.title.bold()); Text("mejor racha").font(.caption) }
                }
                Text("Historial completo · al menos un entrenamiento por semana, de lunes a domingo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var recordsCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Marcas por ejercicio").font(.headline)
                Picker("Ejercicio", selection: Binding(get: { activeExercise }, set: { selectedExercise = $0 })) {
                    ForEach(exerciseIDs, id: \.self) { id in Text(exerciseName(id)).tag(id) }
                }.tint(Theme.accent)
                Picker("Fórmula de 1RM", selection: $formula) {
                    ForEach(OneRMFormula.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                let points = TrainingMetrics.oneRMHistory(selectedEntries, formula: formula)
                if !points.isEmpty {
                    Chart(points) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("1RM", store.displayWeight(point.value)))
                            .foregroundStyle(Theme.accent)
                        PointMark(x: .value("Fecha", point.date), y: .value("1RM", store.displayWeight(point.value)))
                            .foregroundStyle(Theme.accent)
                    }.frame(height: 170)
                    recordRow("1RM estimado", metric: { formula.estimate(weight: $0.weightKg, reps: $0.reps) }, unit: store.weightUnit, weight: true)
                }
                recordRow("Mayor carga", metric: { $0.weightKg }, unit: store.weightUnit, weight: true)
                recordRow("Más repeticiones", metric: { Double($0.reps) }, unit: "reps")
                recordRow("Volumen de una serie", metric: { $0.volume }, unit: store.weightUnit, weight: true)
                recordRow("Mayor distancia", metric: { $0.distanceKm ?? 0 }, unit: "km")
                recordRow("Mayor duración", metric: { Double($0.durationSeconds ?? 0) }, unit: "s")
                Text("Marcas del periodo elegido, sin calentamientos. El 1RM es una estimación matemática; pierde precisión con muchas repeticiones.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func recordRow(_ title: String, metric: (WorkoutSet) -> Double, unit: String, weight: Bool = false) -> some View {
        if let best = selectedEntries.filter({ metric($0.set).isFinite && metric($0.set) > 0 })
            .sorted(by: { $0.date < $1.date }).max(by: { metric($0.set) < metric($1.set) }) {
            let raw = metric(best.set)
            let value = weight ? store.displayWeight(raw) : raw
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline)
                    Text("\(best.date.formatted(date: .abbreviated, time: .omitted)) · \(store.displayWeight(best.set.weightKg).gymNumber) \(store.weightUnit) × \(best.set.reps)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(value.gymNumber) \(unit)").font(.subheadline.bold()).multilineTextAlignment(.trailing)
            }
        }
    }

    private func exerciseName(_ id: String) -> String {
        store.data.exercises.first(where: { $0.id == id })?.name
            ?? entries.first(where: { $0.exerciseID == id })?.exerciseName ?? "Ejercicio"
    }

    private var muscleCard: some View {
        let muscles = TrainingMetrics.muscleDistribution(sessions, exercises: store.data.exercises)
        return GymCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribución muscular").font(.headline)
                if muscles.isEmpty {
                    Text("Añade porcentajes musculares a tus ejercicios para ver la distribución.").foregroundStyle(.secondary)
                } else {
                    Chart(muscles, id: \.name) { muscle in
                        BarMark(x: .value("Series ponderadas", muscle.sets), y: .value("Músculo", muscle.name))
                            .foregroundStyle(Theme.accent)
                            .annotation(position: .trailing) { Text(muscle.sets.gymNumber).font(.caption) }
                    }.frame(height: max(140, Double(muscles.count) * 30))
                }
                Text("Cada serie efectiva se reparte según los porcentajes del catálogo. Una serie con un 60 % de pecho suma 0,6 series de pecho.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
