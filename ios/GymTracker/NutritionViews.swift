import SwiftUI
import Charts

struct EnergyEstimate {
    var basalCalories: Int
    var dailyCalories: Int
    var targetCalories: Int
    var proteinGrams: Int

    /// Initial estimate ported from the Android calculator; no invented weight/performance trend.
    static func calculate(weightKg: Double, profile: UserProfile) -> EnergyEstimate? {
        guard weightKg.isFinite, (0.1...10000).contains(weightKg), profile.heightCm.isFinite, (30...300).contains(profile.heightCm),
              (1...120).contains(profile.age), profile.activityFactor.isFinite else { return nil }
        let basal = Int((10 * weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + (profile.male ? 5 : -161)).rounded())
        guard basal > 0 else { return nil }
        let daily = Int((Double(basal) * min(2.2, max(1.2, profile.activityFactor))).rounded())
        let adjustment: Int
        switch profile.goal {
        case "FAT_LOSS": adjustment = -400
        case "LEAN_GAIN": adjustment = 250
        default: adjustment = 0
        }
        return EnergyEstimate(basalCalories: basal, dailyCalories: daily,
                              targetCalories: max(1200, daily + adjustment), proteinGrams: Int((weightKg * 1.8).rounded()))
    }
}

struct NutritionView: View {
    @EnvironmentObject private var store: GymStore
    @State private var editing: NutritionLog?
    @State private var showGoals = false
    @State private var metric = "Calorías"
    private var logs: [NutritionLog] { store.data.nutrition.sorted { $0.date > $1.date } }
    private var today: NutritionLog? { logs.first { Calendar.current.isDateInToday($0.date) } }
    private var chartLogs: [NutritionLog] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) ?? Date()
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return logs.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
    }

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Hoy").font(.headline)
                    HStack {
                        MetricTile(title: "Calorías · kcal", value: today.map { "\($0.calories)" } ?? "—", symbol: "flame")
                        MetricTile(title: "Proteína · g", value: today.map { "\($0.protein)" } ?? "—", symbol: "fork.knife")
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Objetivos diarios").font(.headline)
                            Text("\(store.data.profile.calorieGoal) kcal · \(store.data.profile.proteinGoal) g de proteína").font(.title3.bold())
                            Button("Editar objetivos y estimación") { showGoals = true }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: { editing = today ?? NutritionLog() }) { Label(today == nil ? "Registrar hoy" : "Editar registro de hoy", systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                    chartCard
                    Text("Diario de alimentación").font(.title2.bold())
                    if logs.isEmpty {
                        EmptyState(title: "Empieza tu diario", message: "Registra las calorías, la proteína y las notas de cada día.", symbol: "fork.knife")
                    }
                    ForEach(logs) { log in
                        Button(action: { editing = log }) {
                            GymCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { Text(log.date.formatted(date: .abbreviated, time: .omitted)).font(.headline); Spacer(); Image(systemName: "pencil") }
                                    Text("\(log.calories) kcal · \(log.protein) g de proteína")
                                    if !log.notes.isEmpty { Text(log.notes).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }.background(Theme.background)
                .navigationTitle("Nutrición")
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { editing = NutritionLog() }) { Image(systemName: "plus").accessibilityLabel("Añadir registro") } } }
                .sheet(item: $editing) { NutritionLogEditor(log: $0) }
                .sheet(isPresented: $showGoals) { NutritionGoalsEditor(profile: store.data.profile) }
        }
    }

    private var chartCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Últimos 30 días").font(.headline)
                Picker("Métrica", selection: $metric) { Text("Calorías").tag("Calorías"); Text("Proteína").tag("Proteína") }.pickerStyle(.segmented)
                if chartLogs.isEmpty {
                    Text("No hay registros en este periodo.").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    Chart {
                        ForEach(chartLogs) { log in
                            BarMark(x: .value("Fecha", log.date, unit: .day), y: .value(metric, metric == "Calorías" ? log.calories : log.protein))
                                .foregroundStyle(Theme.accent)
                        }
                        RuleMark(y: .value("Objetivo", metric == "Calorías" ? store.data.profile.calorieGoal : store.data.profile.proteinGoal))
                            .foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) { Text("Objetivo actual").font(.caption2) }
                    }.frame(height: 200)
                }
                Text("Los días sin registro se dejan vacíos.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct NutritionLogEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State var log: NutritionLog
    @State private var originalID: String?
    @State private var showDelete = false
    private var valid: Bool { log.calories >= 0 && log.calories <= 100000 && log.protein >= 0 && log.protein <= 10000 }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha", selection: $log.date, displayedComponents: .date)
                    LabeledContent("Calorías · kcal") { TextField("0", value: $log.calories, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Proteína · g") { TextField("0", value: $log.protein, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    TextField("Notas", text: $log.notes, axis: .vertical).lineLimit(3...8)
                } header: { Text("Registro diario") } footer: { Text("Hay un registro por día. Guardar actualiza los datos de la fecha elegida.") }
                    .listRowBackground(Theme.surface)
                if originalID != nil {
                    Section { Button("Eliminar registro", role: .destructive) { showDelete = true } }.listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Registro de nutrición").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!valid) }
            }
            .onAppear { originalID = store.data.nutrition.contains(where: { $0.id == log.id }) ? log.id : nil }
            .alert("Eliminar registro", isPresented: $showDelete) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    guard let id = originalID else { return }
                    store.mutate { $0.nutrition.removeAll { $0.id == id } }
                    if !store.data.nutrition.contains(where: { $0.id == id }) { dismiss() }
                }
            } message: { Text("Se eliminarán las calorías, la proteína y las notas de este registro.") }
        }
    }
    private func save() {
        let result = log
        store.mutate { data in
            data.nutrition.removeAll { $0.id == result.id || $0.id == originalID }
            data.nutrition.append(result)
        }
        if store.data.nutrition.contains(result) { dismiss() }
    }
}

