package dev.sigra.proof

import android.app.Activity
import android.content.Context
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.browser.auth.AuthTabIntent
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

data class HostedAuthConfiguration(val baseUrl: String, val profileId: String)

data class HostedAuthorizationAttempt(
    val state: String,
    val verifier: String,
    val startUri: URI,
    val query: Map<String, String>,
)

data class HostedSessionMaterial(val access: ByteArray, val refresh: ByteArray)

enum class BrowserMode(val wireValue: String) {
    AUTH_TAB("auth_tab"),
    CUSTOM_TAB_FALLBACK("custom_tab_fallback");

    companion object {
        fun fromWire(value: String): BrowserMode = entries.singleOrNull { it.wireValue == value }
            ?: throw IllegalArgumentException("browser mode is not allowlisted")
    }
}

sealed class HostedAuthException(message: String) : IllegalArgumentException(message) {
    class InvalidConfiguration : HostedAuthException("invalid hosted auth configuration")
    class InvalidCallback : HostedAuthException("invalid hosted auth callback")
    class InvalidResponse : HostedAuthException("invalid hosted auth response")
    class ServerRevoked : HostedAuthException("host revoked the session")
}

interface HostedAuthTransport {
    fun exchange(code: String, verifier: String, configuration: HostedAuthConfiguration): HostedSessionMaterial
    fun refresh(material: ByteArray, configuration: HostedAuthConfiguration): HostedSessionMaterial
}

class HttpHostedAuthTransport : HostedAuthTransport {
    override fun exchange(
        code: String,
        verifier: String,
        configuration: HostedAuthConfiguration,
    ): HostedSessionMaterial = request(
        "/api/app-login/exchange",
        mapOf(
            "code" to code,
            "code_verifier" to verifier,
            "profile_id" to configuration.profileId,
            "callback" to HostedAuthSession.CALLBACK_URI,
        ),
        configuration,
    )

    override fun refresh(
        material: ByteArray,
        configuration: HostedAuthConfiguration,
    ): HostedSessionMaterial = request(
        "/api/app-login/refresh",
        mapOf("refresh_token" to material.toString(StandardCharsets.UTF_8)),
        configuration,
    )

