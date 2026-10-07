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

    /// Sign In, Sign Up, then "OR", then Sign in with Apple above Sign in with Google.
    func testAppleButtonSitsBetweenSignUpAndGoogle() {
        let app = launch(signedIn: false)
        let signUp = app.buttons["welcome.signUp"]
        let apple = app.buttons["welcome.apple"]
        let google = app.buttons["welcome.google"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))

        XCTAssertLessThan(app.buttons["welcome.signIn"].frame.maxY, signUp.frame.minY)
        XCTAssertLessThan(signUp.frame.maxY, apple.frame.minY)
        XCTAssertLessThanOrEqual(apple.frame.maxY, google.frame.minY)
        XCTAssertGreaterThanOrEqual(apple.frame.height, 44)
        XCTAssertTrue(apple.isHittable)
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
        let greeting = app.staticTexts["home.greeting"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
        XCTAssertTrue(greeting.label.hasPrefix("Hello"))

        app.buttons["feature.partners"].tap()
        XCTAssertTrue(app.navigationBars["Partners"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["feature.upcomingEvents"].tap()
        XCTAssertTrue(app.navigationBars["Upcoming Events"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Register"].waitForExistence(timeout: 5))
    }

    func testAnsweringACodingQuestionShowsFeedback() {
        let app = launch(signedIn: true)
        app.tabBars.buttons["Learn"].tap()

        let firstOption = app.buttons["quiz.option.0"]
        XCTAssertTrue(firstOption.waitForExistence(timeout: 5))
        firstOption.tap()
        app.buttons["quiz.submit"].tap()

        let proceed = app.buttons["quiz.feedback.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        proceed.tap()
        XCTAssertTrue(app.buttons["quiz.option.0"].waitForExistence(timeout: 5))
    }

    func testContactCardCanBeCreatedAndShared() {
        let app = launch(signedIn: true)
        app.buttons["feature.upcomingEvents"].tap()

        let create = app.buttons["networking.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        let firstName = app.textFields["contactCard.firstName"]
        XCTAssertTrue(firstName.waitForExistence(timeout: 5))
        firstName.tap()
        firstName.typeText("Ada")
        let email = app.textFields["contactCard.email"]
        email.tap()
        email.typeText("ada@example.com")
        app.buttons["contactCard.save"].tap()

        let share = app.buttons["networking.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.navigationBars["My Tatum Tech Card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["My Tatum Tech Card QR code"].waitForExistence(timeout: 5))
    }

    func testContactCardRequiresNameAndEmail() {
        let app = launch(signedIn: true)
        app.buttons["feature.upcomingEvents"].tap()
        let create = app.buttons["networking.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        let save = app.buttons["contactCard.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["First name is required"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Email is required"].exists)
    }

    func testHomeCategoriesOpenTheirScreens() {
        let app = launch(signedIn: true)
        let destinations: [(category: String, card: String, title: String)] = [
            ("coding", "stats", "Stats"),
            ("coding", "resources", "Resources"),
            ("community", "donate", "Donate"),
            ("career", "careers", "Career"),
            ("games", "discoverGames", "Discover Games")
        ]
        for destination in destinations {
            let chip = app.buttons["home.category.\(destination.category)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5))
            chip.tap()
            let card = app.buttons["feature.\(destination.card)"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            card.tap()
            XCTAssertTrue(app.navigationBars[destination.title].waitForExistence(timeout: 5), destination.title)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    func testTimelineAndStatsTabs() {
        let app = launch(signedIn: true)
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.navigationBars["My Timeline"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 5))
    }

    func testProfileOffersDeletion() {
        let app = launch(signedIn: true)
        app.buttons["home.menu"].tap()
        XCTAssertTrue(app.buttons["menu.profile"].waitForExistence(timeout: 5))
        app.buttons["menu.profile"].tap()
        XCTAssertTrue(app.buttons["account.delete"].waitForExistence(timeout: 5))
        app.buttons["account.delete"].tap()
        XCTAssertTrue(app.alerts["Delete Account"].waitForExistence(timeout: 2))
        app.alerts.buttons["No"].tap()
    }

    /// "Sign Out" sits below Save; "No" keeps the user on Profile, "Yes" returns to the welcome
    /// screen with no way back.
    func testProfileSignOutConfirmsThenReturnsToWelcome() {
        let app = launch(signedIn: true)
        app.buttons["home.menu"].tap()
        XCTAssertTrue(app.buttons["menu.profile"].waitForExistence(timeout: 5))
        app.buttons["menu.profile"].tap()

        let save = app.buttons["profile.save"]
        let signOut = app.buttons["account.signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        XCTAssertEqual(signOut.label, "Sign Out")
        XCTAssertLessThan(save.frame.maxY, signOut.frame.minY)
        XCTAssertGreaterThanOrEqual(signOut.frame.height, 44)

        signOut.tap()
        let confirmation = app.alerts["Sign Out"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        XCTAssertTrue(confirmation.staticTexts["Are you sure you want to sign out?"].exists)
        confirmation.buttons["No"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 2))

        signOut.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Yes"].tap()
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Profile"].exists)
    }
}
