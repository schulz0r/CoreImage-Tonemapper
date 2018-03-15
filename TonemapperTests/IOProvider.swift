//
//  IOProvider.swift
//  TonemapperTests
//
//  Created by Philipp Waxweiler on 14.03.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Foundation
import MetalKitPlus
@testable import Tonemapper

/* This IO is the same as "kMeansShaderIO", but the labels texture has another pixel format to make it compatible with CoreImage. This class is intended for the use in test functions only. */
final class kMeansShader_TestIO: MTKPIOProvider {
    
    let inTexture, Labels : MTLTexture
    let Means, meanCount_k, buffer, bufferLen : MTLBuffer
    
    init(grayInputTexture: MTLTexture){
        self.inTexture = grayInputTexture
        
        let LabelTexture_descriptor = grayInputTexture.getDescriptor()
        LabelTexture_descriptor.pixelFormat = .r8Unorm
        
        var Means = Array<Float>(stride(from: 0, to: 1, by: 0.5)) + [1] // evenly distribute means over values
        var K = Means.count
        var bufferLen:uint = uint( K * Int(ceil(Float(grayInputTexture.width) / 16.0) * ceil(Float(grayInputTexture.height) / 16.0)) )
        
        guard
            let Means_ = MTKPDevice.instance.makeBuffer(bytes: &Means, length: K * MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            let K_ = MTKPDevice.instance.makeBuffer(bytes: &K, length: MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            // buffer to store structs "clusterSum" (see .metal file). clusterSum consists of a uint and a half. Due to memory alignment, the half value takes 4 bytes, so here, we allocate 8 bytes (uint + float) for every clusterSum element
            let Buffer_ = MTKPDevice.instance.makeBuffer(length: (MemoryLayout<uint>.size + MemoryLayout<Float>.size) * Int(bufferLen), options: .storageModeShared),
            let BufferLen_ = MTKPDevice.instance.makeBuffer(bytes: &bufferLen, length: MemoryLayout<uint>.size, options: .cpuCacheModeWriteCombined),
            let LabelTexture = MTKPDevice.instance.makeTexture(descriptor: LabelTexture_descriptor)
            else {
                fatalError()
        }
        
        self.Means = Means_
        self.meanCount_k = K_
        self.buffer = Buffer_
        self.bufferLen = BufferLen_
        self.Labels = LabelTexture
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.Labels]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return [Means, meanCount_k, buffer, bufferLen]
    }
}
