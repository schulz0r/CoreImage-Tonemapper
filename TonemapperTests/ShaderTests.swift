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
    var computer:MTKPComputer! = nil
    
    override func setUp() {
        super.setUp()
        let textureLoader = MTKTextureLoader(device: MTKPDevice.instance)
        let pictureURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/QianYuan/myTestpic.jpg")
        
        // load a texture
        do{
            TestTexture = try textureLoader.newTexture(URL: pictureURL, options: nil)
        } catch { fatalError() }
        
        let assets = MTKPAssets()
        assets.add(MTKPShader(name: "toGray", io: toGrayShaderIO(image: TestTexture)))
        assets.add(MTKPShader(name: "bilateralFilter", io: toGrayShaderIO(image: TestTexture)))
        
        computer = MTKPComputer(assets: assets)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGrayShader() {
        computer.encode("toGray")
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
