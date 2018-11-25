//
//  KeybindFileManager.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/24/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Foundation


struct KeybindFileManager {
    
    let fileManager = FileManager.default
    
    func fetchAvailableFiles(inFolder url: URL) {
        if fileManager.fileExists(atPath: url.path) {
           print("path exists")
        }
    }
}
