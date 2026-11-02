import Foundation

public enum CLI {
    public static func run(arguments: [String]) {
        if arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            exit(0)
        }
        
        if arguments.contains("--list-folders") {
            listFolders()
            exit(0)
        }
        
        let isAll = arguments.contains("--all") || arguments.contains("-a")
        let folderName = getArgumentValue(arguments, flag: "--folder") ?? getArgumentValue(arguments, flag: "-f")
        let formatStr = getArgumentValue(arguments, flag: "--format") ?? "txt"
        let destPath = getArgumentValue(arguments, flag: "--dest") ?? getArgumentValue(arguments, flag: "-d")
        let flat = arguments.contains("--flat")
        let noHeader = arguments.contains("--no-header")
        
        guard isAll || folderName != nil else {
            printUsage()
            exit(1)
        }
        
        let format: ExportFormat
        switch formatStr.lowercased() {
        case "md", "markdown":
            format = .markdown
        case "html":
            format = .html
        default:
            format = .txt
        }
        
        let destURL: URL
        if let destPath = destPath {
            destURL = URL(fileURLWithPath: (destPath as NSString).expandingTildeInPath)
        } else {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
            destURL = desktop.appendingPathComponent("NotesExport")
        }
        
        let config = ExportConfig(
            destinationURL: destURL,
            format: format,
            preserveFolderHierarchy: !flat,
            includeMetadataHeader: !noHeader
        )
        
        print("NoteExport CLI")
        print("Destination: \(config.destinationURL.path)")
        print("Format:      \(config.format.rawValue)")
        print("Hierarchy:   \(config.preserveFolderHierarchy ? "Preserved" : "Flat")")
        print("Connecting to Apple Notes...")
        
        do {
            let bridge = NotesBridge.shared
            let allAccounts = try bridge.fetchAccountsAndFolders()
            var folders: [FolderItem] = []
            for a in allAccounts {
                folders.append(contentsOf: a.folders)
            }
            
            var targetNotes: [NoteItem] = []
            if let folderName = folderName {
                guard let match = folders.first(where: { $0.name.lowercased() == folderName.lowercased() || $0.fullPath.lowercased() == folderName.lowercased() }) else {
                    print("Error: Folder '\(folderName)' not found.")
                    print("Use --list-folders to see available folders.")
                    exit(1)
                }
                print("Fetching notes from folder '\(match.fullPath)'...")
                targetNotes = try bridge.fetchNotesForFolder(folderId: match.id, folderPath: match.fullPath, accountName: "")
            } else {
                print("Scanning notes across \(folders.count) folders...")
                targetNotes = bridge.fetchAllNotes(folders: folders) { cur, tot in
                    print("Scanning folder \(cur)/\(tot)...", terminator: "\r")
                    fflush(stdout)
                }
                print("")
            }
            
            print("Found \(targetNotes.count) note(s) to export.")
            guard !targetNotes.isEmpty else {
                print("Nothing to export.")
                exit(0)
            }
            
            var success = 0
            var errors = 0
            for (idx, note) in targetNotes.enumerated() {
                print("[\(idx + 1)/\(targetNotes.count)] Exporting: \(note.name)...", terminator: "")
                fflush(stdout)
                do {
                    _ = try bridge.exportNote(note, config: config)
                    print(" ✓")
                    success += 1
                } catch {
                    print(" ✗ (\(error.localizedDescription))")
                    errors += 1
                }
            }
            
            print("\nExport completed!")
            print("Successfully exported: \(success) notes")
            if errors > 0 {
                print("Failed: \(errors) notes")
            }
            print("Files saved to: \(config.destinationURL.path)")
            exit(0)
            
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    private static func listFolders() {
        print("Connecting to Apple Notes to list folders...")
        do {
            let accounts = try NotesBridge.shared.fetchAccountsAndFolders()
            for acc in accounts {
                print("\n[Account: \(acc.name)]")
                for f in acc.folders {
                    let depth = f.fullPath.components(separatedBy: "/").count - 1
                    let indent = String(repeating: "  ", count: depth)
                    print("\(indent)- \(f.name) (\(f.noteCount) notes)  [Path: \(f.fullPath)]")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    private static func getArgumentValue(_ args: [String], flag: String) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }
    
    private static func printUsage() {
        let help = """
        NoteExport - Apple Notes Text Exporter
        Usage:
          NoteExport                          Launch GUI application
          NoteExport --list-folders           List all Apple Notes folders and note counts
          NoteExport --all [options]          Export all notes in bulk
          NoteExport --folder <name> [opt]    Export notes from a specific folder

        Options:
          --dest, -d <path>      Destination directory (default: ~/Desktop/NotesExport)
          --format <txt|md|html> Export format: txt (default), md (markdown), html
          --flat                 Export all notes into a single flat folder (default: preserves hierarchy)
          --no-header            Do not prepend title/folder/date metadata header to notes
          --help, -h             Show this help message

        Examples:
          NoteExport --all --dest ~/Desktop/MyNotes --format md
          NoteExport --folder "Competencies" --dest ~/Documents/Competencies
          NoteExport --list-folders
        """
        print(help)
    }
}
