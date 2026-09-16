import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var store: GymStore
    @State private var editor: Routine?
    @State private var showWorkout = false
    @State private var showFolderEditor = false
    @State private var editedFolder: RoutineFolder?
    @State private var folderName = ""
    @State private var deletedRoutine: Routine?
    @State private var deletedFolder: RoutineFolder?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.startWorkout()
                        showWorkout = store.data.draft != nil
                    } label: {
                        Label(store.data.draft == nil ? "Iniciar entrenamiento libre" : "Continuar entrenamiento", systemImage: "play.fill")
                            .font(.headline).padding(.vertical, 10)
                    }
                    if let draft = store.data.draft {
                        Text("\(draft.title) · \(draft.completedSets) series completadas")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if store.data.routines.isEmpty && store.data.folders.isEmpty {
                    EmptyState(title: "Tus rutinas", message: "Crea una rutina con tus ejercicios y series para repetirla cada semana.", symbol: "list.bullet.clipboard")
                        .listRowBackground(Color.clear)
                }
                routineSection(title: "Sin carpeta", routines: store.data.routines.filter { $0.folderId == nil })
                ForEach(store.data.folders) { folder in
                    Section {
                        let routines = store.data.routines.filter { $0.folderId == folder.id }
                        if routines.isEmpty { Text("Carpeta vacía").foregroundStyle(.secondary) }
                        ForEach(routines) { routine in routineRow(routine) }
                    } header: {
                        HStack {
                            Label(folder.name, systemImage: "folder")
                            Spacer()
                            Menu {
                                Button("Cambiar nombre") {
                                    editedFolder = folder
                                    folderName = folder.name
                                    showFolderEditor = true
                                }
                                Button("Eliminar carpeta", role: .destructive) { deletedFolder = folder }
                            } label: { Image(systemName: "ellipsis") }
                            .accessibilityLabel("Opciones de \(folder.name)")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Entrenar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { editor = Routine() } label: { Label("Nueva rutina", systemImage: "list.bullet.clipboard") }
                        Button {
                            editedFolder = nil
                            folderName = ""
                            showFolderEditor = true
                        } label: { Label("Nueva carpeta", systemImage: "folder.badge.plus") }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Crear rutina o carpeta")
                }
            }
            .sheet(item: $editor) { RoutineEditor(routine: $0) }
            .sheet(isPresented: $showWorkout) { ActiveWorkoutView() }
            .alert(editedFolder == nil ? "Nueva carpeta" : "Cambiar nombre", isPresented: $showFolderEditor) {
                TextField("Nombre", text: $folderName)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") { saveFolder() }.disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .confirmationDialog("Eliminar rutina", isPresented: Binding(get: { deletedRoutine != nil }, set: { if !$0 { deletedRoutine = nil } }), titleVisibility: .visible) {
                Button("Eliminar rutina", role: .destructive) {
                    guard let routine = deletedRoutine else { return }
                    store.mutate { $0.routines.removeAll { $0.id == routine.id } }
                    deletedRoutine = nil
                }
            } message: { Text("Los entrenamientos guardados se conservarán.") }
            .confirmationDialog("Eliminar carpeta", isPresented: Binding(get: { deletedFolder != nil }, set: { if !$0 { deletedFolder = nil } }), titleVisibility: .visible) {
                Button("Eliminar carpeta", role: .destructive) {
                    guard let folder = deletedFolder else { return }
                    store.mutate { data in
                        data.folders.removeAll { $0.id == folder.id }
                        for index in data.routines.indices where data.routines[index].folderId == folder.id {
                            data.routines[index].folderId = nil
                        }
                    }
                    deletedFolder = nil
                }
            } message: { Text("Sus rutinas pasarán a «Sin carpeta».") }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder private func routineSection(title: String, routines: [Routine]) -> some View {
        if !routines.isEmpty {
            Section(title) { ForEach(routines) { routine in routineRow(routine) } }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 14) {
            Button { editor = routine } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(routine.name).font(.headline).foregroundStyle(.primary)
                    Text("\(routine.exercises.count) ejercicios · \(routine.exercises.reduce(0) { $0 + $1.sets.count }) series")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button {
                store.startWorkout(routine: routine)
                showWorkout = store.data.draft != nil
            } label: { Image(systemName: "play.circle.fill").font(.title) }
            .buttonStyle(.borderless)
            .accessibilityLabel(store.data.draft == nil ? "Iniciar \(routine.name)" : "Continuar entrenamiento activo")
            Menu {
                Button { editor = routine } label: { Label("Editar", systemImage: "pencil") }
                Button {
                    var copy = routine
                    copy.id = UUID().uuidString
                    copy.name += " (copia)"
                    copy.exercises = freshExercises(copy.exercises)
                    store.mutate { $0.routines.append(copy) }
                } label: { Label("Duplicar", systemImage: "doc.on.doc") }
                Button("Eliminar", role: .destructive) { deletedRoutine = routine }
            } label: { Image(systemName: "ellipsis").padding(.vertical, 10) }
            .accessibilityLabel("Opciones de \(routine.name)")
        }.padding(.vertical, 6)
    }

    private func saveFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.mutate { data in
            if let folder = editedFolder, let index = data.folders.firstIndex(where: { $0.id == folder.id }) {
                data.folders[index].name = name
            } else {
                data.folders.append(RoutineFolder(name: name))
            }
        }
    }
}

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let draft = store.data.draft {
                ActiveWorkoutContent(workout: draft)
            } else {
                EmptyState(title: "Sin entrenamiento activo", message: "Inicia una rutina o un entrenamiento libre.", symbol: "dumbbell")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            }
        }
        .tint(Theme.accent)
    }
}

