package dev.sigra.proof

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.InvalidKeyException
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import java.util.Base64
import javax.crypto.AEADBadTagException
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

enum class StorageReadResult(val wireValue: String) {
    READ_OK("read_ok"),
    NOT_FOUND("not_found"),
    DECRYPT_FAILED("decrypt_failed"),
    KEY_UNAVAILABLE("key_unavailable"),
}

data class StoragePosture(
    val present: Boolean = false,
    val rotated: Boolean = false,
    val recoveredAfterRelaunch: Boolean = false,
    val deletedAfterLogout: Boolean = false,
    val deletedAfterRevocation: Boolean = false,
    val readResult: StorageReadResult = StorageReadResult.NOT_FOUND,
) {
    fun asMap(): Map<String, Any> = linkedMapOf(
        "present" to present,
        "rotated" to rotated,
        "recovered_after_relaunch" to recoveredAfterRelaunch,
        "deleted_after_logout" to deletedAfterLogout,
        "deleted_after_revocation" to deletedAfterRevocation,
        "read_result" to readResult.wireValue,
        "access_persisted" to false,
    )
}

data class EncryptedRefreshRecord(
    val keyAlias: String,
    val version: Int,
    val nonce: ByteArray,
    val ciphertext: ByteArray,
)

interface RefreshRecordStorage {
    var record: EncryptedRefreshRecord?
}

sealed class RefreshCryptoException : RuntimeException() {
    data object DecryptFailed : RefreshCryptoException()
    data object KeyUnavailable : RefreshCryptoException()
}

interface RefreshCrypto {
    fun encrypt(value: ByteArray): EncryptedRefreshRecord
    fun decrypt(record: EncryptedRefreshRecord): ByteArray
    fun deleteKey()
}

class AppPrivateRefreshRecordStorage(context: Context) : RefreshRecordStorage {
    private val file = File(context.filesDir, "native-refresh-record.json")

    override var record: EncryptedRefreshRecord?
        get() {
            if (!file.isFile) return null
            return runCatching { decode(file.readText(StandardCharsets.UTF_8)) }.getOrElse {
                EncryptedRefreshRecord(CORRUPT_ALIAS, 1, byteArrayOf(), byteArrayOf())
            }
        }
        set(value) {
            if (value == null) {
                file.delete()
                return
            }
            val temporary = File(file.parentFile, ".${file.name}.tmp")
            temporary.outputStream().use { output ->
                output.write(encode(value).toByteArray(StandardCharsets.UTF_8))
                output.flush()
                output.fd.sync()
            }
            if (!temporary.renameTo(file)) {
                temporary.delete()
                throw IllegalStateException("could not persist encrypted refresh record")
            }
        }

    private fun encode(value: EncryptedRefreshRecord): String =
        "{\"nonce\":\"${b64(value.nonce)}\",\"ciphertext\":\"${b64(value.ciphertext)}\"," +
            "\"keyAlias\":\"${value.keyAlias}\",\"version\":${value.version}}"

    private fun decode(value: String): EncryptedRefreshRecord {
        val match = RECORD.matchEntire(value) ?: throw IllegalArgumentException("invalid record")
        return EncryptedRefreshRecord(
            keyAlias = match.groupValues[3],
            version = match.groupValues[4].toInt(),
            nonce = Base64.getDecoder().decode(match.groupValues[1]),
            ciphertext = Base64.getDecoder().decode(match.groupValues[2]),
        )
    }

    private fun b64(value: ByteArray): String = Base64.getEncoder().encodeToString(value)

    companion object {
        const val CORRUPT_ALIAS = "corrupt-record"
        private val RECORD = Regex(
            "\\{\"nonce\":\"([A-Za-z0-9+/]*={0,2})\",\"ciphertext\":\"([A-Za-z0-9+/]*={0,2})\"," +
                "\"keyAlias\":\"([A-Za-z0-9._-]{1,80})\",\"version\":([0-9]+)\\}",
        )
    }
}

