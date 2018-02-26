//
//  bilateralFilterIO.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 25.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Metal
import MetalKitPlus

final class bilateralFilterShaderIO: MTKPIOProvider {
    
    let inTexture, outTexture : MTLTexture
    let Kernel, KernelSize, Sigma_r : MTLBuffer
    
    init(image: MTLTexture, outTexture: MTLTexture, sigma_spatial: Float, sigma_range: Float){
        self.inTexture = image
        self.outTexture = outTexture
        
        var sigma_buffer = sigma_range
        
        var KernelSize_s = Int(ceil((2 * sigma_spatial * 3) - 1))
        
        guard KernelSize_s <= 16 else {
            fatalError("KernelSize cannot be greater than 16. Choose a value for sigma_spatial which is lower than 2.8")
        }
        
        // generate one dimensional gaussian
        let gaussCoefficients = (0..<KernelSize_s).map{ exp(-0.5 * powf(Float($0) / sigma_spatial, 2.0)) / (sigma_spatial * sqrt(2 * Float.pi)) }
        // outer product gives Kernel (cannot use separability with bilateral filter?)
        var KernelCoefficients = gaussCoefficients.map{ Coeff in gaussCoefficients.map{Coeff * $0} }
        
        guard
            let Kernel_ = MTKPDevice.instance.makeBuffer(bytes: &KernelCoefficients, length: MemoryLayout<Float>.size * KernelSize_s * KernelSize_s, options: .storageModeManaged),
            let KernelSize_ = MTKPDevice.instance.makeBuffer(bytes: &KernelSize_s, length: MemoryLayout<uint>.size, options: .storageModeManaged),
            let sigma_r_ = MTKPDevice.instance.makeBuffer(bytes: &sigma_buffer, length: MemoryLayout<Float>.size, options: .storageModeManaged)
        else {
            fatalError()
        }
        
        self.Kernel = Kernel_
        self.KernelSize = KernelSize_
        self.Sigma_r = sigma_r_
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.outTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return [Kernel, KernelSize, Sigma_r]
    }
}

