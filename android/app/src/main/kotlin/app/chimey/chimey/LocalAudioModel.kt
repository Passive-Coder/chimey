package app.chimey.chimey

import android.app.ActivityManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.StatFs
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import java.io.File
import java.util.concurrent.Executors

/** Native worker serializes model import/load/inference/unload away from capture. */
object LocalAudioModel {
    private val worker=Executors.newSingleThreadExecutor()
    private var engine:Engine?=null
    @Volatile var state="not_loaded"
        private set
    private var failure:String?=null
    fun status(context:Context):Map<String,Any?> {
        val info=ActivityManager.MemoryInfo();context.getSystemService(ActivityManager::class.java).getMemoryInfo(info)
        return mapOf("state" to state,"error" to failure,"installed" to File(context.filesDir,"audio-model.litertlm").isFile,"totalMemory" to info.totalMem,"availableMemory" to info.availMem,"abis" to Build.SUPPORTED_ABIS.toList())
    }
    fun import(context:Context,uri:Uri,reply:(Result<Unit>)->Unit) = worker.execute {
        update("importing")
        val file=File(context.filesDir,"audio-model.pending")
        try {
            engine?.close();engine=null
            val maximum=8L*1024*1024*1024;var written=0L
            context.contentResolver.openInputStream(uri).use { input ->
                require(input!=null) {"Cannot read the selected model"}
                file.outputStream().use { out ->
                    val bytes=ByteArray(1024*1024)
                    while(true) {
                        val n=input.read(bytes);if(n<0) break
                        written+=n;require(written<=maximum) {"Model exceeds the supported import size"}
                        require(StatFs(context.filesDir.path).availableBytes>n+256L*1024*1024) {"Not enough free storage"}
                        out.write(bytes,0,n)
                    }
                }
            }
            require(written>1024*1024) {"Choose a complete audio-enabled .litertlm model"}
            val target=File(context.filesDir,"audio-model.litertlm")
            require(file.renameTo(target)) {"Could not install model"}
            update("not_loaded");reply(Result.success(Unit))
        } catch(t:Throwable) {file.delete();fail(t);reply(Result.failure(t))}
    }
    fun load(context:Context,reply:(Result<Unit>)->Unit) = worker.execute {
        if(engine!=null) {reply(Result.success(Unit));return@execute}
        update("loading")
        var candidate:Engine?=null
        try {
            require(Build.SUPPORTED_64_BIT_ABIS.isNotEmpty()) {"This audio model needs a 64-bit device"}
            val info=ActivityManager.MemoryInfo();context.getSystemService(ActivityManager::class.java).getMemoryInfo(info)
            require(!info.lowMemory && info.availMem>1536L*1024*1024) {"Not enough available memory to load the audio model"}
            val file=File(context.filesDir,"audio-model.litertlm");require(file.isFile) {"Import an audio-enabled Gemma 3n E2B .litertlm model first"}
            candidate=Engine(EngineConfig(modelPath=file.absolutePath,backend=Backend.CPU(),audioBackend=Backend.CPU(),cacheDir=context.cacheDir.path,maxNumTokens=2048))
            candidate.initialize();engine=candidate;update("ready");reply(Result.success(Unit))
        } catch(t:Throwable) {try{candidate?.close()}catch(_:Throwable){};fail(t);reply(Result.failure(t))}
    }
    fun describe(wav:ByteArray,reply:(Result<String>)->Unit) = worker.execute {
        try {
            val loaded=engine ?: error("Load the audio model first")
            update("analyzing")
            val answer=loaded.createConversation().use { conversation ->
                conversation.sendMessage(Contents.of(Content.AudioBytes(wav),Content.Text("Describe the environmental sounds in this recording. Separate audible evidence from possible sources. Offer two plausible alternatives where uncertain. Do not identify a specific appliance or assert that a task is finished from a generic beep. Say unknown if unclear. Keep the answer under 120 words."))).toString()
            }
            require(answer.isNotBlank()) {"The audio model returned no explanation"}
            update("ready");reply(Result.success(answer))
        } catch(t:Throwable) {failure=t.message;update(if(engine!=null) "ready" else "error");reply(Result.failure(t))}
    }
    fun unload(reply:(Result<Unit>)->Unit) = worker.execute {
        try{engine?.close();engine=null;update("not_loaded");reply(Result.success(Unit))}
        catch(t:Throwable){fail(t);reply(Result.failure(t))}
    }
    private fun update(value:String) {state=value; if(value!="error") failure=null;RuntimeBridge.emit(mapOf("type" to "model","state" to state,"error" to failure))}
    private fun fail(t:Throwable) {failure=t.message ?: t.javaClass.simpleName;state="error";RuntimeBridge.emit(mapOf("type" to "model","state" to state,"error" to failure))}
}