private struct ActiveWorkoutContent: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var timer = RestTimer.shared
    @State private var workout: WorkoutSession
    @State private var showPicker = false
    @State private var replacementID: String?
    @State private var replacementChoice: Exercise?
    @State private var showReplacementConfirmation = false
    @State private var showDiscard = false
    @State private var showFinish = false
    @State private var showDetails = false
    @State private var finishing = false
    @State private var error: String?
    @State private var saveWarning: String?

    init(workout: WorkoutSession) { _workout = State(initialValue: workout) }

    var body: some View {
        List {
            if let saveWarning {
                Section {
                    Label(saveWarning, systemImage: "exclamationmark.triangle")
                        .font(.subheadline).foregroundStyle(.orange)
                    Button("Reintentar guardado") { saveDraft() }
                } header: { Text("Cambios sin guardar") }
            }
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Label(elapsedString(context.date.timeIntervalSince(workout.startedAt)), systemImage: "clock")
                            .monospacedDigit()
                        Spacer()
                        Text("\(workout.completedSets) series").foregroundStyle(.secondary)
                    }.font(.headline)
                }
                if workout.routineId != nil { Text("Entrenamiento de rutina").font(.caption).foregroundStyle(.secondary) }
                Button("Editar título, inicio y duración") { showDetails = true }
                TextField("Notas del entrenamiento", text: $workout.notes, axis: .vertical).lineLimit(2...5)
            }
            if timer.deadline != nil {
                Section { RestTimerPanel(timer: timer) }
            }
            if workout.exercises.isEmpty {
                EmptyState(title: "Añade tu primer ejercicio", message: "Registra peso, repeticiones y las series que completes.", symbol: "dumbbell")
                    .listRowBackground(Color.clear)
            }
            ForEach($workout.exercises) { $exercise in
                Section {
                    ExerciseTrainingEditor(
                        exercise: $exercise,
                        position: workout.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0,
                        supersetName: supersetName(for: exercise, in: workout.exercises),
                        active: true,
                        canMoveDown: workout.exercises.last?.id != exercise.id,
                        onReplace: { replacementID = exercise.id; showPicker = true },
                        onRemove: { removeExercise(exercise.id, from: &workout.exercises) },
                        onMove: { direction in moveExercise(exercise.id, direction: direction) },
                        onSuperset: { toggleSuperset(exercise.id) },
                        onComplete: { timer.start(seconds: exercise.restSeconds, exercise: store.exerciseName(exercise.exerciseId)) }
                    )
                }
            }
            Section {
                Button { replacementID = nil; showPicker = true } label: { Label("Añadir ejercicio", systemImage: "plus") }
                Button("Descartar entrenamiento", role: .destructive) { showDiscard = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { if saveDraft() { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Finalizar") {
                    if workout.completedSets == 0 { error = "Completa al menos una serie antes de guardar el entrenamiento." }
                    else { showFinish = true }
                }.fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: { showReplacementConfirmation = replacementChoice != nil }) {
            ExercisePicker { selected in selectExercise(selected) }
        }
        .confirmationDialog("Reemplazar ejercicio", isPresented: $showReplacementConfirmation, titleVisibility: .visible) {
            Button("Reemplazar y marcar series pendientes") {
                if let selected = replacementChoice { applyReplacement(selected) }
                replacementChoice = nil
            }
            Button("Cancelar", role: .cancel) { replacementChoice = nil; replacementID = nil }
        } message: { Text("Las series completadas de este ejercicio pasarán a pendientes para que puedas registrar el ejercicio nuevo.") }
        .sheet(isPresented: $showDetails) { WorkoutDetailsEditor(workout: $workout) }
        .sheet(isPresented: $showFinish) {
            FinishWorkoutSheet(workout: workout) { routineName in try finish(routineName: routineName) }
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("¿Descartar este entrenamiento?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Descartar entrenamiento", role: .destructive) {
                finishing = true
                store.mutate { $0.draft = nil }
                if store.data.draft == nil { timer.cancel(); dismiss() }
                else {
                    finishing = false
                    error = store.errorMessage ?? "No se pudo descartar el entrenamiento."
                    store.errorMessage = nil
                }
            }
        } message: { Text("Se perderán las series y notas de este entrenamiento.") }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Aceptar", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .onChange(of: workout) { _ in saveDraft() }
        .onDisappear { saveDraft() }
        .interactiveDismissDisabled(saveWarning != nil)
    }

    @discardableResult private func saveDraft() -> Bool {
        guard !finishing, store.data.draft?.id == workout.id else { return true }
        if store.data.draft == workout { saveWarning = nil; return true }
        store.mutate { $0.draft = workout }
        if store.data.draft == workout { saveWarning = nil; return true }
        saveWarning = store.errorMessage ?? "No se pudieron guardar los últimos cambios."
        store.errorMessage = nil
        return false
    }

    private func selectExercise(_ selected: Exercise) {
        if let replacementID, let index = workout.exercises.firstIndex(where: { $0.id == replacementID }) {
            if workout.exercises[index].exerciseId == selected.id { self.replacementID = nil; return }
            if workout.exercises[index].sets.contains(where: \.completed) {
                replacementChoice = selected
                return
            }
            applyReplacement(selected)
        } else {
            workout.exercises.append(WorkoutExercise(exerciseId: selected.id, exerciseName: selected.name))
        }
        replacementID = nil
    }

    private func applyReplacement(_ selected: Exercise) {
        guard let replacementID, let index = workout.exercises.firstIndex(where: { $0.id == replacementID }) else { return }
        workout.exercises[index].exerciseId = selected.id
        workout.exercises[index].exerciseName = selected.name
        for set in workout.exercises[index].sets.indices { workout.exercises[index].sets[set].completed = false }
        self.replacementID = nil
    }

    private func moveExercise(_ id: String, direction: Int) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard workout.exercises.indices.contains(target) else { return }
        workout.exercises.swapAt(index, target)
    }

    private func toggleSuperset(_ id: String) { linkSuperset(id, in: &workout.exercises) }

    private func finish(routineName: String?) throws {
        var completed = workout
        completed.endedAt = Date()
        finishing = true
        do {
            let routine = routineName.map { Routine(name: $0, notes: workout.notes, exercises: freshExercises(workout.exercises)) }
            try store.finishWorkout(completed, routine: routine)
            timer.cancel()
            showFinish = false
            dismiss()
        } catch {
            finishing = false
            throw error
        }
    }
}

