import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: GymStore
    @State private var search = ""
    @State private var selectedDate = Date()
    @State private var filterByDate = false

    private var sessions: [WorkoutSession] {
        WorkoutHistory.recentFirst(store.data.sessions).filter { session in
            let matchesDate = !filterByDate || Calendar.current.isDate(session.date, inSameDayAs: selectedDate)
            let searchable = ([session.title, session.notes] + session.exercises.map { $0.exerciseName.isEmpty ? store.exerciseName($0.exerciseId) : $0.exerciseName }).joined(separator: " ")
            return matchesDate && (search.isEmpty || searchable.localizedStandardContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Filtrar por fecha", isOn: $filterByDate).tint(Theme.accent)
                    if filterByDate {
                        DatePicker("Fecha", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical).tint(Theme.accent)
                    }
                }.listRowBackground(Theme.surface)
                if sessions.isEmpty {
                    EmptyState(title: store.data.sessions.isEmpty ? "Tu historial de entrenamiento" : "Sin resultados",
                               message: store.data.sessions.isEmpty ? "Tus sesiones aparecerán aquí cuando las finalices." : "Prueba otra fecha o cambia la búsqueda.", symbol: "calendar")
                        .listRowBackground(Color.clear)
                } else {
                    Section("\(sessions.count) entrenamientos") {
                        ForEach(sessions) { session in
                            NavigationLink { HistoryDetailView(sessionID: session.id) } label: {
                                HistorySessionRow(session: session)
                            }
                        }.listRowBackground(Theme.surface)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .gymScreenStyle()
            .searchable(text: $search, prompt: "Sesión, ejercicio o notas")
            .navigationTitle("Historial")
        }
    }
}

private struct HistorySessionRow: View {
    @EnvironmentObject private var store: GymStore
    var session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(session.title).font(.system(.headline, design: .rounded))
            Text("\(session.exercises.count) ejercicios · \(session.completedSets) series · \(store.displayWeight(session.volume).gymNumber) \(store.weightUnit)")
                .font(.caption).foregroundStyle(.secondary)
            if !session.notes.isEmpty { Text(session.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(.vertical, 10)
    }
}

private struct HistoryDetailView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    var sessionID: String
    @State private var editing: WorkoutSession?
    @State private var newRoutine: Routine?
    @State private var showDelete = false
    @State private var showActiveWorkout = false
    @State private var showExistingDraft = false

    private var session: WorkoutSession? { store.data.sessions.first { $0.id == sessionID } }

    var body: some View {
        Group {
            if let session = session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(session.date.formatted(date: .complete, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            MetricTile(title: "Series", value: "\(session.completedSets)", symbol: "list.number")
                                .accessibilityIdentifier("history-set-count")
                                .accessibilityLabel("Series guardadas")
                                .accessibilityValue("\(session.completedSets)")
                            MetricTile(title: "Volumen · \(store.weightUnit)", value: store.displayWeight(session.volume).gymNumber, symbol: "scalemass")
                        }
                        if !session.notes.isEmpty { GymCard { Text(session.notes).frame(maxWidth: .infinity, alignment: .leading) } }
                        ForEach(session.exercises) { exercise in
                            HistoryExerciseCard(exercise: exercise)
                        }
                        Button(action: { repeatSession(session) }) { Label("Repetir entrenamiento", systemImage: "arrow.clockwise") }
                            .buttonStyle(GymPrimaryButtonStyle()).tint(Theme.accent).frame(maxWidth: .infinity)
                        Button(action: { newRoutine = routine(from: session) }) { Label("Crear rutina con esta sesión", systemImage: "list.bullet.rectangle") }
                            .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
                    }.padding(.horizontal, 20).padding(.vertical, 16)
                }.navigationTitle(session.title)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(action: { editing = session }) { Label("Editar sesión", systemImage: "pencil") }
                                Button(role: .destructive, action: { showDelete = true }) { Label("Eliminar sesión", systemImage: "trash") }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
            } else {
                EmptyState(title: "Sesión no disponible", message: "Este entrenamiento ya no está en el historial.", symbol: "calendar.badge.exclamationmark")
            }
        }
        .gymScreenStyle().navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { SessionHistoryEditor(session: $0) }
        .sheet(item: $newRoutine) { RoutineEditor(routine: $0) }
        .sheet(isPresented: $showActiveWorkout) { ActiveWorkoutView() }
        .alert("Eliminar entrenamiento", isPresented: $showDelete) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                store.mutate { $0.sessions.removeAll { $0.id == sessionID } }
                if !store.data.sessions.contains(where: { $0.id == sessionID }) { dismiss() }
            }
        } message: { Text("Se eliminarán esta sesión y sus series del historial.") }
        .alert("Ya hay un entrenamiento en curso", isPresented: $showExistingDraft) {
            Button("Continuar el actual") { showActiveWorkout = true }
            Button("Cerrar", role: .cancel) {}
        } message: { Text("Finaliza o descarta el entrenamiento actual antes de repetir otro.") }
    }

    private func repeatSession(_ original: WorkoutSession) {
        guard store.data.draft == nil else { showExistingDraft = true; return }
        store.repeatWorkout(original)
        if store.data.draft != nil { showActiveWorkout = true }
    }

    private func routine(from session: WorkoutSession) -> Routine {
        var result = Routine()
        result.name = session.title
        result.notes = session.notes
        result.exercises = copiedExercises(session.exercises)
        return result
    }

    private func copiedExercises(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        WorkoutTemplates.exercises(from: exercises)
    }
}

