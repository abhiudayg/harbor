struct ReaderArticle: Equatable {
    struct Metric: Equatable, Identifiable {
        let index: String
        let title: String
        let lines: [String]

        var id: String { index }
    }

    let kicker: String
    let title: String
    let author: String
    let reviewer: String
    let published: String
    let readingTime: String
    let paragraphs: [String]
    let pullQuote: String
    let pullQuoteSource: String
    let metrics: [Metric]
    let codeCaption: String
    let codeSample: String
    let footnotes: [String]
    let nextInQueue: String

    static let cognitiveErgonomics = ReaderArticle(
        kicker: "Research Archive",
        title: "The Architecture of Quiet Interfaces: Why Power Users Crave Visual Restraint",
        author: "Dr. Elena Vance",
        reviewer: "Systems Guild",
        published: "Published Nov 14, 2024",
        readingTime: "9 min read",
        paragraphs: [
            "Every decorative flourish introduced to a technical application carries a persistent thermodynamic cognitive tax. When an interface relies on vibrating gradients, erratic multi-tiered elevation shadows, and unmetered notifications, the user's executive function spends precious working memory constantly parsing chrome rather than processing thought.",
            "The ethos of desktop computing has drifted toward superficial theatrics. Yet the master craftsman’s bench is not lined with polished brass or mirrored chrome; it is constructed of dense, oiled birch, marked only by hairline measurements and functional recesses where tools can rest without slipping.",
            "In Harbor, depth is never faked with sprawling blurred drop shadows. Boundaries are established exclusively through tonal stepping and physical single-pixel hairlines. When visual divisions are predictable and razor-sharp, the eye traverses workspaces with zero hesitation.",
            "By restricting the visual spectrum to a foundational warm paper neutral, a deliberate harbor teal accent, and purposeful semantic state indicators, the screen recedes entirely into the periphery. The user ceases to look at the browser; they think directly through the document.",
        ],
        pullQuote: "Restraint is not the absence of energy; it is the deliberate containment of noise so that signal can resonate without friction.",
        pullQuoteSource: "Systems Architecture Monograph, Vol. IV",
        metrics: [
            Metric(index: "Metric 01", title: "Cognitive Saccade Latency", lines: ["Baseline: 180ms", "Harbor: 112ms"]),
            Metric(index: "Metric 02", title: "Spatial Working Memory", lines: ["Retention rate", "94.2% stability"]),
        ],
        codeCaption: "ergonomics.config.ts · TypeScript",
        codeSample: "interface ViewportConstraint { maxLine: \"68ch\"; divider: \"hairline-1px\"; shadows: false; accent: \"#b45309\"; success: \"#005823\"; error: \"#ba1a1a\"; }",
        footnotes: ["The Disappearance of the Browser Frame"],
        nextInQueue: "The Disappearance of the Browser Frame"
    )

    var plainText: String {
        ([title] + paragraphs).joined(separator: "\n\n")
    }
}
