//
//  SegmentationShader.metal
//  Tonemapper
//
//  Created by Philipp Waxweiler on 24.02.18.
//  Copyright © 2018 Philipp Waxweiler. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "SortAndCount.h"

/* --- PREPROCESSING --- */

/* Convert a colour image to a gray scale image */
kernel void toGray(texture2d<half, access::read> inTexture [[texture(0)]],
                   texture2d<half, access::write> outTexture [[texture(1)]],
                   uint2 gid [[thread_position_in_grid]])
{
    const half4 inColor = inTexture.read(gid);
    const half value = dot(inColor.rgb, half3(0.333, 0.333, 0.333));
    const half4 grayColor(value, value, value, 1.0);
    outTexture.write(grayColor, gid);
}

/* A naive implementation of a bilateral filter */
half gaussianPDF(half x, half sigma) {
    return (M_SQRT1_2_H * M_2_SQRTPI_H) / (2 * sigma) * metal::exp(-0.5 * pow(x / sigma, 2.h));
}

template<typename T>
struct Window {
    const uint size;
    array<T, 256> data;
    
    Window(uint size) : size(size) { }
    
    void loadPixelNeighbood(uint2 aroundCenter, texture2d<T, access::read> fromTexture) {
        const int halfWindowSize = (size - 1) / 2;
        // are pixels outside the image border? origin of window is 0 : origin is shifted by size-1/2 relative to the center
        uint2 origin = select(aroundCenter - halfWindowSize, uint2(0), (int2(aroundCenter) - halfWindowSize) < 0);
        
        for(int i = 0; i < size; i++) {
            for(uint j = 0; j < size; j++) {
               data[i + size * j] = fromTexture.read( uint2(origin.x + i, origin.y + j) ).x;
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

kernel void bilateralFilter(texture2d<half, access::read> inTexture [[texture(0)]], // expects a grayscale image with half precision gray pixels
                            texture2d<half, access::write> outTexture [[texture(1)]], // same as inTexture
                            constant float * KernelCoefficients [[buffer(0)]],  // Row-major linearly indexed coefficients
                            constant uint & KernelSize [[buffer(1)]],
                            constant float & Sigma_pixelDistance [[buffer(2)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    half result = 0, weights = 0;
    
    Window<half> FilterWindow(KernelSize);
    const half x = inTexture.read(gid).x;
    
    FilterWindow.loadPixelNeighbood(gid, inTexture);
    
    for(uint y = 0; y < FilterWindow.area(); y++){
        const half weight = KernelCoefficients[y] * gaussianPDF(abs(FilterWindow[y] - x), Sigma_pixelDistance);
        result += FilterWindow[y] * weight;
        weights += weight;
    }
    
    outTexture.write(result / weights, gid);
}

/* --- KMEANS CLUSTERING --- */

// Assign each pixel to the cluster with the smalest distance to the center
kernel void label(texture2d<half, access::read> grayTexture [[texture(0)]],
                    texture2d<ushort, access::write> labels [[texture(1)]],
                    constant float * Means [[buffer(0)]],  // Row-major linearly indexed coefficients
                    constant uint & clusterCount_k [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]]) {
    
    uchar label = 0;
    half closestDistance = 1.0;
    
    const half dataPoint = grayTexture.read(gid).x;
    
    for(uchar i = 0; i < clusterCount_k; i++) {
        const half dist = abs(dataPoint - Means[i]);
        
        if (dist < closestDistance) {
            closestDistance = dist;
            label = i;
        }
    }
    
    labels.write(label, gid);
}

// cluster the image pixels. it is similar to labeling, but the center means are written to the output image instead the index of the corresponding cluster. this function is used in the testing module.
kernel void cluster(texture2d<half, access::read> grayTexture [[texture(0)]],
                    texture2d<half, access::write> clusteredImage [[texture(1)]],
                    constant float * Means [[buffer(0)]],  // Row-major linearly indexed coefficients
                    constant uint & clusterCount_k [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]]) {
    
    uchar label = 0;
    half closestDistance = 1.0;
    
    const half dataPoint = grayTexture.read(gid).x;
    
    for(uchar i = 0; i < clusterCount_k; i++) {
        const half dist = abs(dataPoint - Means[i]);
        
        if (dist < closestDistance) {
            closestDistance = dist;
            label = i;
        }
    }
    
    clusteredImage.write(Means[label], gid);
}

kernel void kMeans(texture2d<half, access::read> grayTexture [[texture(0)]],
                   texture2d<ushort, access::read> labels [[texture(1)]],
                   constant float * Means [[buffer(0)]],  // Row-major linearly indexed coefficients
                   constant uint & clusterCount_k [[buffer(1)]],
                   device float * buffer [[buffer(2)]],
                   threadgroup SortAndCountElement<uint, float> * sortBuffer [[threadgroup(0)]],
                   uint2 gid [[thread_position_in_grid]],
                   uint tid [[thread_index_in_threadgroup]],
                   ushort2 dataLength [[threads_per_threadgroup]],
                   uint2 tgid [[threadgroup_position_in_grid]],
                   uint2 tgCount [[threadgroups_per_grid]]) {
    
    // read pixel
    const half dataPoint = grayTexture.read(gid).x;
    const uchar label = labels.read(gid).x;
    
    sortBuffer[tid] = {label, dataPoint};  // write pixel to threadgroup memory, label indicates to which cluster element belongs
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // sum up all elements with respect to the cluster index using sort and count
    // here, a sort and count algorithm is used for a collision free reduction of the data
    bitonicSortAndCount(tid, (dataLength.x * dataLength.y) / 2, sortBuffer);
    
    // write partial sums to buffer
    if(sortBuffer[tid].counter != 0) {
        const uint linearThreadgroupIndex = tgid.x + tgid.y * tgCount.x;
        buffer[clusterCount_k * linearThreadgroupIndex + sortBuffer[tid].element] = sortBuffer[tid].counter;
    }
}

/* reduction of the partial sums of cluster elements */
kernel void kMeansSumUp(device float * Means [[buffer(0)]],  // Row-major linearly indexed coefficients
                        constant uint & clusterCount_k [[buffer(1)]],
                        constant float * buffer [[buffer(2)]],
                        constant uint & totalBufferlength [[buffer(3)]],
                        constant uint * numberOfElements [[buffer(4)]],
                        threadgroup float * tgBuffer [[threadgroup(0)]],
                        uint clusterIndex [[threadgroup_position_in_grid]],
                        uint tid [[thread_index_in_threadgroup]],
                        ushort tgLength [[threads_per_threadgroup]]) {
    
    float partialSum = 0;
    // each threadgroup sums up partial sums for the cluster with the respective index (threadgroup 1 sums up results for cluster 1 etc.).
    for(uint position = (tid * clusterCount_k) + clusterIndex, offset = clusterCount_k * tgLength; position < totalBufferlength; position += offset) {
        partialSum += buffer[position];
    }
    
    // put all partial sums into a threadgroup buffer and finally reduce it to one complete sum
    tgBuffer[tid] = partialSum;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    for(uint s = tgLength / 2; s > 0; s>>=1) {
        if(tid < s) {
            tgBuffer[tid] += tgBuffer[tid + s];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // calculate and save new center
    if(tid == 0) {
        Means[clusterIndex] = tgBuffer[0] / numberOfElements[clusterIndex]; // TODO: get number of elements of a cluster with an MPSHistogram shader which will be applied to the label texture
    }
}