struct RoutineEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State private var routine: Routine
    @State private var showPicker = false
    @State private var replacementID: String?
    @State private var showDiscard = false
    @State private var saveError: String?
    private let original: Routine

    init(routine: Routine) {
        original = routine
        _routine = State(initialValue: routine)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Rutina") {
                    TextField("Nombre", text: $routine.name)
                    Picker("Carpeta", selection: $routine.folderId) {
                        Text("Sin carpeta").tag(String?.none)
                        ForEach(store.data.folders) { Text($0.name).tag(Optional($0.id)) }
                    }
                    TextField("Notas de la rutina", text: $routine.notes, axis: .vertical).lineLimit(2...5)
                }
                ForEach($routine.exercises) { $exercise in
                    Section {
                        ExerciseTrainingEditor(
                            exercise: $exercise,
                            position: routine.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0,
                            supersetName: supersetName(for: exercise, in: routine.exercises),
                            active: false,
                            canMoveDown: routine.exercises.last?.id != exercise.id,
                            onReplace: { replacementID = exercise.id; showPicker = true },
                            onRemove: { removeExercise(exercise.id, from: &routine.exercises) },
                            onMove: { direction in moveExercise(exercise.id, direction: direction) },
                            onSuperset: { linkSuperset(exercise.id, in: &routine.exercises) },
                            onComplete: {}
                        )
                    }
                }
                Section {
                    Button { replacementID = nil; showPicker = true } label: { Label("Añadir ejercicio", systemImage: "plus") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Editar rutina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { if routine == original { dismiss() } else { showDiscard = true } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePicker { selected in
                    if let replacementID, let index = routine.exercises.firstIndex(where: { $0.id == replacementID }) {
                        routine.exercises[index].exerciseId = selected.id
                        routine.exercises[index].exerciseName = selected.name
                    } else {
                        routine.exercises.append(WorkoutExercise(exerciseId: selected.id, exerciseName: selected.name))
                    }
                    replacementID = nil
                }
            }
            .confirmationDialog("¿Descartar los cambios?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Descartar cambios", role: .destructive) { dismiss() }
            }
            .interactiveDismissDisabled(routine != original)
            .alert("No se pudo guardar", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("Aceptar", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
        .tint(Theme.accent)
    }

    private func moveExercise(_ id: String, direction: Int) {
        guard let index = routine.exercises.firstIndex(where: { $0.id == id }), routine.exercises.indices.contains(index + direction) else { return }
        routine.exercises.swapAt(index, index + direction)
    }

    private func save() {
        routine.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        for exercise in routine.exercises.indices {
            for set in routine.exercises[exercise].sets.indices { routine.exercises[exercise].sets[set].completed = false }
        }
        store.mutate { data in
            if let index = data.routines.firstIndex(where: { $0.id == routine.id }) { data.routines[index] = routine }
            else { data.routines.append(routine) }
        }
        if store.data.routines.first(where: { $0.id == routine.id }) == routine { dismiss() }
        else {
            saveError = store.errorMessage ?? "No se pudieron guardar los cambios de la rutina."
            store.errorMessage = nil
        }
    }
}

private struct ExerciseTrainingEditor: View {
    @EnvironmentObject private var store: GymStore
    @Binding var exercise: WorkoutExercise
    let position: Int
    let supersetName: String?
    let active: Bool
    let canMoveDown: Bool
    let onReplace: () -> Void
    let onRemove: () -> Void
    let onMove: (Int) -> Void
    let onSuperset: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let supersetName {
                Label(supersetName, systemImage: "link").font(.caption).foregroundStyle(Theme.accent)
            }
            TextField("Notas del ejercicio", text: $exercise.notes, axis: .vertical).font(.subheadline).lineLimit(1...4)
            Stepper(value: $exercise.restSeconds, in: 0...1800, step: 15) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text(exercise.restSeconds == 0 ? "Sin descanso automático" : "Descanso: \(elapsedString(Double(exercise.restSeconds)))")
                }.font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach($exercise.sets) { $set in
                let index = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                WorkoutSetEditor(set: $set, number: index + 1, previous: store.previousSet(exerciseId: exercise.exerciseId, index: index), active: active, onComplete: onComplete) {
                    exercise.sets.removeAll { $0.id == set.id }
                }
            }
            Button {
                var next = exercise.sets.last ?? WorkoutSet()
                next.id = UUID().uuidString
                next.importKey = nil
                next.completed = false
                exercise.sets.append(next)
            } label: { Label("Añadir serie", systemImage: "plus") }.font(.subheadline)
        }.padding(.vertical, 8)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("\(position + 1). \(exercise.exerciseName.isEmpty ? store.exerciseName(exercise.exerciseId) : exercise.exerciseName)")
                .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button(action: onReplace) { Label("Reemplazar ejercicio", systemImage: "arrow.triangle.2.circlepath") }
                Button { onMove(-1) } label: { Label("Subir", systemImage: "arrow.up") }.disabled(position == 0)
                Button { onMove(1) } label: { Label("Bajar", systemImage: "arrow.down") }.disabled(!canMoveDown)
                Button(action: onSuperset) { Label(exercise.supersetId == nil ? "Unir en superserie con anterior" : "Separar de superserie", systemImage: "link") }
                    .disabled(position == 0 && exercise.supersetId == nil)
                Button(store.weightUnit == "kg" ? "Mostrar peso en lb" : "Mostrar peso en kg") {
                    store.mutate { $0.profile.usePounds.toggle() }
                }
                Button("Eliminar ejercicio", role: .destructive, action: onRemove)
            } label: { Image(systemName: "ellipsis").padding(.leading, 8).padding(.vertical, 4) }
            .accessibilityLabel("Opciones del ejercicio")
        }
    }
}

