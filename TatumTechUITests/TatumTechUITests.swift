import XCTest

/// Runs against bundled JSON and in-memory credentials (see `AppDependencies.uiTesting`), so no
/// network or real account is needed.
final class TatumTechUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(signedIn: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (signedIn ? ["-uiTestingSignedIn"] : [])
        app.launch()
        return app
    }

    func testWelcomeOffersEverySignInOption() {
        let app = launch(signedIn: false)
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["welcome.signUp"].exists)
        XCTAssertTrue(app.buttons["welcome.google"].exists)
        XCTAssertTrue(app.buttons["welcome.apple"].exists)
    }

    func testSignInStaysDisabledUntilTheFormIsValid() {
        let app = launch(signedIn: false)
        app.buttons["welcome.signIn"].tap()

        let submit = app.buttons["signIn.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)

        let email = app.textFields["signIn.email"]
        email.tap()
        email.typeText("not-an-email")
        app.secureTextFields["signIn.password"].tap()
        XCTAssertTrue(app.staticTexts["Input a valid email address."].waitForExistence(timeout: 2))
        XCTAssertFalse(submit.isEnabled)
    }

    func testHomeOpensPartnersAndEvents() {
        let app = launch(signedIn: true)
        XCTAssertTrue(app.staticTexts["Hello, Ada!"].waitForExistence(timeout: 5))

        app.buttons["feature.partners"].tap()
        XCTAssertTrue(app.navigationBars["Partners"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["feature.upcomingEvents"].tap()
        XCTAssertTrue(app.navigationBars["Upcoming Events"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Register"].waitForExistence(timeout: 5))
    }

    func testAccountMenuOffersDeletion() {
        let app = launch(signedIn: true)
        app.buttons["home.menu"].tap()
        XCTAssertTrue(app.buttons["account.delete"].waitForExistence(timeout: 5))
        app.buttons["account.delete"].tap()
        XCTAssertTrue(app.alerts["Delete Account"].waitForExistence(timeout: 2))
        app.alerts.buttons["No"].tap()
    }
}
