//
//  TonemappingTest.swift
//  TonemapperTests
//
//  Created by Philipp Waxweiler on 05.05.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import XCTest
@testable import Tonemapper

class CIProcessorTests: XCTestCase {
    
    func testTonemappingProcessor() {
        let pictureURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/myTestpic.jpg")
        
        guard let ImageIn = CIImage(contentsOf: pictureURL) else {
            fatalError("Test Image could not be loaded")
        }
        
        do{
            let output = try ThresholdImageProcessorKernel.apply(withExtent: ImageIn.extent, inputs: [ImageIn], arguments: nil)
            output.write(url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Tonemapped.png"))
        } catch let Error {
            XCTFail("CI processor failed:" + Error.localizedDescription)
        }
        
        XCTAssert(true)
    }
}
