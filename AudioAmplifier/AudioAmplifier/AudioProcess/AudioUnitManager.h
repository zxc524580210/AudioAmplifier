//
//  AudioUnitManager.h
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/11.
//  Copyright © 2019 agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "voice_processing_audio_unit.h"
#include <iostream>
#include <list>
#include <mutex>
#include "AudioCircularBuffer.h"
#include "AudioAgcProcess.h"
struct AudioFrame
{
    UInt32 num_frames;
    AudioBufferList *audioBufferList;
};
class AudioUnitManager : public VoiceProcessingAudioUnitObserver{
public:
    ~AudioUnitManager(){};
    virtual OSStatus OnDeliverRecordeData(AudioUnitRenderActionFlags* flags,
                                          const AudioTimeStamp* time_stamp,
                                          UInt32 bus_number,
                                          UInt32 num_frames,
                                          AudioBufferList* io_data);
    
    virtual OSStatus OnGetPlayoutData(AudioUnitRenderActionFlags* flags,
                                      const AudioTimeStamp* time_stamp,
                                      UInt32 bus_number,
                                      UInt32 num_frames,
                                      AudioBufferList* io_data);
    AudioUnitManager();
    virtual void Start();
    virtual void Stop();
    virtual void Initialize(Float64 sample_rate);
    virtual void Uninitialize();
    virtual void adjustAudioGainLevel(float level);
    virtual void adjustVolume(float volume);
private:
    std::unique_ptr<VoiceProcessingAudioUnit> audio_unit_;
    std::unique_ptr<AudioCircularBuffer<int16_t>> audioBuf;
    std::unique_ptr<AudioCircularBuffer<int16_t>> audio_process_buf;
    float audio_gain_level = 1.0;
    std::unique_ptr<AGC> audio_agc_;


};
