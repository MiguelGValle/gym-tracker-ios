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
                    }.buttonStyle(GymPrimaryButtonStyle())
                    if let draft = store.data.draft {
                        Text("\(draft.title) · \(draft.completedSets) series")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
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
            .listStyle(.insetGrouped)
            .gymScreenStyle()
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
                VStack(alignment: .leading, spacing: 7) {
                    Text(routine.name).font(.system(.headline, design: .rounded)).foregroundStyle(.primary)
                    Text("\(routine.exercises.count) ejercicios · \(routine.exercises.reduce(0) { $0 + $1.sets.count }) series")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button {
                store.startWorkout(routine: routine)
                showWorkout = store.data.draft != nil
            } label: {
                Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
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
            } label: { Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).frame(width: 28, height: 40) }
            .accessibilityLabel("Opciones de \(routine.name)")
        }.padding(.vertical, 10).listRowBackground(Theme.surface)
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
                Text("\(workout.completedSets) series").font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                    .accessibilityIdentifier("workout-set-count")
                if workout.routineId != nil { Text("Entrenamiento de rutina").font(.caption).foregroundStyle(.secondary) }
                Button("Editar título y fecha") { showDetails = true }
                TextField("Notas del entrenamiento", text: $workout.notes, axis: .vertical).lineLimit(2...5)
            }.listRowBackground(Theme.surface)
            if workout.exercises.isEmpty {
                EmptyState(title: "Añade tu primer ejercicio", message: "Registra peso, repeticiones y las series del entrenamiento.", symbol: "dumbbell")
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
                        onSuperset: { toggleSuperset(exercise.id) }
                    )
                }.listRowBackground(Theme.surface)
            }
            Section {
                Button { replacementID = nil; showPicker = true } label: { Label("Añadir ejercicio", systemImage: "plus") }
                Button("Descartar entrenamiento", role: .destructive) { showDiscard = true }
            }
        }
        .gymScreenStyle()
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { if saveDraft() { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Finalizar") {
                    if workout.completedSets == 0 { error = "Añade al menos una serie antes de guardar el entrenamiento." }
                    else { showFinish = true }
                }.fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: { showReplacementConfirmation = replacementChoice != nil }) {
            ExercisePicker { selected in selectExercise(selected) }
        }
        .confirmationDialog("Reemplazar ejercicio", isPresented: $showReplacementConfirmation, titleVisibility: .visible) {
            Button("Reemplazar por una serie") {
                if let selected = replacementChoice { applyReplacement(selected) }
                replacementChoice = nil
            }
            Button("Cancelar", role: .cancel) { replacementChoice = nil; replacementID = nil }
        } message: { Text("El ejercicio nuevo comenzará con una sola serie. Se sustituirán las series del ejercicio anterior en este entrenamiento.") }
        .sheet(isPresented: $showDetails) { WorkoutDetailsEditor(workout: $workout) }
        .sheet(isPresented: $showFinish) {
            FinishWorkoutSheet(workout: workout) { routineName in try finish(routineName: routineName) }
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("¿Descartar este entrenamiento?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Descartar entrenamiento", role: .destructive) {
                finishing = true
                store.mutate { $0.draft = nil }
                if store.data.draft == nil { dismiss() }
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
            if !workout.exercises[index].sets.isEmpty {
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
        workout.exercises[index].restSeconds = 0
        workout.exercises[index].sets = [WorkoutTemplates.nextSet(from: workout.exercises[index].sets.first)]
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
        let completed = workout
        finishing = true
        do {
            let routine = routineName.map { Routine(name: $0, notes: workout.notes, exercises: freshExercises(workout.exercises)) }
            try store.finishWorkout(completed, routine: routine)
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
                            onSuperset: { linkSuperset(exercise.id, in: &routine.exercises) }
                        )
                    }
                }
                Section {
                    Button { replacementID = nil; showPicker = true } label: { Label("Añadir ejercicio", systemImage: "plus") }
                }
            }
            .gymScreenStyle()
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
                        routine.exercises[index].restSeconds = 0
                        routine.exercises[index].sets = [WorkoutTemplates.nextSet(from: routine.exercises[index].sets.first)]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let supersetName {
                Label(supersetName, systemImage: "link").font(.caption).foregroundStyle(Theme.accent)
            }
            TextField("Notas del ejercicio", text: $exercise.notes, axis: .vertical).font(.subheadline).lineLimit(1...4)
            ForEach($exercise.sets) { $set in
                let index = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                WorkoutSetEditor(set: $set, number: index + 1, previous: store.previousSet(exerciseId: exercise.exerciseId, index: index), active: active) {
                    exercise.sets.removeAll { $0.id == set.id }
                }
            }
            Button {
                exercise.sets.append(WorkoutTemplates.nextSet(from: exercise.sets.last))
            } label: {
                Label("Añadir serie", systemImage: "plus")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 42)
                    .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.borderless)
                .accessibilityIdentifier("add-set-\(exercise.id)")
        }.padding(.vertical, 12).listRowBackground(Theme.surface)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("\(position + 1). \(exercise.exerciseName.isEmpty ? store.exerciseName(exercise.exerciseId) : exercise.exerciseName)")
                .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
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
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Serie \(number)").font(.system(.subheadline, design: .rounded).weight(.bold)).monospacedDigit()
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
                    ReplaceableNumberField(title: "Peso", value: Binding(get: { store.displayWeight(set.weightKg) }, set: { set.weightKg = max(0, store.kgWeight($0)) }))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps").font(.caption).foregroundStyle(.secondary)
                    ReplaceableNumberField(title: "Reps", value: Binding(get: { Double(set.reps) }, set: { set.reps = max(0, Int($0)) }), integer: true)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if active {
                    FailureSetCheckbox(set: $set, accessibilityLabel: "Al fallo, serie \(number)")
                }
            }
            if let previous {
                Text(previousDescription(previous)).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("RPE y distancia") {
                VStack(spacing: 10) {
                    optionalDecimal("RPE (1–10)", value: $set.rpe, range: 1...10)
                    optionalDecimal("Distancia (km)", value: $set.distanceKm, range: 0...10000)
                }.padding(.top, 8)
            }.font(.caption)
        }
        .padding(14)
        .background(Theme.background.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-set-\(set.id)")
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
        if let distance = previous.distanceKm { text += " · \(distance.gymNumber) km" }
        return text
    }
}

