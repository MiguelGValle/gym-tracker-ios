import SwiftUI

@main
struct GymTrackerApp: App {
    @StateObject private var store: GymStore
    init() {
        let noChecksUITest = ProcessInfo.processInfo.arguments.contains("-ui-testing-no-checks")
        let testingDirectory = noChecksUITest || ProcessInfo.processInfo.arguments.contains("-ui-testing-training")
            ? FileManager.default.temporaryDirectory.appendingPathComponent("TrainingUITest-\(UUID().uuidString)", isDirectory: true)
            : nil
        let gymStore = GymStore(directory: testingDirectory)
        if noChecksUITest {
            let names = ["Sentadilla barra", "Press banca barra", "Remo polea sentado"]
            gymStore.mutate { data in
                var workout = WorkoutSession(id: "ui-workout-all-sets", title: "Todas las series", workoutDate: GymDate.dayKey(Date()))
                workout.exercises = names.enumerated().map { index, name in
                    let exercise = data.exercises.first { $0.name == name }!
                    return WorkoutExercise(id: "ui-exercise-\(index + 1)", exerciseId: exercise.id, exerciseName: name,
                        sets: [8, 10].enumerated().map { setIndex, reps in
                            WorkoutSet(id: "ui-set-\(index + 1)-\(setIndex + 1)", reps: reps, weightKg: Double(40 + index * 10), completed: false)
                        })
                }
                data.sessions = []
                data.draft = workout
            }
        }
        _store = StateObject(wrappedValue: gymStore)
        LegacyRestCleanup.clear()
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .alert("No se pudo completar la operación", isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )) { Button("Entendido") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        }
    }
}

enum Theme {
    static let accent = Color(red: 1, green: 0.42, blue: 0)
    static let background = Color(red: 0.047, green: 0.051, blue: 0.059)
    static let surface = Color(red: 0.09, green: 0.095, blue: 0.11)
}

struct GymCard<Content: View>: View {
    private let content: Content
    private let emphasized: Bool
    init(emphasized: Bool = false, @ViewBuilder content: () -> Content) {
        self.emphasized = emphasized
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(
                                colors: [emphasized ? Theme.accent.opacity(0.08) : Color.primary.opacity(0.035), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [emphasized ? Theme.accent.opacity(0.3) : Color.primary.opacity(0.1), Color.primary.opacity(0.025)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
    }
}

struct GymPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func gymScreenStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        GymCard {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(value).font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit().tracking(-0.6).minimumScaleFactor(0.65).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.accent.opacity(0.14), lineWidth: 1) }
            Text(title).font(.system(.headline, design: .rounded)).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
        }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 36)
    }
}

struct DecimalField: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .accessibilityLabel(title)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }
            TrainingView().tabItem { Label("Entrenar", systemImage: "dumbbell.fill") }
            HistoryView().tabItem { Label("Historial", systemImage: "calendar") }
            ProgressViewScreen().tabItem { Label("Progreso", systemImage: "chart.xyaxis.line") }
            ProfileView().tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: GymStore
    @State private var showWorkout = false
    private var recent: [WorkoutSession] { WorkoutHistory.recentFirst(store.data.sessions) }
    private var todayLog: NutritionLog? { store.data.nutrition.first { Calendar.current.isDateInToday($0.date) } }
    private var week: [WorkoutSession] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return recent.filter { interval.contains($0.date) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                    Text("Tu siguiente\nmejor versión.")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy)).tracking(-1.2).lineSpacing(1)
                    GymCard(emphasized: true) {
                        Label(store.data.draft == nil ? "TODO EMPIEZA CON UNA SERIE" : "SESIÓN EN CURSO", systemImage: "bolt.fill")
                            .font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(Theme.accent)
                        Text(store.data.draft?.title ?? "Vamos a entrenar").font(.system(.title2, design: .rounded).weight(.bold))
                        Text(store.data.draft == nil ? "Registra tus series y sigue tu progreso." : "Tu entrenamiento está guardado. Continúa cuando quieras.")
                            .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                        Button {
                            store.startWorkout()
                            if store.data.draft != nil { showWorkout = true }
                        } label: {
                            Label(store.data.draft == nil ? "Iniciar entrenamiento" : "Continuar entrenamiento", systemImage: "play.fill")
                        }.buttonStyle(GymPrimaryButtonStyle()).padding(.top, 4)
                    }
                    Text("Esta semana").font(.system(.title3, design: .rounded).weight(.bold)).padding(.top, 4)
                    HStack(alignment: .top, spacing: 12) {
                        MetricTile(title: "Sesiones", value: String(week.count), symbol: "dumbbell.fill")
                        MetricTile(title: "Volumen", value: "\(store.displayWeight(week.reduce(0) { $0 + $1.volume }).gymNumber) \(store.weightUnit)", symbol: "chart.bar.fill")
                    }
                    NavigationLink { NutritionView() } label: {
                        GymCard {
                            HStack {
                                Label("Nutrición de hoy", systemImage: "fork.knife").font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("\(todayLog?.calories ?? 0) kcal").font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                                Spacer()
                                Text("\(todayLog?.protein ?? 0) g proteína").font(.subheadline).foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(todayLog?.calories ?? 0), total: Double(max(1, store.data.profile.calorieGoal)))
                        }
                    }.buttonStyle(.plain)
                    Text("Último entrenamiento").font(.system(.title3, design: .rounded).weight(.bold)).padding(.top, 4)
                    if let last = recent.first {
                        GymCard {
                            Text(last.title).font(.headline)
                            Text(last.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            Text("\(last.completedSets) series · \(store.displayWeight(last.volume).gymNumber) \(store.weightUnit)")
                                .font(.subheadline)
                        }
                    } else {
                        EmptyState(title: "Tu historia empieza aquí", message: "Los entrenamientos que completes aparecerán en el historial y en tus gráficas.", symbol: "chart.line.uptrend.xyaxis")
                    }
                }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
            }
            .gymScreenStyle()
            .navigationTitle("GYM TRACKER").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink { ExerciseCatalogView() } label: { Image(systemName: "square.grid.2x2").accessibilityLabel("Catálogo de ejercicios") } }
            .sheet(isPresented: $showWorkout) { ActiveWorkoutView() }
        }
    }
}
