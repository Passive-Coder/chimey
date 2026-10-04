package app.chimey.chimey

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object RuntimeBridge {
    val sessions=SessionAuthority()
    @Volatile var state="stopped"
    @Volatile var sink: EventChannel.EventSink?=null
    private val main=Handler(Looper.getMainLooper())
    fun emitFor(lease:SessionAuthority.Lease,value:Map<String,Any?>) { main.post { if(sessions.current===lease) sink?.success(value) } }
    fun status(lease:SessionAuthority.Lease,value:String,error:String?=null) {
        synchronized(sessions) { if(sessions.current!==lease) return; state=value; emitFor(lease,mapOf("type" to "status","state" to value,"error" to error)) }
    }
    fun emit(value:Map<String,Any?>) { main.post { sink?.success(value) } }
}
