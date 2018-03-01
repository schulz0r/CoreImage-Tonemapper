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
        
        let descriptor = TestTexture.getDescriptor()
        descriptor.pixelFormat = .r16Float
        guard let bilateralOutputTexture = MTKPDevice.instance.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        
        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: toGrayShaderIO(image: TestTexture)))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: bilateralFilterShaderIO(image: assets["toGray"]!.textures![1]!, outTexture:
            bilateralOutputTexture, sigma_spatial: 2, sigma_range: 0.2)))
        
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
        computer.commandBuffer = MTKPDevice.commandQueue.makeCommandBuffer()
        computer.encode("toGray")
        computer.commandBuffer.commit()
        computer.commandBuffer.waitUntilCompleted()
        
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
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
