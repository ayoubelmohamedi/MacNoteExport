# NoteExport 📝

A lightweight, high-performance native macOS application to export notes from the Apple **Notes** app to clean text files (`.txt`, `.md`, `.html`) inside any destination folder.

Designed to work out-of-the-box across **both modern Apple Silicon (M1/M2/M3/M4) and older Intel-based MacBooks** (macOS 11.0 Big Sur and later).

---

## ✨ Features

- **Bulk & Granular Selection**:
  - Export **all notes at once** with a single click.
  - Or **pick and choose specific notes** using interactive checkboxes.
  - Quick **Select All / Deselect All** controls.
- **Full Folder & Nested Subfolder Support**:
  - Automatically discovers all Apple Notes accounts (iCloud, On My Mac, Exchange, etc.).
  - Navigates nested subfolders (e.g. `Projects / 2026 / Notes`) with live note counts.
  - Filter notes by folder or view all notes across your entire library.
- **Multiple Export Formats**:
  - **Plain Text (`.txt`)**: Clean text stripped of HTML tags, preserving line breaks and lists.
  - **Markdown (`.md`)**: Converts Apple Notes rich text into clean Markdown (headers, bold, italics, links, lists, checkboxes `- [ ]` / `- [x]`).
  - **HTML (`.html`)**: Preserves complete original formatting and styling.
- **Folder Organization**:
  - **Preserve folder hierarchy**: Automatically recreates your Apple Notes folder tree on disk (e.g., `Destination/Work/Projects/Note.txt`).
  - **Flat export**: Exports all notes directly into the destination directory with automatic collision handling for duplicate note titles.
- **Live Preview & Search**:
  - Instant real-time search across titles and folders.
  - Built-in note preview pane to inspect note contents before exporting.
- **Preserves Original Dates**:
  - Retains original note modification dates on the exported filesystem files.
  - Optional metadata header (Title, Folder, Created Date, Modified Date) at the top of each file.
- **Universal Binary & Zero Dependencies**:
  - Native Cocoa / AppKit application.
  - Universal 2 binary (`arm64` + `x86_64`).
  - No Python, Node, Homebrew, or external libraries required for end users.
- **Built-in CLI Mode**:
  - Terminal automation support built directly into the same binary (`note-export --all --dest ~/Desktop/Notes`).

---

## 🚀 Quick Install & Sharing

### Sharing with Others (No Xcode / Developer Tools Needed)
Two pre-packaged distribution files are ready in the `build/` directory:
- **[NoteExport-macOS-Universal.dmg](build/NoteExport-macOS-Universal.dmg)** (Standard Mac Disk Image)
- **[NoteExport-macOS-Universal.zip](build/NoteExport-macOS-Universal.zip)** (Universal ZIP archive)

You can send either file via **AirDrop, Email, Slack, Google Drive, or USB** to anyone with a MacBook (Apple Silicon M1/M2/M3/M4 or Intel).

#### Instructions for the Recipient:
1. Double-click **`NoteExport-macOS-Universal.dmg`** and drag **NoteExport** to **Applications**.
2. **First launch (Gatekeeper)**:
   - Because the app is not signed with a paid Apple Developer certificate, macOS will show a message when first opening it.
   - **How to open**: **Right-click (or Control-click)** `NoteExport.app` in Applications, select **Open**, and click **Open**. (You only need to do this once).
   - Alternatively, open **System Settings > Privacy & Security**, scroll down, and click **"Open Anyway"**.
3. **Grant Notes Permission**: Click **OK** when macOS asks for permission to access Notes.

---

## 🖥️ Using the Graphical App

1. **Open NoteExport**: Launch `NoteExport` from your `/Applications` folder or Spotlight.
2. **Grant Permission (First Launch Only)**:
   - macOS will display a prompt asking: *"NoteExport wants permission to control Notes"*.
   - Click **OK**.
   - *(If prompted later, you can verify this in **System Settings > Privacy & Security > Automation**).*
3. **Select Folders or Notes**:
   - In the left sidebar, click **All Notes** or choose any specific folder/subfolder.
   - Use the search bar to filter notes by title.
   - Check the boxes for the notes you wish to export, or click **Select All**.
   - Click any note row to see an instant preview in the right pane.
4. **Choose Destination & Format**:
   - Click **Choose Folder...** to select your target export directory (defaults to `~/Desktop/NotesExport`).
   - Select your desired format: **Plain Text (`.txt`)**, **Markdown (`.md`)**, or **HTML (`.html`)**.
   - Check or uncheck **Preserve folder hierarchy** and **Include metadata header**.
5. **Export**:
   - Click **Export Selected Notes**.
   - Watch the real-time progress bar.
   - When finished, click **Reveal in Finder** to immediately view your exported files!

---

## 💻 Using the Command Line (CLI Mode)

The same binary can be used from the terminal for headless exports or scripts:

```bash
# List all folders and note counts
./build/note-export --list-folders

# Export all notes to a folder in Markdown format
./build/note-export --all --dest ~/Desktop/AllNotes --format md

# Export only a specific folder (e.g. "Competencies")
./build/note-export --folder "Competencies" --dest ~/Desktop/Competencies --format txt

# Export flat (without creating subdirectories) and without metadata header
./build/note-export --all --dest ~/Desktop/FlatNotes --flat --no-header

# View help
./build/note-export --help
```

---

## 🛠️ Architecture & Compatibility

| System Component | Specification |
| :--- | :--- |
| **Supported macOS** | macOS 11.0 (Big Sur), 12 (Monterey), 13 (Ventura), 14 (Sonoma), 15 (Sequoia), 26+ |
| **Hardware** | Apple Silicon (M1, M2, M3, M4) & Intel 64-bit MacBooks |
| **Binary Architecture** | Universal 2 (`arm64` + `x86_64`) |
| **Frameworks** | AppKit, Foundation, JavaScriptCore/OSAScript |
| **Dependencies** | None (100% self-contained native Swift) |

---

## 🔒 Privacy & Permissions

NoteExport runs **100% locally on your MacBook**. None of your notes, data, or files are ever transmitted over the network. 

Access to Apple Notes uses Apple's official Scripting automation interface. When first run, macOS requests permission under:
> **System Settings > Privacy & Security > Automation > NoteExport > Notes**

---

## 📄 License

MIT License. Free to use, modify, and distribute.
