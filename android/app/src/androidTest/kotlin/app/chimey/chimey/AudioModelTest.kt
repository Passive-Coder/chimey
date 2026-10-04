package app.chimey.chimey
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
@RunWith(AndroidJUnit4::class)
class AudioModelTest {
    @Test fun missingAudioArtifactFailsExplicitlyWithoutPretendingToRecognizeSound() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals(false,LocalAudioModel.status(context)["installed"])
        val done=CountDownLatch(1);var failed=false
        LocalAudioModel.load(context) {failed=it.isFailure;done.countDown()}
        assertTrue(done.await(15,TimeUnit.SECONDS));assertTrue(failed)
        assertEquals("error",LocalAudioModel.state)
        val unloaded=CountDownLatch(1);LocalAudioModel.unload{unloaded.countDown()};assertTrue(unloaded.await(5,TimeUnit.SECONDS))
    }
}
