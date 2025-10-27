package app.aggregator

import app.common.AnalyzeRequest
import app.common.AnalyzeResponse
import app.common.HealthResponse
import app.common.OpRequest
import app.common.TextOps
import app.common.installPprofEndpoints
import io.ktor.client.*
import io.ktor.client.call.body
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation as ClientContentNegotiation
import io.ktor.client.request.*
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation as ServerContentNegotiation
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.*

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8081
    embeddedServer(Netty, port = port, module = Application::module).start(wait = true)
}

fun Application.module() {
    install(ServerContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
    installPprofEndpoints()

    val client = HttpClient(CIO) { install(ClientContentNegotiation) { json(Json { ignoreUnknownKeys = true }) } }

    routing {
        get("/healthz") { call.respond(HealthResponse()) }

        post("/analyze") {
            val req = runCatching { call.receive<AnalyzeRequest>() }.getOrElse {
                call.respond(HttpStatusCode.OK, AnalyzeResponse(degraded = true, error = "invalid json"))
                return@post
            }

            val text = req.text
            if (text.isNullOrBlank()) {
                call.respond(HttpStatusCode.OK, AnalyzeResponse(degraded = true, error = "missing text"))
                return@post
            }

            val urls = ServiceUrls.fromEnv()

            val result = analyzeAll(client, text, urls)
            call.respond(result)
        }
    }
}

private suspend fun analyzeAll(client: HttpClient, text: String, urls: ServiceUrls): AnalyzeResponse = coroutineScope {
    var degraded = false
    var errMsg: String? = null

    // 1) normalized
    val normalized = runCatching { callServiceForString(client, urls.normalized, "normalized", OpRequest(text = text)) }
        .onFailure { degraded = true; errMsg = appendErr(errMsg, "normalized: ${'$'}{it.message}") }
        .getOrNull()

    // 2) transliterated, slug depend on normalized
    val transliterated = runCatching {
        val deps = mapOf("normalized" to (normalized ?: TextOps.normalize(text)))
        callServiceForString(client, urls.transliterated, "transliterated", OpRequest(deps = deps))
    }.onFailure { degraded = true; errMsg = appendErr(errMsg, "transliterated: ${'$'}{it.message}") }.getOrNull()

    val slug = runCatching {
        val deps = mapOf("normalized" to (normalized ?: TextOps.normalize(text)))
        callServiceForString(client, urls.slug, "slug", OpRequest(deps = deps))
    }.onFailure { degraded = true; errMsg = appendErr(errMsg, "slug: ${'$'}{it.message}") }.getOrNull()

    val tokens = runCatching {
        val deps = mapOf("normalized" to (normalized ?: TextOps.normalize(text)))
        callServiceForStringList(client, urls.tokens, "tokens", OpRequest(deps = deps))
    }.onFailure { degraded = true; errMsg = appendErr(errMsg, "tokens: ${'$'}{it.message}") }.getOrNull()

    // 3) the rest depend on normalized
    val normBase = normalized ?: TextOps.normalize(text)

    var uniqueWords: Int? = null
    var bigramCount: Int? = null
    var charCount: Int? = null
    var uniqueChars: Int? = null
    var hash64: String? = null
    var entropy: Double? = null
    var palindrome: Boolean? = null

    // Launch concurrently for each downstream field
    awaitAll(
        async {
            runCatching { callServiceForInt(client, urls.unique_words, "unique_words", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { uniqueWords = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "unique_words: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForInt(client, urls.bigram_count, "bigram_count", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { bigramCount = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "bigram_count: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForInt(client, urls.char_count, "char_count", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { charCount = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "char_count: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForInt(client, urls.unique_chars, "unique_chars", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { uniqueChars = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "unique_chars: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForString(client, urls.hash64, "hash64", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { hash64 = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "hash64: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForDouble(client, urls.entropy, "entropy", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { entropy = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "entropy: ${'$'}{ex.message}") }
        },
        async {
            runCatching { callServiceForBool(client, urls.palindrome, "palindrome", OpRequest(deps = mapOf("normalized" to normBase))) }
                .onSuccess { palindrome = it }
                .onFailure { ex -> degraded = true; errMsg = appendErr(errMsg, "palindrome: ${'$'}{ex.message}") }
        }
    )

    return@coroutineScope AnalyzeResponse(
        normalized = normalized,
        transliterated = transliterated,
        slug = slug,
        tokens = tokens,
        unique_words = uniqueWords,
        bigram_count = bigramCount,
        char_count = charCount,
        unique_chars = uniqueChars,
        hash64 = hash64,
        entropy = entropy,
        palindrome = palindrome,
        degraded = degraded,
        error = errMsg
    )
}

private fun appendErr(current: String?, add: String): String =
    if (current.isNullOrBlank()) add else current + "; " + add

private suspend fun callServiceForString(client: HttpClient, url: String, expectedKey: String, body: OpRequest): String {
    val json = callService(client, url, body)
    val gotKey = json["key"]?.jsonPrimitive?.content
    require(gotKey == expectedKey) { "expected key ${'$'}expectedKey got ${'$'}gotKey" }
    return json["value"]?.jsonPrimitive?.content ?: error("missing value")
}

private suspend fun callServiceForInt(client: HttpClient, url: String, expectedKey: String, body: OpRequest): Int {
    val json = callService(client, url, body)
    val gotKey = json["key"]?.jsonPrimitive?.content
    require(gotKey == expectedKey) { "expected key ${'$'}expectedKey got ${'$'}gotKey" }
    return json["value"]?.jsonPrimitive?.int ?: error("missing value")
}

private suspend fun callServiceForDouble(client: HttpClient, url: String, expectedKey: String, body: OpRequest): Double {
    val json = callService(client, url, body)
    val gotKey = json["key"]?.jsonPrimitive?.content
    require(gotKey == expectedKey) { "expected key ${'$'}expectedKey got ${'$'}gotKey" }
    return json["value"]?.jsonPrimitive?.double ?: error("missing value")
}

private suspend fun callServiceForBool(client: HttpClient, url: String, expectedKey: String, body: OpRequest): Boolean {
    val json = callService(client, url, body)
    val gotKey = json["key"]?.jsonPrimitive?.content
    require(gotKey == expectedKey) { "expected key ${'$'}expectedKey got ${'$'}gotKey" }
    return json["value"]?.jsonPrimitive?.boolean ?: error("missing value")
}

private suspend fun callService(client: HttpClient, url: String, body: OpRequest): JsonObject {
    val resp = client.post(url) { setBody(body) }
    if (resp.status != HttpStatusCode.OK) error("status ${'$'}{resp.status}")
    return resp.body()
}

private suspend fun callServiceForStringList(client: HttpClient, url: String, expectedKey: String, body: OpRequest): List<String> {
    val json = callService(client, url, body)
    val gotKey = json["key"]?.jsonPrimitive?.content
    require(gotKey == expectedKey) { "expected key ${'$'}expectedKey got ${'$'}gotKey" }
    val arr = json["value"]?.jsonArray ?: error("missing value")
    return arr.map { it.jsonPrimitive.content }
}

private data class ServiceUrls(
    val normalized: String,
    val transliterated: String,
    val slug: String,
    val tokens: String,
    val unique_words: String,
    val bigram_count: String,
    val char_count: String,
    val unique_chars: String,
    val hash64: String,
    val entropy: String,
    val palindrome: String
) {
    companion object {
        fun fromEnv(): ServiceUrls = ServiceUrls(
            normalized = envUrlOrDefault("NORMALIZER_URL", 7001),
            transliterated = envUrlOrDefault("TRANSLITERATOR_URL", 7002),
            slug = envUrlOrDefault("SLUG_URL", 7003),
            tokens = envUrlOrDefault("TOKENS_URL", 7004),
            unique_words = envUrlOrDefault("UNIQUE_WORDS_URL", 7005),
            bigram_count = envUrlOrDefault("BIGRAM_COUNT_URL", 7006),
            char_count = envUrlOrDefault("CHAR_COUNT_URL", 7007),
            unique_chars = envUrlOrDefault("UNIQUE_CHARS_URL", 7008),
            hash64 = envUrlOrDefault("HASH64_URL", 7009),
            entropy = envUrlOrDefault("ENTROPY_URL", 7010),
            palindrome = envUrlOrDefault("PALINDROME_URL", 7011),
        )
    }
}

private fun envUrlOrDefault(name: String, port: Int): String =
    System.getenv(name) ?: "http://127.0.0.1:${'$'}port/op"
