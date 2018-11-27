//
//  ViewController.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/24/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet private var keybindPopUpBtn: NSPopUpButton!
    @IBOutlet private var selectedKeybindLabel: NSTextField!
    @IBOutlet private var setKeybindBtn: NSButton!
    @IBOutlet private var deleteKeybindBtn: NSButton!
    @IBOutlet private var currentSetKeybindLbl: NSTextField!
    
    private lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        return panel
    }()
    
    private var keybinds: [Keybind] = []
    
    
    // MARK: - Override Behavior
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadKeybindPopUpBtn()
        reloadLastSetKeybindLabelString()
    }
    
    
    // MARK: - Action
    
    @IBAction private func openLolKeybindFolderBtnClicked(_ sender: NSButton) {
        guard let lolKeybindDir = FileHandler.default.lolKeybindDir else { return }
        NSWorkspace.shared.open(lolKeybindDir)
    }
    
    /// Update the client keybind with user's selected keybind
    @IBAction private func setKeybindBtnClicked(_ sender: NSButton) {
        let selectedIndex = keybindPopUpBtn.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < keybinds.count else { return }
        let keybindUrl = keybinds[selectedIndex].fileUrl
        FileHandler.default.writeKeybindToClientPersistedSettings(keybindToWriteUrl: keybindUrl) { (error) in
            guard let error = error as NSError? else {
                showAlert(title: "Done", message: "\(keybindUrl.lastPathComponentWithoutExtension) keybind is set", runModel: false)
                FileHandler.default.rememberSetKeybindUrlPath(keybindUrl.path)
                reloadLastSetKeybindLabelString()
                return
            }
            
            if error.domain == "FileNotFound", error.code == 404 {
                let message = """
                Cannot find \(keybindUrl.lastPathComponentWithoutExtension) keybind
                - Make sure the file is in the \(FileHandler.default.lolKeybindFolderName) folder or
                - Try to refresh keybind for available list
                """
                showAlert(title: error.domain, message: message, runModel: true)
            } else {
                showErrorAlert(error: error)
            }
        }
    }
    
    /// Copy all keybind json files from a folder to LoLKeybind folder
    @IBAction private func loadKeybindsBtnClicked(_ sender: NSButton) {
        guard let window = view.window else { return }
        openPanel.beginSheetModal(for: window) { (respone) in
            guard let selectedDir = self.openPanel.directoryURL else {
                self.showAlert(title: "Failed", message: "Cannot access directory", runModel: true)
                return
            }
            
            let fileUrls = try? FileManager.default.contentsOfDirectory(at: selectedDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let keybindFileUrls = fileUrls?.filter({ $0.pathExtension == "json" }) ?? []
            FileHandler.default.copyFilesToLoLKeybindDirectory(filesToCopy: keybindFileUrls) { (error) in
                if let error = error {
                    self.showErrorAlert(error: error)
                } else {
                    let pluralString = keybindFileUrls.count > 1 ? "s" : ""
                    self.showAlert(title: "Done", message: "copied \(keybindFileUrls.count) keybind\(pluralString)", runModel: false)
                }
                self.reloadKeybindPopUpBtn()
            }
        }
    }
    
    /// Copy client current keybind Input.ini key-value pairs to LoLKeybind folder
    @IBAction private func saveClientKeybindBtnClicked(_ sender: NSButton) {
        FileHandler.default.saveClientCurrentKeybind { (url, error) in
            if let error = error {
                showErrorAlert(error: error)
            } else if let url = url {
                askUserToNameSavedFile(url: url) { renamed in
                    self.reloadKeybindPopUpBtn()
                }
            }
        }
    }
    
    @IBAction private func refreshKeybindBtnClicked(_ sender: NSButton) {
        reloadKeybindPopUpBtn()
    }
    
    @IBAction private func deleteKeybindBtnClicked(_ sender: NSButton) {
        let selectedIndex = keybindPopUpBtn.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < keybinds.count else { return }
        let keybindUrl = keybinds[selectedIndex].fileUrl
        FileHandler.default.deleteFile(at: keybindUrl) { (error) in
            if let error = error {
                showErrorAlert(error: error)
            } else {
                showAlert(title: "Done", message: "Deleted \(keybindUrl.lastPathComponent)", runModel: false)
                FileHandler.default.rememberSetKeybindUrlPath(nil)
                reloadLastSetKeybindLabelString()
            }
            self.reloadKeybindPopUpBtn()
        }
    }

    
    // MARK: - Function
    
    private func reloadKeybindPopUpBtn() {
        guard let lolKeybindDir = FileHandler.default.lolKeybindDir else { return }
        keybinds = FileHandler.default.fetchKeybinds(at: lolKeybindDir)
        keybindPopUpBtn.removeAllItems()
        
        if keybinds.isEmpty {
            keybindPopUpBtn.addItem(withTitle: "None")
        } else {
            keybindPopUpBtn.addItems(withTitles: keybinds.compactMap({ $0.fileName }))
        }
        
        keybindPopUpBtn.isEnabled = !keybinds.isEmpty
        setKeybindBtn.isEnabled = keybindPopUpBtn.isEnabled
        deleteKeybindBtn.isEnabled = keybindPopUpBtn.isEnabled
    }
    
    private func askUserToNameSavedFile(url: URL, completion: @escaping (Bool) -> Void) {
        let fileDefaultName = url.lastPathComponentWithoutExtension
        
        let alert = NSAlert()
        alert.messageText = "Saved Current Keybind"
        alert.informativeText = "File name (cannot use duplicated name)"
        alert.alertStyle = .informational
        
        guard let window = view.window else {
            alert.runModal()
            return
        }
        
        let textField = NSTextField(string: fileDefaultName)
        alert.accessoryView = textField
        alert.accessoryView?.frame.size.width = 200
        
        alert.beginSheetModal(for: window) { (response) in
            let inputName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            let fileNewName = inputName.isEmpty ? fileDefaultName : inputName
            FileHandler.default.renameFile(at: url, to: fileNewName) { (error) in
                if error != nil {
                    self.askUserToNameSavedFile(url: url, completion: completion)
                } else {
                    self.showAlert(title: "Done", message: "\(fileNewName) keybind is saved", runModel: false)
                    completion(error != nil)
                }
            }
        }
    }
    
    private func reloadLastSetKeybindLabelString() {
        guard let lastSetKeybindUrl = FileHandler.default.previousSetKeybindUrl() else {
            currentSetKeybindLbl.stringValue = "LOLKEYBIND"
            return
        }
        currentSetKeybindLbl.stringValue = lastSetKeybindUrl.lastPathComponentWithoutExtension
    }
    
    private func showErrorAlert(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    
    private func showAlert(title: String, message: String, runModel: Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        
        if runModel {
            alert.runModal()
        } else if let windown = view.window {
            alert.beginSheetModal(for: windown, completionHandler: nil)
        }
    }
}
