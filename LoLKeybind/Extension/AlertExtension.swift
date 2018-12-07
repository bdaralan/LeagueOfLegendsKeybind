//
//  AlertExtension.swift
//  LoLKeybind
//
//  Created by Dara Beng on 12/5/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa


extension NSAlert {
    
    static func showKeybindNotFound(_ window: NSWindow? = nil) {
        let alert = NSAlert()
        alert.messageText = "FileNotFound"
        alert.informativeText = "Keybind was probably deleted. Try to reload keybinds."
        if let window = window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
    
    static func show(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    
    static func textFieldAlert(messageText: String, informativeText: String, textFieldString: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        
        let textField = NSTextField(string: textFieldString)
        alert.accessoryView = textField
        alert.accessoryView?.frame.size.width = 200
        return alert
    }
}
