#include <cuda.h>
#include <cuda_runtime.h>
#include <iostream>
#include <vector>
#include "mosaic_c_api.h"


// 生成0-255之间的随机整数
__device__ unsigned char randomByte(unsigned int x, unsigned int y, unsigned int seed) {
    unsigned int i = x + y * 1000 + seed;
    i = (i ^ 61) ^ (i >> 16);
    i = i + (i << 3);
    i = i ^ (i >> 4);
    i = i * 0x27d4eb2d;
    i = i ^ (i >> 15);
    return (unsigned char)(i % 256);
}

// 马赛克效果核函数 - RGBA格式
__global__ void mosaicKernel(
    unsigned char* frame,        // 帧数据
    int frameWidth,             // 帧宽度
    int frameHeight,            // 帧高度
    int pitch,                  // 行间距（字节）
    float* bboxes,              // bbox数组 [left, top, width, height, ...]
    int numBboxes,              // bbox数量
    unsigned int seed           // 随机数种子
) {
    // 计算全局线程索引
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (x >= frameWidth || y >= frameHeight) return;
    
    // 计算像素在内存中的偏移
    int offset = y * pitch + x * 4; // RGBA: 4字节/像素
    
    // 检查该像素是否在任何bbox内
    for (int i = 0; i < numBboxes; i++) {
        float left = bboxes[i * 4];
        float top = bboxes[i * 4 + 1];
        float width = bboxes[i * 4 + 2];
        float height = bboxes[i * 4 + 3];
        
        // 如果像素在bbox内
        if (x >= left && x < left + width && y >= top && y < top + height) {
            // 计算马赛克块大小（这里设为10x10，可以根据需要调整）
            const int mosaicSize = 10;
            
            // 计算当前像素所在的马赛克块的左上角坐标
            int mosaicX = (x / mosaicSize) * mosaicSize;
            int mosaicY = (y / mosaicSize) * mosaicSize;
            
            // 计算该马赛克块左上角像素在内存中的偏移
            int mosaicOffset = mosaicY * pitch + mosaicX * 4;
            
            // 使用马赛克块左上角像素的颜色作为整个块的颜色
            frame[offset] = frame[mosaicOffset];       // R
            frame[offset + 1] = frame[mosaicOffset + 1];   // G
            frame[offset + 2] = frame[mosaicOffset + 2];   // B
            // frame[offset + 3] 保持不变 (A)
            
            break; // 已经处理，退出循环
        }
    }
}  

void applyMosaic(
    unsigned char* d_frame,     // 显存中的帧数据
    int frameWidth,             // 帧宽度
    int frameHeight,            // 帧高度
    int pitch,                  // 行间距
    std::vector<float>& bboxes, // bbox数组 [left, top, width, height, ...]
    unsigned int seed = 0       // 随机数种子
) {
    if (bboxes.empty()) return;
    
    // 分配显存存储bbox数据
    float* d_bboxes = nullptr;
    int numBboxes = bboxes.size() / 4;
    
    cudaMalloc(&d_bboxes, bboxes.size() * sizeof(float));
    cudaMemcpy(d_bboxes, bboxes.data(), bboxes.size() * sizeof(float), cudaMemcpyHostToDevice);
    
    // 设置线程块和网格尺寸
    dim3 blockSize(16, 16);
    dim3 gridSize(
        (frameWidth + blockSize.x - 1) / blockSize.x,
        (frameHeight + blockSize.y - 1) / blockSize.y
    );
    
    // 调用核函数
    mosaicKernel<<<gridSize, blockSize>>>(
        d_frame, frameWidth, frameHeight, pitch, 
        d_bboxes, numBboxes, seed
    );
    
    // 检查核函数调用错误
    cudaError_t err = cudaGetLastError();
    printf("CUDA kernel error: %s\n", cudaGetErrorString(err));
    // if (err != cudaSuccess) {
    //     // std::cerr << "CUDA kernel error: " << cudaGetErrorString(err) << std::endl;
    // }
    
    // 释放资源
    cudaFree(d_bboxes);
}

// C兼容版本（新添加）
extern "C" {
void applyMosaicC(
    unsigned char* d_frame, int frameWidth, int frameHeight, int pitch,
    float* bboxes, int numBboxes, unsigned int seed) {
    if (bboxes == nullptr || numBboxes <= 0) return;
    // printf("C compatible version\n");

    cudaError_t ret;
    
    // 分配显存存储bbox数据
    float* d_bboxes = nullptr;
    ret = cudaMalloc(&d_bboxes, numBboxes * 4 * sizeof(float));
    // printf("CUDA malloc error: %s\n", cudaGetErrorString(ret));
    ret = cudaMemcpy(d_bboxes, bboxes, numBboxes * 4 * sizeof(float), cudaMemcpyHostToDevice);
    // printf("CUDA memcpy error: %s\n", cudaGetErrorString(ret));
    
    // 设置线程块和网格尺寸
    dim3 blockSize(16, 16);
    dim3 gridSize(
        (frameWidth + blockSize.x - 1) / blockSize.x,
        (frameHeight + blockSize.y - 1) / blockSize.y
    );
    
    // printf("blockSize: %d, %d\n", blockSize.x, blockSize.y);
    // 调用核函数
    mosaicKernel<<<gridSize, blockSize>>>(
        d_frame, frameWidth, frameHeight, pitch, d_bboxes, numBboxes, seed
    );
    // printf("kernel launched\n");
    
    // 检查核函数调用错误
    cudaError_t err = cudaGetLastError();
    // printf("CUDA kernel error: %s\n", cudaGetErrorString(err));
    
    // 释放资源
    cudaFree(d_bboxes);
}
}  