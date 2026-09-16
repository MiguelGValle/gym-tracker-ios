$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$seedSourcePath = Join-Path $projectRoot 'app/src/main/java/com/codex/gymtracker/data/ExerciseSeed.kt'
if (-not (Test-Path -LiteralPath $seedSourcePath)) { $seedSourcePath = Join-Path $projectRoot 'ios/reference/ExerciseSeed.kt' }
$source = Get-Content -Raw -LiteralPath $seedSourcePath
$categories = @{ chest = @('Pecho','Empuje'); back = @('Espalda','Traccion'); shoulder = @('Hombro','Empuje/aislamiento'); legs = @('Pierna','Pierna'); arms = @('Brazos','Aislamiento'); core = @('Core','Core'); cardio = @('Cardio','Cardio') }
$rows = [regex]::Matches($source, '(?m)^\s*(chest|back|shoulder|legs|arms|core|cardio|technogym)\("([^"]+)", "([^"]+)", (?:"([^"]+)", "([^"]+)", )?mapOf\((.*?)\)\)')
if ($rows.Count -ne 104) { throw "Expected 104 exercises; found $($rows.Count)" }
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('// Generated from the Android catalog by ios/scripts/generate-seed.ps1.')
$lines.Add('import Foundation')
$lines.Add('enum ExerciseSeed {')
$lines.Add('    static let all: [Exercise] = [')
foreach ($row in $rows) {
    $kind = $row.Groups[1].Value
    $name = $row.Groups[2].Value
    $equipment = $row.Groups[3].Value
    $id = [regex]::Replace($name.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_')
    $category = if ($kind -eq 'technogym') { $row.Groups[4].Value } else { $categories[$kind][0] }
    $movement = if ($kind -eq 'technogym') { $row.Groups[5].Value } else { $categories[$kind][1] }
    $tech = if ($kind -eq 'technogym') { 'true' } else { 'false' }
    $muscles = ([regex]::Matches($row.Groups[6].Value, '"([^"]+)" to (\d+)') | ForEach-Object { '"' + $_.Groups[1].Value + '": ' + $_.Groups[2].Value }) -join ', '
    $lines.Add(('        Exercise(id: "{0}", name: "{1}", equipment: "{2}", category: "{3}", movement: "{4}", technogym: {5}, muscles: [{6}]),' -f $id,$name,$equipment,$category,$movement,$tech,$muscles))
}
$lines.Add('    ]')
$lines.Add('    static var routines: [Routine] {')
$lines.Add('        let templates: [(String, [String])] = [')
$logic = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'app/src/main/java/com/codex/gymtracker/ui/WorkoutLogic.kt')
$templates = [regex]::Matches($logic, '(?m)^\s*"([^"]+)" to listOf\(([^\n]+)\)')
if ($templates.Count -ne 6) { throw 'Expected six routine templates' }
foreach ($template in $templates) { $lines.Add(('            ("{0}", [{1}]),' -f $template.Groups[1].Value,$template.Groups[2].Value)) }
$lines.Add('        ]')
$lines.Add('        return templates.enumerated().map { index, template in')
$lines.Add('            Routine(id: "seed-routine-\(index)", name: template.0, notes: "Plantilla editable. Ajusta ejercicios, series, repeticiones y descansos a tu plan.", exercises: template.1.compactMap { name in')
$lines.Add('                guard let exercise = all.first(where: { $0.name == name }) else { return nil }')
$lines.Add('                let sets = (0..<3).map { _ in name == "Plancha" ? WorkoutSet(reps: 0, durationSeconds: 30) : WorkoutSet() }')
$lines.Add('                return WorkoutExercise(exerciseId: exercise.id, exerciseName: name, sets: sets)')
$lines.Add('            })')
$lines.Add('        }')
$lines.Add('    }')
$lines.Add('    static var initialData: GymData { GymData(exercises: all, routines: routines) }')
$lines.Add('}')
[IO.File]::WriteAllLines((Join-Path $projectRoot 'ios/GymTracker/ExerciseSeed.swift'), $lines, [Text.UTF8Encoding]::new($false))
Write-Output "Generated $($rows.Count) exercises and $($templates.Count) routine templates."
