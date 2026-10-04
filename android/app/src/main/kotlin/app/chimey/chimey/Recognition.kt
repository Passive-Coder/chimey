package app.chimey.chimey

import org.json.JSONArray
import kotlin.math.sqrt

/** Service-side gate keeps capture and actions working without a Flutter isolate. */
object Recognition {
    fun cosine(a: List<Double>, b: List<Double>): Double {
        if (a.isEmpty() || a.size != b.size || a.any { !it.isFinite() } || b.any { !it.isFinite() }) return -1.0
        var dot=0.0; var aa=0.0; var bb=0.0
        a.indices.forEach { dot+=a[it]*b[it]; aa+=a[it]*a[it]; bb+=b[it]*b[it] }
        val result=dot/sqrt(aa*bb)
        return if(result.isFinite()) result.coerceIn(-1.0,1.0) else -1.0
    }
    fun match(features: List<Double>, profiles: JSONArray): Pair<Int, Double>? {
        val candidates = mutableListOf<Pair<Int,Double>>()
        for (i in 0 until profiles.length()) {
            val p=profiles.getJSONObject(i)
            if(!p.optBoolean("enabled") || !p.optBoolean("validated") || p.optString("featureModel")!="yamnet-embedding-v1") continue
            val examples=p.getJSONArray("examples")
            if(examples.length()<3) continue
            var score=-1.0
            for(j in 0 until examples.length()) {
                val v=examples.getJSONArray(j)
                score=maxOf(score,cosine(features,List(v.length()){v.getDouble(it)}))
            }
            val threshold=p.optDouble("threshold",1.0)
            if(threshold.isFinite() && threshold>0 && threshold<=1) candidates.add(i to score)
        }
        candidates.sortByDescending{it.second}
        if(candidates.size>1 && candidates[0].second-candidates[1].second<.05) return null
        val winner=candidates.firstOrNull() ?: return null
        return if(winner.second>=profiles.getJSONObject(winner.first).getDouble("threshold")) winner else null
    }
}
