import XCTest

/// Safe against an existing device account: no sign-out, saved mutations,
/// invitations, recordings, or final account deletion.
@MainActor
final class DeviceSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement? = nil) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            (scrollView ?? app.scrollViews.firstMatch).swipeUp()
        }
    }

    private func requireSignedIn() throws {
        guard app.buttons["Add"].waitForExistence(timeout: 20) else {
            capture("Authentication required")
            throw XCTSkip("A signed-in device account is required. No credentials are embedded in these tests.")
        }
    }

    func testLaunchAndRelaunchReachUsableScreen() {
        for _ in 0..<2 {
            let ready = NSPredicate { [self] _, _ in
                app.buttons["Add"].exists || app.buttons["GoogleSignInButton"].exists ||
                    app.staticTexts["Make it yours"].exists || app.buttons["Try again"].exists
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 30), .completed)
            XCTAssertFalse(app.staticTexts["Unable to connect"].exists, "Session restoration failed against the configured API")
            capture("Launch state")
            app.terminate()
            app.launch()
        }
    }

    func testSignedOutEmailValidationDoesNotSendEmail() throws {
        guard app.buttons["GoogleSignInButton"].waitForExistence(timeout: 15) else {
            throw XCTSkip("Device is already signed in; preserving its session.")
        }
        let email = app.textFields["Email address"]
        reveal(email)
        XCTAssertTrue(email.isHittable)
        XCTAssertFalse(app.buttons["Continue with email"].isEnabled)
        email.tap()
        email.typeText("invalid")
        XCTAssertFalse(app.buttons["Continue with email"].isEnabled)
        capture("Invalid email remains disabled")
    }

    func testSignedInNavigationAndCreatePlanCancellation() throws {
        try requireSignedIn()
        for tab in ["Plans", "Activity", "You", "Home"] {
            XCTAssertTrue(app.buttons[tab].isHittable)
            app.buttons[tab].tap()
            capture("Tab \(tab)")
        }
        app.buttons["Add"].tap()
        let create = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Create plan")).firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        reveal(create)
        create.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        capture("Create plan before saving")
        app.buttons["Cancel"].tap()
    }

    func testDeletionScreenLoadsAndCanBeCancelled() throws {
        try requireSignedIn()
        app.buttons["You"].tap()
        let delete = app.buttons["Delete account"]
        reveal(delete)
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        XCTAssertTrue(app.staticTexts["Delete your Paktly account?"].waitForExistence(timeout: 10))
        let confirmation = app.switches["I understand this cannot be undone"]
        for _ in 0..<6 {
            if confirmation.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(confirmation.waitForExistence(timeout: 20), "Deletion options unavailable; inspect attached screenshot and API configuration")
        XCTAssertEqual(confirmation.value as? String, "0")
        capture("Deletion options, not confirmed")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Delete your Paktly account?"].exists)
    }

    func testVoiceEntryDoesNotShowRejectedPermissionCopy() throws {
        try requireSignedIn()
        app.buttons["Add"].tap()
        let voice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Speak to Paktly")).firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 5) {
            // Test the denial path without recording audio or consenting to AI.
            let deny = springboard.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "allow")).allElementsBoundByIndex
                .first { $0.label.localizedCaseInsensitiveContains("don't") || $0.label.localizedCaseInsensitiveContains("don’t") }
            XCTAssertNotNil(deny, "Expected the system microphone permission prompt")
            deny?.tap()
        }
        let ready = NSPredicate { [self] _, _ in
            app.staticTexts["AI data sharing"].exists || app.staticTexts["Microphone access is off"].exists
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 10), .completed)
        XCTAssertFalse(app.buttons["Allow and continue"].exists)
        XCTAssertFalse(app.buttons["Not now"].exists)
        capture("Voice permission or AI consent, no recording")
        XCTAssertTrue(app.buttons["Close"].exists)
        app.buttons["Close"].tap()
    }

    private func openPlanAction(_ title: String) throws {
        try requireSignedIn()
        app.buttons["Add"].tap()
        let action = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        reveal(action)
        action.tap()
        if app.staticTexts["Create a plan first"].waitForExistence(timeout: 2) {
            throw XCTSkip("No plan is available; this smoke test does not create account data.")
        }
        let plan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " people · ")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        plan.tap()
    }

    func testExpenseEditorValidationAndCancellation() throws {
        try openPlanAction("Add expense")
        let description = app.textFields["What was it?"]
        XCTAssertTrue(description.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save"].isEnabled, "An empty expense must not be saved")
        description.tap()
        description.typeText("Device smoke test - not saved")
        XCTAssertFalse(app.buttons["Save"].isEnabled, "An expense without an amount must not be saved")
        capture("Expense validation without saving")
        app.buttons["Cancel"].tap()
    }

    func testReceiptEntryAndCancellation() throws {
        try openPlanAction("Scan receipt")
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Receipt images are read on your device. Only the expense details you confirm are saved to Paktly."].exists)
        capture("Receipt entry without camera or photo access")
        app.buttons["Cancel"].tap()
    }

    /// Resets only Paktly's microphone permission and finishes with access granted.
    /// Both paths stop before AI consent, capture, or upload.
    func testFreshMicrophoneDenialAndGrantBeforeAIConsent() throws {
        try requireSignedIn()
        for grant in [false, true] {
            app.terminate()
            app.resetAuthorizationStatus(for: .microphone)
            app.launch()
            try requireSignedIn()
            app.buttons["Add"].tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Speak to Paktly")).firstMatch.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let promptReady = NSPredicate { [self] _, _ in
                app.alerts.firstMatch.exists || springboard.alerts.firstMatch.exists
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: promptReady, object: nil)], timeout: 10), .completed)
            let alert = app.alerts.firstMatch.exists ? app.alerts.firstMatch : springboard.alerts.firstMatch
            XCTAssertFalse(app.staticTexts["AI data sharing"].exists, "AI disclosure must not precede the system permission prompt")
            capture("Fresh native microphone prompt")
            if grant {
                let allow = alert.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Allow", "OK")).firstMatch
                XCTAssertTrue(allow.exists)
                allow.tap()
                XCTAssertTrue(app.staticTexts["AI data sharing"].waitForExistence(timeout: 10))
                let decline = app.buttons["Don’t use AI"]
                reveal(decline)
                XCTAssertTrue(decline.isHittable)
                capture("AI consent after microphone approval")
                decline.tap()
                XCTAssertFalse(app.buttons["Stop recording"].exists)
            } else {
                let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "don't", "don’t")).firstMatch
                XCTAssertTrue(deny.exists)
                deny.tap()
                XCTAssertTrue(app.staticTexts["Microphone access is off"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.buttons["Open Settings"].exists)
                capture("Microphone denial offers Settings and Close")
                app.buttons["Close"].tap()
            }
        }
    }
}
