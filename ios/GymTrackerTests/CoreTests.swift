import XCTest
@testable import GymTracker

final class CoreTests: XCTestCase {
    func testCivilDatesKeepTheirDayWhenDeviceTimeZoneChanges() throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "Pacific/Kiritimati"))
        let originalDay = try XCTUnwrap(GymDate.localDate(fromCivilDay: "2026-09-11"))
        var original = GymData()
        original.nutrition = [NutritionLog(date: originalDay, calories: 2100, protein: 140, notes: "Día local")]
        original.measurements = [BodyMeasurement(date: originalDay, weightKg: 75, values: ["waistCm": 80])]
        let encoded = try BackupCodec.encode(original)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let encodedNutrition = try XCTUnwrap((document["nutrition"] as? [[String: Any]])?.first)
        XCTAssertEqual(encodedNutrition["civilDate"] as? String, "2026-09-11")
        XCTAssertNil(encodedNutrition["date"])

        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let decoded = try BackupCodec.decode(encoded)
        XCTAssertEqual(original.nutrition[0].id, "2026-09-11")
        XCTAssertEqual(GymDate.dayKey(original.nutrition[0].date), "2026-09-11")
        XCTAssertEqual(decoded.nutrition[0].id, "2026-09-11")
        XCTAssertEqual(decoded.measurements[0].id, "2026-09-11")
        XCTAssertEqual(GymDate.dayKey(decoded.nutrition[0].date), "2026-09-11")
        XCTAssertEqual(GymDate.dayKey(decoded.measurements[0].date), "2026-09-11")
        XCTAssertEqual(decoded, original)
    }

    func testCivilDateDecoderMigratesLegacyDatesAndRejectsInvalidDays() throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        NSTimeZone.default = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let nutrition = try decoder.decode(NutritionLog.self, from: Data("{\"date\":\"2026-09-11T23:00:00Z\",\"calories\":2000,\"protein\":120,\"notes\":\"legacy\"}".utf8))
        let measurement = try decoder.decode(BodyMeasurement.self, from: Data("{\"date\":\"2026-09-11T23:00:00Z\",\"weightKg\":70,\"heightCm\":175,\"values\":{}}".utf8))
        XCTAssertEqual(nutrition.id, "2026-09-11")
        XCTAssertEqual(measurement.id, "2026-09-11")
        let invalid = Data("{\"civilDate\":\"2026-02-30\",\"calories\":2000,\"protein\":120,\"notes\":\"\"}".utf8)
        XCTAssertThrowsError(try decoder.decode(NutritionLog.self, from: invalid))
        XCTAssertNil(GymDate.localDate(fromCivilDay: "2026-02-30"))
        XCTAssertNil(GymDate.localDate(fromCivilDay: "2026-9-1"))
        XCTAssertNotNil(GymDate.localDate(fromCivilDay: "2024-02-29"))
    }

    func testScientificMetricIdentityMatchesAndroid() throws {
        let header = "title,start_time,exercise_title,set_index,reps,weight_kg\n"
        let result = try HevyCSV.preview(header + "A,2026-09-11T09:30:00,Press banca barra,0,10,0.0002", catalog: ExerciseSeed.all)
        let expected = HevyCSV.canonicalKey(["A", "2026-09-11T09:30", "Press banca barra", "0", "0", "normal", "2.0E-4", "10", "", "", "", "", ""], prefix: "set") + ":0"
        XCTAssertEqual(result.sessions.first?.exercises.first?.sets.first?.importKey, expected)
    }

    func testUnsafeNumericBackupValuesAreRejected() throws {
        var data = ExerciseSeed.initialData
        data.routines[0].exercises[0].restSeconds = Int.max
        XCTAssertThrowsError(try GymValidation.validate(data))
        data = ExerciseSeed.initialData
        data.routines[0].exercises[0].sets[0].weightKg = Double.greatestFiniteMagnitude
        XCTAssertThrowsError(try GymValidation.validate(data))
    }

    func testHevyQuotedMultilineNotesAndDecimalComma() throws {
        let csv = "\u{FEFF}title;start_time;end_time;description;exercise_title;exercise_notes;set_index;set_type;weight_lbs;reps;rpe;distance_miles;duration_seconds;superset_id\r\n\"Torso; A\";\"11 septiembre 2026, 10:00\";\"11 septiembre 2026, 11:00\";\"Primera línea\r\nSegunda \"\"citada\"\"\";Press banca barra;\"nota; lateral\";0;normal;100;10;\"8,5\";;;A\r\n"
        let preview = try HevyCSV.preview(csv, catalog: ExerciseSeed.all)
        XCTAssertTrue(preview.warnings.isEmpty)
        let session = try XCTUnwrap(preview.sessions.first)
        XCTAssertEqual(session.title, "Torso; A")
        XCTAssertEqual(session.notes, "Primera línea\r\nSegunda \"citada\"")
        XCTAssertEqual(session.exercises[0].notes, "nota; lateral")
        XCTAssertEqual(session.exercises[0].supersetId, "A")
        XCTAssertEqual(session.exercises[0].sets[0].weightKg, 45.359237, accuracy: 0.000001)
        XCTAssertEqual(session.exercises[0].sets[0].rpe, 8.5)
    }

    func testTabCardioConversionAndExactNameMatching() throws {
        let csv = "title\tstart_time\texercise_title\tset_index\treps\tdistance_miles\tduration_seconds\nA\t11 Sep 2026, 9:00 AM\tCinta\t0\t0\t1\t600\nA\t11 Sep 2026, 9:00 AM\tCinta inclinada\t0\t0\t2\t900"
        let preview = try HevyCSV.preview(csv, catalog: ExerciseSeed.all)
        XCTAssertTrue(preview.warnings.isEmpty)
        XCTAssertEqual(preview.exercises.count, 1)
        XCTAssertEqual(preview.exercises[0].name, "Cinta inclinada")
        XCTAssertEqual(preview.sessions[0].exercises[0].sets[0].distanceKm!, 1.609344, accuracy: 0.000001)
        XCTAssertEqual(preview.sessions[0].exercises.count, 2)
    }

    func testInvalidDatesAndMetricsAreSkippedWithoutReplacementDates() throws {
        let csv = "title,start_time,exercise_title,set_index,reps,weight_kg,rpe\nA,2026-02-30T10:00:00Z,Cinta,0,10,0,8\nA,not-a-date,Cinta,0,10,0,8\nA,2026-09-11T10:00:00,Cinta,0,10,NaN,8\nA,2026-09-11T10:00:00,Cinta,0,10,10,11\nA,2026-09-11T10:00:00,Cinta,0,10,10,8"
        let preview = try HevyCSV.preview(csv, catalog: ExerciseSeed.all)
        XCTAssertEqual(preview.warnings.count, 4)
        XCTAssertEqual(preview.sessions.count, 1)
        XCTAssertEqual(preview.sessions[0].completedSets, 1)
        XCTAssertEqual(GymDate.dayKey(preview.sessions[0].startedAt), "2026-09-11")
        XCTAssertNil(HevyCSV.parseDate("31 febrero 2026, 10:00"))
        XCTAssertNil(HevyCSV.parseDate("2026-09-11T99:00:00"))
    }

    func testMalformedCSVAndDuplicateColumnsAreRejected() throws {
        XCTAssertThrowsError(try HevyCSV.preview("title,title,start_time,exercise_title,set_index,reps", catalog: []))
        let malformed = "title,start_time,exercise_title,set_index,reps\n\"A,2026-09-11T10:00,Cinta,0,10"
        let preview = try HevyCSV.preview(malformed, catalog: [])
        XCTAssertTrue(preview.sessions.isEmpty)
        XCTAssertEqual(preview.warnings.count, 1)
    }

    func testDateFormatsGiveSameStableImportIdentity() throws {
        let header = "title;start_time;exercise_title;set_index;reps\n"
        let variants = ["2026-09-11T09:30:00", "11/9/2026 9:30", "11 September 2026, 09:30", "11 septiembre 2026, 09:30"]
        let keys = try variants.map { try HevyCSV.preview(header + "A;\($0);Press banca barra;0;10", catalog: ExerciseSeed.all).sessions[0].importKey }
        XCTAssertEqual(Set(keys).count, 1)
    }

    func testNativeBackupKeepsPhotoBytesAndRejectsUnknownVersion() throws {
        var data = ExerciseSeed.initialData
        data.photos = [ProgressPhoto(date: Date(timeIntervalSince1970: 1700000000), imageData: Data([1, 2, 3, 4]), notes: "foto")]
        let encoded = try BackupCodec.encode(data)
        XCTAssertEqual(try BackupCodec.decode(encoded).photos, data.photos)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["version"] = 999
        XCTAssertThrowsError(try BackupCodec.decode(JSONSerialization.data(withJSONObject: json)))
    }

    func testAndroidBackupPreservesSessionsDraftRoutinesMeasuresAndPhotos() throws {
        let raw = try androidFixture()
        let value = try BackupCodec.decode(raw)
        XCTAssertEqual(value.exercises[0].id, "press_banca_barra")
        XCTAssertEqual(value.sessions[0].id, "android-session")
        XCTAssertEqual(value.sessions[0].importKey, "session-key")
        XCTAssertEqual(value.sessions[0].exercises[0].sets[0].importKey, "set-key")
        XCTAssertEqual(value.sessions[0].exercises[0].sets[0].rpe, 8.5)
        XCTAssertEqual(value.routines.count, 1)
        XCTAssertEqual(value.draft?.title, "Sesión activa")
        XCTAssertEqual(value.measurements[0].values["waistCm"], 80)
        XCTAssertEqual(value.photos[0].imageData, Data([1, 2, 3]))
        XCTAssertEqual(value.nutrition[0].protein, 140)
        XCTAssertEqual(value.profile.age, 35)
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode(value)).photos, value.photos)
    }

    func testAndroidBackupMissingPhotoAndDanglingReferenceAreRejected() throws {
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: androidFixture()) as? [String: Any])
        document["photoAttachments"] = [:]
        XCTAssertThrowsError(try BackupCodec.decode(JSONSerialization.data(withJSONObject: document)))
        document = try XCTUnwrap(JSONSerialization.jsonObject(with: androidFixture()) as? [String: Any])
        var tables = try XCTUnwrap(document["tables"] as? [String: Any])
        tables["exercises"] = []
        document["tables"] = tables
        XCTAssertThrowsError(try BackupCodec.decode(JSONSerialization.data(withJSONObject: document)))
    }

    private func androidFixture() throws -> Data {
        let set: [String: Any] = ["id": "draft-set", "reps": 10, "weightKg": 40.0, "setType": "normal", "rpe": NSNull(), "distanceKm": NSNull(), "durationSeconds": NSNull(), "completed": false]
        let block: [String: Any] = ["id": "block", "exerciseId": "press_banca_barra", "exerciseName": "Press banca barra", "notes": "nota", "restSeconds": 90, "supersetId": NSNull(), "sets": [set]]
        let draft: [String: Any] = ["id": "active-draft", "title": "Sesión activa", "startedAt": "2026-09-11T10:00:00", "notes": "", "routineId": "routine", "exercises": [block]]
        let routineJSON = String(data: try JSONSerialization.data(withJSONObject: [block]), encoding: .utf8)!
        let draftJSON = String(data: try JSONSerialization.data(withJSONObject: draft), encoding: .utf8)!
        let tables: [String: Any] = [
            "exercises": [["id": "press_banca_barra", "name": "Press banca barra", "equipment": "Barra", "category": "Pecho", "movement": "Empuje", "technogym": 0, "archived": 0, "notes": ""]],
            "exercise_muscles": [["exercise_id": "press_banca_barra", "muscle": "Pectoral esternal", "percentage": 100]],
            "workout_sessions": [["id": "android-session", "date_epoch_day": 20707, "title": "Historial", "started_at": "2026-09-10T10:00:00", "ended_at": "2026-09-10T11:00:00", "notes": "Nota", "import_key": "session-key"]],
            "set_entries": [["id": "android-set", "session_id": "android-session", "exercise_id": "press_banca_barra", "exercise_block_id": "android-block", "exercise_index": 0, "set_number": 1, "reps": 10, "weight_kg": 50.0, "set_type": "normal", "rpe": 8.5, "exercise_notes": "Ejercicio", "rest_seconds": 100, "import_key": "set-key"]],
            "routine_folders": [["id": "folder", "name": "Favoritas"]],
            "routines": [["id": "routine", "name": "Torso", "folder_id": "folder", "notes": "", "exercises_json": routineJSON]],
            "workout_drafts": [["id": "active", "payload": draftJSON]],
            "nutrition_logs": [["date_epoch_day": 20707, "calories": 2200, "protein": 140, "notes": ""]],
            "body_measurements": [["date_epoch_day": 20707, "weight_kg": 75, "height_cm": 175, "values_json": "{\"waistCm\":80}"]],
            "progress_photos": [["id": "photo", "date_epoch_day": 20707, "uri": "content://private/photo", "notes": "Frente"]]
        ]
        let document: [String: Any] = ["format": "ember-gym-backup", "version": 1, "databaseVersion": 6, "tables": tables,
            "photoAttachments": ["photo": ["data": "AQID", "mimeType": "image/jpeg"]],
            "profile": ["male": true, "age": 35, "heightCm": 175, "activityFactor": 1.55, "goal": "RECOMP"]]
        return try JSONSerialization.data(withJSONObject: document)
    }
}
