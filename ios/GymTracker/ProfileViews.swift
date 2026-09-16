import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct GymDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw GymError.invalid("El archivo no se puede leer.") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct ImportReview: Identifiable {
    let id = UUID()
    var backup: GymData?
    var csv: ImportPreview?
    var summary: String
}

struct ProfileView: View {
    @EnvironmentObject private var store: GymStore
    @State private var importing = false
    @State private var importingCSV = false
    @State private var exporting = false
    @State private var exportDocument = GymDocument(data: Data())
    @State private var exportType = UTType.json
    @State private var exportName = "GymTracker-copia"
    @State private var review: ImportReview?
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 45)).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tu espacio personal").font(.headline)
                            Text("Datos guardados en este iPhone").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                    NavigationLink { PersonalSettingsView() } label: { Label("Perfil y unidades", systemImage: "slider.horizontal.3") }
                }
                Section("Seguimiento") {
                    NavigationLink { NutritionView() } label: { Label("Nutrición", systemImage: "fork.knife") }
                    NavigationLink { MeasurementsView() } label: { Label("Medidas corporales", systemImage: "scalemass") }
                    NavigationLink { PhotosView() } label: { Label("Fotos de progreso", systemImage: "photo.on.rectangle") }
                    NavigationLink { ExerciseCatalogView() } label: { Label("Ejercicios", systemImage: "dumbbell") }
                    NavigationLink { PlateCalculatorView() } label: { Label("Discos y calentamiento", systemImage: "circle.grid.cross") }
                }
                Section {
                    Button { exportingBackup() } label: { Label("Guardar copia completa", systemImage: "square.and.arrow.up") }
                    Button { importingCSV = false; importing = true } label: { Label("Restaurar copia", systemImage: "square.and.arrow.down") }
                    Button { importingCSV = true; importing = true } label: { Label("Importar desde Hevy", systemImage: "arrow.down.doc") }
                    Button { exportingWorkouts() } label: { Label("Exportar entrenamientos CSV", systemImage: "tablecells") }
                } header: { Text("Tus datos") } footer: {
                    Text("Restaura una copia de Gym Tracker para iOS o Android, o importa el CSV de entrenamientos de Hevy. Revisarás el contenido antes de importarlo.")
                }
                Section {
                    LabeledContent("Versión iOS", value: "0.1.0")
                    Text("Entrenamientos, rutinas, nutrición y progreso sin conexión.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Perfil")
            .fileImporter(isPresented: $importing, allowedContentTypes: importingCSV ? [.commaSeparatedText, .plainText, .text, .data] : [.json, .data]) { result in
                readImport(result)
            }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
                if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
            }
            .sheet(item: $review) { item in
                NavigationStack {
                    List {
                        Section("Contenido de la importación") { Text(item.summary) }
                        if let warnings = item.csv?.warnings, !warnings.isEmpty {
                            Section("Avisos") { ForEach(Array(warnings.enumerated()), id: \.offset) { Text($0.element) } }
                        }
                        Section {
                            Text("Se combinarán los datos con los de este iPhone. Guarda una copia antes si quieres conservar el estado actual.")
                            Button("Confirmar importación") { confirmImport(item) }.disabled(store.data.draft != nil)
                            if store.data.draft != nil { Text("Termina o descarta tu entrenamiento activo antes de importar.").foregroundStyle(Theme.accent) }
                        }
                    }
                    .navigationTitle("Revisar datos").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { review = nil } } }
                }
            }
            .alert("Importación completada", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("Aceptar") { message = nil }
            } message: { Text(message ?? "") }
        }
    }
    private func exportingBackup() {
        do {
            exportDocument = GymDocument(data: try store.backupData())
            exportType = .json; exportName = "GymTracker-\(GymDate.dayKey(Date()))"; exporting = true
        } catch { store.errorMessage = error.localizedDescription }
    }
    private func readImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 60_000_000 else { throw GymError.invalid("El archivo supera el límite de 60 MB.") }
            let raw = try Data(contentsOf: url)
            if importingCSV {
                guard let text = String(data: raw, encoding: .utf8) else { throw GymError.invalid("Guarda el CSV con codificación UTF-8.") }
                let preview = try store.previewHevyCSV(text)
                review = ImportReview(csv: preview, summary: preview.summary)
            } else {
                let data = try store.previewImport(raw)
                review = ImportReview(backup: data, summary: "\(data.sessions.count) entrenamientos\n\(data.routines.count) rutinas\n\(data.exercises.count) ejercicios\n\(data.measurements.count) medidas\n\(data.nutrition.count) registros de nutrición\n\(data.photos.count) fotos")
            }
        } catch { store.errorMessage = error.localizedDescription }
    }
    private func confirmImport(_ item: ImportReview) {
        do {
            if let backup = item.backup { try store.restore(backup) }
            else if let csv = item.csv { try store.importHevy(csv) }
            review = nil
            message = "Los datos se han combinado y guardado en este iPhone."
        } catch { review = nil; store.errorMessage = error.localizedDescription }
    }
    private func exportingWorkouts() {
        func escape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let iso = ISO8601DateFormatter()
        var rows = ["title,start_time,end_time,description,exercise_title,exercise_notes,set_index,set_type,weight_kg,reps,rpe,distance_km,duration_seconds,superset_id"]
        for workout in store.data.sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            for block in workout.exercises {
                for (index, set) in block.sets.enumerated() where set.completed {
                    let fields = [workout.title, iso.string(from: workout.startedAt), workout.endedAt.map { iso.string(from: $0) } ?? "", workout.notes,
                                  block.exerciseName.isEmpty ? store.exerciseName(block.exerciseId) : block.exerciseName, block.notes,
                                  String(index), set.setType, String(set.weightKg), String(set.reps), set.rpe.map { String($0) } ?? "",
                                  set.distanceKm.map { String($0) } ?? "", set.durationSeconds.map { String($0) } ?? "", block.supersetId ?? ""]
                    rows.append(fields.map(escape).joined(separator: ","))
                }
            }
        }
        exportDocument = GymDocument(data: Data(rows.joined(separator: "\r\n").utf8))
        exportType = .commaSeparatedText; exportName = "GymTracker-entrenamientos"; exporting = true
    }
}

