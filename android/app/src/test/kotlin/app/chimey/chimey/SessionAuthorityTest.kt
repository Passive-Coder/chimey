package app.chimey.chimey
import org.junit.Assert.*
import org.junit.Test
class SessionAuthorityTest {
    @Test fun cancelledAndReplacedWorkersCannotStartCaptureOrPublish() {
        val authority=SessionAuthority();val old=authority.begin()
        authority.cancel(old)
        var starts=0
        assertFalse(authority.runIfActive(old){starts++})
        val next=authority.begin();authority.finish(old)
        assertTrue(old.stopped.isDone);assertFalse(next.stopped.isDone)
        assertTrue(authority.active(next));assertFalse(authority.active(old))
        assertTrue(authority.runIfActive(next){starts++});assertEquals(1,starts)
    }
    @Test fun oldAudioWorkerCannotClearSuccessorClip() {
        RecentAudio.begin(1);RecentAudio.append(ByteArray(32000){1},1)
        RecentAudio.begin(2);RecentAudio.append(ByteArray(32000){2},2)
        RecentAudio.append(ByteArray(32000){3},1);RecentAudio.clear(1)
        assertEquals(2,RecentAudio.wav()[44].toInt())
        RecentAudio.clear(2)
    }
}
