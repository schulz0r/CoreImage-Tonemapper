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
    
    private let inTexture, outTexture, labels : MTLTexture
    private let segmentationResults : [MTLBuffer]
    
    init(inputLinearImage: MTLTexture, output: MTLTexture, segmentationIO: segmentationIOProvider){
        self.inTexture = inputLinearImage
        self.outTexture = output
        self.segmentationResults = segmentationIO.fetchBuffers()!
        self.labels = segmentationIO.Labels
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.labels, self.outTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return self.segmentationResults
    }
}
