// android/app/src/main/kotlin/vn/ongbi/english/LlmBridge.kt
package vn.ongbi.english

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

/**
 * Bridge to LiteRT-LM (Gemma 4 .litertlm files).
 *
 * All engine calls run on one single-thread executor, as the LiteRT-LM
 * Android guide requires. Streaming events: {id, type: chunk|done|error, text}.
 */
class LlmBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val scope = CoroutineScope(SupervisorJob() + executor.asCoroutineDispatcher())
    private val main = Handler(Looper.getMainLooper())

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var loadedPath: String? = null
    private var loadedBackend: String? = null
    private var replyJob: Job? = null
    private var sink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "ongbi/llm").setMethodCallHandler(this)
        EventChannel(messenger, "ongbi/llm/stream").setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val path = call.argument<String>("modelPath")
                val useGpu = call.argument<Boolean>("useGpu") ?: false
                if (path == null) {
                    result.error("bad_args", "modelPath is required", null)
                    return
                }
                launchWithResult(result) { load(path, useGpu) }
            }
            "startConversation" -> {
                val prompt = call.argument<String>("systemPrompt") ?: ""
                launchWithResult(result) { startConversation(prompt) }
            }
            "send" -> {
                val id = call.argument<Int>("id") ?: 0
                val text = call.argument<String>("text") ?: ""
                send(id, text)
                result.success(null)
            }
            "cancel" -> launchWithResult(result) { cancelReply() }
            "unload" -> launchWithResult(result) { unload() }
            "status" -> result.success(
                mapOf(
                    "loaded" to (engine != null),
                    "modelPath" to loadedPath,
                    "backend" to loadedBackend,
                ),
            )
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        scope.launch {
            try {
                unload()
            } catch (_: Throwable) {
            }
            scope.cancel()
            executor.shutdown()
        }
    }

    private fun launchWithResult(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (t: Throwable) {
                main.post { result.error("llm_error", t.message ?: t.javaClass.simpleName, null) }
            }
        }
    }

    private fun emit(id: Int, type: String, text: String) {
        main.post { sink?.success(mapOf("id" to id, "type" to type, "text" to text)) }
    }

    private suspend fun load(path: String, useGpu: Boolean): Map<String, Any?> {
        val gpu = useGpu && gpuAllowed()
        if (engine != null && loadedPath == path && loadedBackend == backendName(gpu)) {
            return mapOf("backend" to loadedBackend, "reused" to true)
        }
        unload()
        if (gpu) {
            try {
                return createEngine(path, gpu = true)
            } catch (_: Throwable) {
                // The GPU driver refused the model: remember it and use the CPU.
                markGpuBad()
            }
        }
        return createEngine(path, gpu = false)
    }

    private fun createEngine(path: String, gpu: Boolean): Map<String, Any?> {
        val config = EngineConfig(
            modelPath = path,
            backend = if (gpu) Backend.GPU() else Backend.CPU(),
            cacheDir = context.cacheDir.path,
        )
        // A GPU driver can kill the whole process during initialize(). The
        // marker survives that, so the next start goes straight to the CPU.
        if (gpu) prefs().edit().putBoolean(KEY_GPU_PENDING, true).commit()
        try {
            // Store the engine only after initialize() returns: closing an engine
            // whose initialize() threw raises IllegalStateException.
            val created = Engine(config)
            created.initialize()
            engine = created
        } finally {
            if (gpu) prefs().edit().putBoolean(KEY_GPU_PENDING, false).commit()
        }
        loadedPath = path
        loadedBackend = backendName(gpu)
        return mapOf("backend" to loadedBackend, "reused" to false)
    }

    private fun prefs() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** False once a GPU start failed, or the process died during one. */
    private fun gpuAllowed(): Boolean {
        val p = prefs()
        if (p.getBoolean(KEY_GPU_PENDING, false)) {
            markGpuBad()
        }
        return !p.getBoolean(KEY_GPU_BAD, false)
    }

    private fun markGpuBad() {
        prefs().edit().putBoolean(KEY_GPU_BAD, true).putBoolean(KEY_GPU_PENDING, false).commit()
    }

    private fun backendName(useGpu: Boolean): String = if (useGpu) "gpu" else "cpu"

    private companion object {
        const val PREFS = "ongbi_llm"
        const val KEY_GPU_PENDING = "gpu_init_pending"
        const val KEY_GPU_BAD = "gpu_bad"
    }

    private suspend fun startConversation(systemPrompt: String): Boolean {
        val current = engine ?: throw IllegalStateException("model not loaded")
        cancelReply()
        conversation?.let {
            try {
                it.close()
            } catch (_: Throwable) {
            }
        }
        conversation = current.createConversation(
            ConversationConfig(systemInstruction = Contents.of(systemPrompt)),
        )
        return true
    }

    private fun send(id: Int, text: String) {
        replyJob = scope.launch {
            val active = conversation
            if (active == null) {
                emit(id, "error", "conversation not started")
                return@launch
            }
            try {
                active.sendMessageAsync(text).collect { message ->
                    emit(id, "chunk", message.toString())
                }
                emit(id, "done", "")
            } catch (c: CancellationException) {
                emit(id, "done", "")
                throw c
            } catch (t: Throwable) {
                emit(id, "error", t.message ?: t.javaClass.simpleName)
            }
        }
    }

    private suspend fun cancelReply(): Boolean {
        val job = replyJob
        if (job != null && job.isActive) {
            try {
                conversation?.cancelProcess()
            } catch (_: Throwable) {
            }
            job.cancel()
            try {
                job.join()
            } catch (_: Throwable) {
            }
        }
        replyJob = null
        return true
    }

    private suspend fun unload(): Boolean {
        cancelReply()
        conversation?.let {
            try {
                it.close()
            } catch (_: Throwable) {
            }
        }
        conversation = null
        engine?.let {
            try {
                it.close()
            } catch (_: Throwable) {
            }
        }
        engine = null
        loadedPath = null
        loadedBackend = null
        return true
    }
}
