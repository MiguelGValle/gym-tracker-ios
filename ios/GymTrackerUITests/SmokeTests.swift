import XCTest

final class SmokeTests: XCTestCase {
    func testWorkoutSavesAllThreeExercisesWithoutAnyCompletionOrFailureMarks() {
        let app = launchWorkoutWithoutChecks()
        XCTAssertEqual(app.staticTexts["workout-set-count"].label, "6 series")
        XCTAssertFalse(app.buttons["Completar serie 1"].exists)
        XCTAssertFalse(app.switches["Serie completada"].exists)
        XCTAssertEqual(app.buttons["failure-ui-set-1-1"].value as? String, "Sin marcar")

        saveAndOpenHistory(app, expectedSeries: 6)
        assertFixtureSeriesArePresent(app)
        XCTAssertFalse(app.images["Completada"].exists)
    }

    func testFailureTogglePreservesValuesAndDoesNotCarryOverToAddedSeries() {
        let app = launchWorkoutWithoutChecks()
        let firstFailure = app.buttons["failure-ui-set-1-1"]
        let firstSet = app.otherElements["workout-set-ui-set-1-1"]
        let weightBefore = firstSet.textFields["Peso"].value as? String
        let repsBefore = firstSet.textFields["Reps"].value as? String
        XCTAssertEqual(weightBefore, "40")
        XCTAssertEqual(repsBefore, "8")
        firstFailure.tap()
        XCTAssertEqual(firstFailure.value as? String, "Marcada")
        firstFailure.tap()
        XCTAssertEqual(firstFailure.value as? String, "Sin marcar")
        XCTAssertEqual(firstSet.textFields["Peso"].value as? String, weightBefore)
        XCTAssertEqual(firstSet.textFields["Reps"].value as? String, repsBefore)

        let secondFailure = app.buttons["failure-ui-set-1-2"]
        scrollTo(secondFailure, in: app)
        secondFailure.tap()
        XCTAssertEqual(secondFailure.value as? String, "Marcada")
        let addSet = app.buttons["add-set-ui-exercise-1"]
        scrollTo(addSet, in: app)
        addSet.tap()
        let newFailure = app.buttons["Al fallo, serie 3"].firstMatch
        scrollTo(newFailure, in: app)
        XCTAssertEqual(newFailure.value as? String, "Sin marcar")

        saveAndOpenHistory(app, expectedSeries: 7)
        assertFixtureSeriesArePresent(app, expectedFailureSets: ["ui-set-1-2"])
    }

    func testWorkoutStartsOneSetAndNumericTapReplacesPreviousValue() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-training"]
        app.launch()
        app.tabBars.buttons["Entrenar"].tap()
        let start = app.buttons["Iniciar Full Body A"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.staticTexts["Serie 1"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Serie 2"].exists)
        XCTAssertFalse(app.staticTexts["Descanso"].exists)
        XCTAssertFalse(app.buttons["Editar título, inicio y duración"].exists)
        let weight = app.textFields["Peso"].firstMatch
        let reps = app.textFields["Reps"].firstMatch
        weight.tap()
        weight.typeText("42")
        reps.tap()
        reps.typeText("8")
        XCTAssertEqual(weight.value as? String, "42")
        XCTAssertEqual(reps.value as? String, "8")
        // Tapping the same active field again must also select the previous value.
        reps.tap()
        reps.typeText("6")
        XCTAssertEqual(reps.value as? String, "6")
        app.buttons["Añadir serie"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Serie 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.matching(identifier: "Peso").element(boundBy: 1).value as? String, "42")
        XCTAssertEqual(app.textFields.matching(identifier: "Reps").element(boundBy: 1).value as? String, "6")
    }

    func testPrimaryScreensLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.navigationBars["GYM TRACKER"].waitForExistence(timeout: 10))
        for title in ["Entrenar", "Historial", "Progreso", "Perfil", "Inicio"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists, "Missing tab: \(title)")
            tab.tap()
            XCTAssertTrue(app.tabBars.firstMatch.exists)
        }
    }

    private func launchWorkoutWithoutChecks() -> XCUIApplication {
        let app = XCUIApplication()
        // The app seeds an isolated temporary store; no personal data is touched.
        app.launchArguments = ["-ui-testing-no-checks"]
        app.launch()
        app.tabBars.buttons["Entrenar"].tap()
        let start = app.buttons["Continuar entrenamiento"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.staticTexts["workout-set-count"].waitForExistence(timeout: 5))
        return app
    }

    private func saveAndOpenHistory(_ app: XCUIApplication, expectedSeries: Int) {
        app.buttons["Finalizar"].tap()
        let save = app.navigationBars["Finalizar entrenamiento"].buttons["Guardar"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["\(expectedSeries) series"].exists)
        XCTAssertFalse(app.buttons["Guardar solo las completadas"].exists)
        save.tap()
        XCTAssertTrue(app.tabBars.buttons["Historial"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Historial"].tap()
        let session = app.staticTexts["Todas las series"].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        session.tap()
        XCTAssertTrue(app.staticTexts["history-exercise-ui-exercise-1"].waitForExistence(timeout: 5))
        let count = app.descendants(matching: .any)["history-set-count"]
        XCTAssertTrue(count.exists)
        XCTAssertEqual(count.value as? String, "\(expectedSeries)")
    }

    private func assertFixtureSeriesArePresent(_ app: XCUIApplication, expectedFailureSets: Set<String> = []) {
        for exercise in 1...3 {
            let heading = app.staticTexts["history-exercise-ui-exercise-\(exercise)"]
            scrollTo(heading, in: app)
            XCTAssertTrue(heading.exists, "Falta el ejercicio \(exercise)")
            for set in 1...2 {
                let setID = "ui-set-\(exercise)-\(set)"
                let row = app.staticTexts["history-set-\(setID)"]
                scrollTo(row, in: app)
                XCTAssertTrue(row.exists, "Falta la serie \(set) del ejercicio \(exercise)")
                XCTAssertEqual(app.staticTexts["history-failure-\(setID)"].exists, expectedFailureSets.contains(setID))
            }
        }
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "No se puede acceder a \(element.identifier)")
    }
}
