import SwiftUI

#if NATIVE_PROOF
struct NativeProofStatus {
    let hostedReturn: Bool
    let storagePosture: Bool
    let imageVerified: Bool
    let audioVerified: Bool
    let strictLeaseEdge: Bool
    let offlineUse: Bool
    let killRelaunch: Bool
    let accountSwitch: Bool
    let serverRevocation: Bool
    let cleanup: Bool
    let replayAccepted: Bool
    let replayRejected: Bool
    let replayConflict: Bool

    static let contractComplete = NativeProofStatus(
        hostedReturn: true,
        storagePosture: true,
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
        storagePosture: false,
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
    private let status: NativeProofStatus

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        status = environment["SIGRA_NATIVE_PROOF_FIXTURE"] == "contract_complete"
            ? .contractComplete
            : .unavailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sigra native proof")
                    .font(.headline)
                    .accessibilityIdentifier("proof.ready")
                proofValue("Contract evidence class", value: "contract_only", identifier: "proof.evidence-class")
                proofValue("Hosted return", value: status.hostedReturn, identifier: "proof.hosted-return")
                proofValue("Storage posture", value: status.storagePosture, identifier: "proof.storage-posture")
                proofValue(
                    "Storage read",
                    value: status.storagePosture ? "read_ok" : "not_found",
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
