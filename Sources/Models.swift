import Foundation

/// Supported export file formats
public enum ExportFormat: String, CaseIterable {
    case txt = "Plain Text (.txt)"
    case markdown = "Markdown (.md)"
    case html = "HTML (.html)"
    
    public var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .markdown: return "md"
        case .html: return "html"
        }
    }
}

/// Represents an Apple Notes account (e.g., iCloud, On My Mac)
public struct AccountItem: Identifiable, Codable {
    public let id: String
    public let name: String
    public var folders: [FolderItem]
    
    public init(id: String, name: String, folders: [FolderItem] = []) {
        self.id = id
        self.name = name
        self.folders = folders
    }
}

/// Represents a folder or subfolder inside Apple Notes
public final class FolderItem: Identifiable, Codable {
    public let id: String
    public let name: String
    public let fullPath: String
    public var noteCount: Int
    public var subfolders: [FolderItem]
    
    public init(id: String, name: String, fullPath: String, noteCount: Int = 0, subfolders: [FolderItem] = []) {
        self.id = id
        self.name = name
        self.fullPath = fullPath
        self.noteCount = noteCount
        self.subfolders = subfolders
    }
}

/// Represents an individual note item
public final class NoteItem: Identifiable, Codable {
    public let id: String
    public var name: String
    public var folderName: String
    public var folderPath: String
    public var accountName: String
    public var modificationDate: Date?
    public var creationDate: Date?
    public var isSelected: Bool = false
    
    public init(id: String, name: String, folderName: String, folderPath: String, accountName: String, modificationDate: Date? = nil, creationDate: Date? = nil, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.folderName = folderName
        self.folderPath = folderPath
        self.accountName = accountName
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.isSelected = isSelected
    }
}

/// Export configuration options selected by the user
public struct ExportConfig {
    public var destinationURL: URL
    public var format: ExportFormat
    public var preserveFolderHierarchy: Bool
    public var includeMetadataHeader: Bool
    
    public init(destinationURL: URL, format: ExportFormat = .txt, preserveFolderHierarchy: Bool = true, includeMetadataHeader: Bool = true) {
        self.destinationURL = destinationURL
        self.format = format
        self.preserveFolderHierarchy = preserveFolderHierarchy
        self.includeMetadataHeader = includeMetadataHeader
    }
}

/// Progress state during export
public struct ExportProgress {
    public var totalCount: Int
    public var currentCount: Int
    public var currentNoteName: String
    public var isFinished: Bool
    public var errorCount: Int
    
    public var fractionCompleted: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(currentCount) / Double(totalCount)
    }
}
