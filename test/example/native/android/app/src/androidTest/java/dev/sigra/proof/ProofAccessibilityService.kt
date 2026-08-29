package dev.sigra.proof

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/** Test-APK-only service that makes Chrome's renderer accessibility tree observable. */
class ProofAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit
}
