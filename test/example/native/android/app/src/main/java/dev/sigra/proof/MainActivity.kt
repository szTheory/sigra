package dev.sigra.proof

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.browser.auth.AuthTabIntent

class MainActivity : Activity() {
    private lateinit var readiness: TextView
    private lateinit var callbackStatus: TextView

    private val authTabLauncher = AuthTabIntent.registerActivityResultLauncher(this) { result ->
        callbackStatus.text = if (result.resultCode == AuthTabIntent.RESULT_OK && result.resultUri != null) {
            CALLBACK_RETURNED
        } else {
            CALLBACK_NOT_RETURNED
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        readiness = statusView(READINESS_HOOK, NOT_AUTHENTICATED)
        callbackStatus = statusView(CALLBACK_HOOK, CALLBACK_NOT_RETURNED)
        column.addView(readiness)
        column.addView(callbackStatus)
        STATUS_HOOKS.forEach { hook -> column.addView(statusView(hook, STATUS_PENDING)) }
        setContentView(column)
        handleCallbackIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallbackIntent(intent)
    }

    fun launchHostedLogin() {
        val configuration = HostedAuthConfiguration(BuildConfig.PROOF_HOST_BASE_URL, "android-primary")
        val attempt = HostedAuthSession.authorizationRequest(configuration)
        HostedAuthSession.launchBrowser(
            this,
            authTabLauncher,
            attempt.startUri,
            BrowserMode.fromWire(BuildConfig.LOCKED_BROWSER_MODE),
        )
    }

    private fun handleCallbackIntent(candidate: Intent?) {
        val data = candidate?.dataString ?: return
        callbackStatus.text = runCatching {
            val uri = java.net.URI(data)
            if (uri.scheme == "sigra-native-proof" && uri.host == "auth" && uri.path == "/android") {
                CALLBACK_RETURNED
            } else {
                CALLBACK_REJECTED
            }
        }.getOrDefault(CALLBACK_REJECTED)
    }

    private fun statusView(hook: String, value: String): TextView = TextView(this).apply {
        contentDescription = hook
        text = value
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    companion object {
        const val READINESS_HOOK = "proof.readiness"
        const val CALLBACK_HOOK = "proof.callback"
        const val NOT_AUTHENTICATED = "not_authenticated"
        const val CALLBACK_NOT_RETURNED = "not_returned"
        const val CALLBACK_RETURNED = "returned"
        const val CALLBACK_REJECTED = "rejected"
        const val STATUS_PENDING = "pending_external_orchestration"
        val STATUS_HOOKS = listOf(
            "proof.hosted-return",
            "proof.image-verified",
            "proof.audio-verified",
            "proof.strict-lease-edge",
            "proof.offline-use",
            "proof.kill-relaunch",
            "proof.account-switch",
            "proof.server-revocation",
            "proof.replay-accepted",
            "proof.replay-rejected",
            "proof.replay-conflict",
        )
    }
}
