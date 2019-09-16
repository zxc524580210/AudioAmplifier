//
//  AudioUnitManager.m
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/11.
//  Copyright © 2019 agora. All rights reserved.
//

#include "AudioUnitManager.h"
#include <AVFoundation/AVFoundation.h>
OSStatus AudioUnitManager::OnGetPlayoutData(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList *io_data){
    //provide silence data if playout is not have actived
    AudioBuffer *audio_buffer = &io_data->mBuffers[0];
//    int ret = audioBuf->mAvailSamples - 160;
//    if (ret <= 0) {
//        const size_t size_in_bytes = audio_buffer->mDataByteSize;
//        *flags |=  kAudioUnitRenderAction_OutputIsSilence;
//        memset(static_cast<int8_t *>(audio_buffer->mData), 0, size_in_bytes);
//        printf("PlayOutData == %u",(unsigned int)num_frames);
//        return noErr;
//    }
////    AudioFrame *frame = audioBufferList.front();
////    memcpy(audio_buffer->mData, frame->audioBufferList->mBuffers[0].mData, (size_t)num_frames);
////    audioBufferList.pop_front();
//    printf("PlayOutData == %u \n",(unsigned int)num_frames);
//    int agcSize = 160;
//    int16_t *buffer = (int16_t *)malloc(sizeof(int16_t) * agcSize);
//    audioBuf->Pop(buffer, agcSize);
//    int16_t tmp[agcSize];
//    audio_agc_->Process(buffer, tmp, agcSize);
//    audio_process_buf->Push(tmp, agcSize);
//    printf("mAvailSamples == %u",audio_process_buf->mAvailSamples);
    int  ret = audio_process_buf->mAvailSamples - num_frames;
    if (ret <= 0) {
        const size_t size_in_bytes = audio_buffer->mDataByteSize;
        *flags |=  kAudioUnitRenderAction_OutputIsSilence;
        memset(static_cast<int8_t *>(audio_buffer->mData), 0, size_in_bytes);
        printf("PlayOutData == %u",(unsigned int)num_frames);
        return noErr;
    }
    int16_t *io_buffer = (int16_t *)malloc(sizeof(int16_t) * num_frames);
    audio_process_buf->Pop(io_buffer,num_frames);
    memcpy(audio_buffer->mData,io_buffer, io_data->mBuffers[0].mDataByteSize);
    free(io_buffer);
    return noErr;
}
OSStatus AudioUnitManager::OnDeliverRecordeData(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList *io_data){
    AudioBufferList audio_buffer_list;
    audio_buffer_list.mNumberBuffers = 1;
    AudioBuffer *audio_buffer = &audio_buffer_list.mBuffers[0];
    audio_buffer->mNumberChannels = 1 ;
    audio_buffer->mDataByteSize = num_frames * VoiceProcessingAudioUnit::kBytesPersample;
    int16_t *buffer = (int16_t *)malloc(sizeof(int16_t) * num_frames);
    audio_buffer->mData = buffer;
    memset(static_cast<int8_t *>(audio_buffer->mData), 0, audio_buffer->mDataByteSize);
    //receive audio data frome microphone
    audio_unit_->Render(flags, time_stamp, bus_number, num_frames, &audio_buffer_list);
    printf("RecordData == %u \n",(unsigned int)num_frames);
    audioBuf->Push((int16_t *)audio_buffer->mData, num_frames);
    int ret = audioBuf->mAvailSamples - 160;
    while (ret > 0) {
        int agcSize = 160;
        int16_t *buffer = (int16_t *)malloc(sizeof(int16_t) * agcSize);
        audioBuf->Pop(buffer, agcSize);
        int16_t tmp[agcSize];
        audio_agc_->Process(buffer, tmp, agcSize);
        audio_process_buf->Push(tmp, agcSize);
        ret = audioBuf->mAvailSamples - 160;
    }
    free(buffer);
    return noErr;
}
AudioUnitManager::AudioUnitManager():audio_unit_(new VoiceProcessingAudioUnit(this)),audio_process_buf(new AudioCircularBuffer<int16_t>(2822,true)),audioBuf(new AudioCircularBuffer<int16_t>(2822,true)),audio_agc_(new AGC(16000)){
    AVAudioSession *audio_session = [AVAudioSession sharedInstance];
    NSError *error;
    [audio_session setActive:NO error:&error];
    [audio_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audio_session setActive:true error:&error];
    [audio_session setPreferredIOBufferDuration:0.020 error:&error];
    [audio_session setPreferredSampleRate:16000 error:&error];
    [audio_session setInputGain:1.0 error:&error];
    // [audio_session setPreferredInputNumberOfChannels:441 error:&error];

}

void AudioUnitManager::Initialize(Float64 sample_rate){
    audio_unit_->Init();
    audio_unit_->Initialize(sample_rate);
}
void AudioUnitManager::Start(){
    audio_unit_->Start();
}
void AudioUnitManager::Stop(){
    audio_unit_->Stop();
}
void AudioUnitManager::Uninitialize(){
    audio_unit_->Uninialize();
}
void AudioUnitManager::adjustAudioGainLevel(float level)
{
    audio_gain_level = level;
}
void AudioUnitManager::adjustVolume(float volume){
    audio_unit_->adjustVolume(volume);
}
