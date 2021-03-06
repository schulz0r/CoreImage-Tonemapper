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
 Tonemapping is performed w.r.t. each cluster according to the paper below:
 
 Bertalm, M., Hall, L., E, C. S. S., Ferradans, S., Provenzi, E., & Bertalm, M. (2009). An analysis of visual adaptation and contrast perception for a fast tone mapping operator.
 
 This will be done for each class independently.
 */

half NakaRushton(const half luminance, const half µ, const half2 lambda) {
    const half m = ((µ * µ) - (lambda.x * lambda.y)) / (lambda.x + lambda.y - 2 * µ);
    const half k = 1.h / metal::log( (m + lambda.y) / (m + lambda.x) );
    return ( luminance / (0.5 + k * metal::log( (m + luminance) / (m + µ) )) ) - luminance;
}

kernel void tonemap(texture2d<half, access::read> image [[texture(0)]],
                    texture2d<half, access::read> labels [[texture(1)]],
                    texture2d<half, access::write> result [[texture(2)]],
                    constant float * Means [[buffer(0)]],
                    constant uint & kCluster [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]]) {
    
    const half3 pixel = image.read(gid).rgb;
    const uchar label = uchar(labels.read(gid).x);
    const half lightness = metal::dot(pixel, half3(0.33333));
    
    const half2 lambda(label == 0 ? 0 : (Means[label] + Means[label - 1]) / 2, label == (kCluster - 1) ? 1.0 : (Means[label] + Means[label + 1]) / 2);
    const half lightnessPerception = NakaRushton(lightness, Means[label], lambda);
    
    result.write(half4(pixel / (pixel + lightnessPerception), 1), gid);
}
