package dev.sigra.proof

import android.content.Context
import java.io.File
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.withContentDescription
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.runner.AndroidJUnit4

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
    fun androidKeyStorePostureCoversEveryAllowlistedReadOutcome() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val record = File(context.filesDir, "native-refresh-record.json")
        val crypto = AndroidKeyStoreRefreshCrypto()
        record.delete()
        crypto.deleteKey()
        val store = SecureRefreshStore(context)

        assertEquals(StorageReadResult.NOT_FOUND, store.readPosture().readResult)
        assertEquals(StorageReadResult.READ_OK, store.saveInitial("first".toByteArray()).readResult)
        assertTrue(store.rotate("second".toByteArray()).rotated)
        assertTrue(SecureRefreshStore(context).recoverAfterRelaunch().recoveredAfterRelaunch)
        assertTrue(store.deleteAfterLogout().deletedAfterLogout)
        store.saveInitial("third".toByteArray())
        assertTrue(store.deleteAfterRevocation().deletedAfterRevocation)

        store.saveInitial("fourth".toByteArray())
        record.writeText("{\"nonce\":\"AA==\",\"ciphertext\":\"AA==\",\"keyAlias\":\"corrupt-record\",\"version\":1}")
        assertEquals(StorageReadResult.DECRYPT_FAILED, store.readPosture().readResult)

        store.saveInitial("fifth".toByteArray())
        crypto.deleteKey()
        assertEquals(StorageReadResult.KEY_UNAVAILABLE, store.readPosture().readResult)
        assertEquals(
            setOf(
                "present", "rotated", "recovered_after_relaunch", "deleted_after_logout",
                "deleted_after_revocation", "read_result", "access_persisted",
            ),
            store.posture.asMap().keys,
        )
        assertEquals(false, store.posture.asMap()["access_persisted"])
        record.delete()
    }

    @Test
    fun browserBoundaryUsesUiAutomatorConditionWithoutFixedDelay() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        val context = ApplicationProvider.getApplicationContext<Context>()
        val launchIntent = context.packageManager.getLaunchIntentForPackage("com.android.chrome")
        assertNotNull("locked Chrome package must be installed by the proof lane", launchIntent)
        context.startActivity(launchIntent!!.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))

        assertNotNull(device.wait(Until.findObject(By.pkg("com.android.chrome")), 5_000))
        assertEquals("com.android.chrome", device.currentPackageName)
    }
}
