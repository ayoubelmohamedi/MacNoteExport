import Foundation

public final class NotesBridge {
    public static let shared = NotesBridge()
    
    private init() {}
    
    /// Executes an AppleScript via /usr/bin/osascript and returns stdout string
    public func executeAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown AppleScript error"
            throw NSError(
                domain: "NotesBridge",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMsg.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }
        
        return String(data: outputData, encoding: .utf8) ?? ""
    }
    
    /// Fetches all accounts and folders with note counts rapidly via vectorized AppleScript
    public func fetchAccountsAndFolders() throws -> [AccountItem] {
        let script = """
        on scanFolder(f, parentPath, accName)
            tell application "Notes"
                set fName to name of f
                set fId to id of f
                set nCount to count of notes of f
                if parentPath is "" then
                    set curPath to fName
                else
                    set curPath to parentPath & "/" & fName
                end if
                set fInfo to (accName & "|||" & fName & "|||" & fId & "|||" & nCount & "|||" & curPath)
                set subOut to {fInfo}
                
                repeat with subF in folders of f
                    set subResults to my scanFolder(subF, curPath, accName)
                    set subOut to subOut & subResults
                end repeat
                return subOut
            end tell
        end scanFolder

        tell application "Notes"
            set out to {}
            repeat with acc in accounts
                set accName to name of acc
                repeat with topF in folders of acc
                    set folderList to my scanFolder(topF, "", accName)
                    set out to out & folderList
                end repeat
            end repeat
            
            set AppleScript's text item delimiters to "###"
            return out as text
        end tell
        """
        
        let raw = try executeAppleScript(script)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let folderEntries = trimmed.components(separatedBy: "###")
        var accountsMap: [String: [FolderItem]] = [:]
        
        for entry in folderEntries {
            let parts = entry.components(separatedBy: "|||")
            guard parts.count >= 4 else { continue }
            let accName = parts[0]
            let fName = parts[1]
            let fId = parts[2]
            let nCount = Int(parts[3]) ?? 0
            let fPath = (parts.count >= 5) ? parts[4] : fName
            
            let item = FolderItem(
                id: fId,
                name: fName,
                fullPath: fPath,
                noteCount: nCount,
                subfolders: []
            )
            
            accountsMap[accName, default: []].append(item)
        }
        
        return accountsMap.map { (accName, folders) in
            AccountItem(id: accName, name: accName, folders: folders)
        }
    }
    
    /// Flattens folder list
    public func flattenFolders(_ folders: [FolderItem]) -> [FolderItem] {
        return folders
    }
    
    /// Fetches all notes inside a single folder (takes ~0.25s)
    public func fetchNotesForFolder(folderId: String, folderPath: String, accountName: String) throws -> [NoteItem] {
        let escapedId = folderId.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Notes"
            set f to folder id "\(escapedId)"
            set nIDs to id of notes of f
            set nNames to name of notes of f
            set out to {}
            repeat with i from 1 to count of nIDs
                set end of out to (item i of nIDs & "|||" & item i of nNames)
            end repeat
            set AppleScript's text item delimiters to "###"
            return out as text
        end tell
        """
        
        let raw = try executeAppleScript(script)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let noteEntries = trimmed.components(separatedBy: "###")
        let fName = folderPath.components(separatedBy: "/").last ?? "Notes"
        
        return noteEntries.compactMap { entry in
            let parts = entry.components(separatedBy: "|||")
            guard parts.count >= 2 else { return nil }
            let id = parts[0]
            let name = parts[1].isEmpty ? "Untitled Note" : parts[1]
            return NoteItem(
                id: id,
                name: name,
                folderName: fName,
                folderPath: folderPath,
                accountName: accountName
            )
        }
    }
    
    /// Fetches notes across all specified folders
    public func fetchAllNotes(folders: [FolderItem], progress: ((Int, Int) -> Void)? = nil) -> [NoteItem] {
        var allNotes: [NoteItem] = []
        let nonZeroFolders = folders.filter { $0.noteCount > 0 }
        let total = nonZeroFolders.count
        
        for (idx, f) in nonZeroFolders.enumerated() {
            progress?(idx + 1, total)
            if let notes = try? fetchNotesForFolder(folderId: f.id, folderPath: f.fullPath, accountName: "") {
                allNotes.append(contentsOf: notes)
            }
        }
        return allNotes
    }
    
    /// Fetches both HTML body and plaintext for a specific note in a single fast AppleScript call
    public func fetchNoteContent(noteId: String) throws -> (plaintext: String, body: String) {
        let escapedId = noteId.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Notes"
            set theNote to note id "\(escapedId)"
            set pText to plaintext of theNote
            set hBody to body of theNote
            return hBody & "<---NOTEEXPORT-DIVIDER--->" & pText
        end tell
        """
        
        let output = try executeAppleScript(script)
        let parts = output.components(separatedBy: "<---NOTEEXPORT-DIVIDER--->")
        
        if parts.count >= 2 {
            let body = parts[0]
            let plaintext = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return (plaintext, body)
        } else {
            return (output.trimmingCharacters(in: .whitespacesAndNewlines), output)
        }
    }
    
    /// Sanitizes filename for filesystem safety
    public static func sanitizeFilename(_ name: String) -> String {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { clean = "Untitled Note" }
        
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\0\n\r\t")
        clean = clean.components(separatedBy: illegal).joined(separator: "-")
        
        if clean.count > 120 {
            clean = String(clean.prefix(120)).trimmingCharacters(in: .whitespaces)
        }
        if clean == "." || clean == ".." || clean == "-" {
            clean = "Note"
        }
        return clean
    }
    
    /// Exports note to destination folder
    public func exportNote(_ note: NoteItem, config: ExportConfig) throws -> URL {
        let (rawPlaintext, rawBody) = try fetchNoteContent(noteId: note.id)
        
        var content = ""
        let fileExt = config.format.fileExtension
        
        switch config.format {
        case .txt:
            var text = rawPlaintext.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                text = HTMLToMarkdown.convertToPlainText(html: rawBody)
            }
            if config.includeMetadataHeader {
                var header = "\(note.name)\n"
                header += "Folder: \(note.folderPath)\n"
                if let mod = note.modificationDate {
                    header += "Modified: \(DateFormatter.localizedString(from: mod, dateStyle: .medium, timeStyle: .short))\n"
                }
                header += "----------------------------------------\n\n"
                content = header + text
            } else {
                content = text
            }
            
        case .markdown:
            let md = HTMLToMarkdown.convertToMarkdown(html: rawBody)
            if config.includeMetadataHeader {
                var header = "# \(note.name)\n\n"
                header += "- **Folder:** `\(note.folderPath)`\n"
                if let mod = note.modificationDate {
                    header += "- **Modified:** \(DateFormatter.localizedString(from: mod, dateStyle: .medium, timeStyle: .short))\n"
                }
                if let cre = note.creationDate {
                    header += "- **Created:** \(DateFormatter.localizedString(from: cre, dateStyle: .medium, timeStyle: .short))\n"
                }
                header += "\n---\n\n"
                content = header + md
            } else {
                content = md
            }
            
        case .html:
            if config.includeMetadataHeader {
                var meta = "<div class='meta' style='border-bottom:1px solid #ccc; margin-bottom:15px; padding-bottom:10px; font-family:sans-serif; color:#555; font-size:13px;'>"
                meta += "<p><strong>Folder:</strong> \(note.folderPath)</p>"
                if let mod = note.modificationDate {
                    meta += "<p><strong>Modified:</strong> \(DateFormatter.localizedString(from: mod, dateStyle: .medium, timeStyle: .short))</p>"
                }
                meta += "</div>"
                content = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <title>\(note.name)</title>
                <style>body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.5; padding: 20px; max-width: 800px; margin: 0 auto; }</style>
                </head>
                <body>
                \(meta)
                \(rawBody)
                </body>
                </html>
                """
            } else {
                content = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <title>\(note.name)</title>
                <style>body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.5; padding: 20px; max-width: 800px; margin: 0 auto; }</style>
                </head>
                <body>
                \(rawBody)
                </body>
                </html>
                """
            }
        }
        
        let fm = FileManager.default
        var targetDir = config.destinationURL
        if config.preserveFolderHierarchy && !note.folderPath.isEmpty {
            let parts = note.folderPath.components(separatedBy: "/").map { Self.sanitizeFilename($0) }
            for part in parts {
                targetDir.appendPathComponent(part, isDirectory: true)
            }
        }
        
        try fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
        
        let baseFilename = Self.sanitizeFilename(note.name)
        var fileURL = targetDir.appendingPathComponent("\(baseFilename).\(fileExt)")
        
        var counter = 1
        while fm.fileExists(atPath: fileURL.path) {
            fileURL = targetDir.appendingPathComponent("\(baseFilename) (\(counter)).\(fileExt)")
            counter += 1
        }
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        if let modDate = note.modificationDate {
            try? fm.setAttributes([.modificationDate: modDate], ofItemAtPath: fileURL.path)
        }
        
        return fileURL
    }
}
