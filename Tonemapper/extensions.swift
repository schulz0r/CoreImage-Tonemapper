//
//  extensions.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 25.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Foundation
import Metal

extension MTLTexture {
    func getDescriptor() -> MTLTextureDescriptor {
        let Descriptor = MTLTextureDescriptor()
        Descriptor.arrayLength = self.arrayLength
        Descriptor.depth = self.depth
        Descriptor.height = self.height
        Descriptor.mipmapLevelCount = self.mipmapLevelCount
        Descriptor.pixelFormat = self.pixelFormat
        Descriptor.sampleCount = self.sampleCount
        Descriptor.storageMode = self.storageMode
        Descriptor.textureType = self.textureType
        Descriptor.usage = self.usage
        Descriptor.width = self.width
        
        return Descriptor
    }
    
    func size() -> MTLSize {
        return MTLSizeMake(self.width, self.height, self.depth)
    }
}