private struct WorkoutSetEditor: View {
    @EnvironmentObject private var store: GymStore
    @Binding var set: WorkoutSet
    let number: Int
    let previous: WorkoutSet?
    let active: Bool
    let onComplete: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Serie \(number)").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Tipo", selection: $set.setType) {
                    Text("Normal").tag("normal")
                    Text("Calentamiento").tag("warmup")
                    Text("Descendente").tag("dropset")
                    Text("Al fallo").tag("failure")
                }.pickerStyle(.menu).labelsHidden()
                Menu {
                    Button("Eliminar serie", role: .destructive, action: onRemove)
                } label: { Image(systemName: "ellipsis").padding(.vertical, 5) }
                .accessibilityLabel("Opciones de la serie \(number)")
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.weightUnit).font(.caption).foregroundStyle(.secondary)
                    DecimalField(title: "Peso", value: Binding(get: { store.displayWeight(set.weightKg) }, set: { set.weightKg = max(0, store.kgWeight($0)) }))
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps").font(.caption).foregroundStyle(.secondary)
                    TextField("Reps", value: Binding(get: { set.reps }, set: { set.reps = max(0, $0) }), format: .number)
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                }
                if active {
                    Button {
                        set.completed.toggle()
                        if set.completed { onComplete() }
                    } label: {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title).foregroundStyle(set.completed ? Color.green : Color.secondary)
                            .frame(width: 42, height: 36)
                    }.buttonStyle(.borderless)
                        .disabled(!set.completed && set.reps == 0 && (set.durationSeconds ?? 0) == 0 && (set.distanceKm ?? 0) == 0)
                        .accessibilityLabel(set.completed ? "Marcar serie \(number) como pendiente" : "Completar serie \(number)")
                }
            }
            if let previous {
                Text(previousDescription(previous)).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("RPE, duración y distancia") {
                VStack(spacing: 10) {
                    optionalDecimal("RPE (1–10)", value: $set.rpe, range: 1...10)
                    HStack {
                        Text("Duración (seg.)").font(.subheadline)
                        Spacer()
                        TextField("—", text: Binding(get: { set.durationSeconds.map(String.init) ?? "" }, set: { value in
                            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleaned.isEmpty { set.durationSeconds = nil }
                            else if let parsed = Int(cleaned) { set.durationSeconds = max(0, parsed) }
                        })).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                    optionalDecimal("Distancia (km)", value: $set.distanceKm, range: 0...10000)
                }.padding(.top, 8)
            }.font(.caption)
        }
        .padding(12)
        .background(set.completed && active ? Color.green.opacity(0.09) : Theme.background.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: set) { value in
            if value.completed && value.reps == 0 && (value.durationSeconds ?? 0) == 0 && (value.distanceKm ?? 0) == 0 {
                set.completed = false
            }
        }
    }

    private func optionalDecimal(_ title: String, value: Binding<Double?>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            OptionalWorkoutDecimalField(title: "—", value: value, range: range)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func previousDescription(_ previous: WorkoutSet) -> String {
        var text = "Anterior: \(store.displayWeight(previous.weightKg).gymNumber) \(store.weightUnit) × \(previous.reps)"
        if let rpe = previous.rpe { text += " · RPE \(rpe.gymNumber)" }
        if let seconds = previous.durationSeconds { text += " · \(elapsedString(Double(seconds)))" }
        if let distance = previous.distanceKm { text += " · \(distance.gymNumber) km" }
        return text
    }
}

