import XCTest

final class SmokeTests: XCTestCase {
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
        XCTAssertEqual(app.textFields["Peso"].element(boundBy: 1).value as? String, "42")
        XCTAssertEqual(app.textFields["Reps"].element(boundBy: 1).value as? String, "6")
    }

    func testPrimaryScreensLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["GYM TRACKER"].waitForExistence(timeout: 10))
        for title in ["Entrenar", "Historial", "Progreso", "Perfil", "Inicio"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists, "Missing tab: \(title)")
            tab.tap()
            XCTAssertTrue(app.tabBars.firstMatch.exists)
        }
    }
}
