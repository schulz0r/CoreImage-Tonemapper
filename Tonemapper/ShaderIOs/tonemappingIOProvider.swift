//
//  tonemappingIOProvider.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 15.04.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import MetalKit
import MetalKitPlus

final class tonemappingIOProvider: MTKPIOProvider {
    private let inTexture : MTLTexture
    private let tonemappingCurve, cubicSplineMatrix : MTLBuffer
    
    init(linearHDR: MTLTexture, labels: MTLTexture, classes: Int){
        let curveControlPointsCount = 12 // 8 control points + 4 at the start/end
        var ControlPoints = [0] + stride(from: 0, to: 1, by: 1.0 / 8.0) + [1,1,1]
        var matrix:[float4] = [float4(-1.0/6.0,0.5,-0.5,1.0/6.0),
                               float4(0.5,-1,0,2.0/3.0),
                               float4(-0.5,0.5,0.5,1.0/6.0),
                               float4(1.0/6.0,0,0,0)]    // = float4x4
        
        guard
            let tonemappingCurve_ = MTKPDevice.instance.makeBuffer(length: classes * curveControlPointsCount * MemoryLayout<Float>.size, options: .storageModeManaged),
            let cubicSplineMatrix_ = MTKPDevice.instance.makeBuffer(bytes: &matrix, length: MemoryLayout<float4>.size * 4, options: .cpuCacheModeWriteCombined)
            else {
            fatalError()
        }
        
        // start all control points with linear curves
        (0..<classes).forEach{
            memcpy(tonemappingCurve_.contents() + $0 * curveControlPointsCount * MemoryLayout<Float>.size, &ControlPoints, curveControlPointsCount * MemoryLayout<Float>.size)
        }
        
        self.inTexture = linearHDR
        self.tonemappingCurve = tonemappingCurve_
        self.cubicSplineMatrix = cubicSplineMatrix_
    }
    
    func fetchTextures() -> [MTLTexture?]? {
        return [self.inTexture, self.inTexture]
    }
    
    func fetchBuffers() -> [MTLBuffer]? {
        return [tonemappingCurve, cubicSplineMatrix]
    }
}
