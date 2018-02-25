//
//  TonemapperTests.swift
//  TonemapperTests
//
//  Created by Philipp Waxweiler on 07.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import XCTest
@testable import Tonemapper

class TonemapperTests: XCTestCase {
    
    var TestPic:CIImage! = nil
    
    override func setUp() {
        super.setUp()
        
        guard let Picture = CIImage(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/QianYuan/myTestpic.jpg")) else {
            fatalError("Could not load file: " + FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codes/Testpics/QianYuan/myTestpic.jpg").absoluteString)
        }
        
        TestPic = Picture
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
