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
        if (engine != null && loadedPath == path && loadedBackend == backendName(useGpu)) {
            return mapOf("backend" to loadedBackend, "reused" to true)
        }
        unload()
        val backend = if (useGpu) Backend.GPU() else Backend.CPU()
        val config = EngineConfig(
            modelPath = path,
            backend = backend,
            cacheDir = context.cacheDir.path,
        )
        // Store the engine only after initialize() returns: closing an engine
        // whose initialize() threw raises IllegalStateException.
        val created = Engine(config)
        created.initialize()
        engine = created
        loadedPath = path
        loadedBackend = backendName(useGpu)
        return mapOf("backend" to loadedBackend, "reused" to false)
    }

    private fun backendName(useGpu: Boolean): String = if (useGpu) "gpu" else "cpu"

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