private struct NutritionGoalsEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State var profile: UserProfile
    @State private var weight = 0.0
    private var estimate: EnergyEstimate? { EnergyEstimate.calculate(weightKg: store.kgWeight(weight), profile: profile) }
    private var valid: Bool {
        (1...120).contains(profile.age) && profile.heightCm.isFinite && (30...300).contains(profile.heightCm)
            && profile.activityFactor.isFinite && (1.2...2.2).contains(profile.activityFactor)
            && (0...100000).contains(profile.calorieGoal) && (0...10000).contains(profile.proteinGoal)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Mis objetivos diarios") {
                    LabeledContent("Calorías · kcal") { TextField("Calorías", value: $profile.calorieGoal, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Proteína · g") { TextField("Proteína", value: $profile.proteinGoal, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                }.listRowBackground(Theme.surface)
                Section("Datos para la estimación") {
                    Picker("Sexo de la fórmula", selection: $profile.male) { Text("Masculino").tag(true); Text("Femenino").tag(false) }
                    Stepper("Edad: \(profile.age) años", value: $profile.age, in: 1...120)
                    LabeledContent("Altura · cm") { DecimalField(title: "Altura", value: $profile.heightCm).multilineTextAlignment(.trailing) }
                    LabeledContent("Peso · \(store.weightUnit)") { DecimalField(title: "Peso para estimar", value: $weight).multilineTextAlignment(.trailing) }
                    Picker("Actividad", selection: $profile.activityFactor) {
                        Text("Baja · 1,2").tag(1.2)
                        Text("Ligera · 1,375").tag(1.375)
                        Text("Moderada · 1,55").tag(1.55)
                        Text("Alta · 1,725").tag(1.725)
                        Text("Muy alta · 1,9").tag(1.9)
                        if ![1.2, 1.375, 1.55, 1.725, 1.9].contains(profile.activityFactor) { Text("Personalizada · \(profile.activityFactor.gymNumber)").tag(profile.activityFactor) }
                    }
                    Picker("Objetivo", selection: $profile.goal) {
                        Text("Perder grasa").tag("FAT_LOSS")
                        Text("Mantenimiento").tag("MAINTENANCE")
                        Text("Ganar masa").tag("LEAN_GAIN")
                        Text("Recomposición").tag("RECOMP")
                    }
                }.listRowBackground(Theme.surface)
                Section("Estimación inicial") {
                    if let estimate = estimate, valid, weight > 0 {
                        LabeledContent("Metabolismo basal", value: "\(estimate.basalCalories) kcal")
                        LabeledContent("Gasto diario estimado", value: "\(estimate.dailyCalories) kcal")
                        LabeledContent("Objetivo estimado", value: "\(estimate.targetCalories) kcal")
                        LabeledContent("Proteína estimada", value: "\(estimate.proteinGrams) g")
                        Button("Usar estos valores como objetivos") {
                            profile.calorieGoal = estimate.targetCalories
                            profile.proteinGoal = estimate.proteinGrams
                        }
                    } else { Text("Introduce peso, altura y edad válidos para calcular una estimación.").foregroundStyle(.secondary) }
                    Text("Fórmula Mifflin–St Jeor y factor de actividad. Es una estimación orientativa. Los objetivos se pueden editar; no se ajustan automáticamente por cambios de peso o rendimiento.")
                        .font(.caption).foregroundStyle(.secondary)
                }.listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Objetivos y perfil").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                    let result = profile
                    store.mutate { $0.profile = result }
                    if store.data.profile == result { dismiss() }
                }.disabled(!valid) }
            }
            .onAppear { weight = store.displayWeight(store.data.measurements.filter { $0.weightKg > 0 }.sorted { $0.date > $1.date }.first?.weightKg ?? 0) }
        }
    }
}

