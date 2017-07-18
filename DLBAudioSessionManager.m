//
//  DLBAudioSessionManager.m
//  TestApp
//
//  Created by Gan, Lei on 6/24/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import "DLBAudioSessionManager.h"

#include <AudioUnit/AudioUnit.h>


@implementation DLBAudioSessionManager

AVAudioSession *sessionInstance;

-(void)InitAudioSession{
    
    
    NSError *error = nil;
    sessionInstance = [AVAudioSession sharedInstance];
    // set the session category
    bool success = [sessionInstance setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    NSAssert(success, @"Error setting AVAudioSession category! %@", [error localizedDescription]);
    // activate the audio session
    success = [sessionInstance setActive:YES error:&error];
    NSAssert(success, @"Error setting AVAudioSession active! %@", [error localizedDescription]);
    

    
}

/*
-(AudioDeviceID)GetDefaultOutputDeviceID{
    
    AudioDeviceID outputDeviceID = kAudioObjectUnknown;
    
    // get output device device
    OSStatus status = noErr;
    AudioObjectPropertyAddress propertyAOPA;
    propertyAOPA.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAOPA.mElement = kAudioObjectPropertyElementMaster;
    propertyAOPA.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    
    if (!AudioHardwareServiceHasProperty(kAudioObjectSystemObject, &propertyAOPA))
    {
        NSLog(@"Cannot find default output device!");
        return outputDeviceID;
    }
    
    status = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject, &propertyAOPA, 0, NULL, (UInt32[]){sizeof(AudioDeviceID)}, &outputDeviceID);
    
    if (status != 0)
    {
        NSLog(@"Cannot find default output device!");
    }
    
    return outputDeviceID;
}
*/

-(void)SetAudioChannelLayout:(signed int)channel_number {
    
    NSError *error = nil;
    [sessionInstance setPreferredOutputNumberOfChannels:channel_number error:&error];
    
}



@end
