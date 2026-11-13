// android/app/src/main/kotlin/vn/ongbi/english/LlmBridge.kt
package vn.ongbi.english

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.ExperimentalFlags
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.ModelInfo
import com.google.ai.edge.litertlm.SamplerConfig
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
import java.io.File
import java.util.concurrent.Executors

/**
 * Bridge to LiteRT-LM (Gemma 4 .litertlm files).
 *
 * All engine calls run on one single-thread executor, as the LiteRT-LM
 * Android guide requires. Streaming events: {id, type: chunk|done|error, text}.
 *
 * Optional engine features, each switched off for good on this phone once it
 * crashed or failed during start-up: the GPU, multi-token prediction (MTP,
 * faster replies on the GPU) and audio input (Bi hears the child directly,
 * including Vietnamese).
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
    private var audioOn = false
    private var mtpOn = false
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
                val audio = call.argument<Boolean>("audio") ?: false
                val mtp = call.argument<Boolean>("mtp") ?: false
                if (path == null) {
                    result.error("bad_args", "modelPath is required", null)
                    return
                }
                launchWithResult(result) { load(path, useGpu, audio, mtp) }
            }
            "startConversation" -> {
                val prompt = call.argument<String>("systemPrompt") ?: ""
                val examples = call.argument<List<Map<String, String>>>("examples") ?: emptyList()
                val temperature = call.argument<Double>("temperature")
                val topK = call.argument<Int>("topK")
                val topP = call.argument<Double>("topP")
                val maxOutput = call.argument<Int>("maxOutputTokens")
                launchWithResult(result) {
                    startConversation(prompt, examples, temperature, topK, topP, maxOutput)
                }
            }
            "send" -> {
                val id = call.argument<Int>("id") ?: 0
                val text = call.argument<String>("text") ?: ""
                val audioPath = call.argument<String>("audioPath")
                send(id, text, audioPath)
                result.success(null)
            }
            "cancel" -> launchWithResult(result) { cancelReply() }
            "unload" -> launchWithResult(result) { unload() }
            "status" -> result.success(status())
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

    private fun status(): Map<String, Any?> = mapOf(
        "loaded" to (engine != null),
        "modelPath" to loadedPath,
        "backend" to loadedBackend,
        "audio" to audioOn,
        "mtp" to mtpOn,
    )

    /** Engine features to try, most capable first. */
    private data class Attempt(val gpu: Boolean, val mtp: Boolean, val audio: Boolean)

    private suspend fun load(path: String, useGpu: Boolean, audio: Boolean, mtp: Boolean): Map<String, Any?> {
        recoverFromCrashedStart()
        val p = prefs()
        var audioSupported = false
        var mtpSupported = false
        try {
            ModelInfo.from(path).use { info ->
                audioSupported = info.inputModalities().audio
                mtpSupported = (info as? ModelInfo.Llm)?.hasSpeculativeDecodingSupport() == true
            }
        } catch (_: Throwable) {
            // Old runtime or unreadable metadata: plain text, no MTP.
        }
        val gpu = useGpu && !p.getBoolean(KEY_GPU_BAD, false)
        val wantAudio = audio && audioSupported && !p.getBoolean(KEY_AUDIO_BAD, false)
        val wantMtp = mtp && gpu && mtpSupported && !p.getBoolean(KEY_MTP_BAD, false)

        if (engine != null && loadedPath == path && loadedBackend == backendName(gpu) &&
            audioOn == wantAudio && mtpOn == wantMtp
        ) {
            return status() + ("reused" to true)
        }
        unload()

        val attempts = LinkedHashSet<Attempt>()
        if (gpu) {
            attempts.add(Attempt(gpu = true, mtp = wantMtp, audio = wantAudio))
            attempts.add(Attempt(gpu = true, mtp = false, audio = wantAudio))
            attempts.add(Attempt(gpu = true, mtp = false, audio = false))
        }
        attempts.add(Attempt(gpu = false, mtp = false, audio = wantAudio))
        attempts.add(Attempt(gpu = false, mtp = false, audio = false))

        var last: Throwable? = null
        var audioFailed = false
        for (attempt in attempts) {
            try {
                val started = createEngine(path, attempt)
                if (audioFailed && !attempt.audio) {
                    markBad(KEY_AUDIO_BAD)
                }
                return started
            } catch (t: Throwable) {
                last = t
                // Remember what failed so the next start skips it.
                when {
                    attempt.mtp -> markBad(KEY_MTP_BAD)
                    attempt.audio -> audioFailed = true
                    attempt.gpu -> markBad(KEY_GPU_BAD)
                }
            }
        }
        throw last ?: IllegalStateException("model could not start")
    }

    @OptIn(ExperimentalApi::class)
    private fun createEngine(path: String, attempt: Attempt): Map<String, Any?> {
        val config = EngineConfig(
            modelPath = path,
            backend = if (attempt.gpu) Backend.GPU() else Backend.CPU(),
            audioBackend = if (attempt.audio) Backend.CPU() else null,
            maxNumTokens = MAX_TOKENS,
            cacheDir = context.cacheDir.path,
        )
        // A driver can kill the whole process during initialize(). The marker
        // survives that, so the next start drops the riskiest feature.
        prefs().edit().putString(KEY_PENDING, attemptName(attempt)).commit()
        try {
            ExperimentalFlags.enableSpeculativeDecoding = attempt.mtp
            // Store the engine only after initialize() returns: closing an
            // engine whose initialize() threw raises IllegalStateException.
            val created = Engine(config)
            created.initialize()
            engine = created
        } finally {
            ExperimentalFlags.enableSpeculativeDecoding = null
            prefs().edit().remove(KEY_PENDING).commit()
        }
        loadedPath = path
        loadedBackend = backendName(attempt.gpu)
        audioOn = attempt.audio
        mtpOn = attempt.mtp
        return status() + ("reused" to false)
    }

    private fun attemptName(a: Attempt): String =
        listOfNotNull(if (a.gpu) "gpu" else null, if (a.mtp) "mtp" else null, if (a.audio) "audio" else null)
            .joinToString(",")

    /** The process died during the last start: switch off what it tried. */
    private fun recoverFromCrashedStart() {
        val pending = prefs().getString(KEY_PENDING, null) ?: return
        val tried = pending.split(",").toSet()
        when {
            "mtp" in tried -> markBad(KEY_MTP_BAD)
            "audio" in tried -> markBad(KEY_AUDIO_BAD)
            "gpu" in tried -> markBad(KEY_GPU_BAD)
        }
        prefs().edit().remove(KEY_PENDING).commit()
    }

    private fun prefs() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun markBad(key: String) {
        prefs().edit().putBoolean(key, true).commit()
    }

    private fun backendName(useGpu: Boolean): String = if (useGpu) "gpu" else "cpu"

    private companion object {
        const val PREFS = "ongbi_llm"
        const val KEY_PENDING = "init_pending"
        const val KEY_GPU_BAD = "gpu_bad"
        const val KEY_MTP_BAD = "mtp_bad"
        const val KEY_AUDIO_BAD = "audio_bad"

        /** KV cache size; the chat restarts its conversation before this fills. */
        const val MAX_TOKENS = 4096
    }

    private suspend fun startConversation(
        systemPrompt: String,
        examples: List<Map<String, String>>,
        temperature: Double?,
        topK: Int?,
        topP: Double?,
        maxOutput: Int?,
    ): Boolean {
        val current = engine ?: throw IllegalStateException("model not loaded")
        cancelReply()
        conversation?.let {
            try {
                it.close()
            } catch (_: Throwable) {
            }
        }
        val history = mutableListOf<Message>()
        for (example in examples) {
            val user = example["user"] ?: continue
            val model = example["model"] ?: continue
            history.add(Message.user(user))
            history.add(Message.model(Contents.of(model)))
        }
        val sampler = if (temperature != null && topK != null && topP != null) {
            SamplerConfig(topK = topK, topP = topP, temperature = temperature, seed = (System.nanoTime() and 0x7fffffff).toInt())
        } else {
            null
        }
        conversation = current.createConversation(
            ConversationConfig(
                systemInstruction = Contents.of(systemPrompt),
                initialMessages = history,
                samplerConfig = sampler,
                maxOutputToken = maxOutput,
                // Process the long instructions now, while Bi says hello.
                prefillPrefaceOnInit = true,
            ),
        )
        return true
    }

    private fun send(id: Int, text: String, audioPath: String?) {
        replyJob = scope.launch {
            val active = conversation
            if (active == null) {
                emit(id, "error", "conversation not started")
                return@launch
            }
            try {
                val parts = mutableListOf<Content>()
                if (audioOn && audioPath != null && File(audioPath).isFile) {
                    parts.add(Content.AudioFile(audioPath))
                }
                parts.add(Content.Text(text))
                active.sendMessageAsync(Contents.of(parts)).collect { message ->
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
        audioOn = false
        mtpOn = false
        return true
    }
}