private struct OptionalWorkoutDecimalField: View {
    let title: String
    @Binding var value: Double?
    let range: ClosedRange<Double>
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .onAppear { text = formatted(value) }
            .onChange(of: text) { newValue in
                let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.isEmpty { value = nil }
                else if let number = Double(clean.replacingOccurrences(of: ",", with: ".")), number.isFinite {
                    value = min(range.upperBound, max(range.lowerBound, number))
                }
            }
            .onChange(of: focused) { isFocused in if !isFocused { text = formatted(value) } }
            .onChange(of: value) { newValue in if !focused { text = formatted(newValue) } }
    }

    private func formatted(_ value: Double?) -> String {
        value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...3))) } ?? ""
    }
}

private struct WorkoutDetailsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: WorkoutSession

    var body: some View {
        NavigationStack {
            Form {
                Section("Entrenamiento") {
                    TextField("Título", text: $workout.title)
                    DatePicker("Inicio", selection: $workout.startedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Stepper(value: Binding(get: { max(0, Int(Date().timeIntervalSince(workout.startedAt) / 60)) }, set: { minutes in
                        workout.startedAt = Date().addingTimeInterval(-Double(minutes) * 60)
                        workout.endedAt = nil
                    }), in: 0...10080, step: 1) {
                        Text("Duración: \(max(0, Int(Date().timeIntervalSince(workout.startedAt) / 60))) min")
                    }
                } footer: { Text("Al ajustar la duración se recalcula la hora de inicio. El reloj sigue contando hasta finalizar.") }
            }
            .navigationTitle("Datos del entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }
}

private struct FinishWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutSession
    let onSave: (String?) throws -> Void
    @State private var saveRoutine = false
    @State private var routineName = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(workout.completedSets) series completadas").font(.headline)
                    Text("El historial incluirá las series que has marcado como completadas.").font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Guardar también como rutina", isOn: $saveRoutine)
                    if saveRoutine { TextField("Nombre de la rutina", text: $routineName) }
                } footer: {
                    if saveRoutine { Text("La rutina conservará todos los ejercicios y series planificados.") }
                }
            }
            .navigationTitle("Finalizar entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Volver") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        do { try onSave(saveRoutine ? routineName.trimmingCharacters(in: .whitespacesAndNewlines) : nil) }
                        catch { saveError = error.localizedDescription }
                    }
                        .disabled(saveRoutine && routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { routineName = workout.title }
            .alert("No se pudo guardar", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("Aceptar", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }
}

private struct RestTimerPanel: View {
    @ObservedObject var timer: RestTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.remaining(at: context.date)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(remaining == 0 ? "Descanso completado" : "Descanso", systemImage: "timer")
                            .font(.headline)
                        Text(timer.exerciseName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(elapsedString(Double(remaining))).font(.title2.bold()).monospacedDigit().foregroundStyle(Theme.accent)
                }
                HStack {
                    Button("−15 s") { timer.adjust(seconds: -15) }.disabled(remaining == 0)
                    Spacer()
                    Button("+15 s") {
                        if remaining == 0 { timer.start(seconds: 15, exercise: timer.exerciseName) }
                        else { timer.adjust(seconds: 15) }
                    }
                    Spacer()
                    Button(remaining == 0 ? "Listo" : "Omitir") { timer.cancel() }
                }.buttonStyle(.borderless).font(.subheadline)
            }
            if let warning = timer.notificationWarning { Text(warning).font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 5)
    }
}

