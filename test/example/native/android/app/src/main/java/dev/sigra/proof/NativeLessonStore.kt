package dev.sigra.proof

import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

enum class MediaKind(val wireValue: String) { IMAGE("image"), AUDIO("audio") }

data class NativeMediaManifest(
    val kind: MediaKind,
    val version: String,
    val byteCount: Int,
    val sha256: String,
)

data class NativeLessonLease(val partition: String, val expiresAtMicros: Long)

data class NativeReplayEntry(
    val journalEntryId: String,
    val clientMutationId: String,
    val idempotencyKey: String,
    val baseCheckpoint: String,
    val action: String,
    val answer: String,
)

enum class ReplayTerminal(val wireValue: String) {
    ACCEPTED("accepted"), REJECTED("rejected"), CONFLICT("conflict")
}

sealed class NativeLessonException(message: String) : IllegalArgumentException(message) {
    class InvalidManifest : NativeLessonException("invalid lesson manifest")
    class MediaIntegrityFailed : NativeLessonException("media integrity failed")
    class PartitionMismatch : NativeLessonException("partition mismatch")
    class LeaseExpired : NativeLessonException("lease expired")
    class InvalidReplay : NativeLessonException("invalid replay")
}

class NativeLessonStore(private val root: File) {
    val journalFile = File(root, "native-lesson-journal.tsv")
    private val terminalFile = File(root, "native-lesson-terminals.tsv")

    val terminalCount: Int get() = loadTerminals().size

    init {
        if (!root.exists() && !root.mkdirs()) throw IllegalStateException("could not create app-private lesson root")
    }

    fun activate(
        lease: NativeLessonLease,
        manifests: List<NativeMediaManifest>,
        bodies: Map<MediaKind, ByteArray>,
    ) {
        validateId(lease.partition)
        if (manifests.isEmpty() || manifests.map { it.kind }.toSet().size != manifests.size) {
            throw NativeLessonException.InvalidManifest()
        }
        clearActivationOnly()
        manifests.forEach { manifest ->
            validateId(manifest.version)
            val body = bodies[manifest.kind] ?: throw NativeLessonException.MediaIntegrityFailed()
            if (body.size != manifest.byteCount || sha256(body) != manifest.sha256.lowercase()) {
                clearActivationOnly()
                throw NativeLessonException.MediaIntegrityFailed()
            }
            writeAtomic(mediaFile(lease.partition, manifest.kind, manifest.version), body)
            writeAtomic(markerFile(lease.partition, manifest.kind, manifest.version), "ready".toByteArray())
        }
        val activation = buildString {
            append(lease.partition).append('\t').append(lease.expiresAtMicros).append('\n')
            manifests.sortedBy { it.kind.wireValue }.forEach {
                append(it.kind.wireValue).append('\t').append(it.version).append('\t')
                    .append(it.byteCount).append('\t').append(it.sha256.lowercase()).append('\n')
            }
        }
        writeAtomic(activationFile(lease.partition), activation.toByteArray(StandardCharsets.UTF_8))
    }

    fun isAvailableOffline(partition: String, asOfMicros: Long): Boolean =
        runCatching { readActivation(partition, asOfMicros) }.isSuccess

    fun recover(partition: String, asOfMicros: Long): Boolean = isAvailableOffline(partition, asOfMicros)

    fun offlineMedia(kind: MediaKind, partition: String, asOfMicros: Long): File {
        val activation = readActivation(partition, asOfMicros)
        val manifest = activation.second.singleOrNull { it.kind == kind }
            ?: throw NativeLessonException.InvalidManifest()
        val media = mediaFile(partition, kind, manifest.version)
        if (!media.isFile || media.length() != manifest.byteCount.toLong() || sha256(media.readBytes()) != manifest.sha256) {
            throw NativeLessonException.MediaIntegrityFailed()
        }
        return media
    }

    fun switchPartition(partition: String) {
        validateId(partition)
        clearAll()
    }

    fun clearForLogout() = clearAll()
    fun clearForRevocation() = clearAll()

    fun enqueue(entry: NativeReplayEntry, partition: String, asOfMicros: Long) {
        readActivation(partition, asOfMicros)
        entry.fields().forEach(::validateId)
        val existing = loadJournal().associateBy { it.journalEntryId }[entry.journalEntryId]
        if (existing != null && existing != entry) throw NativeLessonException.InvalidReplay()
        if (existing == null) appendDurable(journalFile, entry.fields().joinToString("\t") + "\n")
    }

