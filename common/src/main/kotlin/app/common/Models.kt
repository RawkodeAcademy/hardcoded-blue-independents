package app.common

import kotlinx.serialization.Serializable

@Serializable
data class OpRequest(
    val text: String? = null,
    val deps: Map<String, String>? = null
)

@Serializable
data class OpResponse(
    val key: String,
    val value: kotlinx.serialization.json.JsonElement? = null,
    val cache_hit: Boolean = false,
    val error: String? = null
)

@Serializable
data class HealthResponse(val ok: Boolean = true)

@Serializable
data class AnalyzeRequest(val text: String? = null)

@Serializable
data class AnalyzeResponse(
    val normalized: String? = null,
    val transliterated: String? = null,
    val slug: String? = null,
    val tokens: List<String>? = null,
    val unique_words: Int? = null,
    val bigram_count: Int? = null,
    val char_count: Int? = null,
    val unique_chars: Int? = null,
    val hash64: String? = null,
    val entropy: Double? = null,
    val palindrome: Boolean? = null,
    val degraded: Boolean = false,
    val error: String? = null
)