struct PersonalSettingsView: View {
    @EnvironmentObject private var store: GymStore
    private func field<T>(_ key: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(get: { store.data.profile[keyPath: key] }, set: { value in store.mutate { $0.profile[keyPath: key] = value } })
    }
    var body: some View {
        Form {
            Section("Unidades") { Toggle("Mostrar libras (lb)", isOn: field(\.usePounds)) }
            Section("Perfil para estimaciones") {
                Picker("Sexo para la fórmula", selection: field(\.male)) { Text("Hombre").tag(true); Text("Mujer").tag(false) }
                Stepper("Edad: \(store.data.profile.age)", value: field(\.age), in: 14...100)
                HStack { Text("Altura (cm)"); DecimalField(title: "Altura", value: field(\.heightCm)).multilineTextAlignment(.trailing) }
                Picker("Actividad", selection: field(\.activityFactor)) {
                    Text("Baja").tag(1.2); Text("Ligera").tag(1.375); Text("Moderada").tag(1.55); Text("Alta").tag(1.725); Text("Muy alta").tag(1.9)
                }
                Picker("Objetivo", selection: field(\.goal)) {
                    Text("Perder grasa").tag("FAT_LOSS"); Text("Mantener").tag("MAINTENANCE"); Text("Ganar músculo").tag("LEAN_GAIN"); Text("Recomposición").tag("RECOMP")
                }
            }
            Section("Objetivos diarios") {
                LabeledContent("Calorías") { TextField("kcal", value: field(\.calorieGoal), format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                LabeledContent("Proteína (g)") { TextField("Proteína", value: field(\.proteinGoal), format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
            }
        }.navigationTitle("Perfil y unidades")
    }
}

struct PhotosView: View {
    @EnvironmentObject private var store: GymStore
    @State private var selected: PhotosPickerItem?
    @State private var date = Date()
    @State private var notes = ""
    @State private var deleting: ProgressPhoto?
    @State private var loading = false
    var body: some View {
        List {
            Section("Añadir foto") {
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                TextField("Notas", text: $notes)
                PhotosPicker(selection: $selected, matching: .images) { Label(loading ? "Guardando…" : "Seleccionar foto", systemImage: "photo.badge.plus") }.disabled(loading)
            }
            ForEach(store.data.photos.sorted { $0.date > $1.date }) { photo in
                VStack(alignment: .leading, spacing: 10) {
                    if let image = UIImage(data: photo.imageData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 360).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(photo.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                    if !photo.notes.isEmpty { Text(photo.notes).foregroundStyle(.secondary) }
                    Button("Eliminar foto", role: .destructive) { deleting = photo }
                }.padding(.vertical, 8)
            }
        }
        .navigationTitle("Fotos de progreso")
        .onChange(of: selected) { item in
            guard let item else { return }
            let selectedDate = date
            let selectedNotes = notes
            loading = true
            Task { @MainActor in
                defer { loading = false; selected = nil }
                do {
                    guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw), let jpeg = resizedPhoto(image) else {
                        throw GymError.invalid("No se pudo leer la foto seleccionada.")
                    }
                    guard store.data.photos.reduce(0, { $0 + $1.imageData.count }) + jpeg.count <= 20 * 1024 * 1024 else {
                        throw GymError.invalid("Las fotos alcanzan el límite de 20 MB de la copia local. Elimina alguna para añadir más.")
                    }
                    let photo = ProgressPhoto(date: selectedDate, imageData: jpeg, notes: selectedNotes)
                    store.mutate { $0.photos.append(photo) }
                    if store.errorMessage == nil && notes == selectedNotes { notes = "" }
                } catch { store.errorMessage = error.localizedDescription }
            }
        }
        .confirmationDialog("¿Eliminar esta foto?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Eliminar foto", role: .destructive) { if let id = deleting?.id { store.mutate { $0.photos.removeAll { $0.id == id } } }; deleting = nil }
        }
    }
    private func resizedPhoto(_ image: UIImage) -> Data? {
        let ratio = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.8)
    }
}

struct PlateCalculatorView: View {
    @EnvironmentObject private var store: GymStore
    @State private var target = 60.0
    @State private var bar = 20.0
    private var targetKg: Double { store.kgWeight(target) }
    private var barKg: Double { store.kgWeight(bar) }
    private var plates: [(Double, Int)] {
        guard target >= bar, target.isFinite, bar.isFinite, bar >= 0, (target - bar).isFinite else { return [] }
        var remaining = (target - bar) / 2
        let available = store.data.profile.usePounds ? [45.0, 35, 25, 10, 5, 2.5] : [25.0, 20, 15, 10, 5, 2.5, 1.25]
        return available.compactMap { size in
            let count = Int(min(100, max(0, (remaining + 0.0001) / size))); remaining -= Double(count) * size
            return count > 0 ? (size, count) : nil
        }
    }
    private var loaded: Double { bar + 2 * plates.reduce(0) { $0 + $1.0 * Double($1.1) } }
    var body: some View {
        Form {
            Section("Carga en \(store.weightUnit)") {
                HStack { Text("Objetivo"); DecimalField(title: "Carga total", value: $target).multilineTextAlignment(.trailing) }
                HStack { Text("Barra"); DecimalField(title: "Peso de la barra", value: $bar).multilineTextAlignment(.trailing) }
            }
            Section("En cada lado") {
                if target < bar || bar < 0 { Text("La carga debe ser al menos el peso de la barra.") }
                else if plates.isEmpty { Text("Solo la barra") }
                ForEach(Array(plates.enumerated()), id: \.offset) { item in Text("\(item.element.1) × \(item.element.0.gymNumber) \(store.weightUnit)") }
                Text("Carga disponible: \(loaded.gymNumber) \(store.weightUnit)").foregroundStyle(.secondary)
            }
            Section("Calentamiento orientativo") {
                ForEach([0.4, 0.6, 0.8], id: \.self) { fraction in
                    LabeledContent("\(Int(fraction * 100))% · \(fraction == 0.4 ? 8 : fraction == 0.6 ? 5 : 3) repeticiones", value: "\(store.displayWeight(max(barKg, targetKg * fraction)).gymNumber) \(store.weightUnit)")
                }
            }
        }.navigationTitle("Discos y calentamiento")
            .onAppear { target = store.displayWeight(60); bar = store.displayWeight(20) }
    }
}
