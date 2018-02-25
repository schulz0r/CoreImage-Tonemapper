//
//  ferradansShaderIO.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 28.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import MetalKitPlus

final class ferradansShaderIO: MTKShaderIO{
    
    convenience init(device: MTLDevice, input: MTLTexture, tonemappedOutput: MTLTexture, numberOfGaussians: MTLBuffer?, mu: MTLBuffer?) {
        
        self.init(device: device)
        
            fetchTextures = {
                return [input, tonemappedOutput]
            }
            fetchBuffers = {
                // First Step of TSTM
                let lambda_minus = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: .storageModeManaged)
                let lambda_plus = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: MTLResourceOptions())
                let m = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: MTLResourceOptions())
                let k = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: MTLResourceOptions())
                let h = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: MTLResourceOptions())
                let C = device.makeBuffer(length: MAXIMUM_GAUSSIANS * MemoryLayout<Float>.size, options: MTLResourceOptions())
                
                return [lambda_minus, lambda_plus, m, k, h, C, numberOfGaussians!, mu!]
            }
        
    }
    
}
