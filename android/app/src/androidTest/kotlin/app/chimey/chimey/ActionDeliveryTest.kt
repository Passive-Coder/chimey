package app.chimey.chimey

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.sin

/** Real model -> production matcher/actions -> Android notification manager. */
@RunWith(AndroidJUnit4::class)
class ActionDeliveryTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun personalMatchPostsNotificationAndCooldownSurvivesPipelineRecreation() {
        InstrumentationRegistry.getInstrumentation().uiAutomation
            .executeShellCommand("pm grant ${context.packageName} ${Manifest.permission.POST_NOTIFICATIONS}").close()
        fixture { pipeline, prefs, frame, emitted, network ->
            prefs.edit().putString("profiles", JSONArray().put(profile("washer", frame.features)).toString()).commit()
            pipeline.process(frame, emitted::add)
            val manager = context.getSystemService(NotificationManager::class.java)
            eventually { manager.activeNotifications.any { it.id == "washer".hashCode() } }
            val notification = manager.activeNotifications.single { it.id == "washer".hashCode() }.notification
            assertEquals("My washer tone", notification.extras.getString("android.title"))
            assertEquals("Personal sound match · chimey", notification.extras.getString("android.text"))
            assertTrue(prefs.getLong("action.washer", 0) > 0)
            val history = JSONArray(prefs.getString("events", "[]"))
            assertEquals(1, history.length())
            assertEquals("personal", history.getJSONObject(0).getString("kind"))
            assertEquals("Notification requested", history.getJSONObject(0).getString("delivery"))
            // A replacement pipeline reads the durable cooldown instead of alerting again.
            SoundRecognition(context, prefs, network).process(frame, emitted::add)
            assertEquals(1, emitted.count { it["type"] == "event" })
            assertEquals(1, JSONArray(prefs.getString("events", "[]")).length())
            manager.cancel("washer".hashCode())
        }
    }

    @Test fun disabledAndAmbiguousProfilesNeverDeliverActions() {
        fixture { pipeline, prefs, frame, emitted, _ ->
            val disabled = profile("disabled", frame.features).put("enabled", false)
            prefs.edit().putString("profiles", JSONArray().put(disabled).toString()).commit()
            pipeline.process(frame, emitted::add)
            val a = profile("a", frame.features)
            val b = profile("b", frame.features)
            prefs.edit().putString("profiles", JSONArray().put(a).put(b).toString()).commit()
            pipeline.process(frame, emitted::add)
            assertEquals(0, emitted.count { it["type"] == "event" })
            assertEquals("[]", prefs.getString("events", "[]"))
            assertFalse(prefs.contains("action.disabled"))
            assertFalse(prefs.contains("action.a"))
            assertFalse(prefs.contains("action.b"))
        }
    }

    @Test fun disconnectedLedPersistsFailureAndDoesNotBlockRecognition() {
        fixture { pipeline, prefs, frame, emitted, _ ->
            val p = profile("led", frame.features)
            p.getJSONObject("rule").put("notification", false).put("ledEndpoint", "https://127.0.0.1:1")
            prefs.edit().putString("profiles", JSONArray().put(p).toString()).commit()
            pipeline.process(frame, emitted::add)
            val initialEvent = JSONObject(emitted.single { it["type"] == "event" }["event"] as String)
            assertEquals("LED pending", initialEvent.getString("delivery"))
            pipeline.process(frame, emitted::add)
            assertEquals(2, emitted.count { it["type"] == "recognition" })
            eventually {
                JSONArray(prefs.getString("events", "[]")).getJSONObject(0).optString("delivery") == "LED unavailable"
            }
            assertEquals(1, JSONArray(prefs.getString("events", "[]")).length())
        }
    }

    @Test fun separateSoundsRequestTheirOwnVibrationPatterns() {
        fixture { pipeline, prefs, frame, emitted, _ ->
            val patterns = listOf(listOf(0, 180, 120, 180), listOf(0, 450, 180, 450, 180, 450))
            for ((index, pattern) in patterns.withIndex()) {
                val p = profile("haptic-$index", frame.features).put("name", "Haptic sound $index")
                p.getJSONObject("rule").put("notification", false).put("vibration", true)
                    .put("pattern", JSONArray(pattern))
                prefs.edit().putString("profiles", JSONArray().put(p).toString()).commit()
                pipeline.process(frame, emitted::add)
                // Let the first waveform finish before requesting the distinct second one.
                Thread.sleep(pattern.sum().toLong() + 100)
            }
            val vibrator = if (android.os.Build.VERSION.SDK_INT >= 31)
                context.getSystemService(android.os.VibratorManager::class.java).defaultVibrator
                else context.getSystemService(android.os.Vibrator::class.java)
            val expected = if (vibrator.hasVibrator()) "Vibration requested" else "Vibration unavailable"
            val history = JSONArray(prefs.getString("events", "[]"))
            assertEquals(2, history.length())
            assertEquals("Haptic sound 1", history.getJSONObject(0).getString("label"))
            assertEquals("Haptic sound 0", history.getJSONObject(1).getString("label"))
            for (i in 0 until history.length()) assertEquals(expected, history.getJSONObject(i).getString("delivery"))
            assertEquals(2, emitted.count { it["type"] == "event" })
        }
    }

    private fun profile(id: String, features: List<Double>) = JSONObject()
        .put("id", id).put("name", "My washer tone").put("enabled", true)
        .put("validated", true).put("featureModel", "yamnet-embedding-v1").put("threshold", .95)
        .put("examples", JSONArray().apply { repeat(3) { put(JSONArray(features)) } })
        .put("rule", JSONObject().put("notification", true).put("vibration", false)
            .put("pattern", JSONArray(listOf(0, 180, 120, 180))).put("cooldownSeconds", 60))

    private fun fixture(test: (SoundRecognition, android.content.SharedPreferences, Yamnet.Frame,
        CopyOnWriteArrayList<Map<String, Any?>>, java.util.concurrent.ExecutorService) -> Unit) {
        val prefs = context.getSharedPreferences("action-test-${System.nanoTime()}", Context.MODE_PRIVATE)
        val network = Executors.newSingleThreadExecutor()
        try {
            Yamnet(context).use { model ->
                val pcm = ShortArray(15600) { (sin(2 * PI * 1000 * it / 16000) * 14000).toInt().toShort() }
                test(SoundRecognition(context, prefs, network), prefs, model.infer(pcm), CopyOnWriteArrayList(), network)
            }
        } finally {
            network.shutdown()
            assertTrue(network.awaitTermination(10, java.util.concurrent.TimeUnit.SECONDS))
            prefs.edit().clear().commit()
        }
    }

    private fun eventually(check: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 10000
        while (!check() && System.currentTimeMillis() < deadline) Thread.sleep(25)
        assertTrue(check())
    }
}
