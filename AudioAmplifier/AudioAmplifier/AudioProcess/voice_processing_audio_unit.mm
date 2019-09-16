//
//  voice_processing_audio_unit.m
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/11.
//  Copyright © 2019 agora. All rights reserved.
//

#import "voice_processing_audio_unit.h"
static const int kMaxNumberOfAudioUnitInitializeAttempts = 5;
// A VP I/O unit's bus 1 connects to input hardware (microphone).
static const AudioUnitElement kInputBus  = 1;
// A VP I/O unit's bus 0 connects to output hardware (speaker).

static const AudioUnitElement kOutputBus = 0;

static OSStatus GetAGCState(AudioUnit audio_unit, UInt32 * enabled){
    UInt32 size  = sizeof(*enabled);
    OSStatus result = AudioUnitGetProperty(audio_unit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, enabled, &size);
    
    NSLog(@"VPIO unit AGC: %u", static_cast<unsigned int>(*enabled));
    return result;
}
VoiceProcessingAudioUnit::VoiceProcessingAudioUnit(VoiceProcessingAudioUnitObserver *observer):observer_(observer),vpio_unit_(nullptr),state_(kInitRequired){
}
VoiceProcessingAudioUnit::~VoiceProcessingAudioUnit(){
    DisposeAudioUnit();
}
const UInt32 VoiceProcessingAudioUnit::kBytesPersample = 2;
bool VoiceProcessingAudioUnit::Init()
{
    //create Audio unit
    AudioComponentDescription vpio_unit_description;
    vpio_unit_description.componentType = kAudioUnitType_Output;
    vpio_unit_description.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    vpio_unit_description.componentManufacturer = kAudioUnitManufacturer_Apple;
    vpio_unit_description.componentFlags = 0;
    vpio_unit_description.componentFlagsMask = 0;
    
    //Obtain a voice Processing UI audio Unit.
    AudioComponent found_vpio_unit_ref = AudioComponentFindNext(nullptr, &vpio_unit_description);
    
    OSStatus result = AudioComponentInstanceNew(found_vpio_unit_ref, &vpio_unit_);
    if (result != noErr) {
        vpio_unit_ = nullptr;
        NSLog(@"AudioComponentInstanceNew failed. error =%ld.",(long)result);
        return false;
    }
    // enable input on the sope of the input element.
    UInt32 enable_input = 1;
    result =  AudioUnitSetProperty(vpio_unit_, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &enable_input, sizeof(enable_input));
    if (result != noErr) {
        DisposeAudioUnit();
        NSLog(@"Failed to enable input on input scope of input element. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    // enble output on the output scope if output element.
    UInt32 enable_output = 1;
    result = AudioUnitSetProperty(vpio_unit_, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &enable_output, sizeof(enable_output));
    if (result != noErr) {
        DisposeAudioUnit();
        NSLog(@"Failed to enable input on output scope of input element. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    //Specify the callback function that provides audio samples to the audio Unit.
    AURenderCallbackStruct render_callback;
    render_callback.inputProc = OnGetPlayoutData;
    render_callback.inputProcRefCon = this;
    result = AudioUnitSetProperty(vpio_unit_, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, kOutputBus, &render_callback, sizeof(render_callback));
    if (result != noErr) {
        DisposeAudioUnit();
        NSLog(@"Failed to specify the render callback on the output bus. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    //disable AU buffer allocation for the recorder , we allocate our own.
    //TODO
    UInt32 flag = 0;
    result = AudioUnitSetProperty(vpio_unit_, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
    if (result != noErr) {
        DisposeAudioUnit();
        NSLog(@"Failed to disable buffer allocation on the input bus. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    AURenderCallbackStruct input_callback;
    input_callback.inputProc = OnDeliverRedcordedData;
    input_callback.inputProcRefCon = this;
    result = AudioUnitSetProperty(vpio_unit_, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &input_callback, sizeof(input_callback));
    if (result != noErr) {
        DisposeAudioUnit();
        NSLog(@"Failed to specify the input callback on the input bus. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    
    state_  =  kUinitialized;
    return true;
    
}
VoiceProcessingAudioUnit::State VoiceProcessingAudioUnit::GetState() const
{
    return state_;
}
bool VoiceProcessingAudioUnit::Initialize(Float64 sample_rate)
{
    OSStatus result = noErr;
    AudioStreamBasicDescription format =  GetFormat(sample_rate);
    UInt32 size = sizeof(format);
    //set the format on the scope of the input element / bus.
    result = AudioUnitSetProperty(vpio_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &format, size);
    if (result != noErr) {
        NSLog(@"Failed to set format on output scope of input bus. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    // set the format on the scope of the output element/bus
    result = AudioUnitSetProperty(vpio_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &format, size);
    if (result != noErr) {
        NSLog(@"Failed to set format on input scope of output bus. "
              "Error=%ld.",
              (long)result);
        return false;
    }
    //Initilize the voice processing I/O unit instance
    //Calls to AudioUnitInialize() can fail if called back-to-back on
    //Test have shown that calling AudioUnitInitialize a second.
    int failed_initalized_attempts = 0;
    result = AudioUnitInitialize(vpio_unit_);
    while (result != noErr) {
        NSLog(@"Failed to initialize the voice processing I/O unit");
        ++failed_initalized_attempts;
        if (failed_initalized_attempts  == kMaxNumberOfAudioUnitInitializeAttempts) {
            NSLog(@"too many initialize attempts");
            return false;
        }
        NSLog(@"Pause 100ms and try audio unit initialize again ...");
        [NSThread sleepForTimeInterval:0.1f];
        result = AudioUnitInitialize(vpio_unit_);
    }
    if (result == noErr) {
        NSLog(@"Voice processing I/O unit is now initialized.");
    }
    // open AGC
    int agc_was_enable_by_default = 0;
    UInt32 agc_is_enabled = 0 ;
    result = GetAGCState(vpio_unit_,&agc_is_enabled);
    if (result != noErr) {
        NSLog(@"open AGC failed");
        
    }else if (agc_is_enabled)
    {
        agc_was_enable_by_default = 1;
    }else{
        UInt32 enable_agc = 1;
        result = AudioUnitSetProperty(vpio_unit_, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, &enable_agc, sizeof(enable_agc));
        if (result != noErr) {
            NSLog(@"failed to enble the buil-in AGC");
        }
        result = GetAGCState(vpio_unit_, &agc_is_enabled);
        if (result != noErr) {
            NSLog(@"enable AGC (2nd attempt)");
        }
    }
    
    state_ = kInitialized;
    return true;
}
bool VoiceProcessingAudioUnit::Start(){
    OSStatus result = AudioOutputUnitStart(vpio_unit_);
    if (result != noErr) {
        NSLog(@"Failed to start audio unit");
        return false;
    }else{
        NSLog(@"start audio unit");
    }
    state_ = kStarted;
    return true;
}
bool VoiceProcessingAudioUnit::Stop(){
    OSStatus result = AudioOutputUnitStop(vpio_unit_);
    if (result != noErr) {
        NSLog(@"Failed to stop audio unit");
        return false;
    }else{
        NSLog(@"Stopped audio unit");
    }
    state_  = kInitialized;
    return true;
}
bool VoiceProcessingAudioUnit::Uninialize(){
    OSStatus result = AudioUnitUninitialize(vpio_unit_);
    if (result != noErr) {
        NSLog(@"uninialize failed");
        return  false;
    }else{
        NSLog(@"Uinitialized audio unit");
    }
    state_ = kUinitialized;
    return true;
}
OSStatus VoiceProcessingAudioUnit::Render(AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull time_stamp, UInt32 output_bus_number, UInt32 num_frames, AudioBufferList * _Nonnull io_data){
    
    OSStatus result = AudioUnitRender(vpio_unit_, flags, time_stamp, output_bus_number, num_frames, io_data);
    
    if (result != noErr) {
        NSLog(@"Failed to render audio unit, Error = %ld",(long) result);
    }
    return result;
}
OSStatus VoiceProcessingAudioUnit::OnGetPlayoutData(void * _Nonnull in_ref_con, AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList * _Nonnull io_data){
    VoiceProcessingAudioUnit *audio_unit = static_cast<VoiceProcessingAudioUnit *>(in_ref_con);
    return audio_unit->NotifyGetPlayoutData(flags, time_stamp, bus_number, num_frames, io_data);
    
}
OSStatus VoiceProcessingAudioUnit::OnDeliverRedcordedData(void * _Nonnull in_ref_con, AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList * _Nonnull io_data){
    VoiceProcessingAudioUnit *audio_unit = static_cast<VoiceProcessingAudioUnit *>(in_ref_con);
    return audio_unit->NotifyDeliverRecordedData(flags, time_stamp, bus_number, num_frames, io_data);
}
OSStatus VoiceProcessingAudioUnit::NotifyDeliverRecordedData(AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList * _Nonnull io_data){
    return observer_->OnDeliverRecordeData(flags, time_stamp, bus_number, num_frames, io_data);
}
OSStatus VoiceProcessingAudioUnit::NotifyGetPlayoutData(AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull time_stamp, UInt32 bus_number, UInt32 num_frames, AudioBufferList * _Nonnull io_data){
    return observer_->OnGetPlayoutData(flags, time_stamp, bus_number, num_frames, io_data);
}
AudioStreamBasicDescription VoiceProcessingAudioUnit::GetFormat(Float64 sample_rate) const
{
    AudioStreamBasicDescription format;
    format.mSampleRate = sample_rate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBytesPerPacket = kBytesPersample;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = kBytesPersample;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 8 * kBytesPersample;
    return format;
}
void VoiceProcessingAudioUnit::DisposeAudioUnit(){
    if (vpio_unit_) {
        switch (state_) {
            case kStarted:
                Stop();
                break;
            case kInitialized   :
                Uninialize();
                break;
            case kUinitialized  :
            case kInitRequired:
                break;
            default:
                break;
        }
    }
    NSLog(@"Disposing audio unit");
    OSStatus result = AudioComponentInstanceDispose(vpio_unit_);
    if (result != noErr) {
        NSLog(@"AudioComponentInstanceDispose failed ！");
    }
    vpio_unit_ = nullptr;
}
void VoiceProcessingAudioUnit::adjustVolume(float volume){
    AudioUnitSetParameter(vpio_unit_, kHALOutputParam_Volume, kAudioUnitScope_Input, kInputBus, volume, 0);
}

