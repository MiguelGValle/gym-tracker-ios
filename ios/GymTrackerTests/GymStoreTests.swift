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
    func testFinishingWorkoutRetainsCompletedSetsAndClearsMatchingDraft() throws {
        let store = GymStore(directory: try temporaryDirectory())
        store.startWorkout(routine: store.data.routines[0])
        let originalID = try XCTUnwrap(store.data.draft?.id)
        store.startWorkout()
        XCTAssertEqual(store.data.draft?.id, originalID)
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].completed = true
        workout.exercises[0].sets[0].weightKg = 50
        try store.finishWorkout(workout)
        XCTAssertNil(store.data.draft)
        XCTAssertEqual(store.data.sessions.count, 1)
        XCTAssertEqual(store.data.sessions[0].completedSets, 1)
        XCTAssertEqual(store.data.sessions[0].exercises.count, 1)
        XCTAssertEqual(store.data.sessions[0].volume, 500)
    }

    @MainActor
    func testFinishValidationFailureRetainsDraftAndDoesNotCreateSession() throws {
        let store = GymStore(directory: try temporaryDirectory())
        store.startWorkout(routine: store.data.routines[0])
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].completed = true
        workout.exercises[0].sets[0].rpe = 11
        XCTAssertThrowsError(try store.finishWorkout(workout))
        XCTAssertNotNil(store.data.draft)
        XCTAssertTrue(store.data.sessions.isEmpty)
    }

    @MainActor
    func testFinishAndRoutineAreSavedTogetherOrNeitherIsSaved() throws {
        let directory = try temporaryDirectory()
        let store = GymStore(directory: directory)
        store.startWorkout(routine: store.data.routines[0])
        var workout = try XCTUnwrap(store.data.draft)
        workout.exercises[0].sets[0].completed = true
        let invalid = Routine(name: "", exercises: workout.exercises)
        XCTAssertThrowsError(try store.finishWorkout(workout, routine: invalid))
        XCTAssertNotNil(store.data.draft)
        XCTAssertTrue(store.data.sessions.isEmpty)
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
}
