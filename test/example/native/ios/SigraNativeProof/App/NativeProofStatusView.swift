import AuthenticationServices
import SwiftUI
import UIKit

#if NATIVE_PROOF
struct NativeProofStatus: Codable {
    var hostedReturn: Bool
    var storagePresent: Bool
    var storageRotated: Bool
    var storageRecoveredAfterRelaunch: Bool
    var storageDeletedAfterLogout: Bool
    var storageDeletedAfterRevocation: Bool
    var storageReadResult: String
    var imageVerified: Bool
    var audioVerified: Bool
    var strictLeaseEdge: Bool
    var offlineUse: Bool
    var killRelaunch: Bool
    var accountSwitch: Bool
    var serverRevocation: Bool
    var cleanup: Bool
    var replayAccepted: Bool
    var replayRejected: Bool
    var replayConflict: Bool

    static let contractComplete = NativeProofStatus(
        hostedReturn: true,
        storagePresent: true,
        storageRotated: true,
        storageRecoveredAfterRelaunch: true,
        storageDeletedAfterLogout: true,
        storageDeletedAfterRevocation: true,
        storageReadResult: "read_ok",
        imageVerified: true,
        audioVerified: true,
        strictLeaseEdge: true,
        offlineUse: true,
        killRelaunch: true,
        accountSwitch: true,
        serverRevocation: true,
        cleanup: true,
        replayAccepted: true,
        replayRejected: true,
        replayConflict: true
    )

    static let unavailable = NativeProofStatus(
        hostedReturn: false,
        storagePresent: false,
        storageRotated: false,
        storageRecoveredAfterRelaunch: false,
        storageDeletedAfterLogout: false,
        storageDeletedAfterRevocation: false,
        storageReadResult: "not_found",
        imageVerified: false,
        audioVerified: false,
        strictLeaseEdge: false,
        offlineUse: false,
        killRelaunch: false,
        accountSwitch: false,
        serverRevocation: false,
        cleanup: false,
        replayAccepted: false,
        replayRejected: false,
        replayConflict: false
    )
}

struct NativeProofStatusView: View {
    @StateObject private var live = NativeLiveProofCoordinator()
    private let fixtureStatus: NativeProofStatus
    private let evidenceClass: String

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        fixtureStatus = environment["SIGRA_NATIVE_PROOF_FIXTURE"] == "contract_complete"
            ? .contractComplete
            : .unavailable
        evidenceClass = environment["SIGRA_NATIVE_PROOF_MODE"] == "live_physical_iphone"
            ? "live_physical_iphone"
            : "contract_only"
    }

    private var status: NativeProofStatus { live.isLive ? live.status : fixtureStatus }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sigra native proof")
                    .font(.headline)
                    .accessibilityIdentifier("proof.ready")
                proofValue("Evidence class", value: evidenceClass, identifier: "proof.evidence-class")
                if live.isLive { liveControls }
                proofValue("Hosted return", value: status.hostedReturn, identifier: "proof.hosted-return")
                proofValue("Storage posture", value: status.storagePresent && status.storageRotated, identifier: "proof.storage-posture")
                proofValue("Storage present", value: status.storagePresent, identifier: "proof.storage-present")
                proofValue("Storage rotated", value: status.storageRotated, identifier: "proof.storage-rotated")
                proofValue("Storage recovered", value: status.storageRecoveredAfterRelaunch, identifier: "proof.storage-recovered")
                proofValue("Storage logout deletion", value: status.storageDeletedAfterLogout, identifier: "proof.storage-deleted-logout")
                proofValue("Storage revocation deletion", value: status.storageDeletedAfterRevocation, identifier: "proof.storage-deleted-revocation")
                proofValue(
                    "Storage read",
                    value: status.storageReadResult,
                    identifier: "proof.storage-read-result"
                )
                proofValue("Access persisted", value: "false", identifier: "proof.access-persisted")
                proofValue("Image verified", value: status.imageVerified, identifier: "proof.image-verified")
                proofValue("Audio verified", value: status.audioVerified, identifier: "proof.audio-verified")
                proofValue("Strict lease edge", value: status.strictLeaseEdge, identifier: "proof.strict-lease-edge")
                proofValue("Offline use", value: status.offlineUse, identifier: "proof.offline-use")
                proofValue("Kill and relaunch", value: status.killRelaunch, identifier: "proof.kill-relaunch")
                proofValue("Account switch", value: status.accountSwitch, identifier: "proof.account-switch")
                proofValue("Server revocation", value: status.serverRevocation, identifier: "proof.server-revocation")
                proofValue("Cleanup", value: status.cleanup, identifier: "proof.cleanup")
                proofValue("Replay accepted", value: status.replayAccepted, identifier: "proof.replay-accepted")
                proofValue("Replay rejected", value: status.replayRejected, identifier: "proof.replay-rejected")
                proofValue("Replay conflict", value: status.replayConflict, identifier: "proof.replay-conflict")
                proofValue(
                    "Transport claim",
                    value: "controlled_transport_failure",
                    identifier: "proof.transport-claim"
                )
            }
            .padding()
        }
    }

    @ViewBuilder
    private var liveControls: some View {
        if !live.failureRule.isEmpty {
            Text(live.failureRule)
                .accessibilityIdentifier("proof.failure-rule")
        } else if live.phase == "fresh" {
            Button("Start live proof") {
                Task { if let anchor = presentationAnchor() { await live.startFirstJourney(anchor: anchor) } }
            }
            .accessibilityIdentifier("proof.start-live")
        } else if live.phase == "awaitingRelaunch" {
            VStack(alignment: .leading) {
                Text("Ready for process relaunch")
                    .accessibilityIdentifier("proof.awaiting-relaunch")
                Button("Resume live proof") {
                    Task { await live.resumeAfterRelaunch() }
                }
                .accessibilityIdentifier("proof.resume-live")
            }
        } else if live.phase == "awaitingFinalLogin" {
            Button("Finish live proof") {
                Task { if let anchor = presentationAnchor() { await live.finishWithLocalLogout(anchor: anchor) } }
            }
            .accessibilityIdentifier("proof.finish-live")
        } else if live.phase == "complete" {
            Text("Live physical proof complete")
                .accessibilityIdentifier("proof.live-complete")
        } else {
            Button("Resume live proof") {
                Task { await live.resumeAfterRelaunch() }
            }
            .accessibilityIdentifier("proof.resume-live")
        }
    }

    private func presentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private func proofValue(_ label: String, value: Bool, identifier: String) -> some View {
        proofValue(label, value: value ? "true" : "false", identifier: identifier)
    }

    private func proofValue(_ label: String, value: String, identifier: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityIdentifier(identifier)
    }
}
#endif
