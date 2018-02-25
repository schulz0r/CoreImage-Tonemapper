//
//  TSTMFirstStepAsset.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 13.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import Metal
import MetalKitPlus
import ImageProcessing

let MAXIMUM_GAUSSIANS = 5

final class TSTMAsset: MTKImageProcessingAssets {
    
    // input buffer
    var mu: MTLBuffer? = nil
    var K: MTLBuffer? = nil
    
    // input texture
    var inputHDR: MTLTexture? = nil
    
    convenience init(IO: MTKAssetIO) {
        self.init(assetIO: IO)
     
        do {
            inputHDR = IO.inputTexture()
            
            // output texture
            let desc = MTLTextureDescriptor()
            desc.textureType = .type2D
            desc.pixelFormat = .rgba16Unorm
            desc.width = Int(inputHDR!.width)
            desc.height = Int(inputHDR!.height)
            desc.depth = 1
            desc.mipmapLevelCount = 1
            desc.arrayLength = 1
            desc.usage = .unknown
            self.outputTexture = device.makeTexture(descriptor: desc)
            
            // prepare first state in pipeline; the others will follow after the execution
            let minMaxMeanIO = extremaShaderIO(device: device, input: inputHDR!)
            add(Function: "getMinMaxMean", shaderIO: minMaxMeanIO, imageSize: (16,16,1))
            
        } catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
    }
    
    func initializeGMMState(with gaussianMixture: GaussianMixtureModell){
        
        //input buffer
        K = device.makeBuffer(bytes: &gaussianMixture.N, length: MemoryLayout<Float>.size, options: .storageModeManaged)
        mu = device.makeBuffer(bytes: &gaussianMixture.gaussians.mu, length: MemoryLayout<Float>.size * gaussianMixture.N, options: .storageModeManaged)
        
        let gmmModellingIO = gaussianModellingIO(device: self.device,
                                                 input: inputHDR!,
                                                 K: K!,
                                                 mu: mu!,
                                                 gaussianMixture: gaussianMixture)
        add(Function: "GMM_modelling", shaderIO: gmmModellingIO, imageSize: (16,16,gaussianMixture.N))
        
        let ferradansIO = ferradansShaderIO(device: device,
                                            input: inputHDR!,
                                            tonemappedOutput: self.outputTexture!,
                                            numberOfGaussians: K,
                                            mu: mu)
        add(Function: "ferradans", shaderIO: ferradansIO)
    }
}
