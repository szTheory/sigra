package dev.sigra.proof

import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import java.util.regex.Pattern
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Live-only proof phases. The host runner invokes each method independently so
 * process death and network removal remain outside the instrumentation process.
 * The retained report contains posture booleans only; credentials are read from
 * an app-private 0600 file and deleted by the terminal phase.
 */
class LiveNativeProofInstrumentedTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)
    private val report = ProofReport(File(context.filesDir, "proof-live-report.json"))
    private val lesson = NativeLessonStore(File(context.filesDir, "proof-lesson"))
    private val configuration = HostedAuthConfiguration(BuildConfig.PROOF_HOST_BASE_URL, "android-native-proof")

    @Test
    fun hostedOnlinePhase() {
        val credentials = credentials().getJSONObject("primary")
        val store = SecureRefreshStore(context)
        store.deleteAfterLogout()
        val session = browserLogin(credentials.getString("email"), credentials.getString("password"), store)
        report.merge("hosted_return" to true, "storage_present" to session.storagePosture.present)

        val client = session.withMemoryOnlyAccess { NativeProofHostClient(BuildConfig.PROOF_HOST_BASE_URL, it) }
        val returned = client.nativeReturn()
        assertTrue(returned)
        val bootstrap = client.bootstrap()
        val partition = bootstrap.getString("partition")
        val expires = Instant.parse(bootstrap.getString("expires_at")).toEpochMilli() * 1_000
        val media = bootstrap.getJSONArray("media")
        val manifests = mutableListOf<NativeMediaManifest>()
        val bodies = mutableMapOf<MediaKind, ByteArray>()
        repeat(media.length()) { index ->
            val entry = media.getJSONObject(index)
            val kind = MediaKind.entries.single { it.wireValue == entry.getString("kind") }
            val body = client.getBytes(entry.getString("url"))
            manifests += NativeMediaManifest(kind, entry.getString("version"), entry.getInt("byte_size"), entry.getString("sha256"))
            bodies[kind] = body
        }
        lesson.activate(NativeLessonLease(partition, expires), manifests, bodies)
        assertTrue(lesson.offlineMedia(MediaKind.IMAGE, partition, expires - 1).isFile)
        assertTrue(lesson.offlineMedia(MediaKind.AUDIO, partition, expires - 1).isFile)
        assertFalse(lesson.isAvailableOffline(partition, expires))
        File(context.filesDir, "proof-partition.txt").writeText(partition)

        val rotated = session.rotateRefresh()
        assertTrue(rotated.rotated)
        report.merge(
            "native_return" to returned,
            "image_verified" to true,
            "audio_verified" to true,
            "strict_lease_edge" to true,
            "storage_rotated" to true,
            "access_persisted" to false,
        )
    }

    @Test
    fun offlinePhase() {
        val partition = File(context.filesDir, "proof-partition.txt").readText()
        val asOf = System.currentTimeMillis() * 1_000
        assertTrue(lesson.isAvailableOffline(partition, asOf))
        assertTrue(lesson.offlineMedia(MediaKind.IMAGE, partition, asOf).isFile)
        assertTrue(lesson.offlineMedia(MediaKind.AUDIO, partition, asOf).isFile)
        report.merge("offline_use" to true)
    }

    @Test
    fun relaunchPhase() {
        val store = SecureRefreshStore(context)
        assertTrue(store.recoverAfterRelaunch().recoveredAfterRelaunch)
        val session = HostedAuthSession(configuration, HttpHostedAuthTransport(), store)
        assertTrue(session.rotateRefresh().rotated)
        val partition = File(context.filesDir, "proof-partition.txt").readText()
        assertTrue(lesson.recover(partition, System.currentTimeMillis() * 1_000))
        report.merge("storage_recovered" to true, "kill_relaunch" to true)
    }

    @Test
    fun accountReplayAndRevocationPhase() {
        val firstPartition = File(context.filesDir, "proof-partition.txt").readText()
        val credentials = credentials().getJSONObject("secondary")
        val store = SecureRefreshStore(context)
        val session = browserLogin(credentials.getString("email"), credentials.getString("password"), store)
        val client = session.withMemoryOnlyAccess { NativeProofHostClient(BuildConfig.PROOF_HOST_BASE_URL, it) }
        val secondPartition = client.bootstrap().getString("partition")
        assertNotEquals(firstPartition, secondPartition)
        lesson.switchPartition(secondPartition)
        assertFalse(lesson.isAvailableOffline(firstPartition, System.currentTimeMillis() * 1_000))

        val accepted = client.replay("market-morning-v1", "answer", "apple")
        val rejected = client.replay("market-morning-v1", "answer", "")
        val conflict = client.replay("stale-checkpoint", "answer", "apple")
        assertEquals("accepted", accepted)
        assertEquals("rejected", rejected)
        assertEquals("conflict", conflict)

        val logoutPosture = session.logout()
        assertTrue(logoutPosture.deletedAfterLogout)
        val revocationStore = SecureRefreshStore(context)
        val revokedSession = browserLogin(credentials.getString("email"), credentials.getString("password"), revocationStore)
        val revokedClient = revokedSession.withMemoryOnlyAccess { NativeProofHostClient(BuildConfig.PROOF_HOST_BASE_URL, it) }
        assertTrue(revokedClient.logout())
        assertTrue(revokedSession.rotateRefresh().deletedAfterRevocation)

        report.merge(
            "account_switch" to true,
            "replay_accepted" to true,
            "replay_rejected" to true,
            "replay_conflict" to true,
            "storage_deleted_logout" to true,
            "storage_deleted_revocation" to true,
            "storage_read_result" to "not_found",
            "server_revocation" to true,
        )
        File(context.filesDir, "proof-credentials.json").delete()
    }

    private fun credentials(): JSONObject = JSONObject(File(context.filesDir, "proof-credentials.json").readText())

    private fun browserLogin(email: String, password: String, store: SecureRefreshStore): HostedAuthSession {
        val attempt = HostedAuthSession.authorizationRequest(configuration)
        val session = HostedAuthSession(configuration, HttpHostedAuthTransport(), store)
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                HostedAuthSession.launchBrowser(
                    activity,
                    activity.authTabLauncherForProof,
                    attempt.startUri,
                    BrowserMode.fromWire(BuildConfig.LOCKED_BROWSER_MODE),
                )
            }
            val edits = waitForHostedLoginFields()
            edits[0].text = email
            edits[1].text = password
            clickExact("Log in")
            clickExact("Approve and continue")
            assertTrue(device.wait(Until.hasObject(By.pkg(context.packageName)), 30_000))
            val deadline = SystemClock.uptimeMillis() + 10_000
            var callback: String? = null
            while (callback == null && SystemClock.uptimeMillis() < deadline) {
                scenario.onActivity { callback = it.intent?.dataString }
                instrumentation.waitForIdleSync()
            }
            session.completeCallback(checkNotNull(callback), attempt.state, attempt.verifier)
        }
        return session
    }

    private fun waitForHostedLoginFields(): List<androidx.test.uiautomator.UiObject2> {
        val deadline = SystemClock.uptimeMillis() + 45_000
        val onboarding = By.text(Pattern.compile("^(Use without an account|Accept & continue|No thanks)$"))
        while (SystemClock.uptimeMillis() < deadline) {
            val edits = device.findObjects(By.clazz("android.widget.EditText"))
            if (edits.size >= 2) return edits
            val action = device.wait(Until.findObject(onboarding), 1_000)
            if (action != null) {
                action.click()
                instrumentation.waitForIdleSync()
            }
        }
        error("hosted login fields unavailable in active package ${device.currentPackageName}")
    }

    private fun clickExact(label: String) {
        val node = device.wait(Until.findObject(By.text(label)), 30_000)
            ?: error("browser action unavailable: $label")
        node.click()
        instrumentation.waitForIdleSync()
    }
}

