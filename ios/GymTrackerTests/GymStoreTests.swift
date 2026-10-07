import XCTest
@testable import GymTracker

final class GymStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GymStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    @MainActor
    func testSeedAndRoundTripPersistence() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        XCTAssertEqual(store.data.exercises.count, 104)
        XCTAssertEqual(store.data.routines.count, 6)
        XCTAssertEqual(Set(store.data.exercises.map(\.id)).count, 104)
        XCTAssertEqual(store.data.exercises.first?.id, "press_banca_barra")
        store.mutate { $0.exercises[0].notes = "Guardado en disco" }
        XCTAssertNil(store.errorMessage)
        let reopened = GymStore(directory: directory)
        XCTAssertEqual(reopened.data.exercises[0].notes, "Guardado en disco")
        XCTAssertEqual(reopened.data.routines, store.data.routines)
    }

    @MainActor
    func testFailedWriteDoesNotPublishMutation() throws {
        let parent = try temporaryDirectory()
        let blocked = parent.appendingPathComponent("file-instead-of-directory")
        try Data("occupied".utf8).write(to: blocked)
        let store = GymStore(directory: blocked)
        let before = store.data
        store.mutate { $0.profile.age = 42 }
        XCTAssertEqual(store.data, before)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: blocked), Data("occupied".utf8))
    }

    @MainActor
    func testInvalidMutationDoesNotChangeMemoryOrDisk() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.mutate { $0.profile.age = 31 }
        let originalFile = try Data(contentsOf: directory.appendingPathComponent("gym-data.json"))
        let before = store.data
        store.mutate { $0.profile.heightCm = .nan }
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("gym-data.json")), originalFile)
        XCTAssertNotNil(store.errorMessage)
    }

    @MainActor
    func testCorruptCurrentFileRecoversPreviousAndPreservesDamagedBytes() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.mutate { $0.profile.age = 31 }
        store.mutate { $0.profile.age = 32 }
        let corrupted = Data("{damaged".utf8)
        try corrupted.write(to: directory.appendingPathComponent("gym-data.json"))
        let reopened = GymStore(directory: directory)
        XCTAssertEqual(reopened.data.profile.age, 31)
        XCTAssertNotNil(reopened.errorMessage)
        reopened.mutate { $0.profile.age = 33 }
        XCTAssertEqual(GymStore(directory: directory).data.profile.age, 33)
        let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("gym-data.corrupt-") }
        XCTAssertFalse(preserved.isEmpty)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), corrupted)
    }

    @MainActor
    func testCorruptionWithoutValidSnapshotCannotOverwriteOriginal() throws {
        let directory = try temporaryDirectory()
        let corrupted = Data("not a backup".utf8)
        let file = directory.appendingPathComponent("gym-data.json")
        try corrupted.write(to: file)
        let store = GymStore(directory: directory)
        store.mutate { $0.profile.age = 50 }
        XCTAssertEqual(try Data(contentsOf: file), corrupted)
        XCTAssertThrowsError(try store.backupData())
        var valid = ExerciseSeed.initialData
        valid.profile.age = 45
        try store.restore(valid)
        XCTAssertEqual(GymStore(directory: directory).data.profile.age, 45)
    }

    @MainActor
    func testFinishingUnmarkedWorkoutRetainsEveryExerciseAndClearsMatchingDraft() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.startWorkout(routine: store.data.routines[0])
        let originalID = try XCTUnwrap(store.data.draft?.id)
        store.startWorkout()
        XCTAssertEqual(store.data.draft?.id, originalID)
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].weightKg = 50
        XCTAssertTrue(workout.exercises.flatMap(\.sets).allSatisfy { !$0.completed })
        try store.finishWorkout(workout)
        XCTAssertNil(store.data.draft)
        XCTAssertEqual(store.data.sessions.count, 1)
        XCTAssertEqual(store.data.sessions[0].completedSets, workout.exercises.flatMap(\.sets).count)
        XCTAssertEqual(store.data.sessions[0].exercises.count, workout.exercises.count)
        XCTAssertEqual(store.data.sessions[0].exercises.map(\.id), workout.exercises.map(\.id))
        XCTAssertEqual(store.data.sessions[0].exercises.flatMap(\.sets).map(\.id), workout.exercises.flatMap(\.sets).map(\.id))
        XCTAssertTrue(store.data.sessions[0].exercises.flatMap(\.sets).allSatisfy(\.completed))
        XCTAssertEqual(store.data.sessions[0].volume, 500)
        XCTAssertEqual(GymStore(directory: directory).data.sessions, store.data.sessions)
    }

    @MainActor
    func testFinishingMixedFlagsKeepsFailureAndAllValuesAcrossReopenAndBackup() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        let sets = [WorkoutSet(reps: 10, weightKg: 50, completed: true),
                    WorkoutSet(reps: 8, weightKg: 60, setType: "failure", rpe: 10),
                    WorkoutSet(reps: 6, weightKg: 40, setType: "dropset"),
                    WorkoutSet(reps: 12, weightKg: 20, setType: "warmup", completed: true)]
        let workout = WorkoutSession(title: "Todas las series", workoutDate: "2026-10-06", notes: "Sin omisiones", exercises: [
            WorkoutExercise(exerciseId: store.data.exercises[0].id, notes: "Primer bloque", restSeconds: 80, supersetId: "group", sets: Array(sets.prefix(2))),
            WorkoutExercise(exerciseId: store.data.exercises[1].id, notes: "Segundo bloque", restSeconds: 90, supersetId: "group", sets: Array(sets.suffix(2)))])
        store.mutate { $0.draft = workout }
        try store.finishWorkout(workout)
        var expected = workout
        for exercise in expected.exercises.indices {
            for index in expected.exercises[exercise].sets.indices { expected.exercises[exercise].sets[index].completed = true }
        }
        XCTAssertEqual(store.data.sessions, [expected])
        XCTAssertNil(store.data.draft)
        let reopened = GymStore(directory: directory)
        XCTAssertEqual(reopened.data.sessions, [expected])
        XCTAssertEqual(try BackupCodec.decode(reopened.backupData()).sessions, [expected])
        XCTAssertEqual(reopened.data.sessions[0].volume, 1220)
        XCTAssertEqual(reopened.previousSet(exerciseId: store.data.exercises[0].id, index: 1)?.setType, "failure")
        let csv = HevyCSV.export(reopened.data.sessions, catalog: reopened.data.exercises)
        let preview = try reopened.previewHevyCSV(csv)
        XCTAssertTrue(preview.warnings.isEmpty)
        XCTAssertEqual(preview.sessions[0].exercises.flatMap(\.sets).map(\.setType), sets.map(\.setType))
        XCTAssertEqual(preview.sessions[0].exercises.flatMap(\.sets).map(\.id), sets.map(\.id))
    }

    @MainActor
    func testEmptyWorkoutCannotFinishAndRetainsDraftOnDisk() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.startWorkout()
        let workout = try XCTUnwrap(store.data.draft)
        let before = store.data
        let file = directory.appendingPathComponent("gym-data.json")
        let stored = try Data(contentsOf: file)
        XCTAssertThrowsError(try store.finishWorkout(workout))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: file), stored)
        XCTAssertEqual(GymStore(directory: directory).data.draft, workout)
    }

    @MainActor
    func testZeroMetricsSaveIndependentlyOfLegacyCompletionOrFailureFlag() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let workout = WorkoutSession(exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id,
            sets: [WorkoutSet(reps: 0), WorkoutSet(reps: 0, setType: "failure", completed: true)])])
        store.mutate { $0.draft = workout }
        XCTAssertNil(store.errorMessage)
        try store.finishWorkout(workout)
        XCTAssertNil(store.data.draft)
        XCTAssertEqual(store.data.sessions[0].completedSets, 2)
        XCTAssertEqual(store.data.sessions[0].exercises[0].sets.map(\.setType), ["normal", "failure"])
    }

    @MainActor
    func testFinishValidationFailureRetainsDraftAndDoesNotCreateSession() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.startWorkout(routine: store.data.routines[0])
        let before = store.data
        let file = directory.appendingPathComponent("gym-data.json")
        let stored = try Data(contentsOf: file)
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].rpe = 11
        XCTAssertThrowsError(try store.finishWorkout(workout))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: file), stored)
        XCTAssertEqual(GymStore(directory: directory).data, before)
    }

    @MainActor
    func testFinishAndRoutineAreSavedTogetherOrNeitherIsSaved() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.startWorkout(routine: store.data.routines[0])
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].setType = "failure"
        let before = store.data
        let stored = try Data(contentsOf: directory.appendingPathComponent("gym-data.json"))
        let invalid = Routine(name: "", exercises: workout.exercises)
        XCTAssertThrowsError(try store.finishWorkout(workout, routine: invalid))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("gym-data.json")), stored)
        let routine = Routine(name: "Sesión guardada", exercises: workout.exercises)
        try store.finishWorkout(workout, routine: routine)
        let reopened = GymStore(directory: directory)
        XCTAssertNil(reopened.data.draft)
        XCTAssertEqual(reopened.data.sessions.count, 1)
        XCTAssertTrue(reopened.data.routines.contains { $0.id == routine.id })
    }

    @MainActor
    func testCSVImportCannotReplaceAnActiveWorkout() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let preview = try store.previewHevyCSV("title,start_time,exercise_title,set_index,reps\nA,2026-09-10T09:00:00,Press banca barra,0,10")
        store.startWorkout()
        let draft = store.data.draft
        XCTAssertThrowsError(try store.importHevy(preview))
        XCTAssertEqual(store.data.draft, draft)
        XCTAssertTrue(store.data.sessions.isEmpty)
    }

    @MainActor
    func testRestoreBlockedByActiveDraftAndInvalidData() throws {
        let store = GymStore(directory: try temporaryDirectory())
        store.startWorkout()
        XCTAssertThrowsError(try store.restore(ExerciseSeed.initialData))
        store.mutate { $0.draft = nil }
        let before = store.data
        var incoming = ExerciseSeed.initialData
        incoming.exercises.append(incoming.exercises[0])
        XCTAssertThrowsError(try store.restore(incoming))
        XCTAssertEqual(store.data, before)
    }

    @MainActor
    func testHevyReimportIsIdempotentAndPartialFileDoesNotDeleteExistingSets() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let header = "title,start_time,exercise_title,set_index,reps,weight_kg\n"
        let first = "A,2026-09-10T09:00:00,Press banca barra,0,10,50\n"
        let second = "A,2026-09-10T09:00:00,Press banca barra,1,8,60\n"
        let preview = try store.previewHevyCSV(header + first + second)
        try store.importHevy(preview)
        try store.importHevy(preview)
        try store.importHevy(store.previewHevyCSV(header + first))
        XCTAssertEqual(store.data.sessions.count, 1)
        XCTAssertEqual(store.data.sessions[0].completedSets, 2)
        XCTAssertEqual(store.data.exercises.count, 104)
    }

    @MainActor
    func testAndroidImportKeysReconcileDifferentInstallationIDs() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let csv = "title,start_time,exercise_title,set_index,reps\nA,2026-09-10T09:00:00,Press banca barra,0,10"
        let preview = try store.previewHevyCSV(csv)
        try store.importHevy(preview)
        var copy = store.data
        copy.sessions[0].id = "android-random-uuid"
        copy.sessions[0].exercises[0].id = "android-block-id"
        copy.sessions[0].exercises[0].sets[0].id = "android-set-id"
        try store.restore(copy)
        XCTAssertEqual(store.data.sessions.count, 1)
        XCTAssertEqual(store.data.sessions[0].completedSets, 1)
    }

    @MainActor
    func testNewRoutineWorkoutStartsWithOneFreshSetAndPreservesTemplate() throws {
        let store = GymStore(directory: try temporaryDirectory())
        var first = WorkoutSet(reps: 8, weightKg: 45, setType: "failure", rpe: 8, distanceKm: 1.2, durationSeconds: 120, completed: true)
        first.importKey = "legacy-import"
        let second = WorkoutSet(reps: 6, weightKg: 50, durationSeconds: 100, completed: true)
        let block = WorkoutExercise(exerciseId: store.data.exercises[0].id, restSeconds: 90, sets: [first, second])
        let routine = Routine(name: "Original", exercises: [block])
        store.mutate { $0.routines.append(routine) }
        store.startWorkout(routine: routine)
        let draft = try XCTUnwrap(store.data.draft)
        let created = try XCTUnwrap(draft.exercises.first?.sets.first)
        XCTAssertEqual(draft.exercises[0].sets.count, 1)
        XCTAssertEqual(created.weightKg, 45)
        XCTAssertEqual(created.reps, 8)
        XCTAssertEqual(created.rpe, 8)
        XCTAssertEqual(created.distanceKm, 1.2)
        XCTAssertEqual(created.setType, "normal")
        XCTAssertNotEqual(created.id, first.id)
        XCTAssertNil(created.importKey)
        XCTAssertNil(created.durationSeconds)
        XCTAssertFalse(created.completed)
        XCTAssertEqual(draft.exercises[0].restSeconds, 0)
        XCTAssertNil(draft.endedAt)
        XCTAssertEqual(draft.startedAt, Calendar.current.startOfDay(for: draft.startedAt))
        XCTAssertEqual(store.data.routines.last, routine)
    }

    @MainActor
    func testRepeatedWorkoutStartsOneSetAndDoesNotAlterHistory() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        let first = WorkoutSet(reps: 0, weightKg: 20, setType: "failure", durationSeconds: 30, completed: true)
        let second = WorkoutSet(reps: 8, weightKg: 40, durationSeconds: 90, completed: true)
        let original = WorkoutSession(importKey: "imported-session", title: "Histórico",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000), endedAt: Date(timeIntervalSince1970: 1_800_003_600),
            notes: "Conservar", exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id, restSeconds: 120, sets: [first, second])])
        store.mutate { $0.sessions.append(original) }
        store.repeatWorkout(original)
        let draft = try XCTUnwrap(store.data.draft)
        XCTAssertNotEqual(draft.id, original.id)
        XCTAssertNil(draft.importKey)
        XCTAssertNil(draft.endedAt)
        XCTAssertEqual(draft.exercises[0].sets.count, 1)
        XCTAssertNil(draft.exercises[0].sets[0].durationSeconds)
        XCTAssertFalse(draft.exercises[0].sets[0].completed)
        XCTAssertEqual(draft.exercises[0].sets[0].setType, "normal")
        XCTAssertEqual(draft.exercises[0].sets[0].reps, first.reps)
        XCTAssertEqual(store.data.sessions, [original])
        let reopened = GymStore(directory: directory)
        XCTAssertEqual(reopened.data.sessions, [original])
        XCTAssertEqual(reopened.data.draft, draft)
    }

    @MainActor
    func testResumeKeepsLegacyDraftAllSetsDatesAndTimes() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        let sets = [WorkoutSet(reps: 10, weightKg: 50, setType: "failure", durationSeconds: 40, completed: true),
                    WorkoutSet(reps: 8, weightKg: 60, setType: "failure", durationSeconds: 50)]
        let original = WorkoutSession(title: "Borrador previo", startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id, restSeconds: 105, sets: sets)])
        store.mutate { $0.draft = original }
        let reopened = GymStore(directory: directory)
        reopened.startWorkout(routine: reopened.data.routines[0])
        reopened.repeatWorkout(original)
        XCTAssertEqual(reopened.data.draft, original)
        XCTAssertEqual(try BackupCodec.decode(reopened.backupData()).draft, original)
    }

    @MainActor
    func testHistoryEditAndBackupRetainLegacyTimesAndAllSets() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        let original = WorkoutSession(title: "Antes", startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            endedAt: Date(timeIntervalSince1970: 1_800_001_800),
            exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id, restSeconds: 90,
                sets: [WorkoutSet(reps: 0, durationSeconds: 30, completed: true),
                       WorkoutSet(reps: 8, weightKg: 50, durationSeconds: 45, completed: true)])])
        store.mutate { $0.sessions.append(original) }
        store.mutate { $0.sessions[0].title = "Después"; $0.sessions[0].exercises[0].sets[1].weightKg = 55 }
        XCTAssertNil(store.errorMessage)
        let edited = store.data.sessions[0]
        XCTAssertEqual(edited.exercises[0].sets.count, 2)
        XCTAssertEqual(edited.startedAt, original.startedAt)
        XCTAssertEqual(edited.endedAt, original.endedAt)
        XCTAssertEqual(edited.exercises[0].restSeconds, 90)
        XCTAssertEqual(edited.exercises[0].sets.map(\.durationSeconds), [30, 45])
        XCTAssertEqual(try BackupCodec.decode(store.backupData()).sessions, [edited])
        XCTAssertEqual(GymStore(directory: directory).data.sessions, [edited])
    }

    @MainActor
    func testFinishingNewWorkoutDoesNotRecordAnEndTime() throws {
        let store = GymStore(directory: try temporaryDirectory())
        store.startWorkout(routine: store.data.routines[0])
        var draft = try XCTUnwrap(store.data.draft)
        try store.finishWorkout(draft)
        XCTAssertNil(store.data.sessions[0].endedAt)
        XCTAssertNil(store.data.sessions[0].exercises[0].sets[0].durationSeconds)
    }

    @MainActor
    func testOwnCSVReimportKeepsOriginalSetIDsAndDoesNotDuplicateSeries() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let date = try XCTUnwrap(GymDate.localDate(fromCivilDay: "2026-10-06"))
        let sessions = (0..<2).map { _ in
            WorkoutSession(importKey: "import-session-\(UUID().uuidString)", title: "Sesión", startedAt: Calendar.current.startOfDay(for: date), workoutDate: "2026-10-06",
                exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id, exerciseName: store.data.exercises[0].name,
                    sets: [WorkoutSet(reps: 8, weightKg: 50, completed: true), WorkoutSet(reps: 8, weightKg: 50, completed: true)])])
        }
        store.mutate { $0.sessions = sessions }
        let csv = HevyCSV.export(sessions, catalog: store.data.exercises)
        let preview = try store.previewHevyCSV(csv)
        try store.importHevy(preview)
        try store.importHevy(preview)
        XCTAssertEqual(store.data.sessions.count, 2)
        XCTAssertEqual(store.data.sessions.map(\.importKey), sessions.map(\.importKey))
        XCTAssertEqual(store.data.sessions.flatMap(\.exercises).flatMap(\.sets).count, 4)
        XCTAssertEqual(store.data.sessions.flatMap(\.exercises).flatMap(\.sets).map(\.id), sessions.flatMap(\.exercises).flatMap(\.sets).map(\.id))
        let empty = GymStore(directory: try temporaryDirectory())
        try empty.importHevy(try empty.previewHevyCSV(csv))
        try empty.importHevy(try empty.previewHevyCSV(csv))
        XCTAssertEqual(empty.data.sessions.count, 2)
        XCTAssertEqual(empty.data.sessions.flatMap(\.exercises).flatMap(\.sets).count, 4)
    }

    @MainActor
    func testPreviousSetAndLatestSessionUseNewestSavedWorkoutOnSameDay() throws {
        let store = GymStore(directory: try temporaryDirectory())
        let sessions = [40.0, 60.0].map { weight in
            WorkoutSession(title: "Mismo día", workoutDate: "2026-10-06",
                exercises: [WorkoutExercise(exerciseId: store.data.exercises[0].id,
                    sets: [WorkoutSet(reps: 8, weightKg: weight, completed: true)])])
        }
        store.mutate { $0.sessions = sessions }
        XCTAssertEqual(store.previousSet(exerciseId: store.data.exercises[0].id, index: 0)?.weightKg, 60)
        XCTAssertEqual(WorkoutHistory.recentFirst(store.data.sessions).first?.id, sessions[1].id)
    }

    @MainActor
    func testPreviousSetsUseAllRowsInOldMixedFlagHistory() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        let exerciseID = store.data.exercises[0].id
        let workout = WorkoutSession(workoutDate: "2026-10-06", exercises: [WorkoutExercise(exerciseId: exerciseID,
            sets: [WorkoutSet(reps: 8, weightKg: 50), WorkoutSet(reps: 6, weightKg: 60, setType: "failure", completed: true)])])
        store.mutate { $0.sessions = [workout] }
        let reopened = GymStore(directory: directory)
        XCTAssertEqual(reopened.previousSet(exerciseId: exerciseID, index: 0)?.weightKg, 50)
        XCTAssertEqual(reopened.previousSet(exerciseId: exerciseID, index: 1)?.setType, "failure")
        XCTAssertNil(reopened.previousSet(exerciseId: exerciseID, index: 2))
        XCTAssertNil(reopened.previousSet(exerciseId: exerciseID, index: -1))
        XCTAssertEqual(reopened.data.sessions, [workout])
    }
}
