//
//  TonemapperTests.swift
//  TonemapperTests
//
//  Created by Philipp Waxweiler on 07.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import XCTest
import MetalKit
import MetalKitPlus
@testable import Tonemapper

class TonemapperTests: XCTestCase {
    var computer:SegmentationProcessor! = nil
    let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/")
    var kMeansIO : segmentationIOProvider! = nil
    
    override func setUp() {
        super.setUp()
        let textureLoader = MTKTextureLoader(device: MTKPDevice.instance)
        let pictureURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/myTestpic.jpg")
        var TestTexture:MTLTexture! = nil
        
        // load a texture
        do{
            TestTexture = try textureLoader.newTexture(URL: pictureURL, options: nil)
        } catch let Error { fatalError(Error.localizedDescription) }
        
        let grayIOProvider = toGrayShaderIO(image: TestTexture)
        let bilateralFilterIO = bilateralFilterShaderIO(image: grayIOProvider.grayTexture, sigma_spatial: 1.5, sigma_range: 0.1)
        
        let kMeansTGLength = [8 * 256] // ushort + uint + half becomes uint + uint + float due to memory alignment
        let kMeansSummationTGLength = [MemoryLayout<Float>.size * 256]
        self.kMeansIO = segmentationIOProvider(grayInputTexture: bilateralFilterIO.outTexture)
        let tonemapperIO = tonemappingIOProvider(inputLinearImage: TestTexture, output: TestTexture, segmentationIO: kMeansIO)

        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: grayIOProvider))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: bilateralFilterIO))
        assets.add(shader: MTKPShader(name: "label", io: kMeansIO))
        assets.add(shader: MTKPShader(name: "kMeans", io: kMeansIO, tgConfig: MTKPThreadgroupConfig(tgSize: (16, 16, 1), tgMemLength: kMeansTGLength)))
        assets.add(shader: MTKPShader(name: "kMeansSumUp", io: kMeansIO, tgConfig: MTKPThreadgroupConfig(tgSize: (256, 1, 1), tgMemLength: kMeansSummationTGLength)))
        assets.add(shader: MTKPShader(name: "tonemap", io: tonemapperIO))
        computer = SegmentationProcessor(assets: assets)
    }
    
    func testGrayShader() {
        guard let grayTexture = computer.assets["toGray"]?.textures?[1] else {
            fatalError()
        }
        
        computer.execute("toGray")
        
        let Image = CIImage(mtlTexture: grayTexture, options: nil)!
        
        Image.write(url: desktopURL.appendingPathComponent("GrayShader.png"))
    }
    
    func testBilateralFilter() {
        guard let filteredTexture = computer.assets["bilateralFilter"]?.textures?[1] else {
            fatalError()
        }
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        let Image = CIImage(mtlTexture: filteredTexture, options: nil)!
        
        Image.write(url: desktopURL.appendingPathComponent("BilateralFilterShader.png"))
    }
    
    func testDataLabeling() {
        guard
            let labelBins = MTKPDevice.instance.makeBuffer(length: MemoryLayout<uint>.size * 256, options: .storageModeShared)
            else {
                fatalError()
        }
        
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        computer.encode("label")
        computer.encodeMPSHistogram(forImage: kMeansIO.Labels, MTLHistogramBuffer: labelBins, numberOfClusters: 3)
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        let ClusterSizes = Array(UnsafeBufferPointer(start: labelBins.contents().bindMemory(to: uint.self, capacity: 3), count: 3))
        
        XCTAssert(ClusterSizes[0] != (kMeansIO.Labels.width * kMeansIO.Labels.height), "Labels are all zero. If your test image was not very dark, labeling has failed.")
    }
    
    func testkMeans() {
        guard let Means_gpu = computer.assets["kMeans"]?.buffers?[0] else {
            fatalError()
        }
        
        var Means = [Float](repeating: 0, count: 3)
        
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        (1...3).forEach{ _ in   // repeat kMeans n times
            computer.encode("label")
            computer.encodeMPSHistogram(forImage: kMeansIO.Labels, MTLHistogramBuffer: kMeansIO.ClusterMemberCount, numberOfClusters: 3)
            computer.encode("kMeans")
            computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * 3, 1, 1))
        }
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        memcpy(&Means, Means_gpu.contents(), Means_gpu.length)
        
        XCTAssert(Means.reduce(true){$0 && $1.isNormal}, "Means are: \(Means). Algorithm has failed.")
    }
    
    func testkTone() {
        guard let result = computer.assets["toGray"]?.textures?[0] else {
            fatalError()
        }
        
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        (1...3).forEach{ _ in   // repeat kMeans n times
            computer.encode("label")
            computer.encodeMPSHistogram(forImage: kMeansIO.Labels, MTLHistogramBuffer: kMeansIO.ClusterMemberCount, numberOfClusters: 3)
            computer.encode("kMeans")
            computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * 3, 1, 1))
        }
        computer.encode("tonemap")
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        CIImage(mtlTexture: result, options: nil)!.write(url: desktopURL.appendingPathComponent("Tone.png"))
        XCTAssert(true)
    }
}
