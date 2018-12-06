//
//  AppDelegate+StatusBarItem.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/28/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa


enum AppStatusBarIconStyle: String { // where String is the correspoding asset's name
    
    static let kPreferredIconStyle = "kPreferredIconStyle"
    static let `default` = AppStatusBarIconStyle.black
    
    case color = "status-item-color"
    case black = "status-item-black"
}


// MARK: - Function

extension AppDelegate {
    
    @objc private func activateSeletecKeybind(_ sender: NSMenuItem) {
        guard sender.tag < availableKeybinds.count else {
            NSAlert.showKeybindNotFound()
            return
        }
        
        let keybind = availableKeybinds[sender.tag]
        let keybindManager = KeybindManager.default
        
        keybindManager.writeKeybindToClientPersistedSettings(keybindToWrite: keybind) { (error) in
            if let error = error {
                NSAlert.show(error)
            } else {
                keybindManager.rememberSetKeybind(keybind)
                sender.state = .on
                sender.menu?.items.forEach({ $0.state = $0.tag == sender.tag ? .on : .off })
                NSSound.play(.done)
                NotificationCenter.default.post(name: .init(rawValue: kApplicationDidSetKeybind), object: keybind)
            }
        }
    }
}


// MARK: - StatusBarItem Setup Function

extension AppDelegate {
    
    func setupStatusBarIcon() {
        let preferredStyleString = UserDefaults.standard.string(forKey: AppStatusBarIconStyle.kPreferredIconStyle) ?? ""
        let preferredStyle = AppStatusBarIconStyle(rawValue: preferredStyleString) ?? .default
        statusBarIcon.menu = statusBarIconMenu
        statusBarIconMenu.delegate = self
        statusBarIconMenu.showsStateColumn = true
        setAppStatusBarIconStyle(preferredStyle)
        reloadStatusBarIconMenuItems()
    }
    
    func setAppStatusBarIconStyle(_ style: AppStatusBarIconStyle) {
        let imageName = NSImage.Name(style.rawValue)
        statusBarIcon.button?.image = NSImage(named: imageName)
        UserDefaults.standard.setValue(style.rawValue, forKey: AppStatusBarIconStyle.kPreferredIconStyle)
    }
    
    @objc private func reloadStatusBarIconMenuItems() {
        let keybindManager = KeybindManager.default
        
        availableKeybinds = keybindManager.availableKeybinds
        statusBarIconMenu.removeAllItems()
        
        guard !availableKeybinds.isEmpty else {
            statusBarIconMenu.addItem(.init(title: "None", action: nil, keyEquivalent: ""))
            return
        }
        
        let previousSetKeybind = keybindManager.previousSetKeybind
        let activateKeybind = #selector(activateSeletecKeybind(_:))
        
        availableKeybinds.enumerated().forEach { (index, keybind) in
            let menuItem = NSMenuItem(title: keybind.fileName, action: activateKeybind, keyEquivalent: "")
            menuItem.tag = index
            menuItem.state = keybind == previousSetKeybind ? .on : .off
            statusBarIconMenu.addItem(menuItem)
        }
    }
    
    func setupStatusBarItemNotificationObserver(_ observer: Any) {
        let notificationCenter = NotificationCenter.default
        let reloadStatusBarMenuItems = #selector(reloadStatusBarIconMenuItems)
        let keybindDidSet = Notification.Name(kApplicationDidSetKeybind)
        let keybindDidDelete = Notification.Name(kApplicationDidDeleteKeybind)
        notificationCenter.addObserver(observer, selector: reloadStatusBarMenuItems, name: keybindDidSet, object: nil)
        notificationCenter.addObserver(observer, selector: reloadStatusBarMenuItems, name: keybindDidDelete, object: nil)
    }
}


extension AppDelegate: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        reloadStatusBarIconMenuItems()
    }
    
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        return true
    }
}

