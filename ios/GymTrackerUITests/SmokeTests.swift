import XCTest

final class SmokeTests: XCTestCase {
    func testPrimaryScreensLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["GYM TRACKER"].waitForExistence(timeout: 10))
        for title in ["Entrenar", "Historial", "Progreso", "Perfil", "Inicio"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists, "Missing tab: \(title)")
            tab.tap()
            XCTAssertTrue(app.tabBars.exists)
        }
    }
}
