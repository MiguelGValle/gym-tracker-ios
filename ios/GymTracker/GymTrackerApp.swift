import SwiftUI

@main
struct GymTrackerApp: App {
    @StateObject private var store = GymStore()
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
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        GymCard {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.65).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 36)).foregroundStyle(Theme.accent)
            Text(title).font(.headline)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
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
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: GymStore
    @State private var showWorkout = false
    private var recent: [WorkoutSession] { store.data.sessions.sorted { $0.startedAt > $1.startedAt } }
    private var todayLog: NutritionLog? { store.data.nutrition.first { Calendar.current.isDateInToday($0.date) } }
    private var week: [WorkoutSession] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return recent.filter { interval.contains($0.startedAt) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Tu siguiente\nmejor versión.").font(.largeTitle.bold())
                    GymCard {
                        Label(store.data.draft == nil ? "TODO EMPIEZA CON UNA SERIE" : "SESIÓN EN CURSO", systemImage: "bolt.fill")
                            .font(.caption.bold()).foregroundStyle(Theme.accent)
                        Text(store.data.draft?.title ?? "Vamos a entrenar").font(.title2.bold())
                        Text(store.data.draft == nil ? "Registra tus series y sigue tu progreso." : "Tu entrenamiento está guardado. Continúa cuando quieras.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button {
                            store.startWorkout()
                            if store.data.draft != nil { showWorkout = true }
                        } label: {
                            Label(store.data.draft == nil ? "Iniciar entrenamiento" : "Continuar entrenamiento", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                    }
                    Text("Esta semana").font(.headline)
                    HStack(alignment: .top) {
                        MetricTile(title: "Sesiones", value: String(week.count), symbol: "dumbbell.fill")
                        MetricTile(title: "Volumen", value: "\(store.displayWeight(week.reduce(0) { $0 + $1.volume }).gymNumber) \(store.weightUnit)", symbol: "chart.bar.fill")
                    }
                    NavigationLink { NutritionView() } label: {
                        GymCard {
                            HStack { Label("Nutrición de hoy", systemImage: "fork.knife"); Spacer(); Image(systemName: "chevron.right") }
                            HStack {
                                Text("\(todayLog?.calories ?? 0) kcal").font(.title3.bold())
                                Spacer()
                                Text("\(todayLog?.protein ?? 0) g proteína").foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(todayLog?.calories ?? 0), total: Double(max(1, store.data.profile.calorieGoal)))
                        }
                    }.buttonStyle(.plain)
                    Text("Último entrenamiento").font(.headline)
                    if let last = recent.first {
                        GymCard {
                            Text(last.title).font(.headline)
                            Text(last.startedAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                            Text("\(last.completedSets) series\(last.endedAt == nil ? "" : " · \(Int(last.duration / 60)) min") · \(store.displayWeight(last.volume).gymNumber) \(store.weightUnit)")
                                .font(.subheadline)
                        }
                    } else {
                        EmptyState(title: "Tu historia empieza aquí", message: "Los entrenamientos que completes aparecerán en el historial y en tus gráficas.", symbol: "chart.line.uptrend.xyaxis")
                    }
                }.padding(20)
            }
            .background(Theme.background)
            .navigationTitle("GYM TRACKER").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink { ExerciseCatalogView() } label: { Image(systemName: "square.grid.2x2").accessibilityLabel("Catálogo de ejercicios") } }
            .sheet(isPresented: $showWorkout) { ActiveWorkoutView() }
        }
    }
}
