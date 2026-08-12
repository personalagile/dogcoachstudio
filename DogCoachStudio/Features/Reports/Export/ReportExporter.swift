import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum ReportPaperSize: Sendable { case a4, letter
    var rect: CGRect { switch self { case .a4: CGRect(x: 0, y: 0, width: 595.2, height: 841.8); case .letter: CGRect(x: 0, y: 0, width: 612, height: 792) } }
}

struct ReportExportArtifact: Sendable { let filename: String; let mimeType: String; let data: Data }

enum ReportExporter {
    static func text(_ report: ComposedReport, filename: String = "training-report.txt") -> ReportExportArtifact { .init(filename: filename, mimeType: "text/plain", data: Data(report.plainText.utf8)) }

    @MainActor static func pdf(_ report: ComposedReport, paper: ReportPaperSize, branding: String? = nil, filename: String = "training-report.pdf") -> ReportExportArtifact {
        let bounds = paper.rect; let margin: CGFloat = 54; let content = ([branding, report.plainText].compactMap { $0 }.joined(separator: "\n\n")) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            let available = CGRect(x: margin, y: margin, width: bounds.width - margin * 2, height: bounds.height - margin * 2)
            let storage = NSTextStorage(string: content as String, attributes: attributes); let manager = NSLayoutManager(); storage.addLayoutManager(manager)
            var glyph = 0
            while glyph < manager.numberOfGlyphs {
                context.beginPage()
                let container = NSTextContainer(size: available.size); container.lineFragmentPadding = 0; manager.addTextContainer(container)
                let range = manager.glyphRange(for: container); manager.drawGlyphs(forGlyphRange: range, at: available.origin); glyph = NSMaxRange(range)
            }
        }
        return .init(filename: filename, mimeType: "application/pdf", data: data)
    }
}

struct ReportShareDocument: Transferable, Sendable {
    let artifact: ReportExportArtifact
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.artifact.data }
            .suggestedFileName { $0.artifact.filename }
    }
}

struct ReportShareButton: View {
    let artifact: ReportExportArtifact
    var body: some View {
        ShareLink(item: ReportShareDocument(artifact: artifact), preview: SharePreview(artifact.filename)) {
            Label("Share report", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("reportShareButton")
    }
}
