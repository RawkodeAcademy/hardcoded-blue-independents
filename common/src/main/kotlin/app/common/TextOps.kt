package app.common

import java.text.Normalizer
import kotlin.math.log2

object TextOps {
    fun normalize(input: String): String {
        val nfkc = Normalizer.normalize(input, Normalizer.Form.NFKC)
        val noControl = nfkc.replace("[\\p{Cc}\\p{Cf}]".toRegex(), "")
        val collapsed = noControl.trim().replace("\\s+".toRegex(), " ")
        return collapsed
    }

    fun transliterate(inputNormalized: String): String {
        val nfd = Normalizer.normalize(inputNormalized, Normalizer.Form.NFD)
        val noMarks = nfd.replace("\\p{M}+".toRegex(), "")
        val asciiish = noMarks.replace("[^\\p{Alnum} ]+".toRegex(), " ")
        return asciiish.trim().replace("\\s+".toRegex(), " ")
    }

    fun slug(transliterated: String, maxLen: Int = 64): String {
        val base = transliterated.lowercase().replace("[^a-z0-9]+".toRegex(), "-").trim('-')
        val cut = if (base.length > maxLen) base.substring(0, maxLen).trim('-') else base
        return if (cut.isEmpty()) "n-a" else cut
    }

    fun tokens(normalized: String): List<String> =
        normalized.lowercase().split("[^\\p{Alnum}]+".toRegex())
            .filter { it.isNotBlank() }

    fun uniqueWordCount(normalized: String): Int = tokens(normalized).toSet().size

    fun bigramCount(normalized: String): Int {
        val t = tokens(normalized)
        if (t.size < 2) return 0
        val set = LinkedHashSet<String>()
        for (i in 0 until t.size - 1) {
            set += t[i] + "\u0001" + t[i + 1]
        }
        return set.size
    }

    fun charCount(normalized: String): Int = normalized.length

    fun uniqueChars(normalized: String): Int = normalized.toSet().size

    fun entropy(normalized: String): Double {
        if (normalized.isEmpty()) return 0.0
        val counts = normalized.groupingBy { it }.eachCount()
        val n = normalized.length.toDouble()
        var h = 0.0
        for (c in counts.values) {
            val p = c / n
            h -= p * log2(p)
        }
        return h
    }

    fun palindrome(normalized: String): Boolean {
        val onlyAlnum = normalized.filter { it.isLetterOrDigit() }.lowercase()
        return onlyAlnum == onlyAlnum.reversed()
    }

    fun hash64(normalized: String): String = xxHash64(normalized.encodeToByteArray()).toULong().toString(16).padStart(16, '0')

    // Minimal pure Kotlin xxHash64 (seed=0)
    private fun xxHash64(data: ByteArray, seed: Long = 0L): Long {
        val PRIME64_1 = -7046029288634856825L // 11400714785074694791
        val PRIME64_2 = -4417276706812531889L // 14029467366897019727
        val PRIME64_3 = 1609587929392839161L
        val PRIME64_4 = -8796714831421723037L // 9650029242287828579
        val PRIME64_5 = 2870177450012600261L

        var hash: Long
        var idx = 0
        val len = data.size

        if (len >= 32) {
            var v1 = seed + PRIME64_1 + PRIME64_2
            var v2 = seed + PRIME64_2
            var v3 = seed + 0
            var v4 = seed - PRIME64_1

            while (idx <= len - 32) {
                v1 = round(v1, getLong(data, idx)); idx += 8
                v2 = round(v2, getLong(data, idx)); idx += 8
                v3 = round(v3, getLong(data, idx)); idx += 8
                v4 = round(v4, getLong(data, idx)); idx += 8
            }

            hash = java.lang.Long.rotateLeft(v1, 1) +
                   java.lang.Long.rotateLeft(v2, 7) +
                   java.lang.Long.rotateLeft(v3, 12) +
                   java.lang.Long.rotateLeft(v4, 18)

            hash = mergeRound(hash, v1)
            hash = mergeRound(hash, v2)
            hash = mergeRound(hash, v3)
            hash = mergeRound(hash, v4)
        } else {
            hash = seed + PRIME64_5
        }

        hash += len.toLong()

        while (idx <= len - 8) {
            val k1 = round(0, getLong(data, idx))
            hash = java.lang.Long.rotateLeft(hash xor k1, 27) * PRIME64_1 + PRIME64_4
            idx += 8
        }

        if (idx <= len - 4) {
            hash = java.lang.Long.rotateLeft(hash xor ((getInt(data, idx).toLong() and 0xffffffffL) * PRIME64_1), 23) * PRIME64_2 + PRIME64_3
            idx += 4
        }

        while (idx < len) {
            hash = java.lang.Long.rotateLeft(hash xor ((data[idx].toLong() and 0xff) * PRIME64_5), 11) * PRIME64_1
            idx++
        }

        hash = fmix64(hash)
        return hash
    }

    private fun round(acc: Long, input: Long): Long {
        val PRIME64_2 = -4417276706812531889L
        val PRIME64_1 = -7046029288634856825L
        var a = acc + (input * PRIME64_2)
        a = java.lang.Long.rotateLeft(a, 31)
        a *= PRIME64_1
        return a
    }

    private fun mergeRound(h: Long, v: Long): Long {
        val PRIME64_1 = -7046029288634856825L
        val PRIME64_4 = -8796714831421723037L
        var a = h xor round(0, v)
        a = a * PRIME64_1 + PRIME64_4
        return a
    }

    private fun fmix64(h0: Long): Long {
        val PRIME64_2 = -4417276706812531889L
        val PRIME64_3 = 1609587929392839161L
        var h = h0
        h = h xor (h ushr 33)
        h *= PRIME64_2
        h = h xor (h ushr 29)
        h *= PRIME64_3
        h = h xor (h ushr 32)
        return h
    }

    private fun getLong(b: ByteArray, i: Int): Long =
        (b[i].toLong() and 0xff) or
        ((b[i + 1].toLong() and 0xff) shl 8) or
        ((b[i + 2].toLong() and 0xff) shl 16) or
        ((b[i + 3].toLong() and 0xff) shl 24) or
        ((b[i + 4].toLong() and 0xff) shl 32) or
        ((b[i + 5].toLong() and 0xff) shl 40) or
        ((b[i + 6].toLong() and 0xff) shl 48) or
        ((b[i + 7].toLong() and 0xff) shl 56)

    private fun getInt(b: ByteArray, i: Int): Int =
        (b[i].toInt() and 0xff) or
        ((b[i + 1].toInt() and 0xff) shl 8) or
        ((b[i + 2].toInt() and 0xff) shl 16) or
        ((b[i + 3].toInt() and 0xff) shl 24)
}

