//
//  extensions.swift
//  TonemapperTests
//
//  Created by Philipp Waxweiler on 26.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import CoreImage
import AppKit

extension CIImage {
    func write(url: URL) {
        guard let pngFile = NSBitmapImageRep(ciImage: self).representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            fatalError("Could not convert to png.")
        }
        
        do {
            try pngFile.write(to: url)
        } catch let Error {
            print(Error.localizedDescription)
        }
    }
}
