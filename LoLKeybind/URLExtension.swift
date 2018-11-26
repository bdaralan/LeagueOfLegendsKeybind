//
//  URLExtension.swift
//  LoLKeybind
//
//  Created by Dara Beng on 11/24/18.
//  Copyright © 2018 Dara Beng. All rights reserved.
//

import Foundation


extension URL {
    
    var lastPathComponentWithoutExtension: String {
        let fileExtension = pathExtension.isEmpty ? "" : ".\(pathExtension)"
        return lastPathComponent.replacingOccurrences(of: fileExtension, with: "")
    }
}
