//
//  tonemappingShader.metal
//  Tonemapper
//
//  Created by Philipp Waxweiler on 14.04.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

/* Tonemapping shaders
 First, control points of a tonemapping curve will be calculted according to the paper below:
 
 Bertalm, M., Hall, L., E, C. S. S., Ferradans, S., Provenzi, E., & Bertalm, M. (2009). An analysis of visual adaptation and contrast perception for a fast tone mapping operator.
 
 This will be done for each class independently. TODO: If possible, let the cpu do this.
 The second kernel will apply the tonemapping curve to each pixel w.r.t. its cluster.
 */

// this kernel calculates the tonemapping curve for some points only. The tonemapper will interpolate between these points.
kernel void makeToneMappingCurve(device metal::array<float, 12> * tonemappingCurve [buffer(0)],
                                 uint clusterIdx [[threadgroup_position_in_grid]]
                                 uint controlPointIdx [[thread_index_in_threadgroup]]) {
    
    const float illumination = tonemappingCurve[clusterIdx][controlPointIdx];
}

kernel void tonemap() {
    
}