    fun reconcile(entry: NativeReplayEntry, hostTerminal: ReplayTerminal): ReplayTerminal {
        if (!loadJournal().contains(entry)) throw NativeLessonException.InvalidReplay()
        val terminals = loadTerminals().toMutableMap()
        val existing = terminals[entry.idempotencyKey]
        if (existing != null && existing != hostTerminal) throw NativeLessonException.InvalidReplay()
        if (existing == null) appendDurable(terminalFile, "${entry.idempotencyKey}\t${hostTerminal.wireValue}\n")
        return hostTerminal
    }

    private fun readActivation(
        partition: String,
        asOfMicros: Long,
    ): Pair<NativeLessonLease, List<NativeMediaManifest>> {
        validateId(partition)
        val file = activationFile(partition)
        if (!file.isFile) throw NativeLessonException.PartitionMismatch()
        val lines = file.readLines(StandardCharsets.UTF_8)
        val header = lines.firstOrNull()?.split('\t') ?: throw NativeLessonException.InvalidManifest()
        if (header.size != 2 || header[0] != partition) throw NativeLessonException.PartitionMismatch()
        val expiresAt = header[1].toLongOrNull() ?: throw NativeLessonException.InvalidManifest()
        if (asOfMicros >= expiresAt) throw NativeLessonException.LeaseExpired()
        val manifests = lines.drop(1).map { line ->
            val values = line.split('\t')
            if (values.size != 4) throw NativeLessonException.InvalidManifest()
            val kind = MediaKind.entries.singleOrNull { it.wireValue == values[0] }
                ?: throw NativeLessonException.InvalidManifest()
            val manifest = NativeMediaManifest(
                kind,
                values[1],
                values[2].toIntOrNull() ?: throw NativeLessonException.InvalidManifest(),
                values[3],
            )
            if (!markerFile(partition, kind, manifest.version).isFile) throw NativeLessonException.InvalidManifest()
            manifest
        }
        return NativeLessonLease(partition, expiresAt) to manifests
    }

    private fun loadJournal(): List<NativeReplayEntry> = if (!journalFile.isFile) emptyList() else
        journalFile.readLines().filter(String::isNotBlank).map { line ->
            val fields = line.split('\t')
            if (fields.size != 6) throw NativeLessonException.InvalidReplay()
            NativeReplayEntry(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5])
        }

    private fun loadTerminals(): Map<String, ReplayTerminal> = if (!terminalFile.isFile) emptyMap() else
        terminalFile.readLines().filter(String::isNotBlank).associate { line ->
            val fields = line.split('\t')
            if (fields.size != 2) throw NativeLessonException.InvalidReplay()
            val terminal = ReplayTerminal.entries.singleOrNull { it.wireValue == fields[1] }
                ?: throw NativeLessonException.InvalidReplay()
            fields[0] to terminal
        }

    private fun clearActivationOnly() {
        root.listFiles()?.filter { it.name.endsWith(".activation") || it.name.endsWith(".ready") || it.name.endsWith(".media") }
            ?.forEach(File::delete)
    }

    private fun clearAll() {
        root.listFiles()?.forEach(File::delete)
    }

    private fun writeAtomic(destination: File, bytes: ByteArray) {
        val temporary = File(root, ".${destination.name}.tmp")
        temporary.outputStream().use { output ->
            output.write(bytes)
            output.flush()
            output.fd.sync()
        }
        if (!temporary.renameTo(destination)) {
            temporary.delete()
            throw IllegalStateException("could not commit app-private lesson file")
        }
    }

    private fun appendDurable(destination: File, value: String) {
        FileOutputStream(destination, true).use { output ->
            output.write(value.toByteArray(StandardCharsets.UTF_8))
            output.flush()
            output.fd.sync()
        }
    }

    private fun activationFile(partition: String) = File(root, "$partition.activation")
    private fun mediaFile(partition: String, kind: MediaKind, version: String) =
        File(root, "$partition.${kind.wireValue}.$version.media")
    private fun markerFile(partition: String, kind: MediaKind, version: String) =
        File(root, "$partition.${kind.wireValue}.$version.ready")

    private fun validateId(value: String) {
        if (!value.matches(Regex("[A-Za-z0-9._-]{1,128}"))) throw NativeLessonException.InvalidManifest()
    }

    private fun sha256(value: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(value).joinToString("") { "%02x".format(it) }

    private fun NativeReplayEntry.fields() =
        listOf(journalEntryId, clientMutationId, idempotencyKey, baseCheckpoint, action, answer)
}
