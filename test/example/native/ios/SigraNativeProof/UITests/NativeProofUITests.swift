import XCTest

final class NativeProofUITests: XCTestCase {
    func testLivePhysicalIphoneHostJourney() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("NP-IOS-PHYSICAL-TARGET")
        #endif

        let environment = ProcessInfo.processInfo.environment
        let baseURL = try required(environment, "SIGRA_NATIVE_PROOF_BASE_URL")
        let failureURL = try required(environment, "SIGRA_NATIVE_PROOF_FAILURE_URL")
        let email = try required(environment, "SIGRA_NATIVE_PROOF_EMAIL")
        let password = try required(environment, "SIGRA_NATIVE_PROOF_PASSWORD")

        let app = XCUIApplication()
        app.launchEnvironment["SIGRA_NATIVE_PROOF_MODE"] = "live_physical_iphone"
        app.launchEnvironment["SIGRA_NATIVE_PROOF_BASE_URL"] = baseURL
        app.launchEnvironment["SIGRA_NATIVE_PROOF_FAILURE_URL"] = failureURL
        app.launch()

        assertValue(app, "proof.evidence-class", equals: "live_physical_iphone")
        let start = app.buttons["proof.start-live"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "NP-IOS-LIVE-START")
        start.tap()
        guard completeSystemBrowserCeremony(app: app, email: email, password: password, loginExpected: true) else {
            return
        }
        assertAbsentFailure(app)
        XCTAssertTrue(
            app.descendants(matching: .any)["proof.awaiting-relaunch"].waitForExistence(timeout: 30),
            "NP-IOS-LIVE-FIRST-JOURNEY"
        )

        app.terminate()
        app.launch()
        let resume = app.buttons["proof.resume-live"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "NP-IOS-LIVE-RELAUNCH")
        resume.tap()
        let finish = app.buttons["proof.finish-live"]
        XCTAssertTrue(finish.waitForExistence(timeout: 30), "NP-IOS-LIVE-RELAUNCH")
        assertAbsentFailure(app)
        finish.tap()
        guard completeSystemBrowserCeremony(app: app, email: email, password: password, loginExpected: false) else {
            return
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["proof.live-complete"].waitForExistence(timeout: 30),
            "NP-IOS-LIVE-FINAL-LOGIN"
        )
        assertAbsentFailure(app)

