package app.chimey.chimey

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executor

/** Matching, durable cooldowns and real actions shared by live capture and qualification. */
class SoundRecognition(
    private val context: Context,
    private val prefs: SharedPreferences,
    private val network: Executor,
) {
    init {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel("sounds", "Recognized sounds", NotificationManager.IMPORTANCE_DEFAULT).apply { enableVibration(false) }
        )
    }
    fun process(frame: Yamnet.Frame, emit: (Map<String, Any?>) -> Unit) {
        val profiles=JSONArray(prefs.getString("profiles","[]"))
        val match=Recognition.match(frame.features,profiles)
        val kind=if(match!=null) "personal" else if(frame.score>=.6) "category" else "unknown"
        val label=match?.let{profiles.getJSONObject(it.first).getString("name")} ?: if(kind=="category") frame.label else "Unknown / mixed sound"
        emit(mapOf("type" to "recognition","kind" to kind,"label" to label,"score" to (match?.second ?: frame.score)))
        if(match==null) return
        val p=profiles.getJSONObject(match.first); val id=p.getString("id"); val rule=p.getJSONObject("rule")
        val now=System.currentTimeMillis(); val last=prefs.getLong("action.$id",0)
        if(now-last<rule.getInt("cooldownSeconds")*1000L) return
        // Persist before delivering to prevent repeated actions after process death.
        check(prefs.edit().putLong("action.$id",now).commit())
        val deliveries=mutableListOf<String>()
        if(rule.optBoolean("notification")) {
            if(Build.VERSION.SDK_INT<33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) {
                val n=Notification.Builder(context,"sounds").setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle(label).setContentText("Personal sound match · chimey").setAutoCancel(true).setContentIntent(PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE)).build()
                context.getSystemService(NotificationManager::class.java).notify(id.hashCode(),n); deliveries.add("Notification requested")
            } else deliveries.add("Notification permission unavailable")
        }
        if(rule.optBoolean("vibration")) {
            val vibrator=if(Build.VERSION.SDK_INT>=31) context.getSystemService(VibratorManager::class.java).defaultVibrator else context.getSystemService(Vibrator::class.java)
            val pattern=rule.getJSONArray("pattern"); val timings=LongArray(pattern.length()){pattern.getLong(it)}
            if(vibrator.hasVibrator() && timings.isNotEmpty() && timings.all{it in 0..5000} && timings.sum()<=10000) { vibrator.vibrate(VibrationEffect.createWaveform(timings,-1)); deliveries.add("Vibration requested") }
            else deliveries.add("Vibration unavailable")
        }
        val endpoint=rule.optString("ledEndpoint","")
        val hasLed=endpoint.isNotEmpty() && endpoint!="null"
        val base=deliveries.joinToString(" · ")
        fun delivery(status:String)=listOf(base,status).filter{it.isNotEmpty()}.joinToString(" · ")
        val eventId="$now-$id"
        val event=JSONObject().put("id",eventId).put("label",label).put("kind",kind).put("time",java.time.Instant.ofEpochMilli(now).toString()).put("score",match.second).put("soundId",id).put("delivery",if(hasLed) delivery("LED pending") else base.ifEmpty{"No action"})
        synchronized(RuntimeBridge) {
            val old=JSONArray(prefs.getString("events","[]")); val next=JSONArray().put(event)
            for(i in 0 until minOf(old.length(),199)) next.put(old.getJSONObject(i))
            check(prefs.edit().putString("events",next.toString()).commit())
        }
        emit(mapOf("type" to "event","event" to event.toString()))
        if(hasLed) network.execute {
            val status=try {
                val url=URL(endpoint); require(url.protocol=="https"); require(url.userInfo==null)
                val connection=url.openConnection() as HttpURLConnection
                try { connection.connectTimeout=4000; connection.readTimeout=4000; connection.requestMethod="POST"; connection.doOutput=true; connection.setRequestProperty("Content-Type","application/json"); connection.outputStream.use{it.write(JSONObject().put("soundId",id).put("name",label).put("on",true).toString().toByteArray())}; if(connection.responseCode in 200..299) "LED acknowledged" else "LED rejected (${connection.responseCode})" }
                finally { connection.disconnect() }
            } catch(e:Exception) { "LED unavailable" }
            val finalDelivery=delivery(status)
            synchronized(RuntimeBridge) {
                val history=JSONArray(prefs.getString("events","[]"))
                for(i in 0 until history.length()) {
                    val item=history.getJSONObject(i)
                    if(item.optString("id")==eventId) item.put("delivery",finalDelivery)
                }
                prefs.edit().putString("events",history.toString()).commit()
            }
            RuntimeBridge.emit(mapOf("type" to "delivery","eventId" to eventId,"delivery" to finalDelivery))
        }
    }

}
