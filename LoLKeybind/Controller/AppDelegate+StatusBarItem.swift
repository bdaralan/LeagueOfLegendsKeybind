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


// MARK: - Computed Property

extension AppDelegate {
    
    var currentStatusBarIconStyle: AppStatusBarIconStyle {
        let currentStyle = UserDefaults.standard.string(forKey: AppStatusBarIconStyle.kPreferredIconStyle) ?? ""
        return AppStatusBarIconStyle(rawValue: currentStyle) ?? .default
    }
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
        setAppStatusBarIconStyle(preferredStyle)
        
        statusBarIcon.menu = statusBarIconMenu
        statusBarIconMenu.delegate = self
        statusBarIconMenu.showsStateColumn = true
        reloadStatusBarIconMenuItems()
        setupStatusBarItemNotificationObserver()
    }
    
    func setAppStatusBarIconStyle(_ style: AppStatusBarIconStyle) {
        let imageName = NSImage.Name(style.rawValue)
        statusBarIcon.button?.image = NSImage(named: imageName)
        UserDefaults.standard.setValue(style.rawValue, forKey: AppStatusBarIconStyle.kPreferredIconStyle)
    }
    
    @objc private func reloadStatusBarIconMenuItems() { // TODO: refactor this
        let keybindManager = KeybindManager.default
        availableKeybinds = keybindManager.availableKeybinds()
        statusBarIconMenu.removeAllItems()
        
        let keybindMenuItems = createMenuItems(for: availableKeybinds, selectKeybind: keybindManager.previousSetKeybind())
        let appFeatureMenuItems = createAppFeatureMenuItems()
    
        if keybindMenuItems.isEmpty {
            let keybindNotFoundMenuItem = NSMenuItem(title: "No Keybind", action: nil, keyEquivalent: "")
            statusBarIconMenu.addItem(keybindNotFoundMenuItem)
        }
        keybindMenuItems.forEach({ statusBarIconMenu.addItem($0) })
        statusBarIconMenu.addItem(.separator())
        appFeatureMenuItems.forEach({ statusBarIconMenu.addItem($0) })
    }
    
    /// Create keybind menu items for the given keybinds where item tag match with the each keybind index.
    private func createMenuItems(for keybinds: [Keybind], selectKeybind: Keybind?) -> [NSMenuItem] {
        let activateKeybind = #selector(activateSeletecKeybind(_:))
        let menuItems = keybinds.enumerated().compactMap { (index, keybind) -> NSMenuItem in
            let meniItem = NSMenuItem(title: keybind.fileName, action: activateKeybind, keyEquivalent: "")
            meniItem.tag = index
            meniItem.state = keybind == selectKeybind ? .on : .off
            return meniItem
        }
        return menuItems
    }
    
    private func createAppFeatureMenuItems() -> [NSMenuItem] {
        var menuItems: [NSMenuItem] = []
        let iconColorOrBlack = currentStatusBarIconStyle == .color ? "Black" : "Color"
        menuItems.append(.init(title: "Save Client's Current Keybind", action: #selector(saveClientCurrentKeybind), keyEquivalent: "s"))
        menuItems.append(.init(title: "Use \(iconColorOrBlack) Status Bar Icon", action: #selector(toggleStatusBarIcon), keyEquivalent: ""))
        menuItems.append(.init(title: "Show App", action: #selector(openApplication), keyEquivalent: ""))
        return menuItems
    }
    
    func setupStatusBarItemNotificationObserver() {
        let notificationCenter = NotificationCenter.default
        let reloadStatusBarMenuItems = #selector(reloadStatusBarIconMenuItems)
        let keybindDidSet = Notification.Name(kApplicationDidSetKeybind)
        let keybindDidDelete = Notification.Name(kApplicationDidDeleteKeybind)
        notificationCenter.addObserver(self, selector: reloadStatusBarMenuItems, name: keybindDidSet, object: nil)
        notificationCenter.addObserver(self, selector: reloadStatusBarMenuItems, name: keybindDidDelete, object: nil)
    }
}


// MARK: - Menu Item Action

extension AppDelegate {
    
    @objc private func openApplication() {
        applicationMainWindow?.makeKey()
        applicationMainWindow?.orderFrontRegardless()
    }
    
    @objc private func saveClientCurrentKeybind() {
        KeybindManager.default.saveClientCurrentKeybind { (keybindUrl, error) in
            guard let keybindUrl = keybindUrl else {
                let alert = NSAlert(error: error!)
                alert.runModal()
                return
            }
            
            mainViewController?.askUserToRenameSavedKeybindFile(url: keybindUrl, completion: { (renamed) in
                self.mainViewController?.reloadKeybindPopUpBtn()
                self.reloadStatusBarIconMenuItems()
            })
        }
    }
    
    @objc private func toggleStatusBarIcon() {
        let style: AppStatusBarIconStyle = currentStatusBarIconStyle == .color ? .black : .color
        setAppStatusBarIconStyle(style)
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

