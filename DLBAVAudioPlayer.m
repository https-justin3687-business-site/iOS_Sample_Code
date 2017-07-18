//
//  DLBAVAudioPlayer.m
//  TestApp
//
//  Created by Tianlei on 2/18/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import "DLBAVAudioPlayer.h"

AVAudioPlayer *audioplayer;

@implementation DLBAVAudioPlayer

-(id) initWithAudio:(NSString *)path{
    
    if (!path) {
        NSLog(@"*** Error *** DLBAVAudioPlayer init path is nil\n");
        return nil;
        
    }
    
    mError = 0;
    NSError *error = nil;
    
    audioplayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSUInteger outputs = session.maximumOutputNumberOfChannels;        //query the number of channels the hardware has
    //NSLog(@"output channel:%lu", (unsigned long)outputs);
    
    NSUInteger source = audioplayer.numberOfChannels;       //query the number of channels in source audio
    //NSLog(@"source channel:%lu", (unsigned long)source);
    
    if (outputs == 2 || outputs == 1) {     // 2 for steoro, 1 for mono
        [session setPreferredOutputNumberOfChannels:outputs error:&error];
    }
    else if (outputs == 6) {
        if (source < 6) {
            [session setPreferredOutputNumberOfChannels:source error:&error];
        } else {
            [session setPreferredOutputNumberOfChannels:outputs error:&error];
        }
    }
    else if (outputs == 8) {
        if (source < 8) {
            [session setPreferredOutputNumberOfChannels:source error:&error];
        } else {
            [session setPreferredOutputNumberOfChannels:outputs error:&error];
        }
    }
    else {
        [session setPreferredOutputNumberOfChannels:outputs error:&error];
    }
    
    bool success = [session setActive:YES error:&error];
    NSAssert(success, @"Error setting AVAudioSession active! %@", [error localizedDescription]);
    
    //NSUInteger input = session.inputNumberOfChannels;
    //NSLog(@"output channel:%lu", (unsigned long)input);   //always return 0

    [audioplayer play];
    
    mStarted = YES;
    mEnd = NO;
    
    return self;
    
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag {
    mEnd = YES;
}

-(int8_t)getPlayingStatus{
    
    if (mError < 0) {
        return mError;
    }
    
    return mStarted;
}

-(Float32)getCurrentPlaybackPos{
    
    if (!mStarted)
        return 0.0;
    
    if (mEnd) {
        return [self getFileDuration];
    }
    
    return audioplayer.currentTime;
    
}

-(Float32)getFileDuration{
    
    return audioplayer.duration;
}

-(void) stopPlayback{
    
    mStarted = NO;
    mEnd = YES;
    NSLog(@"stopPlayback");
    [audioplayer stop];

}

@end