    private fun request(
        path: String,
        body: Map<String, String>,
        configuration: HostedAuthConfiguration,
    ): HostedSessionMaterial {
        val base = URI(configuration.baseUrl)
        if (base.scheme !in setOf("http", "https") || base.host.isNullOrBlank()) {
            throw HostedAuthException.InvalidConfiguration()
        }
        val connection = URL(configuration.baseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.setRequestProperty("Content-Type", "application/json")
        connection.doOutput = true
        connection.outputStream.use { output -> output.write(jsonObject(body).toByteArray(StandardCharsets.UTF_8)) }
        if (connection.responseCode == HttpURLConnection.HTTP_UNAUTHORIZED) {
            throw HostedAuthException.ServerRevoked()
        }
        if (connection.responseCode !in 200..299) throw HostedAuthException.InvalidResponse()
        val response = connection.inputStream.bufferedReader().use(BufferedReader::readText)
        val access = jsonString(response, "access_token")?.toByteArray(StandardCharsets.UTF_8)
        val refresh = jsonString(response, "refresh_token")?.toByteArray(StandardCharsets.UTF_8)
        if (access == null || access.isEmpty() || refresh == null || refresh.isEmpty()) {
            throw HostedAuthException.InvalidResponse()
        }
        return HostedSessionMaterial(access, refresh)
    }

    private fun jsonObject(fields: Map<String, String>): String = fields.entries.joinToString(
        prefix = "{",
        postfix = "}",
    ) { (key, value) -> "\"${escape(key)}\":\"${escape(value)}\"" }

    private fun jsonString(value: String, key: String): String? {
        val pattern = Regex("\\\"${Regex.escape(key)}\\\"\\s*:\\s*\\\"((?:\\\\.|[^\\\"\\\\])*)\\\"")
        return pattern.find(value)?.groupValues?.get(1)?.let(::unescape)
    }

    private fun escape(value: String): String = value
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")

    private fun unescape(value: String): String = value
        .replace("\\n", "\n")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\")
}

class HostedAuthSession(
    private val configuration: HostedAuthConfiguration,
    private val transport: HostedAuthTransport,
    private val refreshStore: SecureRefreshStore,
) {
    private var accessMaterial: ByteArray? = null

    val hasMemoryOnlyAccess: Boolean get() = accessMaterial != null
    val storagePosture: StoragePosture get() = refreshStore.posture

    fun completeCallback(callback: String, expectedState: String, verifier: String): StoragePosture {
        val code = validatedCode(callback, expectedState)
        val issued = transport.exchange(code, verifier, configuration)
        accessMaterial = issued.access.copyOf()
        return refreshStore.saveInitial(issued.refresh)
    }

    fun rotateRefresh(): StoragePosture = try {
        val replacement = transport.refresh(refreshStore.currentMaterial(), configuration)
        accessMaterial = replacement.access.copyOf()
        refreshStore.rotate(replacement.refresh)
    } catch (_: HostedAuthException.ServerRevoked) {
        accessMaterial = null
        refreshStore.deleteAfterRevocation()
    }

    fun recoverAfterRelaunch(): StoragePosture {
        accessMaterial = null
        return refreshStore.recoverAfterRelaunch()
    }

    internal fun <T> withMemoryOnlyAccess(block: (ByteArray) -> T): T {
        val material = accessMaterial ?: throw HostedAuthException.InvalidResponse()
        return block(material.copyOf())
    }

    fun logout(): StoragePosture {
        accessMaterial = null
        return refreshStore.deleteAfterLogout()
    }

    fun markServerRevoked(): StoragePosture {
        accessMaterial = null
        return refreshStore.deleteAfterRevocation()
    }

    companion object {
        const val CALLBACK_URI = "sigra-native-proof://auth/android"
        const val LOCKED_BROWSER_PACKAGE = "com.android.chrome"

        fun authorizationRequest(
            configuration: HostedAuthConfiguration,
            state: String = randomUrlSafe(32),
            verifier: String = randomUrlSafe(48),
        ): HostedAuthorizationAttempt {
            val base = runCatching { URI(configuration.baseUrl) }.getOrNull()
            if (base == null || base.scheme !in setOf("http", "https") || base.host.isNullOrBlank() ||
                configuration.profileId.isBlank() || state.isBlank() || verifier.length !in 43..128 ||
                !verifier.matches(Regex("[A-Za-z0-9._~-]+"))
            ) throw HostedAuthException.InvalidConfiguration()
            val query = linkedMapOf(
                "profile_id" to configuration.profileId,
                "callback" to CALLBACK_URI,
                "state" to state,
                "code_challenge" to pkceChallenge(verifier),
                "code_challenge_method" to "S256",
            )
            val encoded = query.entries.joinToString("&") { (key, value) ->
                "${urlEncode(key)}=${urlEncode(value)}"
            }
            val uri = URI(base.scheme, base.userInfo, base.host, base.port, "/users/app-login", encoded, null)
            return HostedAuthorizationAttempt(state, verifier, uri, query)
        }

        fun validatedCode(callback: String, expectedState: String): String {
            val uri = runCatching { URI(callback) }.getOrNull() ?: throw HostedAuthException.InvalidCallback()
            if (uri.scheme != "sigra-native-proof" || uri.host != "auth" || uri.path != "/android" ||
                uri.port != -1 || uri.userInfo != null || uri.fragment != null
            ) throw HostedAuthException.InvalidCallback()
            val items = parseQuery(uri.rawQuery)
            if (items.keys != setOf("code", "state") || items["code"].isNullOrBlank() ||
                !constantTimeEqual(items["state"].orEmpty(), expectedState)
            ) throw HostedAuthException.InvalidCallback()
            return items.getValue("code")
        }

        fun selectBrowserMode(lockedMode: BrowserMode, providerSupportsAuthTab: Boolean): BrowserMode =
            if (lockedMode == BrowserMode.AUTH_TAB && providerSupportsAuthTab) BrowserMode.AUTH_TAB
            else BrowserMode.CUSTOM_TAB_FALLBACK

        fun shouldLaunchAuthTab(mode: BrowserMode): Boolean = mode == BrowserMode.AUTH_TAB

        fun launchBrowser(
            activity: Activity,
            authTabLauncher: ActivityResultLauncher<android.content.Intent>,
            startUri: URI,
            lockedMode: BrowserMode,
        ): BrowserMode {
            val providerAvailable = activity.packageManager.getLaunchIntentForPackage(LOCKED_BROWSER_PACKAGE) != null
            if (!providerAvailable) throw HostedAuthException.InvalidConfiguration()
            val supportsAuthTab = CustomTabsClient.isAuthTabSupported(activity, LOCKED_BROWSER_PACKAGE)
            val selected = selectBrowserMode(lockedMode, supportsAuthTab)
            if (selected == BrowserMode.AUTH_TAB) {
                AuthTabIntent.Builder().build().launch(authTabLauncher, Uri.parse(startUri.toString()), "sigra-native-proof")
            } else {
                CustomTabsIntent.Builder().build().also { it.intent.setPackage(LOCKED_BROWSER_PACKAGE) }
                    .launchUrl(activity, Uri.parse(startUri.toString()))
            }
            return selected
        }

        fun providerSupportsAuthTab(context: Context): Boolean =
            CustomTabsClient.isAuthTabSupported(context, LOCKED_BROWSER_PACKAGE)

        private fun parseQuery(raw: String?): Map<String, String> {
            if (raw.isNullOrEmpty()) return emptyMap()
            val result = linkedMapOf<String, String>()
            raw.split('&').forEach { pair ->
                val pieces = pair.split('=', limit = 2)
                if (pieces.size != 2) throw HostedAuthException.InvalidCallback()
                val key = URLDecoder.decode(pieces[0], StandardCharsets.UTF_8.name())
                val value = URLDecoder.decode(pieces[1], StandardCharsets.UTF_8.name())
                if (result.put(key, value) != null) throw HostedAuthException.InvalidCallback()
            }
            return result
        }

        private fun pkceChallenge(verifier: String): String = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII)))

        private fun randomUrlSafe(byteCount: Int): String = ByteArray(byteCount).also(SecureRandom()::nextBytes)
            .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }

        private fun urlEncode(value: String): String =
            URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")

        private fun constantTimeEqual(left: String, right: String): Boolean = MessageDigest.isEqual(
            left.toByteArray(StandardCharsets.UTF_8),
            right.toByteArray(StandardCharsets.UTF_8),
        )
    }
}
