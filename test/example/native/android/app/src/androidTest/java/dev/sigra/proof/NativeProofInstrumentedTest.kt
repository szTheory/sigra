package dev.sigra.proof

import android.content.Context
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.withContentDescription
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeProofInstrumentedTest {
    @Test
    fun launchIsStableAndNotAuthenticated() {
        ActivityScenario.launch(MainActivity::class.java).use {
            onView(withContentDescription(MainActivity.READINESS_HOOK))
                .check(matches(withText(MainActivity.NOT_AUTHENTICATED)))
        }
    }

    @Test
    fun browserBoundaryUsesUiAutomatorConditionWithoutFixedDelay() {
        val device = InstrumentationRegistry.getInstrumentation().uiAutomation
        val context = ApplicationProvider.getApplicationContext<Context>()
        val launchIntent = context.packageManager.getLaunchIntentForPackage("com.android.chrome")
        assertNotNull("locked Chrome package must be installed by the proof lane", launchIntent)
        context.startActivity(launchIntent!!.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))

        val root = device.rootInActiveWindow
        assertNotNull(Until.findObject(By.pkg("com.android.chrome")).apply(root))
        assertEquals("com.android.chrome", root.packageName?.toString())
    }
}
