//
//  FileHandler.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/25/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Foundation


// MARK: - Notification Key

let kApplicationDidDeleteKeybind = "kApplicationDidDeleteKeybind"
let kApplicationDidSetKeybind = "kApplicationDidSetKeybind"


class FileHandler {
    
    static let `default` = FileHandler()
    
    let fileManager = FileManager.default
    
    
    // MARK: - Key
    
    private let kPersistedSettingsPath = "lolPersistedSettingsPath" // plist
    private let kPersistedSettingsFileName = "lolPersistedSettingsFileName" // plist
    private let kLastSetKeybind = "kLastSelectedKeybind" // userdefaults
    private let kPersistedSettingInputDict = "files" // client dictionary key
    
    let lolKeybindFolderName = "LoLKeybind"
    
    
    // MARK: - Computed Property
    
    var applicationDir: URL? {
        return fileManager.urls(for: .applicationDirectory, in: .systemDomainMask).first
    }
    
    var documentDir: URL? {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    var lolKeybindDir: URL? {
        guard let keybindDir = documentDir?.appendingPathComponent(lolKeybindFolderName, isDirectory: true) else { return nil }
        if !fileManager.fileExists(atPath: keybindDir.path) {
            try? fileManager.createDirectory(at: keybindDir, withIntermediateDirectories: false, attributes: nil)
        }
        return keybindDir
    }
    
    var clientPersistedSettingsFileUrl: URL? {
        guard let applicationDir = self.applicationDir else { return nil }
        let plist = Bundle.main.infoDictionary ?? [:]
        let persistedSettingsPath = plist[kPersistedSettingsPath] as? String ?? ""
        let persistedSettingsFileName = plist[kPersistedSettingsFileName] as? String ?? ""
        let persistedSettingsFilePath = "\(persistedSettingsPath)/\(persistedSettingsFileName)"
        let persistedSettingFileUrl = applicationDir.appendingPathComponent(persistedSettingsFilePath).appendingPathExtension("json")
        return persistedSettingFileUrl
    }
    
    
    // MARK: - Function
    
    func copyFilesToLoLKeybindDirectory(filesToCopy urls: [URL], completion: (Error?) -> Void) {
        guard let lolKeybindDir = lolKeybindDir else {
            let error = NSError(domain: "DirectoryNotFound", code: 1, userInfo: nil)
            completion(error)
            return
        }
        
        do {
            for url in urls {
                let destinationUrl = lolKeybindDir.appendingPathComponent(url.lastPathComponent)
                try fileManager.copyItem(at: url, to: destinationUrl)
            }
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func writeKeybindToClientPersistedSettings(keybindToWriteUrl: URL, completion: (Error?) -> Void) {
        guard let persistedSettingsFileUrl = clientPersistedSettingsFileUrl,
            let persistedSettingsData = fileManager.contents(atPath: persistedSettingsFileUrl.path) else {
                let error = NSError(domain: "FileNotFound", code: 1, userInfo: nil)
                completion(error)
                return
        }
        
        guard fileManager.fileExists(atPath: keybindToWriteUrl.path) else {
            let error = NSError(domain: "FileNotFound", code: 404, userInfo: nil)
            completion(error)
            return
        }

        guard let userKeybindData = fileManager.contents(atPath: keybindToWriteUrl.path) else {
            let error = NSError(domain: "CannotReadFile", code: 1, userInfo: nil)
            completion(error)
            return
        }

        do {
            let keybindToWrite = try JSONSerialization.jsonObject(with: userKeybindData, options: [])  as? [String: AnyObject]
            let clientPersistedSettingsJSON = try JSONSerialization.jsonObject(with: persistedSettingsData, options: []) as? [String: AnyObject]

            guard var persistedSettingsJSON = clientPersistedSettingsJSON else {
                let error = NSError(domain: "CannotReadFile", code: 1, userInfo: nil)
                completion(error)
                return
            }
            
            var filesKeyDict = clientPersistedSettingsJSON?[kPersistedSettingInputDict] as? [[String: AnyObject]] ?? []
            
            for (index, dict) in filesKeyDict.enumerated() where dict["name"] as? String == "Input.ini" {
                if let keybindToWrite = keybindToWrite {
                    filesKeyDict[index] = keybindToWrite
                    persistedSettingsJSON.updateValue(filesKeyDict as AnyObject, forKey: kPersistedSettingInputDict)
                    let updatedClientPersistedSettingData = try JSONSerialization.data(withJSONObject: persistedSettingsJSON, options: [.prettyPrinted])
                    try updatedClientPersistedSettingData.write(to: persistedSettingsFileUrl, options: [.atomic])
                    completion(nil)
                    return
                }
            }
        } catch {
            completion(error)
        }
    }
    
    func saveClientCurrentKeybind(completion: (URL?, Error?) -> Void) {
        guard let persistedSettingsFileUrl = clientPersistedSettingsFileUrl,
            let persistedSettingsData = fileManager.contents(atPath: persistedSettingsFileUrl.path) else {
                let error = NSError(domain: "CannotReadFile", code: 1, userInfo: nil) // dailed to read PersistedSetting.json
                completion(nil, error)
                return
        }

        guard let lolKeybindDir = lolKeybindDir else {
            let error = NSError(domain: "CannotAccessDirectory", code: 1, userInfo: nil) // failed to access LoLKeybind Folder
            completion(nil, error)
            return
        }

        // locate the input keybind key-vale pairs and write to disk
        // NOTE: Keys: "files", "name", and "Input.ini" needs to be updated manually if needed
        do {
            let persistedSettingsJSON = try JSONSerialization.jsonObject(with: persistedSettingsData, options: []) as? [String: AnyObject]
            let filesKeyDict = persistedSettingsJSON?[kPersistedSettingInputDict] as? [[String: AnyObject]] ?? []

            var foundInputINIToReplace = false
            for dict in filesKeyDict where dict["name"] as? String == "Input.ini" {
                foundInputINIToReplace = true
                let fileExtension = "json"
                let fileName = nonRepeatedFileName(forDirectory: lolKeybindDir, fileName: "Copied Keybind", fileExtension: fileExtension)
                let urlToWrite = lolKeybindDir.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
                let clientKeybindData = try JSONSerialization.data(withJSONObject: dict, options: [])
                try clientKeybindData.write(to: urlToWrite, options: .atomic)
                completion(urlToWrite, nil)
                return
            }
            
            // NOTE: this check can be removed if implementing json file's Input.ini key-valur pairs validation
            if !foundInputINIToReplace {
                let error = NSError(domain: "KeybindNotFound", code: 1, userInfo: nil)
                completion(nil, error)
            }
            
        } catch {
            completion(nil, error)
        }
    }
    
    func deleteFile(at url: URL, completion: (Error?) -> Void) {
        do {
            try fileManager.removeItem(at: url)
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func renameFile(at url: URL, to newName: String, completion: (Error?) -> Void) {
        let fileExtension = url.pathExtension
        let newUrl = url.deletingLastPathComponent().appendingPathComponent(newName).appendingPathExtension(fileExtension)
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func jsonFilesInDirectory(url: URL) -> [URL] {
        var urls = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        urls = urls?.filter({ $0.pathExtension == "json" })
        return urls ?? []
    }
    
    /// Store the given `urlPath` to `UserDefaults`. Pass `nil` to remove.
    func rememberSetKeybindUrlPath(_ urlPath: String?) {
        let userDefaults = UserDefaults.standard
        if let urlPath = urlPath {
            userDefaults.set(urlPath, forKey: kLastSetKeybind)
        } else {
            userDefaults.removeObject(forKey: kLastSetKeybind)
        }
    }
    
    func previousSetKeybindUrl() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: kLastSetKeybind) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    func fetchKeybinds(at url: URL) -> [Keybind] {
        let jsonFileUrls = jsonFilesInDirectory(url: url).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        let keybinds = jsonFileUrls.compactMap({ Keybind(fileName: $0.lastPathComponentWithoutExtension, fileUrl: $0) })
        return keybinds
    }
    
    func nonRepeatedFileName(forDirectory url: URL, fileName: String, fileExtension: String) -> String {
        let usedFileNames = jsonFilesInDirectory(url: url).filter({ $0.pathExtension == fileExtension}).compactMap({ $0.lastPathComponentWithoutExtension })
        
        // assuming user will not have 1000 names of the same file σ(^_^;)
        var result = fileName
        for number in 1 ... 1000 where usedFileNames.contains(result) {
            result = "\(fileName)(\(number))"
        }
        return result
    }
}
