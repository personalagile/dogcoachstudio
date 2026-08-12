import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct IntakePDFArtifact: Equatable, Sendable {
    let filename: String
    let data: Data
}

enum IntakePDFExporter {
    @MainActor
    static func pdf(
        draft: IntakeDraft,
        dogName: String,
        clientName: String?
    ) -> IntakePDFArtifact {
        let bounds = ReportPaperSize.a4.rect
        let margin: CGFloat = 54
        let title = String(localized: "Intake for \(dogName)")
        let subtitle = [clientName, draft.occurredAt.formatted(date: .long, time: .omitted)]
            .compactMap { $0 }
            .joined(separator: " · ")
        let fields: [(String, String)] = [
            (String(localized: "Reason for training"), draft.clientFacing.reason),
            (String(localized: "Environment"), draft.clientFacing.environment),
            (String(localized: "History"), draft.clientFacing.history),
            (String(localized: "Known triggers"), draft.clientFacing.knownTriggers),
            (String(localized: "Previous training"), draft.clientFacing.previousTraining),
            (String(localized: "Health notes"), draft.clientFacing.healthNotes),
            (String(localized: "Desired outcome"), draft.clientFacing.desiredOutcome)
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 8
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "\(title)\n", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]))
        attributed.append(NSAttributedString(string: "\(subtitle)\n\n", attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraph
        ]))
        for (label, value) in fields where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributed.append(NSAttributedString(string: "\(label)\n", attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]))
            attributed.append(NSAttributedString(string: "\(value)\n\n", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]))
        }
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            let available = CGRect(x: margin, y: margin, width: bounds.width - margin * 2, height: bounds.height - margin * 2)
            let storage = NSTextStorage(attributedString: attributed)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            var glyph = 0
            while glyph < manager.numberOfGlyphs {
                context.beginPage()
                let container = NSTextContainer(size: available.size)
                container.lineFragmentPadding = 0
                manager.addTextContainer(container)
                let range = manager.glyphRange(for: container)
                manager.drawGlyphs(forGlyphRange: range, at: available.origin)
                glyph = NSMaxRange(range)
            }
        }
        return IntakePDFArtifact(
            filename: "intake-\(safeFilename(dogName)).pdf",
            data: data
        )
    }

    private static func safeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(result).lowercased()
    }
}

struct IntakeShareDocument: Transferable, Sendable {
    let artifact: IntakePDFArtifact

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.artifact.data }
            .suggestedFileName { $0.artifact.filename }
    }
}

struct IntakeShareButton: View {
    let artifact: IntakePDFArtifact

    var body: some View {
        ShareLink(item: IntakeShareDocument(artifact: artifact), preview: SharePreview(artifact.filename)) {
            Label("Share intake PDF", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("intakeShareButton")
    }
}
