package dev.sigra.proof

import java.io.File
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeProofContractTest {
    @Test
    fun `hosted request binds exact callback and PKCE S256`() {
        val attempt = HostedAuthSession.authorizationRequest(
            HostedAuthConfiguration("http://localhost:4102", "android-primary"),
            state = "expected-state",
            verifier = "v".repeat(43),
        )

        assertEquals("/users/app-login", attempt.startUri.path)
        assertEquals("android-primary", attempt.query["profile_id"])
        assertEquals("sigra-native-proof://auth/android", attempt.query["callback"])
        assertEquals("expected-state", attempt.query["state"])
        assertEquals("S256", attempt.query["code_challenge_method"])
        assertNotEquals("v".repeat(43), attempt.query["code_challenge"])
    }

    @Test
    fun `callback denies wrong scheme host path state missing code and extra query`() {
        assertEquals(
            "one-time",
            HostedAuthSession.validatedCode(
                "sigra-native-proof://auth/android?code=one-time&state=expected",
                "expected",
            ),
        )

        listOf(
            "other://auth/android?code=one-time&state=expected",
            "sigra-native-proof://other/android?code=one-time&state=expected",
            "sigra-native-proof://auth/other?code=one-time&state=expected",
            "sigra-native-proof://auth/android?code=one-time&state=wrong",
            "sigra-native-proof://auth/android?state=expected",
            "sigra-native-proof://auth/android?code=one-time&state=expected&extra=no",
        ).forEach { denied ->
            assertThrows(HostedAuthException.InvalidCallback::class.java) {
                HostedAuthSession.validatedCode(denied, "expected")
            }
        }
    }

    @Test
    fun `committed fallback lock cannot execute Auth Tab`() {
        val decision = HostedAuthSession.selectBrowserMode(
            lockedMode = BrowserMode.CUSTOM_TAB_FALLBACK,
            providerSupportsAuthTab = true,
        )

        assertEquals(BrowserMode.CUSTOM_TAB_FALLBACK, decision)
        assertFalse(HostedAuthSession.shouldLaunchAuthTab(decision))
    }

    @Test
    fun `secure store covers rotation relaunch logout revocation and every read result`() {
        val records = FakeRecordStorage()
        val crypto = FakeRefreshCrypto()
        val store = SecureRefreshStore(records, crypto)

        assertEquals(StorageReadResult.READ_OK, store.saveInitial("first".toByteArray()).readResult)
        assertTrue(store.rotate("second".toByteArray()).rotated)
        assertTrue(SecureRefreshStore(records, crypto).recoverAfterRelaunch().recoveredAfterRelaunch)
        assertTrue(store.deleteAfterLogout().deletedAfterLogout)
        store.saveInitial("third".toByteArray())
        assertTrue(store.deleteAfterRevocation().deletedAfterRevocation)

        records.record = null
        assertEquals(StorageReadResult.NOT_FOUND, store.readPosture().readResult)
        records.record = EncryptedRefreshRecord("alias", 1, byteArrayOf(1), byteArrayOf(2))
        crypto.readFailure = RefreshCryptoException.DecryptFailed
        assertEquals(StorageReadResult.DECRYPT_FAILED, store.readPosture().readResult)
        crypto.readFailure = RefreshCryptoException.KeyUnavailable
        assertEquals(StorageReadResult.KEY_UNAVAILABLE, store.readPosture().readResult)
    }

    @Test
    fun `storage posture is exact and access is never persisted`() {
        val keys = StoragePosture().asMap().keys
        assertEquals(
            setOf(
                "present", "rotated", "recovered_after_relaunch", "deleted_after_logout",
                "deleted_after_revocation", "read_result", "access_persisted",
            ),
            keys,
        )
        assertEquals(false, StoragePosture().asMap()["access_persisted"])
    }

    @Test
    fun `media activates marker last and strict microsecond expiry denies exact edge`() {
        val root = temporaryRoot()
        val store = NativeLessonStore(root)
        val image = "verified-image".toByteArray()
        val audio = "verified-audio".toByteArray()
        val expiresAtMicros = 1_800_000_000_000_000L
        val lease = NativeLessonLease("partition-one", expiresAtMicros)
        val manifests = listOf(
            NativeMediaManifest(MediaKind.IMAGE, "image-v1", image.size, sha256(image)),
            NativeMediaManifest(MediaKind.AUDIO, "audio-v1", audio.size, sha256(audio)),
        )

        store.activate(lease, manifests, mapOf(MediaKind.IMAGE to image, MediaKind.AUDIO to audio))
        assertTrue(store.isAvailableOffline("partition-one", expiresAtMicros - 1))
        assertFalse(store.isAvailableOffline("partition-one", expiresAtMicros))
        assertTrue(File(root, "partition-one.activation").isFile)
        assertTrue(NativeLessonStore(root).recover("partition-one", expiresAtMicros - 1))
        assertTrue(store.offlineMedia(MediaKind.AUDIO, "partition-one", expiresAtMicros - 1).isFile)
    }

    @Test
    fun `short corrupt and switched partition media fail closed`() {
        val expected = "verified-audio".toByteArray()
        val manifest = NativeMediaManifest(MediaKind.AUDIO, "audio-v1", expected.size, sha256(expected))
        listOf(expected.copyOf(expected.size - 1), "verified-Audio".toByteArray()).forEach { supplied ->
            val root = temporaryRoot()
            val store = NativeLessonStore(root)
            assertThrows(NativeLessonException.MediaIntegrityFailed::class.java) {
                store.activate(
                    NativeLessonLease("partition-integrity", nowMicros() + 60_000_000),
                    listOf(manifest),
                    mapOf(MediaKind.AUDIO to supplied),
                )
            }
            assertFalse(File(root, "partition-integrity.activation").exists())
        }

        val root = temporaryRoot()
        val store = NativeLessonStore(root)
        store.activate(
            NativeLessonLease("partition-first", nowMicros() + 60_000_000),
            listOf(manifest),
            mapOf(MediaKind.AUDIO to expected),
        )
        store.switchPartition("partition-second")
        assertFalse(store.isAvailableOffline("partition-first", nowMicros()))
    }

    @Test
    fun `journal is credential free and host terminal results persist exactly once`() {
        val root = temporaryRoot()
        val body = "lesson".toByteArray()
        val store = NativeLessonStore(root)
        val lease = NativeLessonLease("partition-replay", nowMicros() + 60_000_000)
        store.activate(
            lease,
            listOf(NativeMediaManifest(MediaKind.IMAGE, "v1", body.size, sha256(body))),
            mapOf(MediaKind.IMAGE to body),
        )

        ReplayTerminal.entries.forEach { terminal ->
            val suffix = terminal.wireValue
            val entry = NativeReplayEntry(
                "journal-$suffix", "mutation-$suffix", "idempotency-$suffix",
                "market-morning-v1", "answer", "apples",
            )
            store.enqueue(entry, "partition-replay", nowMicros())
            assertEquals(terminal, store.reconcile(entry, terminal))
            assertEquals(terminal, store.reconcile(entry, terminal))
        }

        assertEquals(3, store.terminalCount)
        assertFalse(store.journalFile.readText().contains(Regex("access|refresh|credential|account|user")))
    }

    private fun temporaryRoot(): File =
        File(System.getProperty("java.io.tmpdir"), "sigra-native-${System.nanoTime()}").also { it.mkdirs() }

    private fun nowMicros(): Long = Instant.now().epochSecond * 1_000_000L

    private fun sha256(value: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(value).joinToString("") { "%02x".format(it) }
}

private class FakeRecordStorage : RefreshRecordStorage {
    override var record: EncryptedRefreshRecord? = null
}

private class FakeRefreshCrypto : RefreshCrypto {
    var readFailure: RefreshCryptoException? = null

    override fun encrypt(value: ByteArray): EncryptedRefreshRecord =
        EncryptedRefreshRecord("sigra-native-refresh-v1", 1, byteArrayOf(7), value.reversedArray())

    override fun decrypt(record: EncryptedRefreshRecord): ByteArray {
        readFailure?.let { throw it }
        return record.ciphertext.reversedArray()
    }

    override fun deleteKey() = Unit
}
