//
//  CITonemapper.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 24.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Foundation
import CoreImage
import MetalKitPlus

class ThresholdImageProcessorKernel: CIImageProcessorKernel {
    
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture else  {
                return
        }
        
        let grayIOProvider = toGrayShaderIO(image: sourceTexture)
        let bilateralFilterIO = bilateralFilterShaderIO(image: grayIOProvider.grayTexture, sigma_spatial: 1.5, sigma_range: 0.1)
        
        let kMeansSummationTGLength = [MemoryLayout<Float>.size * 256]
        let IOProvider = segmentationIOProvider(grayInputTexture: bilateralFilterIO.outTexture)
        let tonemapperIO = tonemappingIOProvider(inputLinearImage: sourceTexture, output: destinationTexture, segmentationIO: IOProvider)
        
        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: grayIOProvider))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: bilateralFilterIO))
        assets.add(shader: MTKPShader(name: "label", io: IOProvider))
        assets.add(shader: MTKPShader(name: "kMeans", io: IOProvider, tgConfig: MTKPThreadgroupConfig(tgSize: (16, 16, 1), tgMemLength: [8 * 256])))
        assets.add(shader: MTKPShader(name: "kMeansSumUp", io: IOProvider, tgConfig: MTKPThreadgroupConfig(tgSize: (256, 1, 1), tgMemLength: kMeansSummationTGLength)))
        assets.add(shader: MTKPShader(name: "tonemap", io: tonemapperIO))
        let computer = SegmentationProcessor(assets: assets)
        
        computer.encode("toGray", encodeTo: commandBuffer)
        computer.encode("bilateralFilter", encodeTo: commandBuffer)
        (1...3).forEach{ _ in   // repeat kMeans n times
            computer.encode("label", encodeTo: commandBuffer)
            computer.encodeMPSHistogram(forImage: IOProvider.Labels, MTLHistogramBuffer: IOProvider.ClusterMemberCount, numberOfClusters: 3, to: commandBuffer)
            computer.encode("kMeans", encodeTo: commandBuffer)
            computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * 3, 1, 1), encodeTo: commandBuffer)
        }
        computer.encode("tonemap", encodeTo: commandBuffer)
    }
}
