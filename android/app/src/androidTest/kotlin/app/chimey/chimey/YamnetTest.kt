package app.chimey.chimey

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import kotlin.math.sin
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

@RunWith(AndroidJUnit4::class)
class YamnetTest {
    @Test fun shippedModelRunsActualWaveformInferenceAndProducesDistinctEmbeddings() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        Yamnet(context).use { model ->
            val silence=model.infer(ShortArray(15600))
            val tone=model.infer(ShortArray(15600){(sin(2*Math.PI*1000*it/16000)*20000).toInt().toShort()})
            assertEquals(1024,silence.features.size)
            assertTrue(tone.score.isFinite() && tone.score in 0.0..1.0)
            assertTrue(tone.features.all{it.isFinite()})
            assertTrue(tone.features.zip(silence.features).any{ kotlin.math.abs(it.first-it.second)>.01 })
            assertTrue(tone.elapsedMs>0)
            val originalBytes=InstrumentationRegistry.getInstrumentation().context.assets.open("yamnet-original.tflite").use{it.readBytes()}
            val originalModel=ByteBuffer.allocateDirect(originalBytes.size).order(ByteOrder.nativeOrder()).apply{put(originalBytes);rewind()}
            Interpreter(originalModel,Interpreter.Options().setUseXNNPACK(false)).use { original ->
                val input=FloatArray(15600){(sin(2*Math.PI*1000*it/16000)*20000).toInt().toShort()/32768f}
                val scores=arrayOf(FloatArray(521))
                original.run(input,scores)
                assertEquals(scores[0].max().toDouble(),tone.score,1e-6)
            }
        }
    }
}
