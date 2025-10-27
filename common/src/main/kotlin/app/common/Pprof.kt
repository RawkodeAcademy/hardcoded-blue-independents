package app.common

import io.ktor.http.ContentDisposition
import io.ktor.http.HttpHeaders
import io.ktor.http.content.OutgoingContent
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.response.header
import io.ktor.server.response.respondBytes
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import java.nio.file.Files
import java.time.Duration
import jdk.jfr.Recording

/**
 * Adds a JFR-based CPU profiling endpoint compatible with the common Go path:
 *   GET /debug/pprof/profile?seconds=30
 * Returns a JFR file; many profilers can consume JFR directly or via conversion.
 */
fun Application.installPprofEndpoints() {
    routing {
        get("/debug/pprof/profile") {
            val seconds = call.request.queryParameters["seconds"]?.toIntOrNull()?.coerceIn(1, 300) ?: 30
            val bytes = recordCpuJfr(seconds)
            call.response.header(HttpHeaders.ContentDisposition, ContentDisposition.Attachment.withParameter(ContentDisposition.Parameters.FileName, "profile.jfr").toString())
            call.respondBytes(bytes, contentType = null) // application/octet-stream by default
        }
    }
}

private fun recordCpuJfr(seconds: Int): ByteArray {
    val rec = Recording()
    // Enable events similar to JFR "profile" configuration
    rec.enable("jdk.ExecutionSample")
    rec.enable("jdk.NativeMethodSample")
    rec.enable("jdk.JavaMonitorEnter")
    rec.enable("jdk.ThreadCPULoad")
    rec.duration = Duration.ofSeconds(seconds.toLong())
    rec.start()
    // Let the recording run for the requested duration
    Thread.sleep(seconds * 1000L)
    val tmp = Files.createTempFile("profile", ".jfr")
    rec.dump(tmp)
    rec.stop()
    return Files.readAllBytes(tmp).also { Files.deleteIfExists(tmp) }
}

