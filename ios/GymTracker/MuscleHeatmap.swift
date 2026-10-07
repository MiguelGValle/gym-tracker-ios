import SwiftUI

/// Keeps the colour scale on individual catalogue muscles even when a drawing region
/// represents several muscles. Custom muscle names remain in the distribution chart.
struct MuscleHeatmapScale {
    let totals: [String: Double]
    let maximum: Double

    init(totals: [String: Double], supportedMuscles: [String]) {
        self.totals = totals
        maximum = supportedMuscles.map { totals[$0, default: 0] }
            .filter { $0.isFinite && $0 > 0 }.max() ?? 0
    }

    func equivalentSets(for muscles: [String]) -> Double {
        guard !muscles.isEmpty else { return 0 }
        return muscles.reduce(0) { total, muscle in
            let value = totals[muscle, default: 0]
            return total + (value.isFinite && value > 0 ? value : 0)
        } / Double(muscles.count)
    }

    func intensity(for muscles: [String]) -> Double {
        guard maximum > 0 else { return 0 }
        return min(1, max(0, equivalentSets(for: muscles) / maximum))
    }
}

private enum MuscleHeatmapPalette {
    static let neutral = Color(red: 72.0 / 255, green: 80.0 / 255, blue: 94.0 / 255)
    static let low = Color(red: 71.0 / 255, green: 126.0 / 255, blue: 209.0 / 255)
    static let middle = Color(red: 48.0 / 255, green: 188.0 / 255, blue: 170.0 / 255)
    static let high = Color(red: 1, green: 122.0 / 255, blue: 61.0 / 255)

    static func color(intensity: Double) -> Color {
        guard intensity > 0 else { return neutral }
        let amount = min(1, intensity)
        let start: (red: Double, green: Double, blue: Double)
        let end: (red: Double, green: Double, blue: Double)
        let fraction: Double
        if amount <= 0.5 {
            start = (71, 126, 209)
            end = (48, 188, 170)
            fraction = amount * 2
        } else {
            start = (48, 188, 170)
            end = (255, 122, 61)
            fraction = (amount - 0.5) * 2
        }
        return Color(red: (start.red + (end.red - start.red) * fraction) / 255,
                     green: (start.green + (end.green - start.green) * fraction) / 255,
                     blue: (start.blue + (end.blue - start.blue) * fraction) / 255)
    }
}

struct MuscleHeatmapCard: View {
    let totals: [String: Double]
    let workingSetCount: Int

    private var muscles: [String] {
        Set((MuscleMapGeometry.front + MuscleMapGeometry.back).flatMap(\.muscleKeys))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private var scale: MuscleHeatmapScale { MuscleHeatmapScale(totals: totals, supportedMuscles: muscles) }

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mapa muscular").font(.headline)
                    Text("Series equivalentes · periodo seleccionado")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 16) {
                    MuscleBodyDiagram(title: "Frontal", outline: MuscleMapGeometry.frontOutline,
                                      regions: MuscleMapGeometry.front, scale: scale)
                    MuscleBodyDiagram(title: "Posterior", outline: MuscleMapGeometry.backOutline,
                                      regions: MuscleMapGeometry.back, scale: scale)
                }
                legend
                if workingSetCount == 0 {
                    Text("No hay series efectivas completadas en este periodo.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if scale.maximum == 0 {
                    Text(totals.isEmpty
                         ? "Añade porcentajes musculares a tus ejercicios para colorear el mapa."
                         : "Los músculos personalizados aparecen en la distribución. Usa músculos del catálogo para colorear el mapa.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("El color compara el trabajo registrado de cada músculo con el más trabajado del periodo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup("Series por músculo") {
                    VStack(spacing: 8) {
                        ForEach(muscles, id: \.self) { muscle in
                            HStack {
                                Text(muscle)
                                Spacer(minLength: 8)
                                Text(scale.equivalentSets(for: [muscle]).formatted(.number.precision(.fractionLength(0...2))))
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(muscle)
                            .accessibilityValue("\(scale.equivalentSets(for: [muscle]).formatted(.number.precision(.fractionLength(0...2)))) series equivalentes")
                        }
                    }.padding(.top, 8)
                }.font(.subheadline).tint(.secondary)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 7) {
            LinearGradient(colors: [MuscleHeatmapPalette.low, MuscleHeatmapPalette.middle, MuscleHeatmapPalette.high],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 8).clipShape(Capsule()).accessibilityHidden(true)
            HStack {
                Text("Menos trabajo")
                Spacer()
                Text("Más trabajo")
            }.font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle().fill(MuscleHeatmapPalette.neutral).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Sin trabajo").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MuscleBodyDiagram: View {
    let title: String
    let outline: Path
    let regions: [MuscleMapRegion]
    let scale: MuscleHeatmapScale

    var body: some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let factor = min(size.width / MuscleMapGeometry.width, size.height / MuscleMapGeometry.height)
                var drawing = context
                drawing.translateBy(x: (size.width - MuscleMapGeometry.width * factor) / 2,
                                    y: (size.height - MuscleMapGeometry.height * factor) / 2)
                drawing.scaleBy(x: factor, y: factor)
                drawing.fill(outline, with: .color(Color(red: 0.16, green: 0.18, blue: 0.21)))
                drawing.stroke(outline, with: .color(Color(red: 0.33, green: 0.36, blue: 0.41)), lineWidth: 1)
                for region in regions {
                    drawing.fill(region.path, with: .color(MuscleHeatmapPalette.color(intensity: scale.intensity(for: region.muscleKeys))))
                    drawing.stroke(region.path, with: .color(Theme.surface), lineWidth: 1.2)
                }
            }
            .aspectRatio(MuscleMapGeometry.width / MuscleMapGeometry.height, contentMode: .fit)
            .accessibilityLabel("Vista \(title.lowercased()) del mapa muscular")
            .accessibilityHint("Consulta los valores en Series por músculo.")
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }.frame(maxWidth: .infinity)
    }
}