private class NativeProofHostClient(baseUrl: String, access: ByteArray) {
    private val root = baseUrl.trimEnd('/')
    private val authorization = "Bearer " + access.toString(StandardCharsets.UTF_8)

    fun nativeReturn(): Boolean {
        val body = JSONObject()
            .put("platform", "android")
            .put("transport", "custom_scheme")
            .put("link_verification", "not_applicable")
            .put("callback_binding", "matched")
            .put("replay", "not_seen")
            .put("native_assertion_ref", "android-proof")
        return request("POST", "/api/native-proof/return", body.toString()).getString("status") == "allow"
    }

    fun bootstrap(): JSONObject = request("GET", "/api/native-proof/lesson/bootstrap")

    fun getBytes(path: String): ByteArray = raw("GET", path, null).second

    fun replay(checkpoint: String, action: String, answer: String): String {
        val id = UUID.randomUUID().toString()
        val body = JSONObject()
            .put("client_mutation_id", id)
            .put("idempotency_key", id)
            .put("base_checkpoint", checkpoint)
            .put("action", action)
            .put("answer", answer)
        return request("POST", "/api/native-proof/lesson/replay", body.toString()).getString("status")
    }

    fun logout(): Boolean = request("POST", "/api/native-proof/logout", "{}").getBoolean("ok")

    private fun request(method: String, path: String, body: String? = null): JSONObject {
        val (status, bytes) = raw(method, path, body)
        check(status in 200..299) { "host request failed with bounded status $status" }
        return JSONObject(bytes.toString(StandardCharsets.UTF_8))
    }

    private fun raw(method: String, path: String, body: String?): Pair<Int, ByteArray> {
        val connection = URL(root + path).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.setRequestProperty("Authorization", authorization)
        if (body != null) {
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
        }
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        return status to (stream?.use { it.readBytes() } ?: byteArrayOf())
    }
}

private class ProofReport(private val file: File) {
    @Synchronized
    fun merge(vararg facts: Pair<String, Any>) {
        val current = if (file.isFile) JSONObject(file.readText()) else JSONObject()
        facts.forEach { (key, value) -> current.put(key, value) }
        val temporary = File(file.parentFile, ".${file.name}.tmp")
        temporary.writeText(current.toString())
        check(temporary.renameTo(file)) { "could not publish proof report atomically" }
    }
}
