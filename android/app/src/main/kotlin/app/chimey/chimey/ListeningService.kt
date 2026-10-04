package app.chimey.chimey

import android.app.*
import android.content.*
import android.media.*
import android.os.*
import java.util.concurrent.Executors
import kotlin.math.sqrt

class ListeningService : Service() {
    private val executor=Executors.newSingleThreadExecutor()
    private val network=Executors.newSingleThreadExecutor()
    @Volatile private var running=false
    private lateinit var lease:SessionAuthority.Lease
    private var recorder: AudioRecord?=null
    private val prefs by lazy { getSharedPreferences("chimey.runtime", MODE_PRIVATE) }
    private val recognition by lazy { SoundRecognition(this, prefs, network) }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if(intent?.action=="stop") { stopSelf(); return START_NOT_STICKY }
        if(::lease.isInitialized && !lease.stopped.isDone) return START_NOT_STICKY
        val manager=getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("listening","Listening status",NotificationManager.IMPORTANCE_LOW))
        val open=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE)
        val stop=PendingIntent.getService(this,1,Intent(this,ListeningService::class.java).setAction("stop"),PendingIntent.FLAG_IMMUTABLE)
        val notification=Notification.Builder(this,"listening").setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle("chimey is listening").setContentText("Sound recognition stays on this device").setContentIntent(open).setOngoing(true).addAction(Notification.Action.Builder(null,"Stop",stop).build()).build()
        try { startForeground(101,notification); lease=RuntimeBridge.sessions.begin(); running=true; RecentAudio.begin(lease.id); emitStatus("starting"); val session=lease; executor.execute { capture(session) } }
        catch(e:Exception) { emitStatus("error",e.message ?: "Unable to start listening"); stopSelf() }
        return START_NOT_STICKY
    }
    private fun capture(session:SessionAuthority.Lease) {
        var model: Yamnet?=null
        try {
            if(!active(session)) return
            model=Yamnet(this)
            if(!active(session)) return
            val minimum=AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)
            check(minimum>0) { "16 kHz mono capture is unavailable" }
            val audio=AudioRecord(MediaRecorder.AudioSource.UNPROCESSED,16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,maxOf(minimum*2,31200))
            recorder=audio; check(audio.state==AudioRecord.STATE_INITIALIZED)
            if(!RuntimeBridge.sessions.runIfActive(session) {
                audio.startRecording(); check(audio.recordingState==AudioRecord.RECORDSTATE_RECORDING)
                status(session,"listening")
            }) return
            val window=ShortArray(15600); val block=ShortArray(1920)
            var filled=0; var sinceInference=0
            while(active(session)) {
                val count=audio.read(block,0,block.size)
                if(!active(session)) break
                check(count>0) { "Microphone interrupted ($count)" }
                val bytes=ByteArray(count*2)
                for(i in 0 until count) { bytes[i*2]=block[i].toByte(); bytes[i*2+1]=(block[i].toInt() shr 8).toByte() }
                RecentAudio.append(bytes,session.id)
                RuntimeBridge.emitFor(session,mapOf("type" to "pcm","bytes" to bytes))
                for(i in 0 until count) {
                    window[filled++]=block[i]; sinceInference++
                    if(filled==window.size) {
                        if(sinceInference>=7680) {
                            val rms=sqrt(window.sumOf{ val v=it/32768.0; v*v }/window.size)
                            val frame=model.infer(window)
                            // A relative noise floor avoids enrolling silent YAMNet bias vectors.
                            RuntimeBridge.emitFor(session,mapOf("type" to "features","features" to frame.features,"label" to frame.label,"score" to frame.score,"elapsedMs" to frame.elapsedMs,"rms" to rms,"featureModel" to "yamnet-embedding-v1"))
                            if(rms>.003) RuntimeBridge.sessions.runIfActive(session) { recognition.process(frame) { RuntimeBridge.emitFor(session, it) } }
                            sinceInference=0
                        }
                        window.copyInto(window,0,7680,window.size); filled=window.size-7680
                    }
                }
            }
        } catch(e:Exception) { if(active(session)) status(session,"error",e.message ?: "Microphone interrupted") }
        finally {
            if(lease===session) running=false
            try { recorder?.stop() } catch(_:Exception) {}
            recorder?.release(); recorder=null; model?.close()
            RecentAudio.clear(session.id); status(session,"stopped")
            // Main-thread teardown is serialized with onStartCommand. Attach commands
            // cannot invalidate stopSelf's start ID, or replace an unfinished lease.
            Handler(Looper.getMainLooper()).post {
                if(RuntimeBridge.sessions.current===session) stopSelf()
                RuntimeBridge.sessions.finish(session)
            }
        }
    }

    private fun active(session:SessionAuthority.Lease)=running && RuntimeBridge.sessions.active(session)
    private fun emitStatus(state:String,error:String?=null) { if(::lease.isInitialized) RuntimeBridge.status(lease,state,error) }
    private fun status(session:SessionAuthority.Lease,state:String,error:String?=null)=RuntimeBridge.status(session,state,error)
    override fun onDestroy() {
        running=false
        if(::lease.isInitialized) {
            RuntimeBridge.sessions.cancel(lease)
            if(!lease.stopped.isDone) emitStatus("stopping")
        }
        try { recorder?.stop() } catch(_:Exception) {}
        executor.shutdown(); network.shutdown(); super.onDestroy()
    }
}
