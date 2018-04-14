//
//  tonemappingIOProvider.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 15.04.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKitPlus

final class tonemappingIOProvider: MTKPIOProvider {
    private let inTexture : MTLTexture
    
    init(linearHDR: MTLTexture, labels: MTLTexture){
        self.inTexture = linearHDR
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.inTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return nil
    }
}
