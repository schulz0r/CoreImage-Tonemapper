//
//  kMeansShaderIO.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 02.03.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKit
import MetalKitPlus

final class kMeansShaderIO: MTKPIOProvider {
    
    let inTexture : MTLTexture
    let Means, meanCount_k, buffer : MTLBuffer
    
    init(grayInputTexture: MTLTexture){
        self.inTexture = grayInputTexture
        
        var Means = Array<Float>(stride(from: 0, to: 1, by: 0.5)) // evenly distribute means over values
        var K = Means.count
        
        guard
            let Means_ = MTKPDevice.instance.makeBuffer(bytes: &Means, length: K * MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            let K_ = MTKPDevice.instance.makeBuffer(bytes: &K, length: MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            let Buffer_ = MTKPDevice.instance.makeBuffer(length: (MemoryLayout<uint>.size + MemoryLayout<Float>.size / 2) * K * (grayInputTexture.width * grayInputTexture.height) / (16 * 16), options: .storageModePrivate)
            else {
                fatalError()
        }
        
        self.Means = Means_
        self.meanCount_k = K_
        self.buffer = Buffer_
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return [Means, meanCount_k, buffer]
    }
}
