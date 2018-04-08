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
    
    var TestTexture:MTLTexture! = nil
    var computer:SegmentationProcessor! = nil
    let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/")
    
    override func setUp() {
        super.setUp()
        let textureLoader = MTKTextureLoader(device: MTKPDevice.instance)
        let pictureURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/myTestpic.jpg")
        
        // load a texture
        do{
            TestTexture = try textureLoader.newTexture(URL: pictureURL, options: nil)
        } catch let Error { fatalError(Error.localizedDescription) }
        
        let grayIOProvider = toGrayShaderIO(image: TestTexture)
        let bilateralFilterIO = bilateralFilterShaderIO(image: grayIOProvider.grayTexture, sigma_spatial: 1.5, sigma_range: 0.1)
        
        let kMeansTGLength = [8 * 256] // ushort + uint + half becomes uint + uint + float due to memory alignment
        let kMeansSummationTGLength = [MemoryLayout<Float>.size * 256]
        let clusterTestIO = kMeansShader_TestIO(grayInputTexture: bilateralFilterIO.outTexture)
        let kMeansIO = kMeansShaderIO(grayInputTexture: bilateralFilterIO.outTexture)

        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: grayIOProvider))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: bilateralFilterIO))
        assets.add(shader: MTKPShader(name: "cluster", io: clusterTestIO))
        assets.add(shader: MTKPShader(name: "label", io: kMeansIO))
        assets.add(shader: MTKPShader(name: "kMeans", io: kMeansIO, tgConfig: MTKPThreadgroupConfig(tgSize: (16, 16, 1), tgMemLength: kMeansTGLength)))
        assets.add(shader: MTKPShader(name: "kMeansSumUp", io: kMeansIO, tgConfig: MTKPThreadgroupConfig(tgSize: (256, 1, 1), tgMemLength: kMeansSummationTGLength)))
        computer = SegmentationProcessor(assets: assets)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
    
    func testClustering() {
        guard let filteredTexture = computer.assets["cluster"]?.textures?[1] else {
            fatalError()
        }
        
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")
        computer.encode("cluster")
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        let Image = CIImage(mtlTexture: filteredTexture, options: nil)!
        
        Image.write(url: desktopURL.appendingPathComponent("ClusteringShader.png"))
    }
    
    func testkMeans() {
        guard
            let Means_gpu = computer.assets["kMeans"]?.buffers?[0],
            let Buffer = computer.assets["kMeans"]?.buffers?[2]
        else {
            fatalError()
        }
        var Means = [Float](repeating: 0, count: 3)
        var BufferHost = [Float](repeating: 0, count: 20)
        
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.encode("bilateralFilter")  // <- gray/bilateral filtering have to be performed beause it generates the input data for the kMeans shaders
        computer.encode("label")
        computer.encode("kMeans")
        computer.encode("kMeansSumUp", threads: MTLSizeMake(256 * 3, 1, 1))
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
        memcpy(&Means, Means_gpu.contents(), Means_gpu.length)
        memcpy(&BufferHost, Buffer.contents(), BufferHost.count * 4)
        
        XCTAssert(Means.reduce(true){$0 && $1.isNormal}, "Means are: \(Means). Algorithm has failed.")
    }
}