private func elapsedString(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) }
    return String(format: "%d:%02d", total / 60, total % 60)
}

private func freshExercises(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
    var supersetIDs: [String: String] = [:]
    return exercises.map { source in
        var exercise = source
        exercise.id = UUID().uuidString
        if let old = exercise.supersetId {
            if supersetIDs[old] == nil { supersetIDs[old] = UUID().uuidString }
            exercise.supersetId = supersetIDs[old]
        }
        exercise.sets = source.sets.map { sourceSet in
            var set = sourceSet
            set.id = UUID().uuidString
            set.importKey = nil
            set.completed = false
            return set
        }
        return exercise
    }
}

private func linkSuperset(_ id: String, in exercises: inout [WorkoutExercise]) {
    guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
    if let old = exercises[index].supersetId {
        exercises[index].supersetId = nil
        let remaining = exercises.indices.filter { exercises[$0].supersetId == old }
        if remaining.count == 1 { exercises[remaining[0]].supersetId = nil }
    } else if index > 0 {
        let group = exercises[index - 1].supersetId ?? UUID().uuidString
        exercises[index - 1].supersetId = group
        exercises[index].supersetId = group
    }
}

private func removeExercise(_ id: String, from exercises: inout [WorkoutExercise]) {
    let group = exercises.first(where: { $0.id == id })?.supersetId
    exercises.removeAll { $0.id == id }
    if let group {
        let remaining = exercises.indices.filter { exercises[$0].supersetId == group }
        if remaining.count == 1 { exercises[remaining[0]].supersetId = nil }
    }
}

private func supersetName(for exercise: WorkoutExercise, in exercises: [WorkoutExercise]) -> String? {
    guard let id = exercise.supersetId else { return nil }
    var seen: [String] = []
    for item in exercises {
        if let group = item.supersetId, !seen.contains(group) { seen.append(group) }
    }
    return "Superserie \((seen.firstIndex(of: id) ?? 0) + 1)"
}
