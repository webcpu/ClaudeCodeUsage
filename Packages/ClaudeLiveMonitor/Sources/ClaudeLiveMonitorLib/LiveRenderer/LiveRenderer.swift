//
//  LiveRenderer.swift
//
//  Terminal-based live usage dashboard renderer.
//  Split into extensions for focused responsibilities:
//    - +Terminal: Layout constants, ANSI colors, progress bar
//    - +Metrics: Session, usage, and projection metrics
//

import Foundation

// MARK: - LiveRenderer

public class LiveRenderer {
    private let monitor: LiveMonitor
    private let tokenLimit: Int?

    public init(monitor: LiveMonitor, tokenLimit: Int?) {
        self.monitor = monitor
        self.tokenLimit = tokenLimit
    }

    public func render() async {
        guard let block = await monitor.getActiveBlock() else {
            print("No active session found.")
            return
        }

        let autoLimit = await monitor.getAutoTokenLimit()
        let effectiveLimit = tokenLimit ?? autoLimit ?? 0

        Terminal.clearScreen()
        renderDashboard(block: block, tokenLimit: effectiveLimit)
    }

    private func renderDashboard(block: SessionBlock, tokenLimit: Int) {
        renderHeader()
        renderSection { renderSessionContent(block: block) }
        renderSection { renderUsageContent(block: block, tokenLimit: tokenLimit) }
        renderSection { renderProjectionContent(block: block, tokenLimit: tokenLimit) }
        renderModelsRow(models: block.models)
        renderFooter()
    }
}

// MARK: - Dashboard Layout

extension LiveRenderer {
    func renderHeader() {
        printBorderRow(.top)
        printContentRow(Layout.title.centered(in: Layout.contentWidth))
        printBorderRow(.middle)
    }

    func renderSection(_ content: () -> Void) {
        printEmptyRow()
        content()
        printEmptyRow()
        printBorderRow(.middle)
    }

    func renderModelsRow(models: [String]) {
        let modelsText = models.joined(separator: ", ")
        let formatted = " \(Layout.modelsIcon)  Models: \(modelsText)"
        printContentRow(formatted.padded(to: Layout.contentWidth))
        printBorderRow(.middle)
    }

    func renderFooter() {
        printContentRow(Layout.footerText.centered(in: Layout.contentWidth))
        printBorderRow(.bottom)
    }
}

// MARK: - Section Content Renderers

extension LiveRenderer {
    func renderSessionContent(block: SessionBlock) {
        let session = SessionMetrics(block: block)
        let progressBar = ProgressBar.build(
            percentage: session.percentage,
            color: .green
        )
        printContentRow(" \(Layout.sessionIcon)  SESSION  [\(progressBar)]  \(session.percentage.formatted)%")
        printContentRow("   Started: \(session.startTimeFormatted)  Elapsed: \(session.elapsedFormatted)  Remaining: \(session.remainingFormatted) (\(session.endTimeFormatted))")
    }

    func renderUsageContent(block: SessionBlock, tokenLimit: Int) {
        let usage = UsageMetrics(block: block, tokenLimit: tokenLimit)
        let progressBar = ProgressBar.build(
            percentage: usage.percentage,
            color: usage.percentage.progressColor
        )
        printContentRow(" \(Layout.usageIcon)  USAGE (session)  [\(progressBar)]  \(usage.percentage.formatted)% (\(usage.tokensShort))")
        printContentRow("   Tokens: \(usage.tokensFormatted)  Burn Rate: \(usage.burnRateFormatted) token/min \(usage.burnIndicator)")
        printContentRow("   Cost: $\(String(format: "%.2f", block.costUSD))")
    }

    func renderProjectionContent(block: SessionBlock, tokenLimit: Int) {
        let projection = ProjectionMetrics(block: block, tokenLimit: tokenLimit)
        let progressBar = ProgressBar.build(
            percentage: projection.percentage,
            color: .red
        )
        printContentRow(" \(Layout.projectionIcon)  PROJECTION [\(progressBar)]  \(projection.percentage.formatted)% (\(projection.tokensShort)/\(projection.limitShort))")
        printContentRow("   Status: \(projection.status)  Tokens: \(projection.tokensFormatted)  Cost: $\(String(format: "%.2f", block.projectedUsage.totalCost))")
    }
}

// MARK: - Print Helpers

extension LiveRenderer {
    func printBorderRow(_ position: BorderPosition) {
        let (left, right) = position.corners
        print(" \(left)\(Layout.divider)\(right)")
    }

    func printContentRow(_ content: String) {
        print(" \(Layout.verticalBorder)\(content.padded(to: Layout.contentWidth))\(Layout.verticalBorder)")
    }

    func printEmptyRow() {
        printContentRow("")
    }
}
