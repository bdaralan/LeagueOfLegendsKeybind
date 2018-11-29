//
//  AppDelegate+StatusBarItem.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/28/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa


enum StatusBarItemStyle: String {
    
    static let kPreferredStatusItemStyle = "kPreferredStatusItem"
    
    case color = "status-item-color"
    case black = "status-item-black"
}


// MARK: - Function

extension AppDelegate {
    
    func setStatusBarItemStyle(_ style: StatusBarItemStyle) {
        let imageName = NSImage.Name(style.rawValue)
        statusBarItem.button?.image = NSImage(named: imageName)
        UserDefaults.standard.setValue(style.rawValue, forKey: StatusBarItemStyle.kPreferredStatusItemStyle)
    }
    
    @objc private func activateSeletecKeybind(_ sender: NSMenuItem) {
        let keybind = availableKeybinds[sender.tag]
        
        let fileHandler = FileHandler.default
        fileHandler.writeKeybindToClientPersistedSettings(keybindToWriteUrl: keybind.fileUrl) { (error) in
            if let error = error {
                let alert = NSAlert(error: error)
                alert.runModal()
            } else {
                fileHandler.rememberSetKeybindUrlPath(keybind.fileUrl.path)
                sender.state = NSControl.StateValue.on
                sender.menu?.items.forEach({ $0.state = $0.tag == sender.tag ? .on : .off })
                NotificationCenter.default.post(name: .init(rawValue: kApplicationDidSetKeybind), object: keybind)
            }
        }
    }
}


// MARK: - StatusBarItem Setup Function

extension AppDelegate {
    
    func setupStatusBarItem() {
        let preferredStyleString = UserDefaults.standard.string(forKey: StatusBarItemStyle.kPreferredStatusItemStyle) ?? ""
        let preferredStyle = StatusBarItemStyle(rawValue: preferredStyleString) ?? .color
        setStatusBarItemStyle(preferredStyle)
        setupStatusBarItemMenu()
    }
    
    @objc private func setupStatusBarItemMenu() {
        let fileHandler = FileHandler.default
        guard let keybindDir = fileHandler.lolKeybindDir else { return }
        availableKeybinds = fileHandler.fetchKeybinds(at: keybindDir)
        
        let previousSetKeybindUrl = fileHandler.previousSetKeybindUrl()
        let menu = NSMenu()
        menu.showsStateColumn = true
        
        for (index, keybind) in availableKeybinds.enumerated() {
            let menuItem = NSMenuItem(
                title: keybind.fileName,
                action: #selector(activateSeletecKeybind(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index
            menuItem.state = keybind.fileUrl == previousSetKeybindUrl ? .on : .off
            menu.addItem(menuItem)
        }
        
        statusBarItem.menu = menu
    }
    
    func setupStatusBarItemNotificationObserver(_ observer: Any) {
        let notificationCenter = NotificationCenter.default
        let setupStatusBarItemMenuAction = #selector(setupStatusBarItemMenu)
        notificationCenter.addObserver(
            observer, selector: setupStatusBarItemMenuAction,
            name: .init(rawValue: kApplicationDidSetKeybind), object: nil
        )
        notificationCenter.addObserver(
            observer, selector: setupStatusBarItemMenuAction,
            name: .init(rawValue: kApplicationDidDeleteKeybind), object: nil
        )
    }
}



