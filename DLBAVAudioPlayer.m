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
    
    audioplayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
    //audioplayer.delegate = self;
    //[audioplayer setNumberOfLoops:0];
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
    
    [audioplayer stop];

}

@end
