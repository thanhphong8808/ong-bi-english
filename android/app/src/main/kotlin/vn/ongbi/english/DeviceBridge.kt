// android/app/src/main/kotlin/vn/ongbi/english/DeviceBridge.kt
package vn.ongbi.english

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Read-only hardware and connectivity facts used by DeviceProfile on the Dart side. */
class DeviceBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    init {
        MethodChannel(messenger, "ongbi/device").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceInfo" -> result.success(deviceInfo())
            "isUnmeteredNetwork" -> result.success(isUnmeteredNetwork())
            "freeBytes" -> {
                val path = call.argument<String>("path") ?: context.filesDir.path
                result.success(freeBytes(path))
            }
            else -> result.notImplemented()
        }
    }

    private fun deviceInfo(): Map<String, Any?> {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memory)

        val socManufacturer = if (Build.VERSION.SDK_INT >= 31) Build.SOC_MANUFACTURER else ""
        val socModel = if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else ""

        return mapOf(
            "totalRamMb" to (memory.totalMem / (1024L * 1024L)).toInt(),
            "availRamMb" to (memory.availMem / (1024L * 1024L)).toInt(),
            "lowRamDevice" to activityManager.isLowRamDevice,
            "socManufacturer" to socManufacturer,
            "socModel" to socModel,
            "hardware" to Build.HARDWARE,
            "board" to Build.BOARD,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "cpuCores" to Runtime.getRuntime().availableProcessors(),
            "cpuMaxFreqsKhz" to cpuMaxFrequencies(),
            "hasOpenCl" to hasOpenCl(),
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
        )
    }

    /** Max frequency per core, used to count "big" cores for thread selection. */
    private fun cpuMaxFrequencies(): List<Int> {
        val out = ArrayList<Int>()
        val cores = Runtime.getRuntime().availableProcessors()
        for (i in 0 until cores) {
            val file = File("/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq")
            val value = try {
                file.readText().trim().toInt()
            } catch (_: Throwable) {
                0
            }
            out.add(value)
        }
        return out
    }

    /** Heuristic: the LiteRT-LM GPU backend needs a vendor OpenCL library. */
    private fun hasOpenCl(): Boolean {
        val candidates = listOf(
            "/vendor/lib64/libOpenCL.so",
            "/system/vendor/lib64/libOpenCL.so",
            "/system/lib64/libOpenCL.so",
            "/vendor/lib64/egl/libGLES_mali.so",
            "/vendor/lib64/libOpenCL-pixel.so",
        )
        return candidates.any {
            try {
                File(it).exists()
            } catch (_: Throwable) {
                false
            }
        }
    }

    /** True on Wi-Fi or Ethernet. Model downloads are refused on mobile data. */
    private fun isUnmeteredNetwork(): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return false
        val caps = manager.getNetworkCapabilities(network) ?: return false
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }

    private fun freeBytes(path: String): Long {
        return try {
            StatFs(path).availableBytes
        } catch (_: Throwable) {
            -1L
        }
    }
}