private let measurementFields: [(key: String, label: String)] = [
    ("bodyFatPercent", "Grasa corporal · %"), ("leanMassKg", "Masa magra · kg"),
    ("neckCm", "Cuello · cm"), ("shoulderCm", "Hombros · cm"), ("chestCm", "Pecho · cm"),
    ("leftBicepCm", "Bíceps izquierdo · cm"), ("rightBicepCm", "Bíceps derecho · cm"),
    ("leftForearmCm", "Antebrazo izquierdo · cm"), ("rightForearmCm", "Antebrazo derecho · cm"),
    ("waistCm", "Cintura · cm"), ("abdomenCm", "Abdomen · cm"), ("hipsCm", "Caderas · cm"),
    ("leftThighCm", "Muslo izquierdo · cm"), ("rightThighCm", "Muslo derecho · cm"),
    ("leftCalfCm", "Gemelo izquierdo · cm"), ("rightCalfCm", "Gemelo derecho · cm")
]

struct MeasurementsView: View {
    @EnvironmentObject private var store: GymStore
    @State private var editing: BodyMeasurement?
    private var entries: [BodyMeasurement] { store.data.measurements.sorted { $0.date > $1.date } }
    private var weights: [BodyMeasurement] { entries.filter { $0.weightKg > 0 }.sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: { editing = entries.first(where: { Calendar.current.isDateInToday($0.date) }) ?? BodyMeasurement() }) {
                    Label("Registrar medidas", systemImage: "plus.circle.fill")
                }.buttonStyle(.borderedProminent).tint(Theme.accent)
                GymCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Evolución del peso · \(store.weightUnit)").font(.headline)
                        if weights.isEmpty {
                            Text("Registra tu peso para ver la evolución.").foregroundStyle(.secondary).frame(minHeight: 100)
                        } else {
                            Chart(weights) { entry in
                                LineMark(x: .value("Fecha", entry.date), y: .value(store.weightUnit, store.displayWeight(entry.weightKg))).foregroundStyle(Theme.accent)
                                PointMark(x: .value("Fecha", entry.date), y: .value(store.weightUnit, store.displayWeight(entry.weightKg))).foregroundStyle(Theme.accent)
                            }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 200)
                        }
                    }
                }
                Text("Registros corporales").font(.title2.bold())
                if entries.isEmpty {
                    EmptyState(title: "Un punto de partida", message: "Puedes anotar solo las medidas que tengas disponibles.", symbol: "ruler")
                }
                ForEach(entries) { entry in
                    Button(action: { editing = entry }) {
                        GymCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.headline); Spacer(); Image(systemName: "pencil") }
                                if entry.weightKg > 0 { LabeledContent("Peso", value: "\(store.displayWeight(entry.weightKg).gymNumber) \(store.weightUnit)") }
                                if entry.heightCm > 0 { LabeledContent("Altura", value: "\(entry.heightCm.gymNumber) cm") }
                                ForEach(measurementFields, id: \.key) { field in
                                    if let value = entry.values[field.key] { LabeledContent(field.label, value: value.gymNumber).font(.subheadline) }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding()
        }
        .background(Theme.background).navigationTitle("Medidas corporales").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { MeasurementEditor(original: $0) }
    }
}

