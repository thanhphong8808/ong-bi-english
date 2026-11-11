// android/app/src/main/kotlin/vn/ongbi/english/OngBiApplication.kt
package vn.ongbi.english

import android.app.Application
import android.content.Context

/**
 * Installs the crash reporter before anything else runs in the process,
 * including library content providers (ML Kit, WorkManager), so a crash
 * during process start-up is reported too.
 */
class OngBiApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        CrashReporter.install(this)
    }
}
