// android/app/src/main/kotlin/vn/ongbi/english/FilesBridge.kt
package vn.ongbi.english

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.FilterInputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * Heavy file work that must not run on the Dart UI isolate:
 * streaming .tar.bz2 extraction, SHA-256, manual model import through the
 * system file picker, saving backups and certificates to Download, and
 * reading a backup file back. Works with scoped storage: no storage
 * permission is needed on Android 10 and later.
 *
 * Progress events: {op, tag, done, total}.
 */
class FilesBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private var pendingPick: MethodChannel.Result? = null
    private var pendingDest: String? = null
    private var pendingTag: String = ""
    private var pendingText: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "ongbi/files").setMethodCallHandler(this)
        EventChannel(messenger, "ongbi/files/progress").setStreamHandler(this)
    }

    fun dispose() {
        executor.shutdown()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "extractTarBz2" -> {
                val archive = call.argument<String>("archive")
                val destDir = call.argument<String>("destDir")
                val tag = call.argument<String>("tag") ?: ""
                if (archive == null || destDir == null) {
                    result.error("bad_args", "archive and destDir are required", null)
                    return
                }
                runAsync(result) { extractTarBz2(File(archive), File(destDir), tag) }
            }
            "sha256" -> {
                val path = call.argument<String>("path")
                val tag = call.argument<String>("tag") ?: ""
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                    return
                }
                runAsync(result) { sha256(File(path), tag) }
            }
            "pickAndImport" -> {
                val dest = call.argument<String>("dest")
                if (dest == null) {
                    result.error("bad_args", "dest is required", null)
                    return
                }
                if (pendingPick != null) {
                    result.error("busy", "another import is in progress", null)
                    return
                }
                pendingPick = result
                pendingDest = dest
                pendingTag = call.argument<String>("tag") ?: ""
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                try {
                    activity.startActivityForResult(intent, REQUEST_PICK)
                } catch (t: Throwable) {
                    pendingPick = null
                    pendingDest = null
                    result.error("no_picker", t.message, null)
                }
            }
            "saveToDownloads" -> {
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.error("bad_args", "name and bytes are required", null)
                    return
                }
                runAsync(result) { saveToDownloads(name, mime, bytes) }
            }
            "pickText" -> {
                if (pendingText != null) {
                    result.error("busy", "another pick is in progress", null)
                    return
                }
                pendingText = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                }
                try {
                    activity.startActivityForResult(intent, REQUEST_TEXT)
                } catch (t: Throwable) {
                    pendingText = null
                    result.error("no_picker", t.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_TEXT) {
            val textResult = pendingText ?: return
            pendingText = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                textResult.success(null)
                return
            }
            runAsync(textResult) { readText(uri) }
            return
        }
        if (requestCode != REQUEST_PICK) return
        val result = pendingPick ?: return
        val dest = pendingDest
        val tag = pendingTag
        pendingPick = null
        pendingDest = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || dest == null) {
            result.success(null) // user cancelled
            return
        }
        runAsync(result) { copyFromUri(uri, File(dest), tag) }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (t: Throwable) {
                main.post { result.error("io_error", t.message ?: t.javaClass.simpleName, null) }
            }
        }
    }

    private fun progress(op: String, tag: String, done: Long, total: Long) {
        main.post {
            sink?.success(mapOf("op" to op, "tag" to tag, "done" to done, "total" to total))
        }
    }

    /** Counts compressed bytes so extraction progress can be reported. */
    private class CountingInputStream(input: InputStream) : FilterInputStream(input) {
        var count: Long = 0
            private set

        override fun read(): Int {
            val b = super.read()
            if (b >= 0) count++
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            val n = super.read(b, off, len)
            if (n > 0) count += n
            return n
        }
    }

    private fun extractTarBz2(archive: File, destDir: File, tag: String): Map<String, Any?> {
        if (!archive.exists()) throw IllegalArgumentException("archive not found: ${archive.path}")
        destDir.mkdirs()
        val destRoot = destDir.canonicalPath + File.separator
        val total = archive.length()
        var files = 0
        var lastReport = 0L

        val counting = CountingInputStream(BufferedInputStream(FileInputStream(archive), 1 shl 16))
        TarArchiveInputStream(BZip2CompressorInputStream(counting)).use { tar ->
            val buffer = ByteArray(1 shl 16)
            while (true) {
                val entry = tar.nextEntry ?: break
                if (entry.isSymbolicLink || entry.isLink) continue
                val out = File(destDir, entry.name)
                // Zip-slip guard: never write outside the destination directory.
                val canonical = out.canonicalPath
                if (!(canonical + File.separator).startsWith(destRoot) && canonical != destDir.canonicalPath) {
                    throw SecurityException("blocked path traversal: ${entry.name}")
                }
                if (entry.isDirectory) {
                    out.mkdirs()
                    continue
                }
                out.parentFile?.mkdirs()
                FileOutputStream(out).use { fos ->
                    while (true) {
                        val n = tar.read(buffer)
                        if (n < 0) break
                        fos.write(buffer, 0, n)
                        if (counting.count - lastReport > PROGRESS_STEP) {
                            lastReport = counting.count
                            progress("extract", tag, counting.count, total)
                        }
                    }
                }
                files++
            }
        }
        progress("extract", tag, total, total)
        return mapOf("files" to files)
    }

    private fun sha256(file: File, tag: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val total = file.length()
        var done = 0L
        var lastReport = 0L
        FileInputStream(file).use { input ->
            val buffer = ByteArray(1 shl 20)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
                done += n
                if (done - lastReport > PROGRESS_STEP * 4) {
                    lastReport = done
                    progress("sha256", tag, done, total)
                }
            }
        }
        progress("sha256", tag, total, total)
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun copyFromUri(uri: Uri, dest: File, tag: String): Map<String, Any?> {
        val resolver = activity.contentResolver
        var name = ""
        var total = -1L
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: ""
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) total = cursor.getLong(sizeIndex)
            }
        }
        dest.parentFile?.mkdirs()
        var done = 0L
        var lastReport = 0L
        val input = resolver.openInputStream(uri) ?: throw IllegalStateException("cannot open picked file")
        input.use { stream ->
            FileOutputStream(dest).use { fos ->
                val buffer = ByteArray(1 shl 20)
                while (true) {
                    val n = stream.read(buffer)
                    if (n < 0) break
                    fos.write(buffer, 0, n)
                    done += n
                    if (done - lastReport > PROGRESS_STEP * 4) {
                        lastReport = done
                        progress("import", tag, done, total)
                    }
                }
            }
        }
        progress("import", tag, done, if (total > 0) total else done)
        return mapOf("name" to name, "bytes" to done)
    }

    /** Writes into Download/OngBiEnglish through MediaStore (no permission needed). */
    private fun saveToDownloads(name: String, mime: String, bytes: ByteArray): String {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/$DOWNLOAD_FOLDER")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values) ?: throw IllegalStateException("cannot create $name")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("cannot open $name")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (t: Throwable) {
            resolver.delete(uri, null, null)
            throw t
        }
        return "Download/$DOWNLOAD_FOLDER/$name"
    }

    private fun readText(uri: Uri): String {
        val resolver = activity.contentResolver
        val input = resolver.openInputStream(uri) ?: throw IllegalStateException("cannot open file")
        input.use { stream ->
            val bytes = stream.readBytes()
            if (bytes.size > MAX_TEXT_BYTES) throw IllegalStateException("file too large")
            return String(bytes, Charsets.UTF_8)
        }
    }

    companion object {
        private const val REQUEST_PICK = 7301
        private const val REQUEST_TEXT = 7302
        private const val DOWNLOAD_FOLDER = "OngBiEnglish"
        private const val MAX_TEXT_BYTES = 32 * 1024 * 1024
        private const val PROGRESS_STEP = 2L * 1024L * 1024L
    }
}
