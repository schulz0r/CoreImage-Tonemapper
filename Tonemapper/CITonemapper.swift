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
    static let device = MTLCreateSystemDefaultDevice()
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let thresholdValue = arguments?["thresholdValue"] as? Float else  {
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
        
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        (1...5).forEach{ _ in   // repeat kMeans n times
            computer.encode("label")
            computer.encodeMPSHistogram(forImage: IOProvider.Labels, MTLHistogramBuffer: labelBins, numberOfClusters: 3)
            computer.encode("kMeans")
            computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * 3, 1, 1))
        }
        computer.encode("tonemap")
    }
}
