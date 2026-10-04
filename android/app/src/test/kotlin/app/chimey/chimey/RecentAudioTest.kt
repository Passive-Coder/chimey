package app.chimey.chimey
import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
class RecentAudioTest {
    @Test fun clipIsBoundedOrderedWavAndClearedWhenListeningStops() {
        RecentAudio.clear()
        try {RecentAudio.wav();fail("Empty audio must not be shared")}catch(_:IllegalArgumentException){}
        RecentAudio.append(ByteArray(256000){(it%127).toByte()})
        RecentAudio.append(ByteArray(32000){42})
        val wav=RecentAudio.wav()
        assertEquals(256044,wav.size)
        assertEquals("RIFF",String(wav,0,4))
        val header=ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(16000,header.getInt(24));assertEquals(256000,header.getInt(40))
        assertEquals((32000%127).toByte(),wav[44]);assertEquals(42.toByte(),wav.last())
        RecentAudio.clear()
        try{RecentAudio.wav();fail("Stopped audio must not remain available")}catch(_:IllegalArgumentException){}
    }
}
