import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ExerciseMediaError: Error, Equatable {
    case unreadableImage
    case unsupportedMedia
    case assetNotFound
}

actor ExerciseMediaLibrary {
    nonisolated let rootDirectory: URL
    private let fileManager: FileManager
    private let uuid: any UUIDGenerating

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        uuid: any UUIDGenerating
    ) throws {
        self.fileManager = fileManager
        self.uuid = uuid
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            self.rootDirectory = try Self.defaultRootDirectory(fileManager: fileManager)
        }
        try fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    nonisolated static func defaultRootDirectory(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support
            .appending(path: "DogCoachStudio", directoryHint: .isDirectory)
            .appending(path: "ExerciseMedia", directoryHint: .isDirectory)
    }

    func assets(exerciseID: UUID) throws -> [ExerciseMediaAsset] {
        try loadManifest().filter { $0.exerciseID == exerciseID }.sorted { $0.createdAt < $1.createdAt }
    }

    func addPhoto(data: Data, exerciseID: UUID, at date: Date = .now) throws -> ExerciseMediaAsset {
        guard let normalized = Self.downsampledJPEG(data: data, maxPixelSize: 2_048) else {
            throw ExerciseMediaError.unreadableImage
        }
        let id = uuid.makeUUID()
        let fileName = "\(id.uuidString).jpg"
        try normalized.write(to: rootDirectory.appending(path: fileName), options: [.atomic, .completeFileProtection])
        return try appendAsset(id: id, exerciseID: exerciseID, kind: .photo, fileName: fileName, date: date)
    }

    func addVideo(from sourceURL: URL, exerciseID: UUID, at date: Date = .now) throws -> ExerciseMediaAsset {
        let type = UTType(filenameExtension: sourceURL.pathExtension)
        guard type?.conforms(to: .movie) == true else { throw ExerciseMediaError.unsupportedMedia }
        let id = uuid.makeUUID()
        let fileName = "\(id.uuidString).\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension.lowercased())"
        let destination = rootDirectory.appending(path: fileName)
        try fileManager.copyItem(at: sourceURL, to: destination)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
        return try appendAsset(id: id, exerciseID: exerciseID, kind: .video, fileName: fileName, date: date)
    }

    func remove(_ asset: ExerciseMediaAsset) throws {
        var manifest = try loadManifest()
        guard let index = manifest.firstIndex(where: { $0.id == asset.id }) else {
            throw ExerciseMediaError.assetNotFound
        }
        let removed = manifest.remove(at: index)
        let url = rootDirectory.appending(path: removed.fileName)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        try saveManifest(manifest)
    }

    nonisolated func fileURL(for asset: ExerciseMediaAsset) -> URL {
        rootDirectory.appending(path: asset.fileName)
    }

    private func appendAsset(id: UUID, exerciseID: UUID, kind: ExerciseMediaKind, fileName: String, date: Date) throws -> ExerciseMediaAsset {
        let asset = ExerciseMediaAsset(id: id, exerciseID: exerciseID, kind: kind, fileName: fileName, createdAt: date)
        var manifest = try loadManifest()
        manifest.append(asset)
        do {
            try saveManifest(manifest)
            return asset
        } catch {
            try? fileManager.removeItem(at: rootDirectory.appending(path: fileName))
            throw error
        }
    }

    private var manifestURL: URL { rootDirectory.appending(path: "manifest.json") }

    private func loadManifest() throws -> [ExerciseMediaAsset] {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return [] }
        return try JSONDecoder().decode([ExerciseMediaAsset].self, from: Data(contentsOf: manifestURL))
    }

    private func saveManifest(_ assets: [ExerciseMediaAsset]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(assets).write(to: manifestURL, options: [.atomic, .completeFileProtection])
    }

    private static func downsampledJPEG(data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let writer = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(writer, image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(writer) else { return nil }
        return output as Data
    }
}
