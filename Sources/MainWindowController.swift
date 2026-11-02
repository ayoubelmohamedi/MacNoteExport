import AppKit

public final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    // Data
    private var accounts: [AccountItem] = []
    private var allFolders: [FolderItem] = []
    private var allNotes: [NoteItem] = []
    private var filteredNotes: [NoteItem] = []
    private var selectedFolder: FolderItem? = nil // nil means "All Notes"
    private var folderNotesCache: [String: [NoteItem]] = [:]
    
    // UI Elements - Left
    private var folderTableView: NSTableView!
    private var refreshButton: NSButton!
    
    // UI Elements - Center
    private var searchField: NSSearchField!
    private var notesTableView: NSTableView!
    private var countLabel: NSTextField!
    
    // UI Elements - Right (Preview)
    private var previewTitleLabel: NSTextField!
    private var previewMetaLabel: NSTextField!
    private var previewTextView: NSTextView!
    
    // UI Elements - Bottom / Export
    private var destinationField: NSTextField!
    private var formatPopup: NSPopUpButton!
    private var hierarchyCheckbox: NSButton!
    private var metadataCheckbox: NSButton!
    private var exportButton: NSButton!
    private var progressBar: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var revealButton: NSButton!
    
    private var destinationURL: URL
    private var isExporting: Bool = false
    private var cancelExportRequested: Bool = false
    private var isLoadingNotes: Bool = false
    
    public init() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        self.destinationURL = desktop.appendingPathComponent("NotesExport")
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1060, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NoteExport - Apple Notes Exporter"
        window.minSize = NSSize(width: 900, height: 520)
        
        super.init(window: window)
        setupUI()
        loadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let mainContainer = NSView(frame: window.contentView!.bounds)
        mainContainer.autoresizingMask = [.width, .height]
        window.contentView = mainContainer
        
        // Split view (Horizontal: Left Folders, Center Notes, Right Preview)
        let splitView = NSSplitView(frame: NSRect(x: 0, y: 130, width: mainContainer.bounds.width, height: mainContainer.bounds.height - 130))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]
        mainContainer.addSubview(splitView)
        
        // 1. Left View: Folders
        let leftView = createFoldersView()
        leftView.frame = NSRect(x: 0, y: 0, width: 230, height: splitView.bounds.height)
        splitView.addSubview(leftView)
        
        // 2. Middle View: Notes Table
        let middleView = createNotesView()
        middleView.frame = NSRect(x: 0, y: 0, width: 490, height: splitView.bounds.height)
        splitView.addSubview(middleView)
        
        // 3. Right View: Preview
        let rightView = createPreviewView()
        rightView.frame = NSRect(x: 0, y: 0, width: 340, height: splitView.bounds.height)
        splitView.addSubview(rightView)
        
        // 4. Bottom View: Export controls
        let bottomView = createBottomControlsView()
        bottomView.frame = NSRect(x: 0, y: 0, width: mainContainer.bounds.width, height: 130)
        bottomView.autoresizingMask = [.width, .maxYMargin]
        mainContainer.addSubview(bottomView)
    }
    
    // MARK: - Folders View (Left)
    
    private func createFoldersView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 500))
        
        let headerLabel = NSTextField(labelWithString: "FOLDERS")
        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.frame = NSRect(x: 14, y: 470, width: 140, height: 16)
        headerLabel.autoresizingMask = [.minYMargin]
        container.addSubview(headerLabel)
        
        refreshButton = NSButton(title: "↻ Refresh", target: self, action: #selector(refreshClicked))
        refreshButton.bezelStyle = .inline
        refreshButton.font = NSFont.systemFont(ofSize: 10)
        refreshButton.frame = NSRect(x: 155, y: 468, width: 65, height: 20)
        refreshButton.autoresizingMask = [.minYMargin, .minXMargin]
        container.addSubview(refreshButton)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 230, height: 460))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        folderTableView = NSTableView(frame: scrollView.bounds)
        folderTableView.autoresizingMask = [.width, .height]
        folderTableView.headerView = nil
        folderTableView.rowHeight = 26
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FolderColumn"))
        col.resizingMask = .autoresizingMask
        folderTableView.addTableColumn(col)
        
        folderTableView.dataSource = self
        folderTableView.delegate = self
        scrollView.documentView = folderTableView
        
        container.addSubview(scrollView)
        return container
    }
    
    // MARK: - Notes View (Center)
    
    private func createNotesView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 490, height: 500))
        
        // Search bar
        searchField = NSSearchField(frame: NSRect(x: 10, y: 462, width: 250, height: 26))
        searchField.placeholderString = "Search notes..."
        searchField.delegate = self
        searchField.autoresizingMask = [.minYMargin, .width]
        container.addSubview(searchField)
        
        // Select All / Deselect All buttons
        let selectAllBtn = NSButton(title: "Select All", target: self, action: #selector(selectAllClicked))
        selectAllBtn.bezelStyle = .rounded
        selectAllBtn.controlSize = .small
        selectAllBtn.font = NSFont.systemFont(ofSize: 11)
        selectAllBtn.frame = NSRect(x: 270, y: 463, width: 75, height: 22)
        selectAllBtn.autoresizingMask = [.minYMargin, .minXMargin]
        container.addSubview(selectAllBtn)
        
        let deselectAllBtn = NSButton(title: "Deselect All", target: self, action: #selector(deselectAllClicked))
        deselectAllBtn.bezelStyle = .rounded
        deselectAllBtn.controlSize = .small
        deselectAllBtn.font = NSFont.systemFont(ofSize: 11)
        deselectAllBtn.frame = NSRect(x: 350, y: 463, width: 85, height: 22)
        deselectAllBtn.autoresizingMask = [.minYMargin, .minXMargin]
        container.addSubview(deselectAllBtn)
        
        // Notes Table
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 26, width: 490, height: 430))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        notesTableView = NSTableView(frame: scrollView.bounds)
        notesTableView.autoresizingMask = [.width, .height]
        notesTableView.rowHeight = 24
        notesTableView.usesAlternatingRowBackgroundColors = true
        
        // Col 0: Checkbox
        let checkCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CheckColumn"))
        checkCol.title = "✓"
        checkCol.width = 30
        checkCol.minWidth = 30
        checkCol.maxWidth = 30
        notesTableView.addTableColumn(checkCol)
        
        // Col 1: Title
        let titleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TitleColumn"))
        titleCol.title = "Note Title"
        titleCol.width = 280
        titleCol.resizingMask = .userResizingMask
        notesTableView.addTableColumn(titleCol)
        
        // Col 2: Folder
        let folderCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FolderColumn"))
        folderCol.title = "Folder"
        folderCol.width = 150
        folderCol.resizingMask = .userResizingMask
        notesTableView.addTableColumn(folderCol)
        
        notesTableView.dataSource = self
        notesTableView.delegate = self
        scrollView.documentView = notesTableView
        container.addSubview(scrollView)
        
        // Bottom summary count
        countLabel = NSTextField(labelWithString: "Loading notes...")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.frame = NSRect(x: 10, y: 5, width: 470, height: 18)
        countLabel.autoresizingMask = [.width, .maxYMargin]
        container.addSubview(countLabel)
        
        return container
    }
    
    // MARK: - Preview View (Right)
    
    private func createPreviewView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 500))
        
        previewTitleLabel = NSTextField(labelWithString: "No Note Selected")
        previewTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        previewTitleLabel.frame = NSRect(x: 12, y: 465, width: 316, height: 22)
        previewTitleLabel.autoresizingMask = [.width, .minYMargin]
        container.addSubview(previewTitleLabel)
        
        previewMetaLabel = NSTextField(labelWithString: "")
        previewMetaLabel.font = NSFont.systemFont(ofSize: 11)
        previewMetaLabel.textColor = .secondaryLabelColor
        previewMetaLabel.frame = NSRect(x: 12, y: 445, width: 316, height: 18)
        previewMetaLabel.autoresizingMask = [.width, .minYMargin]
        container.addSubview(previewMetaLabel)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 440))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        previewTextView = NSTextView(frame: scrollView.bounds)
        previewTextView.autoresizingMask = [.width, .height]
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.font = NSFont.systemFont(ofSize: 12)
        previewTextView.textContainerInset = NSSize(width: 10, height: 10)
        
        scrollView.documentView = previewTextView
        container.addSubview(scrollView)
        
        return container
    }
    
    // MARK: - Bottom Controls View
    
    private func createBottomControlsView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1060, height: 130))
        
        let sep = NSBox(frame: NSRect(x: 0, y: 129, width: 1060, height: 1))
        sep.boxType = .separator
        sep.autoresizingMask = [.width, .minYMargin]
        container.addSubview(sep)
        
        // Row 1: Destination Folder
        let destLabel = NSTextField(labelWithString: "Destination:")
        destLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        destLabel.frame = NSRect(x: 15, y: 95, width: 85, height: 20)
        container.addSubview(destLabel)
        
        destinationField = NSTextField(frame: NSRect(x: 105, y: 93, width: 480, height: 22))
        destinationField.stringValue = destinationURL.path
        destinationField.isEditable = false
        destinationField.autoresizingMask = [.width]
        container.addSubview(destinationField)
        
        let chooseBtn = NSButton(title: "Choose Folder...", target: self, action: #selector(chooseDestinationClicked))
        chooseBtn.bezelStyle = .rounded
        chooseBtn.controlSize = .small
        chooseBtn.font = NSFont.systemFont(ofSize: 11)
        chooseBtn.frame = NSRect(x: 595, y: 92, width: 120, height: 24)
        container.addSubview(chooseBtn)
        
        // Row 2: Format & Hierarchy Options
        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        formatLabel.frame = NSRect(x: 15, y: 62, width: 85, height: 20)
        container.addSubview(formatLabel)
        
        formatPopup = NSPopUpButton(frame: NSRect(x: 105, y: 60, width: 160, height: 24))
        for format in ExportFormat.allCases {
            formatPopup.addItem(withTitle: format.rawValue)
        }
        formatPopup.selectItem(at: 0) // Default .txt
        container.addSubview(formatPopup)
        
        hierarchyCheckbox = NSButton(checkboxWithTitle: "Preserve folder hierarchy", target: nil, action: nil)
        hierarchyCheckbox.state = .on
        hierarchyCheckbox.font = NSFont.systemFont(ofSize: 12)
        hierarchyCheckbox.frame = NSRect(x: 285, y: 62, width: 180, height: 20)
        container.addSubview(hierarchyCheckbox)
        
        metadataCheckbox = NSButton(checkboxWithTitle: "Include metadata header", target: nil, action: nil)
        metadataCheckbox.state = .on
        metadataCheckbox.font = NSFont.systemFont(ofSize: 12)
        metadataCheckbox.frame = NSRect(x: 475, y: 62, width: 180, height: 20)
        container.addSubview(metadataCheckbox)
        
        // Export Button
        exportButton = NSButton(title: "Export Selected (0)", target: self, action: #selector(exportClicked))
        exportButton.bezelStyle = .rounded
        exportButton.keyEquivalent = "\r"
        exportButton.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        exportButton.frame = NSRect(x: 840, y: 60, width: 195, height: 32)
        exportButton.autoresizingMask = [.minXMargin]
        container.addSubview(exportButton)
        
        // Row 3: Progress & Status
        progressBar = NSProgressIndicator(frame: NSRect(x: 15, y: 22, width: 700, height: 16))
        progressBar.isIndeterminate = false
        progressBar.minValue = 0.0
        progressBar.maxValue = 100.0
        progressBar.doubleValue = 0.0
        progressBar.isHidden = true
        progressBar.autoresizingMask = [.width]
        container.addSubview(progressBar)
        
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 15, y: 5, width: 700, height: 16)
        statusLabel.autoresizingMask = [.width]
        container.addSubview(statusLabel)
        
        revealButton = NSButton(title: "Reveal in Finder", target: self, action: #selector(revealInFinderClicked))
        revealButton.bezelStyle = .rounded
        revealButton.controlSize = .small
        revealButton.font = NSFont.systemFont(ofSize: 11)
        revealButton.frame = NSRect(x: 840, y: 18, width: 130, height: 24)
        revealButton.isHidden = true
        revealButton.autoresizingMask = [.minXMargin]
        container.addSubview(revealButton)
        
        return container
    }
    
    // MARK: - Data Loading
    
    @objc public func refreshClicked() {
        folderNotesCache.removeAll()
        loadData()
    }
    
    public func loadData() {
        statusLabel.stringValue = "Scanning Apple Notes folders..."
        refreshButton.isEnabled = false
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let accs = try NotesBridge.shared.fetchAccountsAndFolders()
                var flattened: [FolderItem] = []
                for a in accs {
                    flattened.append(contentsOf: a.folders)
                }
                
                let totalNotesEstimate = flattened.reduce(0) { $0 + $1.noteCount }
                
                // Immediately display folders in the UI!
                DispatchQueue.main.async {
                    self.accounts = accs
                    self.allFolders = flattened
                    self.refreshButton.isEnabled = true
                    self.folderTableView.reloadData()
                    self.folderTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    self.statusLabel.stringValue = "Found \(flattened.count) folders (\(totalNotesEstimate) notes). Loading note list..."
                    
                    // Now load notes for currently selected folder / all notes
                    self.loadNotesForCurrentSelection()
                }
            } catch {
                DispatchQueue.main.async {
                    self.refreshButton.isEnabled = true
                    self.statusLabel.stringValue = "Error loading Notes: \(error.localizedDescription)"
                    self.showPermissionAlert(error: error)
                }
            }
        }
    }
    
    private func loadNotesForCurrentSelection() {
        if let folder = selectedFolder {
            // Check cache
            if let cached = folderNotesCache[folder.id] {
                self.allNotes = cached
                self.updateFilteredNotes()
                self.statusLabel.stringValue = "Folder '\(folder.name)': \(cached.count) notes loaded."
                return
            }
            
            statusLabel.stringValue = "Loading notes from '\(folder.name)'..."
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    let notes = try NotesBridge.shared.fetchNotesForFolder(folderId: folder.id, folderPath: folder.fullPath, accountName: "")
                    DispatchQueue.main.async {
                        self.folderNotesCache[folder.id] = notes
                        self.allNotes = notes
                        self.updateFilteredNotes()
                        self.statusLabel.stringValue = "Folder '\(folder.name)': \(notes.count) notes loaded."
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // "All Notes" selected
            statusLabel.stringValue = "Loading all notes..."
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                var collected: [NoteItem] = []
                let nonZeroFolders = self.allFolders.filter { $0.noteCount > 0 }
                
                for (idx, f) in nonZeroFolders.enumerated() {
                    let folderNotes: [NoteItem]
                    if let cached = self.folderNotesCache[f.id] {
                        folderNotes = cached
                    } else if let fetched = try? NotesBridge.shared.fetchNotesForFolder(folderId: f.id, folderPath: f.fullPath, accountName: "") {
                        self.folderNotesCache[f.id] = fetched
                        folderNotes = fetched
                    } else {
                        folderNotes = []
                    }
                    collected.append(contentsOf: folderNotes)
                    
                    // Progressive UI update
                    DispatchQueue.main.async {
                        self.statusLabel.stringValue = "Loading notes (\(idx + 1)/\(nonZeroFolders.count) folders: \(collected.count) notes)..."
                        self.allNotes = collected
                        self.updateFilteredNotes()
                    }
                }
                
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "Ready. \(collected.count) notes loaded."
                }
            }
        }
    }
    
    private func showPermissionAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Apple Notes Access Required"
        alert.informativeText = "NoteExport needs permission to read Apple Notes.\n\nPlease check System Settings > Privacy & Security > Automation and make sure NoteExport has permission to automate Notes.\n\nDetails: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Dismiss")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            loadData()
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
        }
    }
    
    private func updateFilteredNotes() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            self.filteredNotes = allNotes
        } else {
            self.filteredNotes = allNotes.filter { note in
                note.name.lowercased().contains(query) || note.folderPath.lowercased().contains(query)
            }
        }
        self.notesTableView.reloadData()
        self.updateCounts()
    }
    
    private func updateCounts() {
        let selectedCount = allNotes.filter { $0.isSelected }.count
        let totalCount = allNotes.count
        let showingCount = filteredNotes.count
        
        countLabel.stringValue = "Showing \(showingCount) of \(totalCount) notes  •  \(selectedCount) selected"
        exportButton.title = "Export Selected (\(selectedCount))"
        exportButton.isEnabled = selectedCount > 0 && !isExporting
    }
    
    // MARK: - Actions
    
    @objc private func selectAllClicked() {
        for n in filteredNotes {
            n.isSelected = true
        }
        notesTableView.reloadData()
        updateCounts()
    }
    
    @objc private func deselectAllClicked() {
        for n in filteredNotes {
            n.isSelected = false
        }
        notesTableView.reloadData()
        updateCounts()
    }
    
    @objc private func chooseDestinationClicked() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Destination"
        panel.message = "Choose destination folder for exported notes:"
        panel.directoryURL = destinationURL
        
        if panel.runModal() == .OK, let url = panel.url {
            self.destinationURL = url
            self.destinationField.stringValue = url.path
        }
    }
    
    @objc private func revealInFinderClicked() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destinationURL.path)
    }
    
    @objc private func exportClicked() {
        if isExporting {
            cancelExportRequested = true
            statusLabel.stringValue = "Cancelling export..."
            return
        }
        
        let selectedNotes = allNotes.filter { $0.isSelected }
        guard !selectedNotes.isEmpty else { return }
        
        let selectedFormatIndex = formatPopup.indexOfSelectedItem
        let format: ExportFormat = (selectedFormatIndex >= 0 && selectedFormatIndex < ExportFormat.allCases.count)
            ? ExportFormat.allCases[selectedFormatIndex]
            : .txt
        
        let config = ExportConfig(
            destinationURL: destinationURL,
            format: format,
            preserveFolderHierarchy: hierarchyCheckbox.state == .on,
            includeMetadataHeader: metadataCheckbox.state == .on
        )
        
        isExporting = true
        cancelExportRequested = false
        exportButton.title = "Cancel Export"
        progressBar.isHidden = false
        progressBar.minValue = 0.0
        progressBar.maxValue = Double(selectedNotes.count)
        progressBar.doubleValue = 0.0
        revealButton.isHidden = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var successCount = 0
            var errorCount = 0
            
            for (idx, note) in selectedNotes.enumerated() {
                if self.cancelExportRequested { break }
                
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "Exporting (\(idx + 1)/\(selectedNotes.count)): \(note.name)..."
                    self.progressBar.doubleValue = Double(idx + 1)
                }
                
                do {
                    _ = try NotesBridge.shared.exportNote(note, config: config)
                    successCount += 1
                } catch {
                    errorCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportButton.title = "Export Selected (\(self.allNotes.filter { $0.isSelected }.count))"
                self.progressBar.isHidden = true
                self.revealButton.isHidden = false
                
                if self.cancelExportRequested {
                    self.statusLabel.stringValue = "Export cancelled. \(successCount) notes exported."
                } else {
                    self.statusLabel.stringValue = "Finished! \(successCount) notes exported successfully to \(self.destinationURL.lastPathComponent)."
                    
                    let alert = NSAlert()
                    alert.messageText = "Export Complete"
                    alert.informativeText = "Successfully exported \(successCount) note(s) to:\n\(self.destinationURL.path)"
                    if errorCount > 0 {
                        alert.informativeText += "\n(\(errorCount) note(s) failed)."
                    }
                    alert.addButton(withTitle: "Reveal in Finder")
                    alert.addButton(withTitle: "OK")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: self.destinationURL.path)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Field Delegate
    
    public func controlTextDidChange(_ obj: Notification) {
        updateFilteredNotes()
    }
    
    // MARK: - Table View DataSource & Delegate
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == folderTableView {
            return 1 + allFolders.count // +1 for "All Notes"
        } else {
            return filteredNotes.count
        }
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == folderTableView {
            let cell = NSTextField()
            cell.isEditable = false
            cell.isBordered = false
            cell.backgroundColor = .clear
            cell.font = NSFont.systemFont(ofSize: 12)
            
            if row == 0 {
                let total = allFolders.reduce(0) { $0 + $1.noteCount }
                cell.stringValue = "📁 All Notes (\(total))"
                cell.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            } else {
                let folder = allFolders[row - 1]
                let depth = folder.fullPath.components(separatedBy: "/").count - 1
                let indent = String(repeating: "   ", count: depth)
                let icon = depth > 0 ? "↳ " : "📁 "
                cell.stringValue = "\(indent)\(icon)\(folder.name) (\(folder.noteCount))"
            }
            return cell
        } else {
            guard row < filteredNotes.count else { return nil }
            let note = filteredNotes[row]
            let colId = tableColumn?.identifier.rawValue ?? ""
            
            if colId == "CheckColumn" {
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(noteCheckboxToggled(_:)))
                checkbox.tag = row
                checkbox.state = note.isSelected ? .on : .off
                return checkbox
            } else if colId == "TitleColumn" {
                let cell = NSTextField()
                cell.isEditable = false
                cell.isBordered = false
                cell.backgroundColor = .clear
                cell.stringValue = note.name
                cell.font = NSFont.systemFont(ofSize: 12)
                return cell
            } else if colId == "FolderColumn" {
                let cell = NSTextField()
                cell.isEditable = false
                cell.isBordered = false
                cell.backgroundColor = .clear
                cell.stringValue = note.folderPath
                cell.textColor = .secondaryLabelColor
                cell.font = NSFont.systemFont(ofSize: 11)
                return cell
            }
            return nil
        }
    }
    
    @objc private func noteCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredNotes.count else { return }
        filteredNotes[row].isSelected = (sender.state == .on)
        updateCounts()
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView else { return }
        
        if tv == folderTableView {
            let row = folderTableView.selectedRow
            if row <= 0 {
                selectedFolder = nil
            } else if row - 1 < allFolders.count {
                selectedFolder = allFolders[row - 1]
            }
            loadNotesForCurrentSelection()
        } else if tv == notesTableView {
            let row = notesTableView.selectedRow
            if row >= 0 && row < filteredNotes.count {
                loadNotePreview(note: filteredNotes[row])
            }
        }
    }
    
    private func loadNotePreview(note: NoteItem) {
        previewTitleLabel.stringValue = note.name
        previewMetaLabel.stringValue = "Folder: \(note.folderPath)"
        previewTextView.string = "Loading note preview..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let (plaintext, body) = try NotesBridge.shared.fetchNoteContent(noteId: note.id)
                let displayText = plaintext.isEmpty ? HTMLToMarkdown.convertToPlainText(html: body) : plaintext
                DispatchQueue.main.async {
                    self.previewTextView.string = displayText
                }
            } catch {
                DispatchQueue.main.async {
                    self.previewTextView.string = "(Could not load preview: \(error.localizedDescription))"
                }
            }
        }
    }
}
