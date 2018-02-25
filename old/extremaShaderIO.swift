//
//  extremaShaderIO.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 27.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import MetalKitPlus

final class extremaShaderIO: MTKShaderIO{
    
    convenience init(device: MTLDevice, input: MTLTexture) {
        self.init(device: device)
        
        fetchTextures = {
            return [input]
        }
        fetchBuffers = {
            let maximum = device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)
            let minimum = device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)
            let arithmeticMean = device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)
            
            return [maximum, minimum, arithmeticMean]
        }
    }
    
}
