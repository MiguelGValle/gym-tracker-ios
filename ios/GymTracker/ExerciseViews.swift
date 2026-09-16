import SwiftUI

struct ExercisePicker: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void
    @State private var search = ""
    @State private var category = "Todos"
    private var categories: [String] { ["Todos"] + Set(store.data.exercises.map(\.category)).sorted() }
    private var filtered: [Exercise] {
        store.data.exercises.filter { !$0.archived && (category == "Todos" || $0.category == category) && (search.isEmpty || $0.name.localizedStandardContains(search) || $0.equipment.localizedStandardContains(search)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        NavigationStack {
            List {
                Picker("Grupo", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }
                ForEach(filtered) { exercise in
                    Button { onSelect(exercise); dismiss() } label: { ExerciseLabel(exercise: exercise) }.buttonStyle(.plain)
                }
                if filtered.isEmpty { Text("No hay ejercicios que coincidan.").foregroundStyle(.secondary) }
            }
            .searchable(text: $search, prompt: "Ejercicio o equipo")
            .navigationTitle("Añadir ejercicio").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

private struct ExerciseLabel: View {
    let exercise: Exercise
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: exercise.category == "Cardio" ? "figure.run" : "dumbbell.fill")
                .foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name).font(.headline)
                Text("\(exercise.category) · \(exercise.equipment)").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
            if exercise.archived { Image(systemName: "archivebox").foregroundStyle(.secondary) }
        }
    }
}

struct ExerciseCatalogView: View {
    @EnvironmentObject private var store: GymStore
    @State private var search = ""
    @State private var showArchived = false
    @State private var editing: Exercise?
    private var filtered: [Exercise] {
        store.data.exercises.filter { (showArchived || !$0.archived) && (search.isEmpty || $0.name.localizedStandardContains(search) || $0.equipment.localizedStandardContains(search)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        List {
            Toggle("Mostrar archivados", isOn: $showArchived)
            ForEach(filtered) { exercise in
                Button { editing = exercise } label: { ExerciseLabel(exercise: exercise) }.buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            var copy = exercise; copy.id = UUID().uuidString; copy.name += " (copia)"; copy.archived = false
                            editing = copy
                        } label: { Label("Duplicar", systemImage: "doc.on.doc") }
                        Button {
                            store.mutate { data in
                                if let index = data.exercises.firstIndex(where: { $0.id == exercise.id }) { data.exercises[index].archived.toggle() }
                            }
                        } label: { Label(exercise.archived ? "Recuperar" : "Archivar", systemImage: "archivebox") }
                    }
            }
        }
        .searchable(text: $search, prompt: "Ejercicio o equipo")
        .navigationTitle("Ejercicios")
        .toolbar { Button { editing = Exercise() } label: { Image(systemName: "plus").accessibilityLabel("Crear ejercicio") } }
        .sheet(item: $editing) { ExerciseEditor(exercise: $0) }
    }
}

struct ExerciseEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State var exercise: Exercise
    @State private var newMuscle = ""
    @State private var validation: String?
    private var total: Int { exercise.muscles.values.reduce(0, +) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Ejercicio") {
                    TextField("Nombre", text: $exercise.name)
                    TextField("Equipo", text: $exercise.equipment)
                    Picker("Grupo", selection: $exercise.category) {
                        ForEach(Array(Set(["Pecho", "Espalda", "Hombro", "Pierna", "Brazos", "Core", "Cardio", "Mixto", exercise.category])).sorted(), id: \.self) { Text($0) }
                    }
                    TextField("Movimiento", text: $exercise.movement)
                    Toggle("Technogym", isOn: $exercise.technogym)
                    Toggle("Archivado", isOn: $exercise.archived)
                    TextField("Notas", text: $exercise.notes, axis: .vertical)
                }
                Section {
                    ForEach(exercise.muscles.keys.sorted(), id: \.self) { muscle in
                        HStack {
                            Text(muscle)
                            Spacer()
                            TextField("%", value: Binding(get: { exercise.muscles[muscle, default: 0] }, set: { exercise.muscles[muscle] = $0 }), format: .number)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 65)
                                .accessibilityLabel("Porcentaje de \(muscle)")
                            Text("%")
                        }
                    }.onDelete { indices in
                        let keys = exercise.muscles.keys.sorted()
                        for index in indices { exercise.muscles.removeValue(forKey: keys[index]) }
                    }
                    HStack {
                        TextField("Añadir músculo", text: $newMuscle)
                        Button("Añadir") {
                            let name = newMuscle.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { exercise.muscles[name] = exercise.muscles[name] ?? 0; newMuscle = "" }
                        }.disabled(newMuscle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Total: \(total)%").foregroundStyle(total == 100 || exercise.muscles.isEmpty ? Color.secondary : Theme.accent)
                } header: { Text("Distribución muscular estimada") } footer: { Text("Los porcentajes deben sumar 100%. Puedes dejar la lista vacía si desconoces la distribución.") }
                if let validation { Text(validation).foregroundStyle(.red) }
            }
            .navigationTitle("Editar ejercicio").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() } }
            }
        }
    }
    private func save() {
        exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !exercise.name.isEmpty else { validation = "Introduce un nombre."; return }
        guard exercise.muscles.isEmpty || (total == 100 && exercise.muscles.values.allSatisfy { (0...100).contains($0) }) else { validation = "Revisa los porcentajes: deben sumar 100%."; return }
        store.mutate { data in
            if let index = data.exercises.firstIndex(where: { $0.id == exercise.id }) { data.exercises[index] = exercise }
            else { data.exercises.append(exercise) }
        }
        if store.errorMessage == nil { dismiss() }
    }
}
