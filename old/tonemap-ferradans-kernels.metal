//
//  tonemap-kernels.metal
//  HiCam
//
//  Created by Philipp Waxweiler on 31.03.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define MAX_TG_SIZE 16
#define X 0 // define what the coordinate in the grid id means. gid[X] = gid[0] = the horizontal position in a picture
#define Y 1

constant float4 L = {0.33, 0.33, 0.33, 0.0}; //{0.2126, 0.7152, 0.0722, 0.0};

float r_j(float luminance, float m, float C, float k, float lambda_minus, float lambda_plus, float mu);
uint selectArea(uint N, float x, device float * lambda_min, device float * lambda_max);

/*-------------------------
 Farradans main - Functions
 ------------------------*/
inline float r(float lambda, float m, float mu, float k, float C){
    float CC = 0.5 - k * log(m + mu);
    return CC + (k * log(m + lambda));
}

float r_j(float luminance, float m, float C, float k, float lambda_minus, float lambda_plus, float mu){
    return ( r(luminance, m, mu, k, C) - r(lambda_minus, m, mu, k, C) ) / ( r(lambda_plus, m, mu, k, C) - r(lambda_minus, m, mu, k, C) );
}

uint selectArea(uint N, float x, device float * lambda_min, device float * lambda_max){
    for(uint k = 0; k<N; k++){
        if( ((x >= lambda_min[k]) && (x <= lambda_max[k])) ){
            return k;
        }
    }
}

// semi saturation for RGB Images (used in ferradansRGB)
float r_sat(float luminance, float lambda_minus, float lambda_plus, float m, float k, float h, float C, float mu){
    
    float r_G = C + h * r_j(luminance, m, C, k, lambda_minus, lambda_plus, mu);
    return (luminance/r_G) - luminance;
}

/*---------------------
 Farradans main
 --------------------*/
kernel void ferradans(texture2d<float, access::read> picture [[texture(0)]],
                      texture2d<float, access::write> result [[texture(1)]],
                         device float * lambda_minus [[buffer(0)]],
                         device float * lambda_plus [[buffer(1)]],
                         device float * m [[buffer(2)]],
                         device float * k [[buffer(3)]],
                         device float * h [[buffer(4)]],
                         device float * C [[buffer(5)]],
                         device uint * N [[buffer(6)]],   // number of intervalls
                         device float * mu [[buffer(7)]],
                         uint2 id [[thread_position_in_grid]]){
    
    float4 pixel = picture.read(id, 0);
    float x = dot(pixel, L);
    
    uint idx = selectArea(N[0], x, lambda_minus, lambda_plus);
    float semiSaturation = r_sat(x, lambda_minus[idx], lambda_plus[idx], m[idx], k[idx], h[idx], C[idx], mu[idx]);
    
    pixel.rgb = pixel.rgb / (pixel.rgb + semiSaturation);
    result.write(pixel, id);
}


