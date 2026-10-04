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
    override fun configureFlutterEngine(engine:FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger,"chimey/runtime/events").setStreamHandler(object:EventChannel.StreamHandler {
            override fun onListen(arguments:Any?,events:EventChannel.EventSink) { RuntimeBridge.sink=events; RuntimeBridge.emit(mapOf("type" to "status","state" to RuntimeBridge.state)) }
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
                        if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),71)
                        result.success(null)
                    }
                    "stop" -> { stopService(Intent(this,ListeningService::class.java)); result.success(null) }
                    "profiles" -> {
                        val text=call.arguments as String; val profiles=JSONArray(text); require(profiles.length()<=100)
                        check(getSharedPreferences("chimey.runtime",MODE_PRIVATE).edit().putString("profiles",profiles.toString()).commit())
                        result.success(null)
                    }
                    "events" -> result.success(getSharedPreferences("chimey.runtime",MODE_PRIVATE).getString("events","[]"))
                    else -> result.notImplemented()
                }
            } catch(e:Exception) { result.error("runtime",e.message,null) }
        }
    }
    private fun startListening(result:MethodChannel.Result) {
        try { startForegroundService(Intent(this,ListeningService::class.java)); result.success(null) }
        catch(e:Exception) { result.error("start",e.message,null) }
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==70) {
            val result=pending; pending=null
            if(result!=null) {
                if(grantResults.isNotEmpty() && grantResults[0]==PackageManager.PERMISSION_GRANTED) startListening(result)
                else result.error("permission","Microphone permission is required",null)
            }
        }
    }
    override fun onDestroy() { pending?.error("cancelled","Activity closed during permission request",null); pending=null; super.onDestroy() }
}
