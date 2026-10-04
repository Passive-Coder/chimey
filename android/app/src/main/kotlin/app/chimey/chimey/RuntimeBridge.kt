package app.chimey.chimey

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object RuntimeBridge {
    @Volatile var state="stopped"
    @Volatile var sink: EventChannel.EventSink?=null
    private val main=Handler(Looper.getMainLooper())
    fun emit(value:Map<String,Any?>) { main.post { sink?.success(value) } }
}
