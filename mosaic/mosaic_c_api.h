/*
 * @Author: zhouyuchong
 * @Date: 2025-06-26 15:53:27
 * @Description: 
 * @LastEditors: zhouyuchong
 * @LastEditTime: 2025-06-26 15:53:29
 */
#ifndef MOSAIC_C_API_H
#define MOSAIC_C_API_H

#ifdef __cplusplus
extern "C" {
#endif

// C兼容的接口
void applyMosaicC(
    unsigned char* d_frame,     // 显存中的帧数据
    int frameWidth,             // 帧宽度
    int frameHeight,            // 帧高度
    int pitch,                  // 行间距
    float* bboxes,              // bbox数组 [left, top, width, height, ...]
    int numBboxes,              // bbox数量（即数组长度除以4）
    unsigned int seed           // 随机数种子
);

#ifdef __cplusplus
}
#endif

#endif // MOSAIC_C_API_H  