        for identifier in [
            "proof.hosted-return", "proof.storage-present", "proof.storage-rotated",
            "proof.storage-recovered", "proof.storage-deleted-logout",
            "proof.storage-deleted-revocation", "proof.image-verified", "proof.audio-verified",
            "proof.strict-lease-edge", "proof.offline-use", "proof.kill-relaunch",
            "proof.account-switch", "proof.server-revocation", "proof.cleanup",
            "proof.replay-accepted", "proof.replay-rejected", "proof.replay-conflict"
        ] {
            assertValue(app, identifier, equals: "true")
        }
        assertValue(app, "proof.storage-read-result", equals: "not_found")
        assertValue(app, "proof.access-persisted", equals: "false")
        assertValue(app, "proof.transport-claim", equals: "controlled_transport_failure")
        addLiveReport(from: app)
    }

    func testContractOnlyFixtureExposesEverySynchronizedNativeScenario() {
        let app = XCUIApplication()
        app.launchEnvironment["SIGRA_NATIVE_PROOF_FIXTURE"] = "contract_complete"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["proof.ready"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["proof.evidence-class"].value as? String, "contract_only")

        let identifiers = [
            "proof.hosted-return", "proof.storage-posture", "proof.image-verified",
            "proof.audio-verified", "proof.strict-lease-edge", "proof.offline-use",
            "proof.kill-relaunch", "proof.account-switch", "proof.server-revocation",
            "proof.cleanup", "proof.replay-accepted", "proof.replay-rejected",
            "proof.replay-conflict"
        ]
        for identifier in identifiers {
            let element = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 5), "missing stable proof hook: \(identifier)")
            XCTAssertEqual(element.value as? String, "true", "fixture posture was not terminal: \(identifier)")
        }
        XCTAssertEqual(
            app.descendants(matching: .any)["proof.transport-claim"].value as? String,
            "controlled_transport_failure"
        )
    }

    private func completeSystemBrowserCeremony(
        app: XCUIApplication,
        email: String,
        password: String,
        loginExpected: Bool
    ) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let continueButton = springboard.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) { continueButton.tap() }

        let browser = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
        if loginExpected {
            let emailField = firstExisting(
                [app.textFields["Email"], browser.textFields["Email"], browser.textFields.firstMatch],
                timeout: 15
            )
            guard let emailField else {
                XCTFail("NP-IOS-BROWSER-LOGIN-EMAIL")
                return false
            }
            guard focusAndType(email, into: emailField, failureRule: "NP-IOS-BROWSER-LOGIN-EMAIL-FOCUS") else {
                return false
            }
            guard emailField.value as? String == email else {
                XCTFail("NP-IOS-BROWSER-LOGIN-EMAIL-VALUE")
                return false
            }
            let passwordField = firstExisting(
                [app.secureTextFields["Password"], browser.secureTextFields["Password"], browser.secureTextFields.firstMatch],
                timeout: 10
            )
            guard let passwordField else {
                XCTFail("NP-IOS-BROWSER-LOGIN-PASSWORD")
                return false
            }
            guard advanceFocusAndType(
                password,
                from: emailField,
                into: passwordField,
                failureRule: "NP-IOS-BROWSER-LOGIN-PASSWORD-FOCUS"
            ) else {
                return false
            }
            guard (passwordField.value as? String)?.count == password.count else {
                XCTFail("NP-IOS-BROWSER-LOGIN-PASSWORD-VALUE")
                return false
            }
            let login = firstExisting(
                [app.buttons["Log in"], browser.buttons["Log in"], browser.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log in'")).firstMatch],
                timeout: 10
            )
            guard let login else {
                XCTFail("NP-IOS-BROWSER-LOGIN-SUBMIT")
                return false
            }
            login.tap()
        }

        let approve = firstExisting(
            [app.buttons["Approve and continue"], browser.buttons["Approve and continue"], browser.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Approve and continue'")).firstMatch],
            timeout: 20
        )
        guard let approve else {
            let rejected = app.staticTexts["Invalid email or password"].exists ||
                browser.staticTexts["Invalid email or password"].exists
            XCTFail(rejected ? "NP-IOS-BROWSER-LOGIN-REJECTED" : classifyPostLoginPage(app: app, browser: browser))
            return false
        }
        approve.tap()
        return true
    }

    private func classifyPostLoginPage(app: XCUIApplication, browser: XCUIApplication) -> String {
        let exactLabels = [
            ("Log in to Tasklane", "NP-IOS-BROWSER-LOGIN-PAGE"),
            ("Verify it's you", "NP-IOS-BROWSER-MFA-PAGE"),
            ("Invalid app login request.", "NP-IOS-BROWSER-CONTINUATION-INVALID"),
            ("Review this request before continuing to the app.", "NP-IOS-BROWSER-APPROVAL-CONTROL-MISSING")
        ]
        for (label, rule) in exactLabels where app.staticTexts[label].exists || browser.staticTexts[label].exists {
            return rule
        }
        let welcome = NSPredicate(format: "label BEGINSWITH[c] 'Welcome back'")
        if app.staticTexts.matching(welcome).firstMatch.exists || browser.staticTexts.matching(welcome).firstMatch.exists {
            return "NP-IOS-BROWSER-APP-FALLBACK"
        }
        return "NP-IOS-BROWSER-APPROVAL"
    }

    private func focusAndType(_ text: String, into field: XCUIElement, failureRule: String) -> Bool {
        let hasKeyboardFocus = NSPredicate(format: "hasKeyboardFocus == true")
        field.tap()
        let initialFocus = XCTNSPredicateExpectation(predicate: hasKeyboardFocus, object: field)
        if XCTWaiter.wait(for: [initialFocus], timeout: 2) != .completed {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let fallbackFocus = XCTNSPredicateExpectation(predicate: hasKeyboardFocus, object: field)
            guard XCTWaiter.wait(for: [fallbackFocus], timeout: 5) == .completed else {
                XCTFail(failureRule)
                return false
            }
        }
        field.typeText(text)
        return true
    }

    private func advanceFocusAndType(
        _ text: String,
        from currentField: XCUIElement,
        into nextField: XCUIElement,
        failureRule: String
    ) -> Bool {
        currentField.typeKey(.tab, modifierFlags: [])
        let hasKeyboardFocus = NSPredicate(format: "hasKeyboardFocus == true")
        let nextFocus = XCTNSPredicateExpectation(predicate: hasKeyboardFocus, object: nextField)
        guard XCTWaiter.wait(for: [nextFocus], timeout: 5) == .completed else {
            XCTFail(failureRule)
            return false
        }
        nextField.typeText(text)
        return true
    }

    private func firstExisting(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let perCandidate = max(1, timeout / Double(candidates.count))
        return candidates.first { $0.waitForExistence(timeout: perCandidate) }
    }

    private func required(_ environment: [String: String], _ key: String) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw XCTSkip("missing process-only live proof input")
        }
        return value
    }

    private func assertValue(_ app: XCUIApplication, _ identifier: String, equals expected: String) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "missing stable live proof hook: \(identifier)")
        XCTAssertEqual(element.value as? String, expected, "unexpected posture: \(identifier)")
    }

    private func assertAbsentFailure(_ app: XCUIApplication) {
        XCTAssertFalse(app.descendants(matching: .any)["proof.failure-rule"].exists)
    }

    private func addLiveReport(from app: XCUIApplication) {
        func value(_ id: String) -> String {
            app.descendants(matching: .any)[id].value as? String ?? ""
        }
        let scenarioIDs = [
            "hosted_return": "proof.hosted-return",
            "image_verified": "proof.image-verified",
            "audio_verified": "proof.audio-verified",
            "strict_lease_edge": "proof.strict-lease-edge",
            "offline_use": "proof.offline-use",
            "kill_relaunch": "proof.kill-relaunch",
            "account_switch": "proof.account-switch",
            "server_revocation": "proof.server-revocation",
            "replay_accepted": "proof.replay-accepted",
            "replay_rejected": "proof.replay-rejected",
            "replay_conflict": "proof.replay-conflict"
        ]
        let report: [String: Any] = [
            "schema_version": 1,
            "evidence_class": "live_physical_iphone",
            "browser": ["component": "as_web_authentication_session", "mode": "system_external_user_agent"],
            "callback": ["transport": "custom_scheme", "link_verification": "registered_scheme", "callback_binding": "matched"],
            "storage": [
                "present": value("proof.storage-present") == "true",
                "rotated": value("proof.storage-rotated") == "true",
                "recovered_after_relaunch": value("proof.storage-recovered") == "true",
                "deleted_after_logout": value("proof.storage-deleted-logout") == "true",
                "deleted_after_revocation": value("proof.storage-deleted-revocation") == "true",
                "read_result": value("proof.storage-read-result"),
                "access_persisted": value("proof.access-persisted") == "true"
            ],
            "scenarios": scenarioIDs.mapValues { value($0) == "true" },
            "transport": ["claim": value("proof.transport-claim")],
            "terminal_status": "complete"
        ]
        let bytes = try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "sigra-native-proof-live-report.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