struct FailureSetCheckbox: View {
    @Binding var set: WorkoutSet
    var accessibilityLabel = "Al fallo"

    private var reachedFailure: Bool { self.set.setType == "failure" }

    var body: some View {
        Button {
            set.setType = reachedFailure ? "normal" : "failure"
        } label: {
            VStack(spacing: 3) {
                Image(systemName: reachedFailure ? "checkmark.square.fill" : "square")
                    .font(.title2)
                Text("Al fallo").font(.caption2)
            }
            .foregroundStyle(reachedFailure ? Theme.accent : Color.secondary)
            .frame(minWidth: 48, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(reachedFailure ? "Marcada" : "Sin marcar")
        .accessibilityHint("Opcional; esta serie se guardará con o sin esta marca.")
        .accessibilityIdentifier("failure-\(set.id)")
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
                    DatePicker("Fecha", selection: $workout.date, in: ...Date(), displayedComponents: .date)
                }
            }
            .gymScreenStyle()
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
                    Text("\(workout.completedSets) series").font(.headline)
                    Text("El historial incluirá todos los ejercicios y series. La marca «Al fallo» es opcional.").font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Guardar también como rutina", isOn: $saveRoutine)
                    if saveRoutine { TextField("Nombre de la rutina", text: $routineName) }
                } footer: {
                    if saveRoutine { Text("La rutina conservará todos los ejercicios y series planificados.") }
                }
            }
            .gymScreenStyle()
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

private func freshExercises(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
    WorkoutTemplates.exercises(from: exercises)
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
