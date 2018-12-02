//
//  SoundExtension.swift
//  LoLKeybind
//
//  Created by Dara Beng on 12/2/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Cocoa


enum Sound: String {
    case done = "Glass"
}

extension NSSound {
    
    static func play(_ sound: Sound) {
        let sound = NSSound(named: sound.rawValue)
        sound?.play()
    }
}
