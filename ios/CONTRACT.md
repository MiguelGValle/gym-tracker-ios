# Internal integration contract

Native SwiftUI iOS 16+, Swift 5 language mode. Models.swift is the shared source of truth. Every model is a value type, Codable and Equatable. Dates are Date; disk JSON uses ISO8601. No third-party packages.

GymStore: @MainActor final class GymStore: ObservableObject.
- @Published private(set) var data: GymData
- @Published var errorMessage: String?
- init(directory: URL? = nil) // nil uses Application Support
- func mutate(_ change: (inout GymData) -> Void) // transactional: validate/write atomically then publish; error shown if persistence fails
- func startWorkout(routine: Routine? = nil) // leaves existing draft intact; new workout starts one fresh set per exercise
- func repeatWorkout(_ original: WorkoutSession) // leaves existing draft intact; copies one fresh set per exercise and today's date
- func finishWorkout(_ workout: WorkoutSession, routine: Routine? = nil) throws // validates and persists every present set atomically with optional routine; clears the draft only on success
- func previousSet(exerciseId: String, index: Int) -> WorkoutSet?
- func exerciseName(_ id: String) -> String
- var weightUnit: String; func displayWeight(_ kg: Double) -> Double; func kgWeight(_ displayed: Double) -> Double
- func backupData() throws -> Data
- func previewImport(_ raw: Data) throws -> GymData // native or Android backup; no mutation
- func restore(_ incoming: GymData) throws // merge by IDs/dates; fail if active draft
- func previewHevyCSV(_ text: String) throws -> ImportPreview
- func importHevy(_ preview: ImportPreview) throws
ImportPreview: sessions: [WorkoutSession], exercises: [Exercise], warnings: [String], summary: String.

The completed flag is retained only for backup compatibility. Counts, volume, progress and CSV export include every present set. The optional failure checkbox records setType=failure and never decides whether a set is saved. New sets reset failure to normal while preserving warmup/dropset and training values. Failed saves retain both history and draft.

Root implements shared UI Theme.accent/background/surface; GymCard<Content>(@ViewBuilder content: () -> Content); MetricTile(title: String, value: String, symbol: String); EmptyState(title: String, message: String, symbol: String); ExercisePicker(onSelect: (Exercise) -> Void), dismisses after single choice; DecimalField(title: String, value: Binding<Double>); optional fields implement locally as needed.

WorkoutTemplates.nextSet(from:) copies values with a fresh ID, nil importKey/durationSeconds and completed=false. WorkoutTemplates.exercises(from:singleSet:) clears restSeconds, refreshes exercise/superset IDs and can create exactly one set per exercise. These helpers apply only to new entries; loading/editing legacy history or resuming a draft preserves its sets and optional legacy times. New WorkoutSession.startedAt is today's civil date at local midnight and endedAt stays nil when finishing. Optional workoutDate stores the independent YYYY-MM-DD date; the date computed property reads it or falls back to startedAt for legacy files, and editing date never modifies retained timestamps. UI/statistics use date and have no session/rest/set timers or time statistics. ReplaceableNumberField(title:value:integer:) uses UITextField to select all on every tap; weight/repetition entries use this component.

HevyCSV.export(_:catalog:) retains original IDs in optional session_id/set_id/exercise_block_id columns and exports the independent workout_date. HevyCSV.preview respects those columns when present, preserving literal IDs (including their case) and keeping two sessions on the same day separate; Hevy identity hashes remain unchanged when those columns are absent. Session merging deduplicates by either a set's ID or its importKey.

Workout agent provides TrainingView() with NavigationStack, ActiveWorkoutView() with its own NavigationStack for sheet, RoutineEditor(routine: Routine) for sheet, uses environmentObject GymStore. Root presents active workout via .sheet based on a user button (don't automatically present merely because draft non-nil).

Progress agent provides HistoryView(), ProgressViewScreen(), NutritionView(), MeasurementsView(), each with NavigationStack except MeasurementsView is a pushed view. May implement private subviews and own calculation helpers. Reads store.data, writes with store.mutate. To repeat sessions use store.repeatWorkout, never overwrite an active draft.

Root implements tab shell (Inicio, Entrenar, Historial, Progreso, Perfil), home dashboard, catalog/editor, ProfileView with navigation to NutritionView/MeasurementsView, photos and file import/export UI. LegacyRestCleanup cancels old rest notifications and clears only their UserDefaults scheduling keys at launch.
