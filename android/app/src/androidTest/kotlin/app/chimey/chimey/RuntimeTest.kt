package app.chimey.chimey

import android.Manifest
import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONArray
import org.json.JSONObject

@RunWith(AndroidJUnit4::class)
class RuntimeTest {
    @Test fun serviceContinuesCaptureWhenVisibleActivityMovesToBackgroundAndStopsExplicitly() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val context=instrumentation.targetContext
        instrumentation.uiAutomation.executeShellCommand("pm grant ${context.packageName} ${Manifest.permission.RECORD_AUDIO}").close()
        ActivityScenario.launch(MainActivity::class.java).use { activity ->
            activity.onActivity { it.startForegroundService(Intent(it,ListeningService::class.java)) }
            waitFor("listening")
            activity.moveToState(androidx.lifecycle.Lifecycle.State.CREATED)
            Thread.sleep(1500)
            assertEquals("listening",RuntimeBridge.state)
            context.stopService(Intent(context,ListeningService::class.java))
            waitFor("stopped")
        }
    }
    @Test fun serviceMatcherAbstainsOnAmbiguityAndInvalidEnrollment() {
        val feature=listOf(1.0,0.0)
        fun profile(id:String)=JSONObject().put("id",id).put("enabled",true).put("validated",true).put("featureModel","yamnet-embedding-v1").put("threshold",.95).put("examples",JSONArray().apply{repeat(3){put(JSONArray(feature))}})
        assertNotNull(Recognition.match(feature,JSONArray().put(profile("a"))))
        assertNull(Recognition.match(feature,JSONArray().put(profile("a")).put(profile("b"))))
        assertNull(Recognition.match(feature,JSONArray().put(profile("a").put("enabled",false))))
        assertNull(Recognition.match(feature,JSONArray().put(profile("a").put("examples",JSONArray().put(JSONArray(feature))))))
        assertNull(Recognition.match(listOf(Double.NaN,0.0),JSONArray().put(profile("a"))))
    }
    private fun waitFor(state:String) {
        val deadline=System.currentTimeMillis()+15000
        while(RuntimeBridge.state!=state && System.currentTimeMillis()<deadline) Thread.sleep(100)
        assertEquals(state,RuntimeBridge.state)
    }
}
