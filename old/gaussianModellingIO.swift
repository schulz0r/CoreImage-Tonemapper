//
//  gaussianModellingIO.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 27.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import MetalKitPlus

final class gaussianModellingIO: MTKShaderIO{
    
    convenience init(device: MTLDevice, input: MTLTexture, K: MTLBuffer, mu: MTLBuffer, gaussianMixture: GaussianMixtureModell) {
        
        self.init(device: device)
        
        do{
            fetchTextures = {
                return [input]
            }
            fetchBuffers = {
                let p = self.device.makeBuffer(bytes: &gaussianMixture.gaussians.p, length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                let sigma = self.device.makeBuffer(bytes: &gaussianMixture.gaussians.variance, length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                let mu_nu_gpu = self.device.makeBuffer(length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                let sigma_nu_gpu = self.device.makeBuffer(length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                let p_nu_gpu = self.device.makeBuffer(length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                let debug = self.device.makeBuffer(length: gaussianMixture.N * MemoryLayout<Float>.size, options: .storageModeShared)
                
                return [K, mu, sigma, p, mu_nu_gpu, sigma_nu_gpu, p_nu_gpu, debug]
            }
        } catch {
            fatalError("Ressources for weight function estimation could not be fetched!")
        }
        
    }
    
}
