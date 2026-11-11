// android/app/src/main/kotlin/vn/ongbi/english/CrashReporter.kt
package vn.ongbi.english

import android.app.ActivityManager
import android.annotation.TargetApi
import android.app.ApplicationExitInfo
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Keeps a readable report when the app stops unexpectedly, so a parent can
 * send it for support without a computer:
 *
 *  - Kotlin/Java crashes are caught by an uncaught-exception handler.
 *  - Native crashes, out-of-memory kills and ANRs are read on the next start
 *    from Android's ApplicationExitInfo (Android 11+).
 *  - Dart errors are kept from the Flutter side as context for the report.
 *
 * Reports stay on the phone: they are written to the app's own folder and to
 * Download/OngBiEnglish. Nothing is uploaded.
 */
object CrashReporter {
    private const val PREFS = "ongbi_crash"
    private const val KEY_LAST_EXIT = "last_exit_ts"
    private const val FOLDER = "OngBiEnglish"
    private const val MAX_TRACE_CHARS = 60_000

    @Volatile
    private var installed = false

    /** Call first thing in Activity.onCreate. */
    fun install(context: Context) {
        if (installed) return
        installed = true
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val text = buildString {
                    append(header(app, "Kotlin/Java crash"))
                    append("Thread: ").append(thread.name).append('\n')
                    append(stackTrace(error))
                }
                pendingFile(app).writeText(text)
            } catch (_: Throwable) {
                // Never let the reporter hide the original crash.
            }
            previous?.uncaughtException(thread, error)
        }
    }

    /**
     * Report of the previous unexpected stop, or null. Each stop is reported
     * once; a copy is saved to Download/OngBiEnglish. Dart errors alone do not
     * count as a stop (they are only attached as context) unless [force] is
     * set, which the start-up failure screen uses.
     */
    fun takePendingReport(context: Context, force: Boolean = false): Map<String, String>? {
        val app = context.applicationContext
        val parts = ArrayList<String>()
        val pending = pendingFile(app)
        val javaCrash = pending.exists()
        if (javaCrash) {
            parts.add(pending.readText())
            pending.delete()
        }
        exitInfoReport(app, skipJavaCrash = javaCrash)?.let { parts.add(it) }
        val dartLog = dartFile(app)
        if (parts.isEmpty() && !(force && dartLog.exists())) return null
        if (dartLog.exists()) {
            parts.add("Recent Dart errors:\n" + dartLog.readText().takeLast(MAX_TRACE_CHARS / 2))
            dartLog.delete()
        }
        val text = parts.joinToString("\n\n----------------\n\n")
        val name = "bao-loi-" + SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date()) + ".txt"
        val saved = try {
            saveToDownloads(app, name, text)
        } catch (_: Throwable) {
            val file = File(reportDir(app), name)
            file.writeText(text)
            file.path
        }
        return mapOf("text" to text, "savedTo" to saved)
    }

    /** Keeps a Dart-side error as context for the next report (rolling log). */
    fun recordDartError(context: Context, text: String) {
        val app = context.applicationContext
        val file = dartFile(app)
        val existing = if (file.exists()) file.readText() else header(app, "Dart errors")
        file.writeText((existing + "\n" + text).takeLast(MAX_TRACE_CHARS))
    }

    fun bind(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "ongbi/crash").setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            try {
                when (call.method) {
                    "takePendingReport" -> result.success(
                        takePendingReport(app, call.argument<Boolean>("force") ?: false),
                    )
                    "recordDartError" -> {
                        recordDartError(app, call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("crash_report", t.message ?: t.javaClass.simpleName, null)
            }
        }
    }

    @TargetApi(30)
    private fun exitInfoReport(app: Context, skipJavaCrash: Boolean): String? {
        if (Build.VERSION.SDK_INT < 30) return null
        val am = app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastSeen = prefs.getLong(KEY_LAST_EXIT, 0L)
        val exits = try {
            am.getHistoricalProcessExitReasons(app.packageName, 0, 5)
        } catch (_: Throwable) {
            return null
        }
        if (exits.isEmpty()) return null
        prefs.edit().putLong(KEY_LAST_EXIT, exits.maxOf { it.timestamp }).apply()
        val interesting = exits.filter {
            it.timestamp > lastSeen && isUnexpected(it) && !(skipJavaCrash && it.reason == ApplicationExitInfo.REASON_CRASH)
        }
        if (interesting.isEmpty()) return null
        return interesting.joinToString("\n\n") { info -> describe(app, info) }
    }

    /**
     * Crashes and ANRs always count. Memory or signal kills count only when
     * the app was on screen: Android routinely stops cached background apps.
     */
    @TargetApi(30)
    private fun isUnexpected(info: ApplicationExitInfo): Boolean = when (info.reason) {
        ApplicationExitInfo.REASON_CRASH,
        ApplicationExitInfo.REASON_CRASH_NATIVE,
        ApplicationExitInfo.REASON_ANR,
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE,
        -> true
        ApplicationExitInfo.REASON_LOW_MEMORY,
        ApplicationExitInfo.REASON_SIGNALED,
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
        -> info.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
        else -> false
    }

    @TargetApi(30)
    private fun describe(app: Context, info: ApplicationExitInfo): String = buildString {
        append(header(app, "Android exit: ${reasonName(info.reason)}"))
        append("When: ").append(Date(info.timestamp)).append('\n')
        append("Status/signal: ").append(info.status).append(", importance: ").append(info.importance).append('\n')
        append("Description: ").append(info.description ?: "-").append('\n')
        append("Memory: pss=").append(info.pss / 1024).append(" MB, rss=").append(info.rss / 1024).append(" MB\n")
        val trace = try {
            info.traceInputStream?.use { it.readBytes() }
        } catch (_: Throwable) {
            null
        }
        if (trace != null && trace.isNotEmpty()) {
            append("Trace:\n")
            append(readable(trace))
        }
    }

    /** ANR traces are text; native tombstones are protobuf, so keep the readable parts. */
    private fun readable(bytes: ByteArray): String {
        val out = StringBuilder()
        val run = StringBuilder()
        for (b in bytes) {
            val c = b.toInt() and 0xff
            if (c in 32..126 || c == 10 || c == 9) {
                run.append(c.toChar())
            } else {
                if (run.length >= 4) out.append(run).append('\n')
                run.setLength(0)
            }
            if (out.length > MAX_TRACE_CHARS) break
        }
        if (run.length >= 4) out.append(run)
        return out.toString().take(MAX_TRACE_CHARS)
    }

    @TargetApi(30)
    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_CRASH -> "CRASH (Kotlin/Java)"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "ANR (not responding)"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        else -> "reason $reason"
    }

    private fun header(app: Context, kind: String): String {
        val version = try {
            val info = app.packageManager.getPackageInfo(app.packageName, 0)
            "${info.versionName} (${if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else 0})"
        } catch (_: Throwable) {
            "?"
        }
        return buildString {
            append("Ong Bi English ").append(version).append(" - ").append(kind).append('\n')
            append("Device: ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
            append(", Android ").append(Build.VERSION.RELEASE).append(" (SDK ").append(Build.VERSION.SDK_INT).append(")\n")
            append("ABI: ").append(Build.SUPPORTED_ABIS.joinToString()).append('\n')
        }
    }

    private fun stackTrace(error: Throwable): String {
        val writer = StringWriter()
        error.printStackTrace(PrintWriter(writer))
        return writer.toString().take(MAX_TRACE_CHARS)
    }

    private fun reportDir(app: Context): File = File(app.filesDir, "crash").apply { mkdirs() }

    private fun pendingFile(app: Context): File = File(reportDir(app), "pending.txt")

    private fun dartFile(app: Context): File = File(reportDir(app), "dart.txt")

    private fun saveToDownloads(app: Context, name: String, text: String): String {
        val resolver = app.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/$FOLDER")
        }
        val uri = resolver.insert(MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
            ?: throw IllegalStateException("cannot create $name")
        resolver.openOutputStream(uri)?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
            ?: throw IllegalStateException("cannot open $name")
        return "Download/$FOLDER/$name"
    }
}
