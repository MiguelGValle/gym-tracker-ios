# Internal integration contract

Native SwiftUI iOS 16+, Swift 5 language mode. Models.swift is the shared source of truth. Every model is a value type, Codable and Equatable. Dates are Date; disk JSON uses ISO8601. No third-party packages.

GymStore: @MainActor final class GymStore: ObservableObject.
- @Published private(set) var data: GymData
- @Published var errorMessage: String?
- init(directory: URL? = nil) // nil uses Application Support
- func mutate(_ change: (inout GymData) -> Void) // transactional: validate/write atomically then publish; error shown if persistence fails
- func startWorkout(routine: Routine? = nil) // leaves existing draft intact
- func finishWorkout(_ workout: WorkoutSession, routine: Routine? = nil) throws // validates, keeps completed sets only, persists atomically with optional routine, clears draft
- func previousSet(exerciseId: String, index: Int) -> WorkoutSet?
- func exerciseName(_ id: String) -> String
- var weightUnit: String; func displayWeight(_ kg: Double) -> Double; func kgWeight(_ displayed: Double) -> Double
- func backupData() throws -> Data
- func previewImport(_ raw: Data) throws -> GymData // native or Android backup; no mutation
- func restore(_ incoming: GymData) throws // merge by IDs/dates; fail if active draft
- func previewHevyCSV(_ text: String) throws -> ImportPreview
- func importHevy(_ preview: ImportPreview) throws
ImportPreview: sessions: [WorkoutSession], exercises: [Exercise], warnings: [String], summary: String.

Root implements shared UI Theme.accent/background/surface; GymCard<Content>(@ViewBuilder content: () -> Content); MetricTile(title: String, value: String, symbol: String); EmptyState(title: String, message: String, symbol: String); ExercisePicker(onSelect: (Exercise) -> Void), dismisses after single choice; DecimalField(title: String, value: Binding<Double>); optional fields implement locally as needed.

Workout agent provides TrainingView() with NavigationStack, ActiveWorkoutView() with its own NavigationStack for sheet, RoutineEditor(routine: Routine) for sheet, uses environmentObject GymStore. Root presents active workout via .sheet based on a user button (don't automatically present merely because draft non-nil).

Progress agent provides HistoryView(), ProgressViewScreen(), NutritionView(), MeasurementsView(), each with NavigationStack except MeasurementsView is a pushed view. May implement private subviews and own calculation helpers. Reads store.data, writes with store.mutate. To repeat sessions set draft through mutate preserving completed=false and new IDs, never overwrite active draft.

Root implements tab shell (Inicio, Entrenar, Historial, Progreso, Perfil), home dashboard, catalog/editor, ProfileView with navigation to NutritionView/MeasurementsView, photos, file import/export UI, notifications integration if not owned by workout agent.
