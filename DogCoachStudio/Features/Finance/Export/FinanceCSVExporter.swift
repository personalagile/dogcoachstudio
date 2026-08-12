import Foundation

struct FinanceCSVFile: Sendable {
    let filename: String
    let data: Data
}

enum FinanceCSVExporter {
    static func export(_ snapshot: FinanceSnapshot) -> FinanceCSVFile {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let header = "date,client,package,packageTemplate,amount,currencyCode"
        let rows = snapshot.transactions.map { event in
            [
                formatter.string(from: event.date),
                escape(event.clientName),
                escape(event.packageName),
                escape(event.packageTemplateName ?? ""),
                String(describing: event.amount),
                event.currencyCode
            ].joined(separator: ",")
        }
        let filename = "finance-\(snapshot.period.rawValue)-\(snapshot.currencyCode.lowercased()).csv"
        return FinanceCSVFile(filename: filename, data: Data(([header] + rows).joined(separator: "\n").utf8))
    }

    static func temporaryURL(for snapshot: FinanceSnapshot) throws -> URL {
        let file = export(snapshot)
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DogCoachStudio-Finance", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: file.filename)
        try file.data.write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
