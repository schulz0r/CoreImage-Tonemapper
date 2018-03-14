//
//  segmentationShaderIOP.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 14.03.18.
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
        let gaussCurveEnd = (KernelSize_s - 1) / 2
        let gaussCoefficients = (-gaussCurveEnd...gaussCurveEnd).map{ exp(-0.5 * powf(Float($0) / sigma_spatial, 2.0)) / (sigma_spatial * sqrt(2 * Float.pi)) }
        // outer product gives Kernel (cannot use separability with bilateral filter?)
        var KernelCoefficients = gaussCoefficients.flatMap{ Coeff in gaussCoefficients.map{Coeff * $0} }
        
        guard
            let Kernel_ = MTKPDevice.instance.makeBuffer(bytes: &KernelCoefficients, length: MemoryLayout<Float>.size * KernelCoefficients.count, options: .storageModeManaged),
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

final class kMeansShaderIO: MTKPIOProvider {
    
    let inTexture, Labels : MTLTexture
    let Means, meanCount_k, buffer, bufferLen : MTLBuffer
    
    init(grayInputTexture: MTLTexture){
        self.inTexture = grayInputTexture
        
        let LabelTexture_descriptor = grayInputTexture.getDescriptor()
        LabelTexture_descriptor.pixelFormat = .r8Uint
        
        var Means = Array<Float>(stride(from: 0, to: 1, by: 0.5)) + [1] // evenly distribute means over values
        var K = Means.count
        var bufferLen:uint = uint( K * Int(ceil(Float(grayInputTexture.width) / 16.0) * ceil(Float(grayInputTexture.height) / 16.0)) )
        
        guard
            let Means_ = MTKPDevice.instance.makeBuffer(bytes: &Means, length: K * MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            let K_ = MTKPDevice.instance.makeBuffer(bytes: &K, length: MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined),
            // buffer to store structs "clusterSum" (see .metal file). clusterSum consists of a uint and a half. Due to memory alignment, the half value takes 4 bytes, so here, we allocate 8 bytes (uint + float) for every clusterSum element
            let Buffer_ = MTKPDevice.instance.makeBuffer(length: (MemoryLayout<uint>.size + MemoryLayout<Float>.size) * Int(bufferLen), options: .storageModePrivate),
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
