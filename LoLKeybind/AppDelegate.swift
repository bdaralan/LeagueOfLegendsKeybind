//
//  AppDelegate.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/24/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var availableKeybinds: [Keybind] = []


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBarItem()
        setupStatusBarItemNotificationObserver(self)
    }
}
