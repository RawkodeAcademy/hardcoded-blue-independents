package app.service

import app.common.HealthResponse
import app.common.OpRequest
import app.common.OpResponse
import app.common.TextOps
import app.common.installPprofEndpoints
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.*
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    embeddedServer(Netty, port = port, module = Application::module).start(wait = true)
}

fun Application.module() {
    install(ContentNegotiation) {
        json(Json { prettyPrint = false; ignoreUnknownKeys = true })
    }

    // pprof endpoint via JFR
    installPprofEndpoints()

    routing {
        get("/healthz") { call.respond(HealthResponse()) }

        post("/op") {
            val svc = System.getenv("SERVICE")?.lowercase()?.trim()
            if (svc.isNullOrBlank()) {
                call.respond(HttpStatusCode.BadRequest, OpResponse(key = "", error = "SERVICE env var not set"))
                return@post
            }

            val req = runCatching { call.receive<OpRequest>() }.getOrElse {
                call.respond(HttpStatusCode.OK, OpResponse(key = svc, error = "invalid json"))
                return@post
            }

            val input = req.text?.let { it } ?: req.deps?.get("normalized")

            if (input == null) {
                call.respond(HttpStatusCode.OK, OpResponse(key = svc, error = "missing input text or deps.normalized"))
                return@post
            }

            val normalized = req.deps?.get("normalized") ?: TextOps.normalize(input)

            val response = when (svc) {
                "normalized" -> OpResponse("normalized", JsonPrimitive(TextOps.normalize(input)))
                "transliterated" -> OpResponse("transliterated", JsonPrimitive(TextOps.transliterate(normalized)))
                "slug" -> OpResponse("slug", JsonPrimitive(TextOps.slug(TextOps.transliterate(normalized))))
                "tokens" -> {
                    val arr = TextOps.tokens(normalized).map { JsonPrimitive(it) }
                    OpResponse("tokens", JsonArray(arr))
                }
                "unique_words" -> OpResponse("unique_words", JsonPrimitive(TextOps.uniqueWordCount(normalized)))
                "bigram_count" -> OpResponse("bigram_count", JsonPrimitive(TextOps.bigramCount(normalized)))
                "char_count" -> OpResponse("char_count", JsonPrimitive(TextOps.charCount(normalized)))
                "unique_chars" -> OpResponse("unique_chars", JsonPrimitive(TextOps.uniqueChars(normalized)))
                "hash64" -> OpResponse("hash64", JsonPrimitive(TextOps.hash64(normalized)))
                "entropy" -> OpResponse("entropy", JsonPrimitive(TextOps.entropy(normalized)))
                "palindrome" -> OpResponse("palindrome", JsonPrimitive(TextOps.palindrome(normalized)))
                else -> OpResponse(svc, error = "unknown service '$svc'")
            }

            call.respond(HttpStatusCode.OK, response)
        }

        get("/") { call.respondText("OK", ContentType.Text.Plain) }
    }
}

