//
//  convergeGaussians.metal
//  HiCam
//
//  Created by Philipp Waxweiler on 04.05.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
//#include "functionLib.metal"

#define SQRT_2PI 2.506628274631000502415765284811045253006986740609938316629
#define THRESHOLD 0.0001
#define SMALL_NUMBER 1e-4

constant float4 L = {0.33, 0.33, 0.33, 0.0};
inline float reduce_add_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id);
float gamma_it(device float *p, device float * mu, device float * sigma, float x, uint K, uint i);
float gauss(float x, float mu, float sigma);

kernel void GMM_modelling(texture2d<float, access::read> picture [[texture(0)]],
                          device int * K [[buffer(0)]],
                          device float * mu [[buffer(1)]],
                          device float * sigma [[buffer(2)]],
                          device float * p [[buffer(3)]],
                          device float * mu_new [[buffer(4)]],
                          device float * sigma_new [[buffer(5)]],
                          device float * p_new [[buffer(6)]],
                          device float * summeDesGits [[buffer(7)]],
                          uint3 id [[thread_position_in_grid]]){
    
    if(K[0] == 1){
        p[0] = 1.0;
    }
    
    float sumGit, MuNew, sumSigma, G_it, pixel;
    threadgroup float gamma[16][16];
    threadgroup float buffer_mu[16][16];
    threadgroup float buffer_sigma[16][16];
    
    // threadgroup memory must be 0 initially
    buffer_mu[id.x][id.y] = 0;
    buffer_sigma[id.x][id.y] = 0;
    gamma[id.x][id.y] = 0;
    /**/
    // get mu and postpriory
    
    for(uint x = id.x; x < picture.get_width(); x += 16){
        for(uint y = id.y; y < picture.get_height(); y += 16){
            
            pixel = log(dot(picture.read( uint2(x,y), 0), L) + SMALL_NUMBER);
            
            // E-Step
            G_it = gamma_it(p, mu, sigma, pixel, K[0], id.z);
            
            // M-Step
            gamma[id.x][id.y] += G_it;
            buffer_mu[id.x][id.y] += G_it * pixel;
            buffer_sigma[id.x][id.y] += G_it * pow(pixel, 2.0);
        }
    }
    
     // reduce the 2D threadgroup to one summed up value
     sumGit = reduce_add_2D(*gamma, 16, id.xy );
     MuNew = reduce_add_2D(*buffer_mu, 16, id.xy );
     sumSigma = reduce_add_2D(*buffer_sigma, 16, id.xy );
     
     threadgroup_barrier(mem_flags::mem_none);
    
    summeDesGits[id.z] = sumGit;
    
     if((id.x == 0) && (id.y == 0) ){
         MuNew /= sumGit;
         p_new[id.z] = sumGit / (picture.get_width() * picture.get_height());
         mu_new[id.z] = MuNew;
         sigma_new[id.z] = (sumSigma / sumGit) - pow(MuNew, 2.0);
     }
    
    /*
     // MU+ und p+
     for(uint x = id.x; x < picture.get_width(); x += 16){
         for(uint y = id.y; y < picture.get_height(); y += 16){
     
             pixel = log(dot(picture.read( uint2(x,y), 0), L) + SMALL_NUMBER);
     
             // E-Step
             G_it = gamma_it(p, mu, sigma, pixel, K[0], id.z);
     
             // M-Step
             gamma[id.x][id.y] += G_it;
             buffer_mu[id.x][id.y] += G_it * pixel;
         }
     }
     
     sumGit = reduce_add_2D(*gamma, 16, id.xy);
     MuNew = reduce_add_2D(*buffer_mu, 16, id.xy )/sumGit;
    
     // Sigma
     for(uint x = id.x; x < picture.get_width(); x += 16){
         for(uint y = id.y; y < picture.get_height(); y += 16){
     
             pixel = log(dot(picture.read( uint2(x,y), 0), L) + SMALL_NUMBER);
             buffer_sigma[id.x][id.y] += gamma_it(p, mu, sigma, pixel, K[0], id.z) * pow(pixel-MuNew, 2.0);
         }
     }
     // reduce the 2D threadgroup to one summed up value
     sumSigma = reduce_add_2D(*buffer_sigma, 16, id.xy );
     
     threadgroup_barrier(mem_flags::mem_none);
     
     if((id.x == 0) && (id.y == 0) ){
         p_new[id.z] = sumGit / (picture.get_width() * picture.get_height());
         mu_new[id.z] = MuNew;
         sigma_new[id.z] = sumSigma / sumGit;
         summeDesGits[id.z] = sumGit;
     }
     */
}

// -----------------------------------------------------------------------

// helper functions

float gamma_it(device float *p, device float * mu, device float * sigma, float x, uint K, uint i){
    
    float nenner = 0;
    for(uint k = 0; k<K; k++){
        nenner += p[k] * gauss(x,mu[k],sigma[k]);
    }
    
    return p[i] * gauss(x,mu[i],sigma[i]) / nenner;
}

float gauss(float x, float mu, float sigma){
    return exp(-pow((x-mu),2.0)/(2*sigma))/(SQRT_2PI*sqrt(sigma) * exp(x));
    //return exp(-pow((x-mu),2.0)/(2*sigma))/(SQRT_2PI * sqrt(sigma));
}

inline float reduce_add_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id){
    
    for(uint s = threadgroupsizeX/2; s > 0; s >>=1){
        if( (id.x<s) && (id.y<s) ){
            data[id.x + (id.y * threadgroupsizeX)] += data[id.x+s + (id.y * threadgroupsizeX)] + data[id.x + ((id.y + s) * threadgroupsizeX)] + data[ id.x + s + ((id.y + s) * threadgroupsizeX) ];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    return data[0];
}
