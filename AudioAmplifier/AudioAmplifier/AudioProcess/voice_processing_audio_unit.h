//
//  voice_processing_audio_unit.h
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/11.
//  Copyright © 2019 agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioUnit/AudioUnit.h>
NS_ASSUME_NONNULL_BEGIN
class VoiceProcessingAudioUnitObserver
{
public:
    virtual OSStatus OnDeliverRecordeData(AudioUnitRenderActionFlags* flags,
                                          const AudioTimeStamp* time_stamp,
                                          UInt32 bus_number,
                                          UInt32 num_frames,
                                          AudioBufferList* io_data) = 0;
    
    virtual OSStatus OnGetPlayoutData(AudioUnitRenderActionFlags* flags,
                                      const AudioTimeStamp* time_stamp,
                                      UInt32 bus_number,
                                      UInt32 num_frames,
                                      AudioBufferList* io_data) = 0;
protected:
    ~VoiceProcessingAudioUnitObserver(){};
    
};
class VoiceProcessingAudioUnit{
public:
    explicit VoiceProcessingAudioUnit(VoiceProcessingAudioUnitObserver *observer);
    ~VoiceProcessingAudioUnit();
    enum State : int32_t{
        kInitRequired,
        kUinitialized,
        kInitialized,
        kStarted
    };
    static const UInt32 kBytesPersample;
    bool Init();
    VoiceProcessingAudioUnit::State GetState()const;
    bool Initialize(Float64 sample_rate);
    bool Start();
    bool Stop();
    bool Uninialize();
    OSStatus Render(AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time_stamp,UInt32 output_bus_number,UInt32 num_frames,AudioBufferList * io_data);
    
private:
    static OSStatus OnGetPlayoutData(void* in_ref_con,
                                     AudioUnitRenderActionFlags* flags,
                                     const AudioTimeStamp* time_stamp,
                                     UInt32 bus_number,
                                     UInt32 num_frames,
                                     AudioBufferList* io_data);
    static OSStatus OnDeliverRedcordedData(void* in_ref_con,
                                           AudioUnitRenderActionFlags* flags,
                                           const AudioTimeStamp* time_stamp,
                                           UInt32 bus_number,
                                           UInt32 num_frames,
                                           AudioBufferList* io_data);
    
    //Notifies observer that samples are need for playback
    OSStatus NotifyGetPlayoutData(AudioUnitRenderActionFlags* flags,
                                  const AudioTimeStamp* time_stamp,
                                  UInt32 bus_number,
                                  UInt32 num_frames,
                                  AudioBufferList* io_data);
    //Notifies observer that recorded data are available for render.
    OSStatus NotifyDeliverRecordedData(AudioUnitRenderActionFlags* flags,
                                       const AudioTimeStamp* time_stamp,
                                       UInt32 bus_number,
                                       UInt32 num_frames,
                                       AudioBufferList* io_data);
    //
    AudioStreamBasicDescription GetFormat(Float64 sample_rate) const;
    
    void DisposeAudioUnit();
    VoiceProcessingAudioUnitObserver *observer_;
    AudioUnit vpio_unit_;
    VoiceProcessingAudioUnit::State state_;
    
};





NS_ASSUME_NONNULL_END
