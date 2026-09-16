import XCTest
@testable import GymTracker

final class TrainingMetricsTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    private func session(on date: Date, weight: Double = 100, reps: Int = 10, type: String = "normal", completed: Bool = true) -> WorkoutSession {
        var set = WorkoutSet()
        set.weightKg = weight
        set.reps = reps
        set.setType = type
        set.completed = completed
        var exercise = WorkoutExercise(exerciseId: "bench")
        exercise.exerciseName = "Press banca"
        exercise.sets = [set]
        var session = WorkoutSession()
        session.startedAt = date
        session.endedAt = date.addingTimeInterval(3600)
        session.exercises = [exercise]
        return session
    }

    func testOneRepFormulasKeepAnActualSingleRep() {
        for formula in OneRMFormula.allCases {
            XCTAssertEqual(formula.estimate(weight: 125, reps: 1), 125)
            XCTAssertEqual(formula.estimate(weight: .nan, reps: 5), 0)
            XCTAssertEqual(formula.estimate(weight: 100, reps: 0), 0)
        }
        XCTAssertEqual(OneRMFormula.epley.estimate(weight: 100, reps: 10), 133.333333, accuracy: 0.0001)
        XCTAssertEqual(OneRMFormula.brzycki.estimate(weight: 100, reps: 10), 133.333333, accuracy: 0.0001)
        XCTAssertEqual(OneRMFormula.lombardi.estimate(weight: 100, reps: 10), 125.892541, accuracy: 0.0001)
        XCTAssertEqual(OneRMFormula.brzycki.estimate(weight: 100, reps: 37), 100)
    }

    func testDailyVolumeKeepsRealCalendarGapsAndGroupsSameDay() {
        let sessions = [session(on: date(2026, 2, 12)), session(on: date(2026, 2, 1)),
                        session(on: date(2026, 2, 1, hour: 20), weight: 50)]
        let points = TrainingMetrics.dailyVolume(sessions, calendar: calendar)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].date, calendar.startOfDay(for: date(2026, 2, 1)))
        XCTAssertEqual(points[1].date, calendar.startOfDay(for: date(2026, 2, 12)))
        XCTAssertEqual(points[0].value, 1500)
    }

    func testWarmupsAndIncompleteSetsDoNotEnterRecordsOrWorkVolume() {
        let sessions = [session(on: date(2026, 2, 1)), session(on: date(2026, 2, 1), weight: 900, type: "warmup"),
                        session(on: date(2026, 2, 1), weight: 800, completed: false)]
        XCTAssertEqual(TrainingMetrics.workingEntries(sessions).count, 1)
        XCTAssertEqual(TrainingMetrics.dailyVolume(sessions, calendar: calendar).first?.value, 1000)
        let history = TrainingMetrics.oneRMHistory(TrainingMetrics.workingEntries(sessions), formula: .epley, calendar: calendar)
        XCTAssertEqual(history.first!.value, 133.333333, accuracy: 0.0001)
    }

    func testWeeklyStreakCrossesYearAndAllowsUnfinishedCurrentWeek() {
        let sessions = [session(on: date(2025, 12, 22)), session(on: date(2025, 12, 29)),
                        session(on: date(2026, 1, 5)), session(on: date(2026, 1, 6)),
                        session(on: date(2026, 1, 19))]
        let streak = TrainingMetrics.weeklyStreak(sessions, today: date(2026, 1, 13), calendar: calendar)
        XCTAssertEqual(streak.current, 3)
        XCTAssertEqual(streak.longest, 3)
    }

    func testWeekWithoutTrainingBreaksCurrentStreak() {
        let sessions = [session(on: date(2025, 12, 22)), session(on: date(2025, 12, 29))]
        let streak = TrainingMetrics.weeklyStreak(sessions, today: date(2026, 1, 13), calendar: calendar)
        XCTAssertEqual(streak.current, 0)
        XCTAssertEqual(streak.longest, 2)
    }

    func testMuscleDistributionUsesPercentagesOfCompletedWorkingSets() {
        var exercise = Exercise()
        exercise.id = "bench"
        exercise.muscles = ["Pecho": 60, "Tríceps": 40]
        let sessions = [session(on: date(2026, 2, 1)), session(on: date(2026, 2, 1), type: "warmup"),
                        session(on: date(2026, 2, 1), completed: false)]
        let muscles = TrainingMetrics.muscleDistribution(sessions, exercises: [exercise])
        XCTAssertEqual(muscles.first { $0.name == "Pecho" }!.sets, 0.6, accuracy: 0.0001)
        XCTAssertEqual(muscles.first { $0.name == "Tríceps" }!.sets, 0.4, accuracy: 0.0001)
    }

    func testEmptyMeasurementValuesKeepExistingFields() {
        var original = BodyMeasurement()
        original.date = date(2026, 1, 1)
        original.weightKg = 80
        original.heightCm = 180
        original.values = ["waistCm": 85, "importedCustomCm": 23]
        let result = MeasurementValues.merging(original: original, existing: original, date: original.date,
                                               weightKg: nil, heightCm: nil, extras: ["chestCm": 100])
        XCTAssertEqual(result.weightKg, 80)
        XCTAssertEqual(result.heightCm, 180)
        XCTAssertEqual(result.values["waistCm"], 85)
        XCTAssertEqual(result.values["importedCustomCm"], 23)
        XCTAssertEqual(result.values["chestCm"], 100)
    }

    func testMovingMeasurementToExistingDateMergesOnlyProvidedValues() {
        var source = BodyMeasurement()
        source.values = ["custom": 12]
        var target = BodyMeasurement()
        target.weightKg = 81
        target.heightCm = 181
        target.values = ["waistCm": 86]
        let result = MeasurementValues.merging(original: source, existing: target, date: date(2026, 2, 1),
                                               weightKg: nil, heightCm: nil, extras: ["waistCm": 83])
        XCTAssertEqual(result.weightKg, 81)
        XCTAssertEqual(result.heightCm, 181)
        XCTAssertEqual(result.values["waistCm"], 83)
        XCTAssertEqual(result.values["custom"], 12)
    }

    func testMeasurementParsingAcceptsDecimalCommaAndRejectsMissingOrInvalid() {
        XCTAssertEqual(MeasurementValues.parse(" 81,5 "), 81.5)
        XCTAssertNil(MeasurementValues.parse(""))
        XCTAssertNil(MeasurementValues.parse("nan"))
        XCTAssertNil(MeasurementValues.parse("-2"))
    }

    func testEnergyEstimationMatchesInitialAndroidFormula() {
        var profile = UserProfile()
        profile.age = 30
        profile.heightCm = 180
        profile.activityFactor = 1.55
        profile.male = true
        profile.goal = "MAINTENANCE"
        let maintenance = EnergyEstimate.calculate(weightKg: 80, profile: profile)!
        XCTAssertEqual(maintenance.basalCalories, 1780)
        XCTAssertEqual(maintenance.dailyCalories, 2759)
        XCTAssertEqual(maintenance.targetCalories, 2759)
        XCTAssertEqual(maintenance.proteinGrams, 144)
        profile.goal = "FAT_LOSS"
        XCTAssertEqual(EnergyEstimate.calculate(weightKg: 80, profile: profile)?.targetCalories, 2359)
        profile.goal = "LEAN_GAIN"
        XCTAssertEqual(EnergyEstimate.calculate(weightKg: 80, profile: profile)?.targetCalories, 3009)
        XCTAssertNil(EnergyEstimate.calculate(weightKg: 0, profile: profile))
        XCTAssertNil(EnergyEstimate.calculate(weightKg: .infinity, profile: profile))
        XCTAssertNil(EnergyEstimate.calculate(weightKg: 1e300, profile: profile))
    }
}
