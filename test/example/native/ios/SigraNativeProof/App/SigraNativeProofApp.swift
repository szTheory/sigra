import SwiftUI

@main
struct SigraNativeProofApp: App {
    var body: some Scene {
        WindowGroup {
            #if NATIVE_PROOF
            NativeProofStatusView()
            #else
            Text("Sigra native proof")
            #endif
        }
    }
}
