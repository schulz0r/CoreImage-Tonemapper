//
//  imageMergeIOP.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 22.05.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKitPlus

final class ImageMergingIOProvider: MTKPIOProvider {
    let blendBuffer_1, blendBuffer_2: MTLTexture
    private let Mask, clusterLabels: MTLTexture
    
    init(clusterLabels: MTLTexture, BlendLevels: Int){
        let descriptor = clusterLabels.getDescriptor()
        descriptor.mipmapLevelCount = BlendLevels
        
        let blendBuffDescriptor = descriptor
        blendBuffDescriptor.pixelFormat = .rgba16Float
        
        guard
            let mask = MTKPDevice.instance.makeTexture(descriptor: descriptor),
            let blendBuffer1 = MTKPDevice.instance.makeTexture(descriptor: blendBuffDescriptor),
            let blendBuffer2 = MTKPDevice.instance.makeTexture(descriptor: blendBuffDescriptor)
        else {
            fatalError("Could not allocate Textures for blending algorithm.")
        }
        
        self.blendBuffer_1 = blendBuffer1
        self.blendBuffer_2 = blendBuffer2
        self.Mask = mask
        self.clusterLabels = clusterLabels
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [blendBuffer_1, blendBuffer_2, Mask, clusterLabels]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return nil
    }
}
