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
    
    var applicationKeyWindow: NSWindow?
    var mainViewController: ViewController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBarIcon()
        applicationKeyWindow = NSApplication.shared.keyWindow
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        applicationKeyWindow?.makeKeyAndOrderFront(self)
        return true
    }
}
