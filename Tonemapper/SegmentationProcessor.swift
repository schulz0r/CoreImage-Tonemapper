//
//  SegmentationComputer.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 26.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import MetalKitPlus

final class SegmentationProcessor: MTKPComputer {
    var assets:MTKPAssets
    public var commandBuffer: MTLCommandBuffer!
    
    init(assets: MTKPAssets) {
        self.assets = assets
        self.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
    }
    
    public func encode(_ name:String, threads: MTLSize? = nil) {
        guard
            let descriptor = self.assets[name] as? MTKPComputePipelineStateDescriptor,
            descriptor.state != nil,
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()
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
}
