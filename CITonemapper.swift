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
            let destinationTexture = output.metalTexture
        else  {
                return
        }
        
        let kClusters = 3 // TODO: enable segmentation provider to provide more clusters
        let globalIterator:[MTLBuffer] = (0..<kClusters).map{
            var index = uint($0)
            guard let buffer = MTKPDevice.instance.makeBuffer(bytes: &index, length: MemoryLayout<uint>.size, options: .cpuCacheModeWriteCombined) else {
                fatalError()
            }
            return buffer
        }
        
        let grayIOProvider = toGrayShaderIO(image: sourceTexture)
        let bilateralFilterIO = bilateralFilterShaderIO(image: grayIOProvider.grayTexture, sigma_spatial: 1.5, sigma_range: 0.1)
        
        let kMeansSummationTGLength = [MemoryLayout<Float>.size * 256]
        let IOProvider = segmentationIOProvider(grayInputTexture: bilateralFilterIO.outTexture)
        let tonemapperIO = tonemappingIOProvider(inputLinearImage: sourceTexture, output: destinationTexture, Means: IOProvider.Means)
        let imageBlendingIO = ImageMergingIOProvider(clusterLabels: IOProvider.Labels, BlendLevels: 3)
        
        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: grayIOProvider))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: bilateralFilterIO))
        assets.add(shader: MTKPShader(name: "label", io: IOProvider))
        assets.add(shader: MTKPShader(name: "kMeans", io: IOProvider, tgConfig: MTKPThreadgroupConfig(tgSize: (16, 16, 1), tgMemLength: [8 * 256])))
        assets.add(shader: MTKPShader(name: "kMeansSumUp", io: IOProvider, tgConfig: MTKPThreadgroupConfig(tgSize: (256, 1, 1), tgMemLength: kMeansSummationTGLength)))
        assets.add(shader: MTKPShader(name: "tonemap", io: tonemapperIO))
        let computer = SegmentationProcessor(assets: assets)
        
        // Segment image
        computer.encode("toGray", encodeTo: commandBuffer)
        computer.encode("bilateralFilter", encodeTo: commandBuffer)
        
        (1...kClusters).forEach{ _ in   // repeat kMeans n times
            computer.encode("label", encodeTo: commandBuffer)
            computer.encodeMPSHistogram(forImage: IOProvider.Labels, MTLHistogramBuffer: IOProvider.ClusterMemberCount, numberOfClusters: 3, to: commandBuffer)
            computer.encode("kMeans", encodeTo: commandBuffer)
            computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * kClusters, 1, 1), encodeTo: commandBuffer)
        }
        
        // tonemap
        computer.encode("tonemap", encodeTo: commandBuffer)
        computer.makeImagePyramid(from: tonemapperIO.tonemappedImage, pyramidTexture: imageBlendingIO.blendBuffer_1, encodeTo: commandBuffer)
        // todo: calculate laplacian pyramid of blendBuffer1
        (1..<kClusters).forEach {
            assets["tonemap"]?.buffers?[5] = globalIterator[$0]
            // todo: make mask for this iteration
            // todo: make gaussian pyramid from said mask
            computer.makeImagePyramid(from: tonemapperIO.tonemappedImage, pyramidTexture: imageBlendingIO.blendBuffer_2, encodeTo: commandBuffer)
            // todo: calculate laplacian pyramid of blendBuffer2
            // todo: blend blendbuffer2 into blendbuufer1 using the gaussian pyramid from mask
        }
    }
}
