import XCTest

final class NativeProofUITests: XCTestCase {
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
}
