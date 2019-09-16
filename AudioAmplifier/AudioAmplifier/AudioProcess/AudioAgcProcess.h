//
//  AudioAgcProcess.h
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/16.
//  Copyright © 2019 agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "gain_control.h"
class AGC{
public:
    AGC(int sample_rate);
    void Process(int16_t * inData,int16_t *outData,int samples);
    ~AGC();
private:
    WebRtcAgc_config_t config;
    void* AgcHandle;
    int maxLevel = 255;
    int minLevel =  1;
    int freq = 16000;
    uint8_t saturationWarning = 0;
    int inMicLevel = 0;
    int outMicLevel = 10;
    int status;
    
};
