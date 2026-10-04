package app.chimey.chimey

import android.content.Context
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Explicit contract for the pinned, embedding-exposed classification artifact. */
class Yamnet(context: Context) : AutoCloseable {
    private val interpreter: Interpreter
    private val labels = context.assets.open("models/yamnet-labels.txt").bufferedReader().readLines()
    private val input = ByteBuffer.allocateDirect(15600 * 4).order(ByteOrder.nativeOrder())
    private val scores = ByteBuffer.allocateDirect(521 * 4).order(ByteOrder.nativeOrder())
    private val embedding = ByteBuffer.allocateDirect(1024).order(ByteOrder.nativeOrder())
    init {
        val bytes = context.assets.open("models/yamnet.tflite").use { it.readBytes() }
        val model = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).apply { put(bytes); rewind() }
        interpreter = Interpreter(model, Interpreter.Options().setNumThreads(2).setUseXNNPACK(false))
        check(interpreter.getInputTensor(0).shape().contentEquals(intArrayOf(15600)))
        check(interpreter.getInputTensor(0).dataType() == DataType.FLOAT32)
        check(interpreter.getOutputTensor(0).shape().contentEquals(intArrayOf(1, 521)))
        check(interpreter.getOutputTensor(1).shape().contentEquals(intArrayOf(1, 1, 1, 1024)))
        check(interpreter.getOutputTensor(1).dataType() == DataType.INT8)
        check(labels.size == 521)
    }
    data class Frame(val label: String, val score: Double, val features: List<Double>, val elapsedMs: Double)
    fun infer(pcm: ShortArray): Frame {
        require(pcm.size == 15600)
        input.rewind(); pcm.forEach { input.putFloat(it / 32768f) }; input.rewind()
        scores.rewind(); embedding.rewind()
        val start = System.nanoTime()
        interpreter.runForMultipleInputsOutputs(arrayOf(input), mutableMapOf<Int, Any>(0 to scores, 1 to embedding))
        scores.rewind(); embedding.rewind()
        val values = FloatArray(521) { scores.float }
        check(values.all { it.isFinite() })
        val best = values.indices.maxBy { values[it] }
        val q = interpreter.getOutputTensor(1).quantizationParams()
        check(q.scale > 0)
        val features = List(1024) { (embedding.get().toInt() - q.zeroPoint) * q.scale.toDouble() }
        check(features.all { it.isFinite() })
        return Frame(labels[best], values[best].toDouble(), features, (System.nanoTime() - start) / 1e6)
    }
    override fun close() = interpreter.close()
}
