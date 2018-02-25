//
//  toGreyShaderIO.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 25.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKitPlus

final class toGrayShaderIO: MTKPIOProvider {
    
    let inTexture : MTLTexture
    
    init(image: MTLTexture){
        self.inTexture = image
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        let descriptor = self.inTexture.getDescriptor()
        descriptor.pixelFormat = .r16Float
        let greyTexture = MTKPDevice.instance.makeTexture(descriptor: descriptor)
        
        return [self.inTexture, greyTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return nil
    }
}
