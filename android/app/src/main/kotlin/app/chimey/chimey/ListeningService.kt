package app.chimey.chimey

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.*
import android.os.*
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.sqrt

class ListeningService : Service() {
    private val executor=Executors.newSingleThreadExecutor()
    private val network=Executors.newSingleThreadExecutor()
    @Volatile private var running=false
    private var recorder: AudioRecord?=null
    private val prefs by lazy { getSharedPreferences("chimey.runtime", MODE_PRIVATE) }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if(intent?.action=="stop") { stopSelf(); return START_NOT_STICKY }
        if(running) return START_NOT_STICKY
        val manager=getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("listening","Listening status",NotificationManager.IMPORTANCE_LOW))
        manager.createNotificationChannel(NotificationChannel("sounds","Recognized sounds",NotificationManager.IMPORTANCE_DEFAULT).apply { enableVibration(false) })
        val open=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE)
        val stop=PendingIntent.getService(this,1,Intent(this,ListeningService::class.java).setAction("stop"),PendingIntent.FLAG_IMMUTABLE)
        val notification=Notification.Builder(this,"listening").setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle("chimey is listening").setContentText("Sound recognition stays on this device").setContentIntent(open).setOngoing(true).addAction(Notification.Action.Builder(null,"Stop",stop).build()).build()
        try { startForeground(101,notification); running=true; emitStatus("starting"); executor.execute { capture() } }
        catch(e:Exception) { emitStatus("error",e.message ?: "Unable to start listening"); stopSelf() }
        return START_NOT_STICKY
    }
    private fun capture() {
        var model: Yamnet?=null
        try {
            model=Yamnet(this)
            val minimum=AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)
            check(minimum>0) { "16 kHz mono capture is unavailable" }
            val audio=AudioRecord(MediaRecorder.AudioSource.UNPROCESSED,16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,maxOf(minimum*2,31200))
            recorder=audio; check(audio.state==AudioRecord.STATE_INITIALIZED)
            audio.startRecording(); check(audio.recordingState==AudioRecord.RECORDSTATE_RECORDING)
            emitStatus("listening")
            val window=ShortArray(15600); val block=ShortArray(1920)
            var filled=0; var sinceInference=0
            while(running) {
                val count=audio.read(block,0,block.size)
                check(count>0) { "Microphone interrupted ($count)" }
                val bytes=ByteArray(count*2)
                for(i in 0 until count) { bytes[i*2]=block[i].toByte(); bytes[i*2+1]=(block[i].toInt() shr 8).toByte() }
                RuntimeBridge.emit(mapOf("type" to "pcm","bytes" to bytes))
                for(i in 0 until count) {
                    window[filled++]=block[i]; sinceInference++
                    if(filled==window.size) {
                        if(sinceInference>=7680) {
                            val rms=sqrt(window.sumOf{ val v=it/32768.0; v*v }/window.size)
                            val frame=model.infer(window)
                            // A relative noise floor avoids enrolling silent YAMNet bias vectors.
                            RuntimeBridge.emit(mapOf("type" to "features","features" to frame.features,"label" to frame.label,"score" to frame.score,"elapsedMs" to frame.elapsedMs,"rms" to rms,"featureModel" to "yamnet-embedding-v1"))
                            if(rms>.003) recognize(frame)
                            sinceInference=0
                        }
                        window.copyInto(window,0,7680,window.size); filled=window.size-7680
                    }
                }
            }
        } catch(e:Exception) { if(running) emitStatus("error",e.message ?: "Microphone interrupted") }
        finally {
            running=false
            try { recorder?.stop() } catch(_:Exception) {}
            recorder?.release(); recorder=null; model?.close()
            emitStatus("stopped"); stopSelf()
        }
    }
    private fun recognize(frame: Yamnet.Frame) {
        val profiles=JSONArray(prefs.getString("profiles","[]"))
        val match=Recognition.match(frame.features,profiles)
        val kind=if(match!=null) "personal" else if(frame.score>=.6) "category" else "unknown"
        val label=match?.let{profiles.getJSONObject(it.first).getString("name")} ?: if(kind=="category") frame.label else "Unknown / mixed sound"
        RuntimeBridge.emit(mapOf("type" to "recognition","kind" to kind,"label" to label,"score" to (match?.second ?: frame.score)))
        if(match==null) return
        val p=profiles.getJSONObject(match.first); val id=p.getString("id"); val rule=p.getJSONObject("rule")
        val now=System.currentTimeMillis(); val last=prefs.getLong("action.$id",0)
        if(now-last<rule.getInt("cooldownSeconds")*1000L) return
        // Persist before delivering to prevent repeated actions after process death.
        check(prefs.edit().putLong("action.$id",now).commit())
        val deliveries=mutableListOf<String>()
        if(rule.optBoolean("notification")) {
            if(Build.VERSION.SDK_INT<33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) {
                val n=Notification.Builder(this,"sounds").setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle(label).setContentText("Personal sound match · chimey").setAutoCancel(true).setContentIntent(PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE)).build()
                getSystemService(NotificationManager::class.java).notify(id.hashCode(),n); deliveries.add("Notification requested")
            } else deliveries.add("Notification permission unavailable")
        }
        if(rule.optBoolean("vibration")) {
            val vibrator=if(Build.VERSION.SDK_INT>=31) getSystemService(VibratorManager::class.java).defaultVibrator else getSystemService(Vibrator::class.java)
            val pattern=rule.getJSONArray("pattern"); val timings=LongArray(pattern.length()){pattern.getLong(it)}
            if(vibrator.hasVibrator() && timings.isNotEmpty() && timings.all{it in 0..5000} && timings.sum()<=10000) { vibrator.vibrate(VibrationEffect.createWaveform(timings,-1)); deliveries.add("Vibration requested") }
            else deliveries.add("Vibration unavailable")
        }
        val event=JSONObject().put("id","$now-$id").put("label",label).put("kind",kind).put("time",java.time.Instant.ofEpochMilli(now).toString()).put("score",match.second).put("soundId",id).put("delivery",deliveries.joinToString(" · ").ifEmpty{"No action"})
        val endpoint=rule.optString("ledEndpoint","")
        if(endpoint.isNotEmpty() && endpoint!="null") network.execute {
            val status=try {
                val url=URL(endpoint); require(url.protocol=="http" || url.protocol=="https"); require(url.userInfo==null)
                val connection=url.openConnection() as HttpURLConnection
                try { connection.connectTimeout=4000; connection.readTimeout=4000; connection.requestMethod="POST"; connection.doOutput=true; connection.setRequestProperty("Content-Type","application/json"); connection.outputStream.use{it.write(JSONObject().put("soundId",id).put("name",label).put("on",true).toString().toByteArray())}; if(connection.responseCode in 200..299) "LED acknowledged" else "LED rejected (${connection.responseCode})" }
                finally { connection.disconnect() }
            } catch(e:Exception) { "LED unavailable" }
            RuntimeBridge.emit(mapOf("type" to "delivery","soundId" to id,"delivery" to status))
        }
        synchronized(RuntimeBridge) {
            val old=JSONArray(prefs.getString("events","[]")); val next=JSONArray().put(event)
            for(i in 0 until minOf(old.length(),199)) next.put(old.getJSONObject(i))
            prefs.edit().putString("events",next.toString()).commit()
        }
        RuntimeBridge.emit(mapOf("type" to "event","event" to event.toString()))
    }
    private fun emitStatus(state:String,error:String?=null) { RuntimeBridge.state=state; RuntimeBridge.emit(mapOf("type" to "status","state" to state,"error" to error)) }
    override fun onDestroy() {
        running=false; try { recorder?.stop() } catch(_:Exception) {}
        executor.shutdown(); network.shutdown(); super.onDestroy()
    }
}
