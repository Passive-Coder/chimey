package app.chimey.chimey

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.sin

/** Synthetic signals only: this is not an appliance-accuracy benchmark. */
@RunWith(AndroidJUnit4::class)
class AcousticFixtureTest {
    @Test fun exportActualModelFeaturesForEnrollmentAndHeldOutMatching() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        Yamnet(context).use { model ->
            fun tone(hz:Double,level:Double,phase:Double=0.0)=ShortArray(15600){
                (sin(2*Math.PI*hz*it/16000+phase)*level*32767).toInt().toShort()
            }
            val signals=linkedMapOf(
                "example1" to tone(1000.0,.35),
                "example2" to tone(1000.0,.45,1.0),
                "example3" to tone(1000.0,.55,2.0),
                "heldOut" to tone(1000.0,.4,.7),
                "differentTone" to tone(2000.0,.4,.7),
                "silence" to ShortArray(15600),
                "roomNoise" to ShortArray(15600).apply {
                    val random=java.util.Random(42)
                    indices.forEach { this[it]=((random.nextDouble()*2-1)*1000).toInt().toShort() }
                },
            )
            val digest=java.security.MessageDigest.getInstance("SHA-256").digest(context.assets.open("models/yamnet.tflite").use{it.readBytes()}).joinToString(""){"%02x".format(it)}
            val fixture=JSONObject().put("artifactSHA256",digest).put("featureModel","yamnet-embedding-v1").put("sampleRate",16000).put("samples",15600).put("synthetic",true)
            val frames=JSONObject()
            for((name,pcm) in signals) {
                val frame=model.infer(pcm)
                assertEquals(1024,frame.features.size)
                assertTrue(frame.features.all{it.isFinite()})
                frames.put(name,JSONObject().put("features",JSONArray(frame.features)).put("category",frame.label).put("score",frame.score))
            }
            val positive=(1..3).map{frames.getJSONObject("example$it").getJSONArray("features").let{a->List(a.length()){a.getDouble(it)}}}
            fun feature(name:String)=frames.getJSONObject(name).getJSONArray("features").let{a->List(a.length()){a.getDouble(it)}}
            val profile=JSONObject().put("enabled",true).put("validated",true).put("featureModel","yamnet-embedding-v1").put("threshold",.8).put("examples",JSONArray(positive))
            assertNotNull(Recognition.match(feature("heldOut"),JSONArray().put(profile)))
            listOf("silence","roomNoise","differentTone").forEach{assertNull(Recognition.match(feature(it),JSONArray().put(profile)))}
            assertNull(Recognition.match(feature("heldOut"),JSONArray().put(profile).put(profile)))
            fixture.put("frames",frames)
            java.io.File(context.filesDir,"acoustic-fixtures.json").writeText(fixture.toString())
        }
    }
}
