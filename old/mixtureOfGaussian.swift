//
//  mixtureOfGaussian.swift
//  HDR-Module
//
//  Created by Philipp Waxweiler on 13.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

import Foundation

struct Gaussian{
    var variance:[Float]
    var mu:[Float]
    var p:[Float]
}

final class GaussianMixtureModell{
    var N = 0
    var gaussians = Gaussian(variance: [Float(0)], mu: [0], p: [0])
    var range:ClosedRange<Float>
    
    init(in range: ClosedRange<Float>){
        self.range = range
        placeInitialGaussians()
    }
    
    func sortAscending(){
        if (N > 1) && (gaussians.mu[0].isNormal){
            // sorts Array in ascending order
            let newArray = gaussians.mu.sorted()
            var newVariance = [Float](repeating: 0, count: N)
            var newWeight = [Float](repeating: 0, count: N)
        
            var index = 0
            for i in 0..<N {
                index = newArray.index(of: newArray[i])!
                newVariance[i] = gaussians.variance[index]
                newWeight[i] = gaussians.p[index]
            }
            gaussians.mu = newArray
            gaussians.variance = newVariance
        }
    }
    
    func checkForUselessGaussians(withLessWeightThan: Float, closerThan: Float) -> Bool{
        
        var gaussiansHadToBeChanged = false
        
        if N > 1{
            for (i,weight) in gaussians.p.enumerated(){
                if weight < withLessWeightThan{
                    kickGaussian(index: i)
                    gaussiansHadToBeChanged = true
                    break
                }
            }
            
            for (i, mean) in gaussians.mu.enumerated(){
                    if(mean.isNaN) { // kick deadGaussians
                        print("Dead Gaussian kicked!")
                        kickGaussian(index: i)
                        gaussiansHadToBeChanged = true
                        break
                    }
            }
            
            //let linearMeans = zip(gaussians.mu, gaussians.variance).map() { exp($0.0 + ($0.1 / 2.0)) }
            let linearMeans = gaussians.mu.map() { exp($0) }
            print("linear Means: \(linearMeans)")
            
            for (i, mean) in linearMeans.enumerated(){
                if( i > 0){
                    if abs(mean - linearMeans[i-1]) < closerThan{ // kick gaussian with least significance
                        if( gaussians.p[i] > gaussians.p[i-1]){
                            kickGaussian(index: i-1)
                        } else {
                            kickGaussian(index: i)
                        }
                        gaussiansHadToBeChanged = true
                        break
                    }
                }
            }
        }
        
        return gaussiansHadToBeChanged
    }
    
    private func kickGaussian(index: Int){
        gaussians.p.remove(at: index)
        gaussians.mu.remove(at: index)
        gaussians.variance.remove(at: index)
        self.N -= 1
        placeInitialGaussians()
    }
    
    func placeInitialGaussians(){
        

        gaussians.variance = [0.4]
        gaussians.mu = [0.7]
        
        N = gaussians.mu.count
        gaussians.p = [Float](repeating: 1.0/Float(N), count: N)
        gaussians.mu = gaussians.mu.map{log($0)}
        
        guard gaussians.mu[0].isFinite else{
            fatalError("Initialisation of GMM failed!")
        }
        
        print("N = \(N) Gaussians!")
    }
    
}