enum MeasurementValues {
    static func parse(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else { return nil }
        return value
    }

    /// Missing input keeps existing fields, including extra values from imported backups.
    static func merging(original: BodyMeasurement, existing: BodyMeasurement?, date: Date,
                        weightKg: Double?, heightCm: Double?, extras: [String: Double]) -> BodyMeasurement {
        var result = existing ?? original
        result.date = date
        if let weight = weightKg { result.weightKg = weight }
        if let height = heightCm { result.heightCm = height }
        for (key, value) in original.values where result.values[key] == nil { result.values[key] = value }
        result.values.merge(extras) { _, updated in updated }
        return result
    }
}

private struct MeasurementEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    var original: BodyMeasurement
    @State private var date = Date()
    @State private var fields: [String: String] = [:]
    @State private var originalID: String?
    @State private var showDelete = false
    private var hasInput: Bool { fields.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    private var valid: Bool {
        hasInput && fields.allSatisfy { key, text in
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            guard let value = MeasurementValues.parse(text) else { return false }
            return key == "bodyFatPercent" ? value <= 100 : value <= 100000
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                } footer: { Text("Los campos vacíos conservan las medidas ya guardadas para esa fecha. Puedes registrar solo los valores que tengas.") }
                    .listRowBackground(Theme.surface)
                Section("Composición corporal") {
                    input("weightKg", "Peso · \(store.weightUnit)")
                    input("heightCm", "Altura · cm")
                    input("bodyFatPercent", "Grasa corporal · %")
                    input("leanMassKg", "Masa magra · kg")
                }.listRowBackground(Theme.surface)
                Section("Perímetros") {
                    ForEach(measurementFields.filter { $0.key.hasSuffix("Cm") }, id: \.key) { field in input(field.key, field.label) }
                }.listRowBackground(Theme.surface)
                if hasInput && !valid { Section { Text("Usa números positivos. La grasa corporal no puede superar el 100 %.").foregroundStyle(.red).font(.caption) } }
                if originalID != nil { Section { Button("Eliminar registro de medidas", role: .destructive) { showDelete = true } }.listRowBackground(Theme.surface) }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Registrar medidas").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!valid) }
            }
            .onAppear(perform: load)
            .alert("Eliminar medidas", isPresented: $showDelete) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    guard let id = originalID else { return }
                    store.mutate { $0.measurements.removeAll { $0.id == id } }
                    if !store.data.measurements.contains(where: { $0.id == id }) { dismiss() }
                }
            } message: { Text("Se eliminarán todas las medidas de este registro.") }
        }
    }
    private func input(_ key: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("Sin dato", text: Binding(get: { fields[key] ?? "" }, set: { fields[key] = $0 }))
                .keyboardType(.decimalPad).accessibilityLabel(label)
        }
    }
    private func load() {
        date = original.date
        originalID = store.data.measurements.contains(where: { $0.id == original.id }) ? original.id : nil
        fields = original.values.mapValues { String($0) }
        fields["weightKg"] = original.weightKg > 0 ? String(store.displayWeight(original.weightKg)) : ""
        fields["heightCm"] = original.heightCm > 0 ? String(original.heightCm) : ""
    }
    private func save() {
        let weight = MeasurementValues.parse(fields["weightKg"] ?? "").map { store.kgWeight($0) }
        let height = MeasurementValues.parse(fields["heightCm"] ?? "")
        let extras = fields.filter { $0.key != "weightKg" && $0.key != "heightCm" }.compactMapValues { MeasurementValues.parse($0) }
        let result = MeasurementValues.merging(original: original, existing: store.data.measurements.first { $0.id == GymDate.dayKey(date) }, date: date, weightKg: weight, heightCm: height, extras: extras)
        store.mutate { data in
            data.measurements.removeAll { $0.id == result.id || $0.id == originalID }
            data.measurements.append(result)
        }
        if store.data.measurements.contains(result) { dismiss() }
    }
}
