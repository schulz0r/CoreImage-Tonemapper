//
//  SegmentationComputer.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 26.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import MetalPerformanceShaders
import MetalKitPlus

final class SegmentationProcessor: MTKPComputer {
    var assets:MTKPAssets
    public var commandBuffer: MTLCommandBuffer!
    
    init(assets: MTKPAssets) {
        self.assets = assets
        self.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
    }
    
    public func encode(_ name:String, threads: MTLSize? = nil, encodeTo: MTLCommandBuffer? = nil) {
        guard
            let descriptor = self.assets[name] as? MTKPComputePipelineStateDescriptor,
            descriptor.state != nil,
            let computeEncoder = encodeTo?.makeComputeCommandEncoder() ?? commandBuffer.makeComputeCommandEncoder()
            else {
                fatalError()
        }
        guard (threads != nil) || (descriptor.textures != nil) else {
            fatalError("The thread count is unknown. Pass it as an argument to the encode function.")
        }
        
        let threadCount = threads ?? descriptor.textures![0]!.size()
        
        computeEncoder.setComputePipelineState(descriptor.state!)
        if let textures = descriptor.textures {
            computeEncoder.setTextures(textures, range: 0..<textures.count)
        }
        if let buffers = descriptor.buffers {
            computeEncoder.setBuffers(buffers, offsets: [Int](repeating: 0, count: buffers.count), range: 0..<buffers.count)
        }
        if let TGMemSize = descriptor.tgConfig.tgMemLength {
            TGMemSize.enumerated().forEach({
                computeEncoder.setThreadgroupMemoryLength($0.element, index: $0.offset)
            })
        }
        computeEncoder.dispatchThreads(threadCount, threadsPerThreadgroup: descriptor.tgConfig.tgSize)
        computeEncoder.endEncoding()
    }
    
    public func execute(_ name:String, threads: MTLSize? = nil) {
        guard
            let descriptor = self.assets[name] as? MTKPComputePipelineStateDescriptor,
            descriptor.state != nil,
            let cmdBuffer = MTKPDevice.commandQueue.makeCommandBuffer(),
            let computeEncoder = cmdBuffer.makeComputeCommandEncoder()
            else {
                fatalError()
        }
        guard (threads != nil) || (descriptor.textures != nil) else {
            fatalError("The thread count is unknown. Pass it as an argument to the encode function.")
        }
        let threadCount = threads ?? descriptor.textures![0]!.size()
        
        computeEncoder.setComputePipelineState(descriptor.state!)
        if let textures = descriptor.textures {
            computeEncoder.setTextures(textures, range: 0..<textures.count)
        }
        if let buffers = descriptor.buffers {
            computeEncoder.setBuffers(buffers, offsets: [Int](repeating: 0, count: buffers.count), range: 0..<buffers.count)
        }
        if let TGMemSize = descriptor.tgConfig.tgMemLength {
            TGMemSize.enumerated().forEach({
                computeEncoder.setThreadgroupMemoryLength($0.element, index: $0.offset)
            })
        }
        computeEncoder.dispatchThreads(threadCount, threadsPerThreadgroup: descriptor.tgConfig.tgSize)
        computeEncoder.endEncoding()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
    }
    
    public func encodeMPSHistogram(forImage: MTLTexture, MTLHistogramBuffer: MTLBuffer, numberOfClusters: Int){
        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: 256, histogramForAlpha: false,
            minPixelValue: vector_float4(0,0,0,0),
            maxPixelValue: vector_float4(256,256,256,256))
        let calculation = MPSImageHistogram(device: MTKPDevice.instance, histogramInfo: &histogramInfo)
        calculation.zeroHistogram = true
        
        guard MTLHistogramBuffer.length == calculation.histogramSize(forSourceFormat: forImage.pixelFormat) else {
            fatalError("Did not allocate enough memory for storing histogram Data in given buffer.")
        }
        
        calculation.encode(to: commandBuffer,
                           sourceTexture: forImage,
                           histogram: MTLHistogramBuffer,
                           histogramOffset: 0)
    }
}