private struct HistoryExerciseCard: View {
    @EnvironmentObject private var store: GymStore
    var exercise: WorkoutExercise
    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.exerciseName.isEmpty ? store.exerciseName(exercise.exerciseId) : exercise.exerciseName).font(.system(.headline, design: .rounded))
                    .accessibilityIdentifier("history-exercise-\(exercise.id)")
                if !exercise.notes.isEmpty { Text(exercise.notes).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index + 1)").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(store.displayWeight(set.weightKg).gymNumber) \(store.weightUnit) × \(set.reps)").font(.subheadline.weight(.medium)).monospacedDigit()
                                .accessibilityIdentifier("history-set-\(set.id)")
                            if set.setType == "warmup" { Text("Calentamiento").font(.caption).foregroundStyle(.secondary) }
                            if set.setType == "failure" {
                                Text("Al fallo").font(.caption).foregroundStyle(Theme.accent)
                                    .accessibilityIdentifier("history-failure-\(set.id)")
                            }
                            if let rpe = set.rpe { Text("RPE \(rpe.gymNumber)").font(.caption).foregroundStyle(.secondary) }
                            if let distance = set.distanceKm { Text("\(distance.gymNumber) km").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                    }.padding(.vertical, 4)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SessionHistoryEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State var session: WorkoutSession
    @State private var showExercisePicker = false

    private var valid: Bool {
        !session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !session.exercises.isEmpty
            && session.exercises.allSatisfy { !$0.sets.isEmpty && $0.sets.allSatisfy {
                $0.weightKg.isFinite && $0.weightKg >= 0 && $0.reps >= 0
            } }
            && (session.endedAt == nil || session.endedAt! >= session.startedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sesión") {
                    TextField("Título", text: $session.title)
                    DatePicker("Fecha", selection: $session.date, displayedComponents: .date)
                    TextField("Notas", text: $session.notes, axis: .vertical).lineLimit(3...8)
                }.listRowBackground(Theme.surface)
                ForEach($session.exercises) { $exercise in
                    Section {
                        TextField("Nombre del ejercicio", text: $exercise.exerciseName)
                        TextField("Notas del ejercicio", text: $exercise.notes, axis: .vertical)
                        ForEach($exercise.sets) { $set in HistorySetEditor(set: $set) }
                            .onDelete { offsets in exercise.sets.remove(atOffsets: offsets) }
                        Button("Añadir serie") {
                            exercise.sets.append(WorkoutTemplates.nextSet(from: exercise.sets.last))
                        }
                        Button("Eliminar ejercicio", role: .destructive) { session.exercises.removeAll { $0.id == exercise.id } }
                    } header: { Text(exercise.exerciseName.isEmpty ? store.exerciseName(exercise.exerciseId) : exercise.exerciseName) }
                        .listRowBackground(Theme.surface)
                }
                Section {
                    Button(action: { showExercisePicker = true }) { Label("Añadir ejercicio", systemImage: "plus") }
                    if !valid { Text("Escribe un título y conserva al menos un ejercicio con una serie válida.").font(.caption).foregroundStyle(.secondary) }
                }.listRowBackground(Theme.surface)
            }
            .gymScreenStyle()
            .navigationTitle("Editar sesión").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!valid) }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePicker { selected in
                    var entry = WorkoutExercise(exerciseId: selected.id)
                    entry.exerciseName = selected.name
                    session.exercises.append(entry)
                }
            }
        }
    }

    private func save() {
        session.title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = session
        store.mutate { data in
            guard let index = data.sessions.firstIndex(where: { $0.id == result.id }) else { return }
            data.sessions[index] = result
        }
        if store.data.sessions.contains(result) { dismiss() }
    }
}

private struct HistorySetEditor: View {
    @EnvironmentObject private var store: GymStore
    @Binding var set: WorkoutSet
    var body: some View {
        DisclosureGroup {
            ReplaceableNumberField(title: "Peso · \(store.weightUnit)", value: Binding(get: { store.displayWeight(set.weightKg) }, set: { set.weightKg = store.kgWeight($0) }))
                .frame(minHeight: 36)
            ReplaceableNumberField(title: "Repeticiones", value: Binding(get: { Double(set.reps) }, set: { set.reps = Int($0) }), integer: true)
                .frame(minHeight: 36)
            Picker("Tipo", selection: $set.setType) {
                Text("Normal").tag("normal")
                Text("Calentamiento").tag("warmup")
                Text("Descendente").tag("dropset")
                Text("Al fallo").tag("failure")
            }
            OptionalSetNumberField(title: "RPE · 0–10", value: $set.rpe, range: 0...10)
            OptionalSetNumberField(title: "Distancia · km", value: $set.distanceKm, range: 0...100000)
            FailureSetCheckbox(set: $set)
        } label: {
            Text("\(store.displayWeight(set.weightKg).gymNumber) \(store.weightUnit) × \(set.reps)").font(.subheadline)
        }
    }
}

private struct OptionalSetNumberField: View {
    var title: String
    @Binding var value: Double?
    var range: ClosedRange<Double>
    @State private var text = ""
    @State private var invalid = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text).keyboardType(.decimalPad)
                .onAppear { text = value.map { String($0) } ?? "" }
                .onChange(of: text) { input in
                    if input.trimmingCharacters(in: .whitespaces).isEmpty { value = nil; invalid = false }
                    else if let parsed = Double(input.replacingOccurrences(of: ",", with: ".")), parsed.isFinite, range.contains(parsed) {
                        value = parsed; invalid = false
                    } else { invalid = true }
                }
            if invalid { Text("Valor no válido; se conserva el valor anterior.").font(.caption).foregroundStyle(.red) }
        }
    }
}
