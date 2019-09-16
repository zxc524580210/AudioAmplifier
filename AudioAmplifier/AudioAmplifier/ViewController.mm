//
//  ViewController.m
//  AudioAmplifier
//
//  Created by zhanxiaochao on 2019/9/12.
//  Copyright © 2019 agora. All rights reserved.
//

#import "ViewController.h"
#import "AudioUnitManager.h"
@interface ViewController ()
@property(atomic)AudioUnitManager *manager;
@end

@implementation ViewController
- (IBAction)Start:(id)sender {
    _manager->Start();
}
- (IBAction)Stop:(id)sender {
    
    _manager->Stop();
}
- (IBAction)value_change:(UISlider *)sender {
    
    _manager->adjustAudioGainLevel(sender.value);
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _manager = new AudioUnitManager();
    _manager->Initialize(16000);
    
}
-(void)dealloc{
    _manager->Uninitialize();
    delete _manager;
    _manager = nullptr;
}

@end
