//
//  AudioAgcProcess.m
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/16.
//  Copyright © 2019 agora. All rights reserved.
//

#import "AudioAgcProcess.h"

AGC::AGC(int sample_rate){
    config.compressionGaindB = 18;
    config.limiterEnable = kAgcTrue;
    config.targetLevelDbfs = 9;
    status = WebRtcAgc_Create(&AgcHandle);
    if (status != 0) {
        printf("Create Agc Failed %d",status);
    }
    status = WebRtcAgc_Init(AgcHandle, minLevel, maxLevel, kAgcModeAdaptiveDigital, sample_rate);
    if (status != 0) {
        printf("Agc init failed %d",status);
    }
    status = WebRtcAgc_set_config(AgcHandle, config);
    if (status != 0) {
        printf("config failed %d",status);
    }
    
    
}
void AGC::Process(int16_t *inData, int16_t *outData,int samples){
    status  = WebRtcAgc_Process(AgcHandle, (WebRtc_Word16 *)(inData), NULL, (WebRtc_Word16)samples, (WebRtc_Word16 *)outData, NULL, inMicLevel, &outMicLevel, 1, &saturationWarning);
    if (status != 0) {
        printf("WebRtcAgc_Process is error !");
    }
}
AGC::~AGC(){
    WebRtcAgc_Free(AgcHandle);
}
