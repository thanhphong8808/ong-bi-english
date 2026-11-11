// android/app/src/main/kotlin/vn/ongbi/english/ReminderReceiver.kt
package vn.ongbi.english

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Shows the daily reminder, and re-arms it after a reboot. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REMIND -> Reminders.show(context)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminders.schedule(context)
        }
    }

    companion object {
        const val ACTION_REMIND = "vn.ongbi.english.REMIND"
    }
}
