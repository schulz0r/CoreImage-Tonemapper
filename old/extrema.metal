//
//  extrema.metal
//  HDR-Module
//
//  Created by Philipp Waxweiler on 29.11.16.
//  Copyright © 2016 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define TGsize 16

constant float4 Lum = float4(float3(0.33),0);

inline float chooseMaximum(thread float4 &pixel, float buffer){
    return fmax(buffer, fmax(fmax(pixel.r, pixel.g), pixel.b) );
}

inline float chooseMinimum(thread float4 &pixel, float buffer){
    return fmin(buffer, fmin(fmin(pixel.r, pixel.g), pixel.b) );
}

inline float LuminanceOf(thread float4 &pixel){
    return dot(pixel, Lum);
}

inline float reduce_add_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id);
inline float reduce_min_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id);
inline float reduce_max_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id);

kernel void getMinMaxMean(texture2d<float, access::read> input [[texture(0)]],
                       device float * maximumOfImage [[buffer(0)]],
                       device float * minimumOfImage [[buffer(1)]],
                       device float * meanOfImage [[buffer(2)]],
                       uint2 id [[thread_position_in_grid]]) {
    
    float4 pixel = 0;
    uint width = input.get_width();
    uint height = input.get_width();
    threadgroup float maxima[TGsize][TGsize];
    threadgroup float minima[TGsize][TGsize];
    threadgroup float means[TGsize][TGsize];
    
    maxima[id.x][id.y] = 0.0;
    minima[id.x][id.y] = 0.0;
    means[id.x][id.y] = 0.0;
    
    for(uint x = id.x; x < width; x += TGsize){
        for(uint y = id.y; y < height; y += TGsize){
            pixel = input.read( id + uint2(x,y), 0);
            
            maxima[id.x][id.y] = chooseMaximum(pixel, maxima[id.x][id.y]);
            minima[id.x][id.y] = chooseMinimum(pixel, maxima[id.x][id.y]);
            means[id.x][id.y] += LuminanceOf(pixel);
        }
    }
    
    maximumOfImage[0] = reduce_max_2D(*maxima, TGsize, id);
    minimumOfImage[0] = reduce_min_2D(*minima, TGsize, id);
    meanOfImage[0] = reduce_add_2D(*means, TGsize, id) / (width * height);
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

inline float reduce_min_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id){
    
    for(uint s = threadgroupsizeX/2; s > 0; s >>=1){
        if( (id.x<s) && (id.y<s) ){
            data[id.x + (id.y * threadgroupsizeX)] = fmin(data[id.x + (id.y * threadgroupsizeX)],
                                                          fmin(data[id.x+s + (id.y * threadgroupsizeX)],
                                                               fmin(data[id.x + ((id.y + s) * threadgroupsizeX)] ,
                                                                    data[ id.x + s + ((id.y + s) * threadgroupsizeX)]
                                                                    )
                                                               )
                                                          );
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    return data[0];
}

inline float reduce_max_2D(threadgroup float * data, uint threadgroupsizeX, thread uint2 id){
    
    for(uint s = threadgroupsizeX/2; s > 0; s >>=1){
        if( (id.x<s) && (id.y<s) ){
            data[id.x + (id.y * threadgroupsizeX)] = fmax(data[id.x + (id.y * threadgroupsizeX)],
                                                           fmax(data[id.x+s + (id.y * threadgroupsizeX)],
                                                                fmax(data[id.x + ((id.y + s) * threadgroupsizeX)] ,
                                                                     data[ id.x + s + ((id.y + s) * threadgroupsizeX)]
                                                                     )
                                                                )
                                                          );
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    return data[0];
}
