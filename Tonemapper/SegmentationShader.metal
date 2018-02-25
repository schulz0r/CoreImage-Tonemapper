//
//  SegmentationShader.metal
//  Tonemapper
//
//  Created by Philipp Waxweiler on 24.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void toGray(texture2d<half, access::read> inTexture [[texture(0)]],
                   texture2d<half, access::write> outTexture [[texture(1)]],
                   uint2 gid [[thread_position_in_grid]])
{
    const half4 inColor = inTexture.read(gid);
    const half value = dot(inColor.rgb, half3(0.333, 0.333, 0.333));
    const half4 grayColor(value, value, value, 1.0);
    outTexture.write(grayColor, gid);
}

half gaussianPDF(half x, half sigma) {
    return (M_SQRT1_2_H * M_2_SQRTPI_H) / (2 * sigma) * metal::exp(-0.5 * pow(x / sigma, 2.h));
}

template<typename T>
struct Window {
    const uint size;
    array<T, 256> data;
    
    Window(uint size) : size(size) { }
    
    void loadPixelNeighbood(uint2 aroundCenter, texture2d<T, access::read> fromTexture) {
        // are pixels outside the image border? origin of window is 0 : origin is shifted by size-1/2 relative to the center
        uint2 origin = select(aroundCenter - ((size - 1) / 2), uint2(0), int2(aroundCenter) - int2((size - 1) / 2) < 0);
        
        for(uint i = origin.x; i < size; i++) {
            for(uint j = origin.y; j < size; j++) {
               data[i + size * j] = fromTexture.read( uint2(i,j) ).x;
            }
        }
    }
    
    uint area(){
        return size << 1;
    }
    
    const thread T & operator[](const int index) {
        return data[index];
    }
};

kernel void bilateralFilter(texture2d<half, access::read> inTexture [[texture(0)]], // expects a grayscale image with half precision grey pixels
                            texture2d<half, access::write> outTexture [[texture(1)]], // same as inTexture
                            constant float * KernelCoefficients [[buffer(0)]],  // Row-major linearly indexed coefficients
                            constant uint & KernelSize [[buffer(1)]],
                            constant float & Sigma_pixelDistance [[buffer(2)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    half result = 0, weights = 0;
    
    Window<half> BilateralWindow(KernelSize);
    const half x = inTexture.read(gid).x;
    
    BilateralWindow.loadPixelNeighbood(gid, inTexture);
    
    for(uint i = 0; i < BilateralWindow.area(); i++){
        const half weight = KernelCoefficients[i] * gaussianPDF(abs(BilateralWindow[i] - x), Sigma_pixelDistance);
        result += x + weight;
        weights += weight;
    }
    
    outTexture.write(result / weights, gid);
}
