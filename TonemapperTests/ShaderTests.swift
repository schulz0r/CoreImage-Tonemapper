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
        
        var assets = MTKPAssets(SegmentationProcessor.self)
        assets.add(shader: MTKPShader(name: "toGray", io: toGrayShaderIO(image: TestTexture)))
        assets.add(shader: MTKPShader(name: "bilateralFilter", io: toGrayShaderIO(image: TestTexture)))
        
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
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
