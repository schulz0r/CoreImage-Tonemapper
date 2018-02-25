//
//  registration.swift
//  HiCam
//
//  Created by Philipp Waxweiler on 31.03.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation
import MetalKit


final class FarradansTonemapper{
    
    static func getNakaRushtonParameters(from mixture: GaussianMixtureModell, global_mean: Float, Intervals: (lambda: (min: [Float], max: [Float]), mu_interval: (minus: [Float], plus: [Float])) ) -> (m:[Float],k:[Float],C:[Float],h:[Float]){
        
        let max = mixture.range.upperBound
        let min = mixture.range.lowerBound
        
        let Gaussians = mixture.gaussians
        
        var m = [Float](repeating: 0, count: mixture.N)
        let m_global = (pow(global_mean,2.0) - max * min) / (max + min - 2 * global_mean) // m with global parameters, see eq. (16)
        
        var k = [Float](repeating: 0, count: mixture.N)
        var h = [Float](repeating: 0, count: mixture.N)
        var C = [Float](repeating: 0, count: mixture.N)
        
        for j in 0..<mixture.N {
            m[j] = fmax(0.0, (pow(Gaussians.mu[j],2.0) - Intervals.lambda.max[j] * Intervals.lambda.min[j]) / (Intervals.lambda.max[j] + Intervals.lambda.min[j] - 2 * Gaussians.mu[j]) )
            k[j] = 1.0 / log( (m[j] + Intervals.lambda.max[j]) / (m[j] + Intervals.lambda.min[j]) )
            h[j] = log( (m_global + exp(Intervals.mu_interval.plus[j])) / (m_global + exp(Intervals.mu_interval.minus[j])) ) // h from eq. (16)
        }
        
        let h_nenner = h.reduce(0, +)
        h = h.map() {$0 / h_nenner}
        
        for j in 1..<mixture.N {
            C[j] = h[0..<j].reduce(0, +)
        }
            
        return (m:m, k:k, C:C, h:h)
    }
    
    static func findIntervals(in gaussianMixture: GaussianMixtureModell) -> (lambda:(min:[Float], max:[Float]), mu_interval:(minus:[Float], plus:[Float])){
        
        let Gaussians = gaussianMixture.gaussians
        
        let mu_plus = zip(Gaussians.mu, Gaussians.variance).map(){ $0.0 + 2 * $0.1 }
        let mu_minus = zip(Gaussians.mu, Gaussians.variance).map(){ $0.0 - 2 * $0.1 }
        
        var lambda_min = [Float](repeating: 0, count: gaussianMixture.N)
        var lambda_max = [Float](repeating: 0, count: gaussianMixture.N)
        
        for j in 0..<gaussianMixture.N{
            print("Iteration \(j)")
            // lambda min
            if j == 0{
                lambda_min[j] = gaussianMixture.range.lowerBound
            } else {
                lambda_min[j] = fmax( exp( (mu_plus[j-1] + mu_minus[j]) / 2), exp(mu_plus[j-1]) )
            }
            // lambda max
            if j == gaussianMixture.N - 1{
                lambda_max[j] = gaussianMixture.range.upperBound
            } else {
                lambda_max[j] = fmin( exp( (mu_plus[j] + mu_minus[j+1]) / 2), exp(mu_minus[j+1]) )
            }
            
            if lambda_min[j] > lambda_max[j]{
                lambda_min[j] = lambda_max[j-1]
                print("histogramintersection buggy")
            }
            guard lambda_max[j] > lambda_min[j] else{
                fatalError("Histogram Intersection was not successful. Upper bound is smaler than lower bound!")
            }/**/
        }
        
        return ((min: lambda_min,max: lambda_max), (minus:mu_minus,plus: mu_plus))
    }

}
