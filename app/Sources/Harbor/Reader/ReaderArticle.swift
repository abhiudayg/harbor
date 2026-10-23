struct ReaderArticle: Equatable {
    enum Block: Equatable {
        case dropCap(String)
        case paragraph(String)
        case pullQuote(text: String, source: String)
        case heading(String)
        case metrics([Metric])
        case code(CodeBlock)
        case footnote(Footnote)
    }

    enum Tone: Equatable {
        case accent
        case positive
    }

    struct Metric: Equatable, Identifiable {
        let index: String
        let title: String
        let detail: String
        let baselineLabel: String
        let baseline: String
        let tone: Tone

        var id: String { index }
    }

    enum CodeRole: Equatable {
        case plain
        case keyword
        case name
        case string
        case literal
        case approval
        case completed
        case failed
    }

    struct CodeToken: Equatable {
        let text: String
        let role: CodeRole
    }

    struct CodeBlock: Equatable {
        let fileName: String
        let language: String
        let lines: [[CodeToken]]
    }

    struct Footnote: Equatable {
        let number: Int
        let lead: String
        let title: String
        let trail: String
    }

    let kicker: String
    let section: String
    let title: String
    let author: String
    let reviewer: String
    let published: String
    let readingTime: String
    let blocks: [Block]
    let nextInQueue: String

    static let cognitiveErgonomics = ReaderArticle(
        kicker: "Research Archive",
        section: "Cognitive Ergonomics",
        title: "The Architecture of Quiet Interfaces: Why Power Users Crave Visual Restraint",
        author: "Dr. Elena Vance",
        reviewer: "Systems Guild",
        published: "Published Nov 14, 2024",
        readingTime: "9 min read",
        blocks: [
            .dropCap("Every decorative flourish introduced to a technical application carries a persistent thermodynamic cognitive tax. When an interface relies on vibrating gradients, erratic multi-tiered elevation shadows, and unmetered notifications, the user's executive function spends precious working memory constantly parsing chrome rather than processing thought."),
            .paragraph("The ethos of desktop computing has drifted toward superficial theatrics. Yet the master craftsman’s bench is not lined with polished brass or mirrored chrome; it is constructed of dense, oiled birch, marked only by hairline measurements and functional recesses where tools can rest without slipping."),
            .pullQuote(
                text: "Restraint is not the absence of energy; it is the deliberate containment of noise so that signal can resonate without friction.",
                source: "Systems Architecture Monograph, Vol. IV"
            ),
            .heading("1. Spatial Discipline & The 1px Hairline"),
            .paragraph("In Harbor, depth is never faked with sprawling blurred drop shadows. Boundaries are established exclusively through tonal stepping and physical single-pixel hairlines. When visual divisions are predictable and razor-sharp, the eye traverses workspaces with zero hesitation."),
            .metrics([
                Metric(
                    index: "Metric 01",
                    title: "Cognitive Saccade Latency",
                    detail: "Hairline delineations reduce ocular search cycles by 38% compared to multi-radius drop shadows across dense information trees.",
                    baselineLabel: "Baseline: 180ms",
                    baseline: "Harbor: 112ms",
                    tone: .accent
                ),
                Metric(
                    index: "Metric 02",
                    title: "Spatial Working Memory",
                    detail: "Persistent sidebar docking anchors cognitive spatial orientation, eliminating context thrashing when hopping between nested files.",
                    baselineLabel: "Retention rate",
                    baseline: "94.2% stability",
                    tone: .positive
                ),
            ]),
            .heading("2. Monospaced Precision in Document Scaffolding"),
            .paragraph("When technical operators navigate reference literature, code annotations must sit comfortably alongside proportional prose. Notice how JetBrains Mono preserves structural cadence without disrupting the vertical typographic rhythm:"),
            .code(CodeBlock(
                fileName: "ergonomics.config.ts",
                language: "TypeScript",
                lines: [
                    [.init(text: "interface", role: .keyword), .init(text: " ", role: .plain), .init(text: "ViewportConstraint", role: .name), .init(text: " {", role: .plain)],
                    [.init(text: "  readonly maxReadingWidth: ", role: .plain), .init(text: "\"68ch\"", role: .string), .init(text: ";", role: .plain)],
                    [.init(text: "  readonly baseElevation: ", role: .plain), .init(text: "\"hairline-1px\"", role: .string), .init(text: ";", role: .plain)],
                    [.init(text: "  readonly chromelessTolerance: ", role: .plain), .init(text: "true", role: .literal), .init(text: ";", role: .plain)],
                    [.init(text: "  readonly stateBadges: {", role: .plain)],
                    [.init(text: "    approvalNeeded: ", role: .plain), .init(text: "\"#b45309\"", role: .approval), .init(text: ";", role: .plain)],
                    [.init(text: "    completed: ", role: .plain), .init(text: "\"#005823\"", role: .completed), .init(text: ";", role: .plain)],
                    [.init(text: "    failed: ", role: .plain), .init(text: "\"#ba1a1a\"", role: .failed), .init(text: ";", role: .plain)],
                    [.init(text: "  };", role: .plain)],
                    [.init(text: "}", role: .plain)],
                ]
            )),
            .paragraph("By restricting the visual spectrum to a foundational warm paper neutral (#F9F9FC), a deliberate harbor teal accent, and purposeful semantic state indicators, the screen recedes entirely into the periphery. The user ceases to look at the browser; they think directly through the document."),
            .footnote(Footnote(
                number: 1,
                lead: "Elena Vance, ",
                title: "The Disappearance of the Browser Frame",
                trail: ", Systems Journal of Cognitive Ergonomics, Issue 14, Zurich Press, 2024."
            )),
        ],
        nextInQueue: "Distributed Consensus Protocols"
    )

    var footnotes: [Footnote] {
        blocks.compactMap {
            if case .footnote(let note) = $0 {
                return note
            }
            return nil
        }
    }

    var plainText: String {
        let parts = blocks.compactMap { block -> String? in
            switch block {
            case .dropCap(let text), .paragraph(let text), .heading(let text):
                text
            case .pullQuote(let text, _):
                text
            case .metrics(let metrics):
                metrics.map { "\($0.title)\n\($0.detail)" }.joined(separator: "\n\n")
            case .footnote(let note):
                note.lead + note.title + note.trail
            case .code:
                nil
            }
        }
        return ([title] + parts).joined(separator: "\n\n")
    }
}
