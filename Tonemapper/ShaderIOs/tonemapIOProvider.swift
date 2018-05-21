//
//  tonemapIOProvider.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 22.04.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKitPlus

final class tonemappingIOProvider: MTKPIOProvider {
    let tonemappedImage : MTLTexture
    private let inTexture : MTLTexture
    private let Means, clusterIndex : MTLBuffer
    
    init(inputLinearImage: MTLTexture, output: MTLTexture, Means: MTLBuffer){
        guard let pickCluster = MTKPDevice.instance.makeBuffer(length: MemoryLayout<Int32>.size, options: MTLResourceOptions.storageModeManaged) else {
            fatalError("Could not allocate a texture.")
        }
        
        self.clusterIndex = pickCluster
        self.tonemappedImage = output
        self.inTexture = inputLinearImage
        self.Means = Means
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.tonemappedImage]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return [self.Means, self.clusterIndex]
    }
}
