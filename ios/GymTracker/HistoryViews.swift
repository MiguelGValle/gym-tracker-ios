import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: GymStore
    @State private var search = ""
    @State private var selectedDate = Date()
    @State private var filterByDate = false

    private var sessions: [WorkoutSession] {
        store.data.sessions.filter { session in
            let matchesDate = !filterByDate || Calendar.current.isDate(session.startedAt, inSameDayAs: selectedDate)
            let searchable = ([session.title, session.notes] + session.exercises.map { $0.exerciseName.isEmpty ? store.exerciseName($0.exerciseId) : $0.exerciseName }).joined(separator: " ")
            return matchesDate && (search.isEmpty || searchable.localizedStandardContains(search))
        }.sorted { $0.startedAt > $1.startedAt }
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
            .scrollContentBackground(.hidden).background(Theme.background)
            .searchable(text: $search, prompt: "Sesión, ejercicio o notas")
            .navigationTitle("Historial")
        }
    }
}

private struct HistorySessionRow: View {
    @EnvironmentObject private var store: GymStore
    var session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(Theme.accent)
            Text(session.title).font(.headline)
            Text("\(session.exercises.count) ejercicios · \(session.completedSets) series · \(store.displayWeight(session.volume).gymNumber) \(store.weightUnit)")
                .font(.caption).foregroundStyle(.secondary)
            if !session.notes.isEmpty { Text(session.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(.vertical, 5)
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text(session.startedAt.formatted(date: .complete, time: .shortened)).foregroundStyle(.secondary)
                        HStack {
                            MetricTile(title: "Series", value: "\(session.completedSets)", symbol: "checkmark.circle")
                            MetricTile(title: "Volumen · \(store.weightUnit)", value: store.displayWeight(session.volume).gymNumber, symbol: "scalemass")
                        }
                        if let end = session.endedAt {
                            Label("Duración: \(Int(max(0, end.timeIntervalSince(session.startedAt)) / 60)) min", systemImage: "clock")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if !session.notes.isEmpty { GymCard { Text(session.notes).frame(maxWidth: .infinity, alignment: .leading) } }
                        ForEach(session.exercises) { exercise in
                            HistoryExerciseCard(exercise: exercise)
                        }
                        Button(action: { repeatSession(session) }) { Label("Repetir entrenamiento", systemImage: "arrow.clockwise") }
                            .buttonStyle(.borderedProminent).tint(Theme.accent).frame(maxWidth: .infinity)
                        Button(action: { newRoutine = routine(from: session) }) { Label("Crear rutina con esta sesión", systemImage: "list.bullet.rectangle") }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }.padding()
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
        .background(Theme.background).navigationBarTitleDisplayMode(.inline)
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
        var copy = original
        copy.id = UUID().uuidString
        copy.importKey = nil
        copy.startedAt = Date()
        copy.endedAt = nil
        copy.exercises = copiedExercises(original.exercises)
        store.mutate { data in if data.draft == nil { data.draft = copy } }
        if store.data.draft?.id == copy.id { showActiveWorkout = true }
    }

    private func routine(from session: WorkoutSession) -> Routine {
        var result = Routine()
        result.name = session.title
        result.notes = session.notes
        result.exercises = copiedExercises(session.exercises)
        return result
    }

    private func copiedExercises(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        var supersets: [String: String] = [:]
        return exercises.map { exercise in
            var copy = exercise
            copy.id = UUID().uuidString
            if let old = exercise.supersetId {
                if supersets[old] == nil { supersets[old] = UUID().uuidString }
                copy.supersetId = supersets[old]
            }
            copy.sets = exercise.sets.map { set in
                var next = set
                next.id = UUID().uuidString
                next.importKey = nil
                next.completed = false
                return next
            }
            return copy
        }
    }
}

private struct HistoryExerciseCard: View {
    @EnvironmentObject private var store: GymStore
    var exercise: WorkoutExercise
    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.exerciseName.isEmpty ? store.exerciseName(exercise.exerciseId) : exercise.exerciseName).font(.headline)
                if !exercise.notes.isEmpty { Text(exercise.notes).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(store.displayWeight(set.weightKg).gymNumber) \(store.weightUnit) × \(set.reps)")
                            if set.setType == "warmup" { Text("Calentamiento").font(.caption).foregroundStyle(.secondary) }
                            if let rpe = set.rpe { Text("RPE \(rpe.gymNumber)").font(.caption).foregroundStyle(.secondary) }
                            if let distance = set.distanceKm { Text("\(distance.gymNumber) km").font(.caption).foregroundStyle(.secondary) }
                            if let seconds = set.durationSeconds { Text("\(seconds) s").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if set.completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).accessibilityLabel("Completada") }
                    }
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
                    && (!$0.completed || $0.reps > 0 || ($0.distanceKm ?? 0) > 0 || ($0.durationSeconds ?? 0) > 0)
            } }
            && (session.endedAt == nil || session.endedAt! >= session.startedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sesión") {
                    TextField("Título", text: $session.title)
                    DatePicker("Fecha e inicio", selection: Binding(get: { session.startedAt }, set: { date in
                        let delta = date.timeIntervalSince(session.startedAt)
                        session.startedAt = date
                        if let end = session.endedAt { session.endedAt = end.addingTimeInterval(delta) }
                    }))
                    if session.endedAt != nil {
                        DatePicker("Fin", selection: Binding(get: { session.endedAt ?? session.startedAt }, set: { session.endedAt = $0 }), in: session.startedAt...)
                    }
                    TextField("Notas", text: $session.notes, axis: .vertical).lineLimit(3...8)
                }.listRowBackground(Theme.surface)
                ForEach($session.exercises) { $exercise in
                    Section {
                        TextField("Nombre del ejercicio", text: $exercise.exerciseName)
                        TextField("Notas del ejercicio", text: $exercise.notes, axis: .vertical)
                        ForEach($exercise.sets) { $set in HistorySetEditor(set: $set) }
                            .onDelete { offsets in exercise.sets.remove(atOffsets: offsets) }
                        Button("Añadir serie") {
                            var set = exercise.sets.last ?? WorkoutSet()
                            set.id = UUID().uuidString
                            set.importKey = nil
                            set.completed = true
                            exercise.sets.append(set)
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
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Editar sesión").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!valid) }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePicker { selected in
                    var entry = WorkoutExercise(exerciseId: selected.id)
                    entry.exerciseName = selected.name
                    entry.sets[0].completed = true
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
            DecimalField(title: "Peso · \(store.weightUnit)", value: Binding(get: { store.displayWeight(set.weightKg) }, set: { set.weightKg = store.kgWeight($0) }))
            Stepper("Repeticiones: \(set.reps)", value: $set.reps, in: 0...10000)
            Picker("Tipo", selection: $set.setType) {
                Text("Normal").tag("normal")
                Text("Calentamiento").tag("warmup")
                Text("Descendente").tag("dropset")
                Text("Al fallo").tag("failure")
            }
            OptionalSetNumberField(title: "RPE · 0–10", value: $set.rpe, range: 0...10)
            OptionalSetNumberField(title: "Distancia · km", value: $set.distanceKm, range: 0...100000)
            OptionalSetNumberField(title: "Duración · segundos", value: Binding(get: { set.durationSeconds.map(Double.init) }, set: { set.durationSeconds = $0.map { Int($0.rounded()) } }), range: 0...10000000)
            Toggle("Serie completada", isOn: $set.completed)
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
