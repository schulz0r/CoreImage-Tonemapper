//
//  CITonemapper.swift
//  Tonemapper
//
//  Created by Philipp Waxweiler on 24.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

import Foundation
import CoreImage

class ThresholdImageProcessorKernel: CIImageProcessorKernel {
    static let device = MTLCreateSystemDefaultDevice()
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let thresholdValue = arguments?["thresholdValue"] as? Float else  {
                return
        }
        
    }

}
