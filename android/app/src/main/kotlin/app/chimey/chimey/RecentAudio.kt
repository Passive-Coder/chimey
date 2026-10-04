package app.chimey.chimey

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Eight seconds of transient PCM; never persisted or transmitted automatically. */
object RecentAudio {
    private val ring=ByteArray(16000*2*8)
    private var owner=0L
    @Synchronized fun begin(session:Long) { owner=session;clear() }
    @Synchronized fun append(bytes:ByteArray,session:Long) { if(owner==session) append(bytes) }
    @Synchronized fun clear(session:Long) { if(owner==session) clear() }
    private var cursor=0; private var count=0
    @Synchronized fun append(bytes:ByteArray) {
        for(b in bytes) {ring[cursor]=b;cursor=(cursor+1)%ring.size;count=minOf(count+1,ring.size)}
    }
    @Synchronized fun clear() {ring.fill(0);cursor=0;count=0}
    @Synchronized fun wav():ByteArray {
        require(count>=16000*2) {"Listen for at least one second first"}
        val result=ByteBuffer.allocate(44+count).order(ByteOrder.LITTLE_ENDIAN)
        result.put("RIFF".toByteArray()).putInt(36+count).put("WAVEfmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(16000).putInt(32000).putShort(2).putShort(16).put("data".toByteArray()).putInt(count)
        val start=(cursor-count+ring.size)%ring.size
        repeat(count){result.put(ring[(start+it)%ring.size])}
        return result.array()
    }
}
