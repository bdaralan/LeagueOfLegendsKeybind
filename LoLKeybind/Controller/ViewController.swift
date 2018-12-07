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
    @IBOutlet private var deleteKeybindBtn: NSButton!
    
    private lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        return panel
    }()
    
    private var availableKeybinds: [Keybind] = []
    
    
    // MARK: - Override Behavior
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keybindPopUpBtn.action = #selector(handlePopupBtnDidSelectItem)
        keybindPopUpBtn.target = self
        
        // must be able to get app delegate
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reloadKeybindPopUpBtn()
        setupNotificationObserver()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Action
    
    @IBAction private func openLolKeybindFolderBtnClicked(_ sender: NSButton) {
        guard let lolKeybindDir = KeybindManager.default.lolKeybindDir else { return }
        NSWorkspace.shared.open(lolKeybindDir)
    }
    
    /// Copy all keybind json files from a folder to LoLKeybind folder
    @IBAction private func loadKeybindsBtnClicked(_ sender: NSButton) {
        guard let window = view.window else { return }
        openPanel.beginSheetModal(for: window) { (response) in
            guard response != .cancel else { return }
            guard let selectedDir = self.openPanel.directoryURL else {
                self.showAlert(title: "Failed", message: "Cannot access directory", runModel: true)
                return
            }
            
            let fileUrls = try? FileManager.default.contentsOfDirectory(at: selectedDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let keybindFileUrls = fileUrls?.filter({ $0.pathExtension == "json" }) ?? []
            KeybindManager.default.copyFilesToLoLKeybindDirectory(filesToCopy: keybindFileUrls) { (error) in
                if let error = error {
                    self.showErrorAlert(error: error)
                } else {
                    let pluralString = keybindFileUrls.count > 1 ? "s" : ""
                    let message = "copied \(keybindFileUrls.count) keybind\(pluralString)"
                    self.showAlert(title: "Done", message: message, runModel: false)
                }
                self.reloadKeybindPopUpBtn()
            }
        }
    }
    
    /// Copy client current keybind Input.ini key-value pairs to LoLKeybind folder
    @IBAction private func saveClientKeybindBtnClicked(_ sender: NSButton) {
        KeybindManager.default.saveClientCurrentKeybind { (url, error) in
            if let error = error {
                showErrorAlert(error: error)
            } else if let url = url {
                askUserToRenameSavedKeybindFile(url: url) { renamed in
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
        guard selectedIndex >= 0, selectedIndex < availableKeybinds.count else { return }
        let keybind = availableKeybinds[selectedIndex]
        KeybindManager.default.deleteFile(at: keybind.fileUrl) { (error) in
            if let error = error {
                showErrorAlert(error: error)
            } else {
                showAlert(title: "Done", message: "Deleted \(keybind.fileUrl.lastPathComponent)", runModel: false)
                NotificationCenter.default.post(name: .init(kApplicationDidDeleteKeybind), object: keybind)
            }
            self.reloadKeybindPopUpBtn()
        }
    }

    
    // MARK: - Function
    
    /// Update the client keybind with user's selected keybind
    @objc func handlePopupBtnDidSelectItem(_ sender: NSPopUpButton) {
        let selectedIndex = keybindPopUpBtn.indexOfSelectedItem
        guard sender === keybindPopUpBtn, selectedIndex >= 0, selectedIndex < availableKeybinds.count else { return }
        let keybind = availableKeybinds[selectedIndex]
        activateKeybind(keybind)
    }
    
    @objc private func handlerKeybindDidSetNotification(_ notification: Notification) {
        guard let keybind = notification.object as? Keybind else { return }
        KeybindManager.default.rememberSetKeybind(keybind)
        reloadKeybindPopUpBtn()
    }
    
    @objc private func handleKeybindDidDeleteNotification(_ notification: Notification) {
        KeybindManager.default.rememberSetKeybind(nil)
        reloadKeybindPopUpBtn()
    }
    
    private func activateKeybind(_ keybind: Keybind) {
        KeybindManager.default.writeKeybindToClientPersistedSettings(keybindToWrite: keybind) { (error) in
            guard let error = error as NSError? else {
                let message = "\(keybind.fileUrl.lastPathComponentWithoutExtension) keybind is set"
                showAlert(title: "Done", message: message, runModel: false)
                NSSound.play(.done)
                NotificationCenter.default.post(name: .init(kApplicationDidSetKeybind), object: keybind)
                return
            }
            
            if error.domain == "FileNotFound", error.code == 404 {
                let message = """
                Cannot find \(keybind.fileUrl.lastPathComponentWithoutExtension) keybind
                - Make sure the file is in the \(KeybindManager.default.lolKeybindFolderName) folder or
                - Try to refresh keybind for available list
                """
                showAlert(title: error.domain, message: message, runModel: true)
            } else {
                showErrorAlert(error: error)
            }
        }
    }
    
    func reloadKeybindPopUpBtn() {
        let keybindManger = KeybindManager.default
        
        availableKeybinds = keybindManger.availableKeybinds()
        keybindPopUpBtn.removeAllItems()
        
        if availableKeybinds.isEmpty {
            keybindPopUpBtn.addItem(withTitle: "None")
        } else {
            keybindPopUpBtn.addItems(withTitles: availableKeybinds.compactMap({ $0.fileName }))
        }
        
        let previousSetKeybind = keybindManger.previousSetKeybind()
        for (index, item) in keybindPopUpBtn.itemArray.enumerated() {
            item.state = item.title == previousSetKeybind?.fileName ? .on : .off
            item.state == .on ? keybindPopUpBtn.selectItem(at: index) : ()
        }
        
        keybindPopUpBtn.isEnabled = !availableKeybinds.isEmpty
        deleteKeybindBtn.isEnabled = keybindPopUpBtn.isEnabled
    }
    
    func askUserToRenameSavedKeybindFile(url: URL, completion: @escaping (Bool) -> Void) {
        let currentFileName = url.lastPathComponentWithoutExtension
        let message = "Saved Client's Current Keybind"
        let informativeText = "File name cannot be duplicate"
        let textFieldAlert = NSAlert.textFieldAlert(messageText: message, informativeText: informativeText, textFieldString: currentFileName)
        
        // force unwrapped view's window
        textFieldAlert.beginSheetModal(for: view.window!) { (response) in
            let textField = textFieldAlert.accessoryView as! NSTextField
            let inputFileName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            let fileNewName = inputFileName.isEmpty ? currentFileName : inputFileName
            KeybindManager.default.renameFile(at: url, to: fileNewName) { (error) in
                if error != nil {
                    self.askUserToRenameSavedKeybindFile(url: url, completion: completion)
                } else {
                    self.showAlert(title: "Done", message: "\(fileNewName) keybind is saved", runModel: false)
                    completion(error != nil)
                }
            }
        }
    }
    
    private func setupNotificationObserver() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self, selector: #selector(handlerKeybindDidSetNotification(_:)),
            name: .init(rawValue: kApplicationDidSetKeybind), object: nil
        )
        notificationCenter.addObserver(
            self, selector: #selector(handleKeybindDidDeleteNotification(_:)),
            name: .init(rawValue: kApplicationDidDeleteKeybind), object: nil
        )
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