class AndroidKeyStoreRefreshCrypto(
    private val alias: String = "sigra-native-proof-refresh-v1",
) : RefreshCrypto {
    private val keyStore: KeyStore get() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    override fun encrypt(value: ByteArray): EncryptedRefreshRecord {
        require(value.isNotEmpty())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, loadOrCreateKey())
        return EncryptedRefreshRecord(alias, 1, cipher.iv, cipher.doFinal(value))
    }

    override fun decrypt(record: EncryptedRefreshRecord): ByteArray {
        if (record.version != 1 || record.keyAlias != alias || record.nonce.isEmpty() || record.ciphertext.isEmpty()) {
            throw RefreshCryptoException.DecryptFailed
        }
        val key = try {
            keyStore.getKey(alias, null) as? SecretKey ?: throw RefreshCryptoException.KeyUnavailable
        } catch (_: UnrecoverableKeyException) {
            throw RefreshCryptoException.KeyUnavailable
        }
        return try {
            Cipher.getInstance("AES/GCM/NoPadding").run {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, record.nonce))
                doFinal(record.ciphertext)
            }
        } catch (_: InvalidKeyException) {
            throw RefreshCryptoException.KeyUnavailable
        } catch (_: AEADBadTagException) {
            throw RefreshCryptoException.DecryptFailed
        } catch (_: BadPaddingException) {
            throw RefreshCryptoException.DecryptFailed
        }
    }

    override fun deleteKey() {
        keyStore.deleteEntry(alias)
    }

    private fun loadOrCreateKey(): SecretKey {
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }
}

class SecureRefreshStore(
    private val storage: RefreshRecordStorage,
    private val crypto: RefreshCrypto,
) {
    @Volatile
    var posture: StoragePosture = StoragePosture()
        private set

    constructor(context: Context) : this(
        AppPrivateRefreshRecordStorage(context.applicationContext),
        AndroidKeyStoreRefreshCrypto(),
    )

    fun saveInitial(material: ByteArray): StoragePosture {
        storage.record = crypto.encrypt(material.copyOf())
        posture = posture.copy(present = true, readResult = StorageReadResult.READ_OK)
        return posture
    }

    fun rotate(replacement: ByteArray): StoragePosture {
        currentMaterial()
        storage.record = crypto.encrypt(replacement.copyOf())
        posture = posture.copy(present = true, rotated = true, readResult = StorageReadResult.READ_OK)
        return posture
    }

    fun currentMaterial(): ByteArray {
        val record = storage.record ?: throw RefreshCryptoException.KeyUnavailable
        return crypto.decrypt(record)
    }

    fun readPosture(): StoragePosture {
        val record = storage.record
        posture = when {
            record == null -> posture.copy(present = false, readResult = StorageReadResult.NOT_FOUND)
            else -> try {
                crypto.decrypt(record)
                posture.copy(present = true, readResult = StorageReadResult.READ_OK)
            } catch (_: RefreshCryptoException.DecryptFailed) {
                posture.copy(present = true, readResult = StorageReadResult.DECRYPT_FAILED)
            } catch (_: RefreshCryptoException.KeyUnavailable) {
                posture.copy(present = true, readResult = StorageReadResult.KEY_UNAVAILABLE)
            }
        }
        return posture
    }

    fun recoverAfterRelaunch(): StoragePosture {
        val read = readPosture()
        posture = read.copy(recoveredAfterRelaunch = read.readResult == StorageReadResult.READ_OK)
        return posture
    }

    fun deleteAfterLogout(): StoragePosture {
        storage.record = null
        crypto.deleteKey()
        posture = posture.copy(present = false, deletedAfterLogout = true, readResult = StorageReadResult.NOT_FOUND)
        return posture
    }

    fun deleteAfterRevocation(): StoragePosture {
        storage.record = null
        crypto.deleteKey()
        posture = posture.copy(present = false, deletedAfterRevocation = true, readResult = StorageReadResult.NOT_FOUND)
        return posture
    }
}
