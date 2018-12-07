//
//  AppDelegate.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/24/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let statusBarIcon = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let statusBarIconMenu = NSMenu()
    lazy var availableKeybinds: [Keybind] = KeybindManager.default.availableKeybinds()
    
    var applicationMainWindow: NSWindow?
    var mainViewController: ViewController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBarIcon()
        applicationMainWindow = NSApplication.shared.mainWindow
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        applicationMainWindow?.makeKey()
        applicationMainWindow?.orderFrontRegardless()
        return true
    }
}
