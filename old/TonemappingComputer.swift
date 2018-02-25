//
//  TonemappingComputer.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 28.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import CoreImage
import MetalKitPlus
import ImageProcessing

final class TonemappingComputer: MTKMetacomputer{
    
    var oldGaussians = Gaussian(variance: [], mu: [], p: [])
    
    func tonemap() -> CIImage{
        
        computer.execute("getMinMaxMean").waitUntilCompleted()
        var mixtureModell = GaussianMixtureModell(in: rangeOfImage())
        initializeGaussianModellingShader(with: mixtureModell)
        
        NakaRushtonParameters(for: mixtureModell)
        
        computer.execute("ferradans")

        return computer.assets.output() as! CIImage
    }
    
    private func NakaRushtonParameters(for gaussianMixture: GaussianMixtureModell){
        guard
            let arithmeticMeanBuffer = computer.assets["getMinMaxMean"]?.buffers![2],
            let lambda_minus = computer.assets["ferradans"]?.buffers![0],
            let lambda_plus = computer.assets["ferradans"]?.buffers![1],
            let m = computer.assets["ferradans"]?.buffers![2],
            let k = computer.assets["ferradans"]?.buffers![3],
            let h = computer.assets["ferradans"]?.buffers![4],
            let C = computer.assets["ferradans"]?.buffers![5],
            let mu = computer.assets["ferradans"]?.buffers![7]
            else {
                fatalError("Could not assign parameters for Naka rushton equation.")
        }
        
        var arithmeticMean:Float = 0
        memcpy(&arithmeticMean, arithmeticMeanBuffer.contents(), MemoryLayout<Float>.size)
        
        gaussianMixture.sortAscending()
        
        let Intervals = FarradansTonemapper.findIntervals(in: gaussianMixture)
        let linearMeans = zip(gaussianMixture.gaussians.mu, gaussianMixture.gaussians.variance).map() { exp($0.0 + ($0.1 / 2.0)) }
        //let linearMeans = gaussianMixture.gaussians.mu.map() { exp($0) }
        
        let rushtonParameters = FarradansTonemapper.getNakaRushtonParameters(from: gaussianMixture, global_mean: arithmeticMean, Intervals: Intervals)
        
        memcpy(lambda_minus.contents(), Intervals.lambda.min, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(lambda_plus.contents(), Intervals.lambda.max, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(m.contents(), rushtonParameters.m, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(k.contents(), rushtonParameters.k, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(h.contents(), rushtonParameters.h, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(C.contents(), rushtonParameters.C, gaussianMixture.N * MemoryLayout<Float>.size)
        memcpy(mu.contents(), linearMeans, gaussianMixture.N * MemoryLayout<Float>.size)
    }
    
    private func rangeOfImage() -> ClosedRange<Float> {
        guard
            let Minimum = computer.assets["getMinMaxMean"]?.buffers![1],
            let Maximum = computer.assets["getMinMaxMean"]?.buffers![0]
            else {
                fatalError("tonemapping could not be performed.")
        }
        
        var brightestPixel:Float = 0
        var darkestPixel: Float = 0
        
        memcpy(&brightestPixel, Maximum.contents(), 4)
        memcpy(&darkestPixel, Minimum.contents(), 4)
        print("Max: \(brightestPixel), Min: \(darkestPixel)")
        
        return darkestPixel...brightestPixel
    }
    
    private func initializeGaussianModellingShader(with mixture: GaussianMixtureModell){
        
        oldGaussians = mixture.gaussians // for the iterative GMM algorithm, we need to know the old values
        
        // fill buffers for next step
        (computer.assets as! TSTMAsset).initializeGMMState(with: mixture)
    }
}
