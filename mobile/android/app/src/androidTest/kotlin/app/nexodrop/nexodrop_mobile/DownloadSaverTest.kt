package app.nexodrop.nexodrop_mobile

import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class DownloadSaverTest {
    @Test
    fun publishesInOnePublicFolderWithoutOverwritingAndRetriesWithoutDuplicates() {
        assumeTrue(Build.VERSION.SDK_INT >= 29)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val folder = File(context.filesDir, "download-test-${UUID.randomUUID()}")
        val created = mutableListOf<Uri>()
        try {
            val a = File(folder, "a").apply { mkdirs() }
            val b = File(folder, "b").apply { mkdirs() }
            val filename = "nexodrop-test-${UUID.randomUUID()}.txt"
            val first = File(a, filename).apply { writeText("primero") }
            val second = File(b, filename).apply { writeText("segundo") }
            val saver = DownloadSaver(context)
            val savedA = saver.save(first.path)
            val uriA = Uri.parse(savedA.getValue("id")).also { created.add(it) }
            assertEquals(savedA, saver.save(first.path))
            val savedB = saver.save(second.path)
            val uriB = Uri.parse(savedB.getValue("id")).also { created.add(it) }
            assertNotEquals(uriA, uriB)
            assertNotEquals(savedA["name"], savedB["name"])
            assertEquals("primero", context.contentResolver.openInputStream(uriA)!!.bufferedReader().use { it.readText() })
            assertEquals("segundo", context.contentResolver.openInputStream(uriB)!!.bufferedReader().use { it.readText() })
            for (uri in created) {
                context.contentResolver.query(uri, arrayOf(MediaStore.Downloads.RELATIVE_PATH, MediaStore.Downloads.IS_PENDING), null, null, null)!!.use {
                    assertTrue(it.moveToFirst())
                    assertEquals(Environment.DIRECTORY_DOWNLOADS + "/NexoDrop/", it.getString(0))
                    assertEquals(0, it.getInt(1))
                }
            }
        } finally {
            for (uri in created) context.contentResolver.delete(uri, null, null)
            folder.deleteRecursively()
        }
    }
}
