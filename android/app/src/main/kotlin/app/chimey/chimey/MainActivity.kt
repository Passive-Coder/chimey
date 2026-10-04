package app.chimey.chimey

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private var pending:MethodChannel.Result?=null
    private var notificationRequest:MethodChannel.Result?=null
    private var modelPicker:MethodChannel.Result?=null
    override fun configureFlutterEngine(engine:FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger,"chimey/runtime/events").setStreamHandler(object:EventChannel.StreamHandler {
            override fun onListen(arguments:Any?,events:EventChannel.EventSink) { RuntimeBridge.sink=events; RuntimeBridge.emit(mapOf("type" to "status","state" to RuntimeBridge.state,"snapshot" to true)) }
            override fun onCancel(arguments:Any?) { RuntimeBridge.sink=null }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger,"chimey/runtime").setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "capabilities" -> result.success(mapOf("recognition" to true,"background" to true,"featureModel" to "yamnet-embedding-v1","state" to RuntimeBridge.state,"spatial" to false))
                    "start" -> {
                        if(pending!=null) result.error("busy","Permission request is pending",null)
                        else if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED) startListening(result)
                        else { pending=result; requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),70) }
                    }
                    "notifications" -> {
                        if(notificationRequest!=null) result.error("busy","Notification permission request pending",null)
                        else if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) { notificationRequest=result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),71) }
                        else result.success(true)
                    }
                    "stop" -> {
                        val session=RuntimeBridge.sessions.current
                        if(session!=null) RuntimeBridge.sessions.cancel(session)
                        stopService(Intent(this,ListeningService::class.java))
                        if(session==null) result.success(null) else {
                            val replied=java.util.concurrent.atomic.AtomicBoolean(false)
                            session.stopped.whenComplete { _,_ -> runOnUiThread { if(replied.compareAndSet(false,true)) result.success(null) } }
                            android.os.Handler(mainLooper).postDelayed({ if(replied.compareAndSet(false,true)) result.error("stop","Capture is still shutting down",null) },10000)
                        }
                    }
                    "profiles" -> {
                        val text=call.arguments as String; val profiles=JSONArray(text); require(profiles.length()<=100)
                        check(getSharedPreferences("chimey.runtime",MODE_PRIVATE).edit().putString("profiles",profiles.toString()).commit())
                        result.success(null)
                    }
                    "clip" -> result.success(RecentAudio.wav())
                    "modelStatus" -> result.success(LocalAudioModel.status(applicationContext))
                    "pickModel" -> {
                        check(modelPicker==null) {"A file selection is pending"}
                        modelPicker=result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE),72)
                    }
                    "loadModel" -> LocalAudioModel.load(applicationContext) { deliver(result,it.map { true }) }
                    "unloadModel" -> LocalAudioModel.unload { deliver(result,it.map { true }) }
                    "explain" -> LocalAudioModel.describe(RecentAudio.wav()) { deliver(result,it) }
                    "events" -> result.success(getSharedPreferences("chimey.runtime",MODE_PRIVATE).getString("events","[]"))
                    else -> result.notImplemented()
                }
            } catch(e:Exception) { result.error("runtime",e.message,null) }
        }
    }
    private fun <T> deliver(reply:MethodChannel.Result,value:Result<T>) {
        runOnUiThread {value.fold({reply.success(it)},{reply.error("model",it.message,null)})}
    }
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode==72) {
            val reply=modelPicker;modelPicker=null
            if(reply!=null) {
                val uri=data?.data
                if(resultCode==RESULT_OK && uri!=null) LocalAudioModel.import(applicationContext,uri) {deliver(reply,it.map{true})}
                else reply.success(false)
            }
        }
    }
    private fun startListening(result:MethodChannel.Result) {
        try { startForegroundService(Intent(this,ListeningService::class.java)); result.success(null) }
        catch(e:Exception) { result.error("start",e.message,null) }
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==71) {
            notificationRequest?.success(grantResults.isNotEmpty() && grantResults[0]==PackageManager.PERMISSION_GRANTED); notificationRequest=null
        }
        if(requestCode==70) {
            val result=pending; pending=null
            if(result!=null) {
                if(grantResults.isNotEmpty() && grantResults[0]==PackageManager.PERMISSION_GRANTED) startListening(result)
                else result.error("permission","Microphone permission is required",null)
            }
        }
    }
    override fun onDestroy() { notificationRequest?.error("cancelled","Activity closed during notification permission request",null);notificationRequest=null; pending?.error("cancelled","Activity closed during permission request",null); pending=null; modelPicker?.error("cancelled","Activity closed during model selection",null); modelPicker=null; super.onDestroy() }
}
