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
    
    private lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        return panel
    }()
    
    private var keybinds: [Keybind] = []
    
    lazy var fileManager = FileManager.default
    lazy var applicationDir: URL? = FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask).first
    lazy var documentDir: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    lazy var lolKeybindDir: URL? = documentDir?.appendingPathComponent("LoLKeybind", isDirectory: true)
    
    lazy var clientPersistedSettingsJSONFileUrl: URL? = {
        let plist = Bundle.main.infoDictionary ?? [:]
        guard let applicationDir = self.applicationDir, let lolKeybindDir = self.lolKeybindDir else {
            showErrorAlert(message: "Failed to access application or LoLKeybind directory")
            return nil
        }
        
        let lolPersistedSettingsPath = plist["lolPersistedSettingsPath"] as? String ?? ""
        let persistedSettingsFileName = plist["lolPersistedSettingsFileName"] as? String ?? ""
        let persistedSettingsFileExtension = "json"
        
        let lolPersistedSettingDir = applicationDir.appendingPathComponent(lolPersistedSettingsPath, isDirectory: true)
        let persistedSettingJSONFileUrl = lolPersistedSettingDir.appendingPathComponent(persistedSettingsFileName).appendingPathExtension(persistedSettingsFileExtension)
        return persistedSettingJSONFileUrl
    }()
    
    private let kLastSelectedKeybind = "kLastSelectedKeybind"
    
    
    // MARK: - Override Behavior
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadKeybindPopUpBtn()
    }
    
    
    // MARK: - Action
    
    @IBAction private func setKeybindBtnClicked(_ sender: NSButton) {
        setCurrentSelectedKeybind()
    }
    
    @IBAction private func loadKeybindsBtnClicked(_ sender: NSButton) {
        chooseKeybindFolderToCopy()
    }
    
    @IBAction private func saveClientKeybindBtnClicked(_ sender: NSButton) {
        saveClientCurrentPersistedSettingsKeybind()
    }
    
    @IBAction private func refreshKeybindBtnClicked(_ sender: NSButton) {
        reloadKeybindPopUpBtn()
    }
    
    @IBAction private func deleteKeybindBtnClicked(_ sender: NSButton) {
        deleteSelectedKeybind()
    }
    
    
    // MARK: - Function
    
    private func reloadKeybindPopUpBtn() {
        keybinds = fetchKeybinds()
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
    
    private func setCurrentSelectedKeybind() {
        let selectedIndex = keybindPopUpBtn.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < keybinds.count ,let keybindUrl = keybinds[selectedIndex].fileUrl else { return }
        writeToClientPersistedSettings(keybindUrl: keybindUrl)
    }
    
    private func deleteSelectedKeybind() {
        let selectedIndex = keybindPopUpBtn.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < keybinds.count, let keybindUrl = keybinds[selectedIndex].fileUrl else { return }
        try? fileManager.removeItem(at: keybindUrl)
        reloadKeybindPopUpBtn()
    }
    
    private func copyJSONFiles(sourceUrl: URL, destinationUrl: URL, createDirectory: Bool) {
        do {
            var jsonFileUrls = try fileManager.contentsOfDirectory(at: sourceUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            jsonFileUrls = jsonFileUrls.filter({ $0.pathExtension == "json" })
            
            if createDirectory, !jsonFileUrls.isEmpty, !fileManager.fileExists(atPath: destinationUrl.path) {
                try fileManager.createDirectory(at: destinationUrl, withIntermediateDirectories: false, attributes: nil)
            }
            
            for url in jsonFileUrls {
                let destinationFileUrl = destinationUrl.appendingPathComponent(url.lastPathComponent)
                try fileManager.copyItem(at: url, to: destinationFileUrl)
            }
        } catch {
            showErrorAlert(error: error) // failed to copy
        }
    }
    
    private func chooseKeybindFolderToCopy() {
        guard let window = view.window else { return }
        openPanel.beginSheetModal(for: window) { (respone) in
            guard let selectedDir = self.openPanel.directoryURL, let lolKeybindDir = self.lolKeybindDir else { return }
            self.copyJSONFiles(sourceUrl: selectedDir, destinationUrl: lolKeybindDir, createDirectory: true)
            self.reloadKeybindPopUpBtn()
        }
    }
    
    private func writeToClientPersistedSettings(keybindUrl: URL) {
        guard let persistedSettingsUrl = clientPersistedSettingsJSONFileUrl, let persistedSettingsData = fileManager.contents(atPath: persistedSettingsUrl.path) else {
            showErrorAlert(message: "Failed to write to client persisted settings file")
            return
        }
        
        guard let userKeybindData = fileManager.contents(atPath: keybindUrl.path) else {
            showErrorAlert(message: "Failed to read user keybind file: \(keybindUrl.lastPathComponent)")
            return
        }
        
        do {
            let userKeybind = try JSONSerialization.jsonObject(with: userKeybindData, options: [])  as? [String: AnyObject]
            let clientPersistedSettingsJSON = try JSONSerialization.jsonObject(with: persistedSettingsData, options: []) as? [String: AnyObject]
            
            guard var persistedSettingsJSON = clientPersistedSettingsJSON else { return }
            var filesKeyDict = clientPersistedSettingsJSON?["files"] as? [[String: AnyObject]] ?? []
            for (index, dict) in filesKeyDict.enumerated() where dict["name"] as? String == "Input.ini" {
                if let userKeybind = userKeybind {
                    filesKeyDict[index] = userKeybind
                    persistedSettingsJSON.updateValue(filesKeyDict as AnyObject, forKey: "files")
                    let updatedClientPersistedSettingData = try JSONSerialization.data(withJSONObject: persistedSettingsJSON, options: [])
                    try updatedClientPersistedSettingData.write(to: persistedSettingsUrl, options: [])
                    return
                }
            }
        } catch {
            showErrorAlert(error: error) // failed to write user keybind to client
        }
    }
    
    private func saveClientCurrentPersistedSettingsKeybind() {
        guard let persistedSettingsUrl = clientPersistedSettingsJSONFileUrl, let persistedSettingsData = fileManager.contents(atPath: persistedSettingsUrl.path) else {
            showErrorAlert(message: "Failed to read PersistedSetting.json")
            return
        }
        
        guard let lolKeybindDir = lolKeybindDir else {
            showErrorAlert(message: "Failed to access LoLKeybind Folder")
            return
        }
        
        // locate the input keybind key-vale pairs and write to disk
        // NOTE: Keys: "files", "name", and "Input.ini" needs to be updated manually if needed
        do {
            let persistedSettingsJSON = try JSONSerialization.jsonObject(with: persistedSettingsData, options: []) as? [String: AnyObject]
            let filesKeyDict = persistedSettingsJSON?["files"] as? [[String: AnyObject]] ?? []
            
            for dict in filesKeyDict where dict["name"] as? String == "Input.ini" {
                if !fileManager.fileExists(atPath: lolKeybindDir.path) {
                    try fileManager.createDirectory(at: lolKeybindDir, withIntermediateDirectories: false, attributes: nil)
                }
                
                let urlToWrite = lolKeybindDir.appendingPathComponent("Copied Keybind.json")
                let keybindJSONToWrite = try JSONSerialization.data(withJSONObject: dict, options: [])
                try keybindJSONToWrite.write(to: urlToWrite, options: [])
                askUserToNameCurrentPerstistedSettingsSavedFile(url: urlToWrite) {
                    self.reloadKeybindPopUpBtn()
                }
            }
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    private func askUserToNameCurrentPerstistedSettingsSavedFile(url: URL, completion: @escaping () -> Void) {
        let fileExtension = url.pathExtension
        let fileDefaultName = url.lastPathComponent.replacingOccurrences(of: ".\(fileExtension)", with: "")
        
        let alert = NSAlert()
        alert.messageText = "Saved Current Keybind"
        alert.informativeText = "File name"
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
            let newUrl = url.deletingLastPathComponent().appendingPathComponent(fileNewName).appendingPathExtension(fileExtension)
            try? self.fileManager.moveItem(at: url, to: newUrl)
            completion()
        }
    }
    
    /// Store the given `urlPath` to `UserDefaults`. Pass `nil` to remove.
    private func rememberSelectedKeybind(urlPath: String?) {
        let userDefaults = UserDefaults.standard
        if let urlPath = urlPath {
            userDefaults.set(urlPath, forKey: kLastSelectedKeybind)
        } else {
            userDefaults.removeObject(forKey: kLastSelectedKeybind)
        }
    }
    
    private func fetchKeybinds() -> [Keybind] {
        guard let lolKeybindDir = lolKeybindDir else { return [] }
        var urls = try? fileManager.contentsOfDirectory(at: lolKeybindDir, includingPropertiesForKeys: nil, options: [])
        urls = urls?.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        let keybinds = urls?.compactMap({ Keybind(fileName: $0.lastPathComponent.replacingOccurrences(of: ".\($0.pathExtension)", with: ""), fileUrl: $0) })
        return keybinds ?? []
    }
    
    private func showErrorAlert(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.runModal()
    }
}
