import Foundation

struct ContentPerformanceScore {
    let contentType: String
    let objective: String
    let pillar: String
    let engagementRate: Double
    let reachPerPost: Double
    let publicationCount: Int
}

struct PerformanceRecommendation {
    let recommendedContentType: String
    let recommendedObjective: String
    let recommendedPillar: String
    let reason: String
    let engagementBenchmark: Double
}

enum ContentPerformanceAnalyzer {
    
    static func analyzeByContentType(
        analytics: [SocialContentAnalytics]
    ) -> [String: (avgEngagementRate: Double, count: Int)] {
        var typeMetrics: [String: (engagementSum: Double, count: Int)] = [:]
        
        for item in analytics {
            let type = item.contentType
            let currentMetrics = typeMetrics[type] ?? (engagementSum: 0, count: 0)
            typeMetrics[type] = (
                engagementSum: currentMetrics.engagementSum + item.engagementRate,
                count: currentMetrics.count + 1
            )
        }
        
        var results: [String: (avgEngagementRate: Double, count: Int)] = [:]
        for (type, metrics) in typeMetrics {
            let avgEngagement = metrics.count > 0 ? metrics.engagementSum / Double(metrics.count) : 0
            results[type] = (avgEngagementRate: avgEngagement, count: metrics.count)
        }
        
        return results
    }
    
    static func analyzeByObjective(
        analytics: [SocialContentAnalytics]
    ) -> [String: (avgEngagementRate: Double, count: Int)] {
        var objectiveMetrics: [String: (engagementSum: Double, count: Int)] = [:]
        
        for item in analytics {
            let objective = item.objective
            let currentMetrics = objectiveMetrics[objective] ?? (engagementSum: 0, count: 0)
            objectiveMetrics[objective] = (
                engagementSum: currentMetrics.engagementSum + item.engagementRate,
                count: currentMetrics.count + 1
            )
        }
        
        var results: [String: (avgEngagementRate: Double, count: Int)] = [:]
        for (objective, metrics) in objectiveMetrics {
            let avgEngagement = metrics.count > 0 ? metrics.engagementSum / Double(metrics.count) : 0
            results[objective] = (avgEngagementRate: avgEngagement, count: metrics.count)
        }
        
        return results
    }
    
    static func analyzeByPillar(
        analytics: [SocialContentAnalytics]
    ) -> [String: (avgEngagementRate: Double, count: Int)] {
        var pillarMetrics: [String: (engagementSum: Double, count: Int)] = [:]
        
        for item in analytics {
            let pillar = item.pillar
            let currentMetrics = pillarMetrics[pillar] ?? (engagementSum: 0, count: 0)
            pillarMetrics[pillar] = (
                engagementSum: currentMetrics.engagementSum + item.engagementRate,
                count: currentMetrics.count + 1
            )
        }
        
        var results: [String: (avgEngagementRate: Double, count: Int)] = [:]
        for (pillar, metrics) in pillarMetrics {
            let avgEngagement = metrics.count > 0 ? metrics.engagementSum / Double(metrics.count) : 0
            results[pillar] = (avgEngagementRate: avgEngagement, count: metrics.count)
        }
        
        return results
    }
    
    static func generateRecommendation(
        from analytics: [SocialContentAnalytics],
        recentlyUsedType: String?,
        recentlyUsedObjective: String?,
        recentlyUsedPillar: String?
    ) -> PerformanceRecommendation {
        
        guard !analytics.isEmpty else {
            return PerformanceRecommendation(
                recommendedContentType: "Reel",
                recommendedObjective: "Alcance",
                recommendedPillar: "Autoridade de pista",
                reason: "Sem dados de performance ainda. Comece com Reels focado em alcance.",
                engagementBenchmark: 0
            )
        }
        
        let typeAnalysis = analyzeByContentType(analytics: analytics)
        let objectiveAnalysis = analyzeByObjective(analytics: analytics)
        let pillarAnalysis = analyzeByPillar(analytics: analytics)
        
        // Find best performing content type
        let bestType = typeAnalysis.max { $0.value.avgEngagementRate < $1.value.avgEngagementRate }?.key ?? "Reel"
        let bestTypeEngagement = typeAnalysis[bestType]?.avgEngagementRate ?? 0
        
        // Find best performing objective
        let bestObjective = objectiveAnalysis.max { $0.value.avgEngagementRate < $1.value.avgEngagementRate }?.key ?? "Alcance"
        let bestObjectiveEngagement = objectiveAnalysis[bestObjective]?.avgEngagementRate ?? 0
        
        // Find best performing pillar
        let bestPillar = pillarAnalysis.max { $0.value.avgEngagementRate < $1.value.avgEngagementRate }?.key ?? "Autoridade de pista"
        let bestPillarEngagement = pillarAnalysis[bestPillar]?.avgEngagementRate ?? 0
        
        let overallBenchmark = (bestTypeEngagement + bestObjectiveEngagement + bestPillarEngagement) / 3
        
        // Build reason
        let typeCount = typeAnalysis[bestType]?.count ?? 0
        let pillarCount = pillarAnalysis[bestPillar]?.count ?? 0
        
        let reason = "\(bestType) com objetivo \(bestObjective) focado em \(bestPillar) teve \(String(format: "%.1f", bestTypeEngagement))% engagement em \(typeCount) tentativas. Pillar obteve \(String(format: "%.1f", bestPillarEngagement))% em \(pillarCount) conteúdos."
        
        return PerformanceRecommendation(
            recommendedContentType: bestType,
            recommendedObjective: bestObjective,
            recommendedPillar: bestPillar,
            reason: reason,
            engagementBenchmark: overallBenchmark
        )
    }
    
    static func identifyUnderperforming(
        analytics: [SocialContentAnalytics],
        threshold: Double = 2.0
    ) -> [(contentType: String, avgEngagement: Double, count: Int)] {
        let typeAnalysis = analyzeByContentType(analytics: analytics)
        
        let overallAvg = typeAnalysis.values.reduce(0) { $0 + $1.avgEngagementRate } / Double(max(1, typeAnalysis.count))
        
        let underperforming = typeAnalysis.filter { $0.value.avgEngagementRate < (overallAvg - threshold) }
            .map { (contentType: $0.key, avgEngagement: $0.value.avgEngagementRate, count: $0.value.count) }
        
        return underperforming
    }
}
