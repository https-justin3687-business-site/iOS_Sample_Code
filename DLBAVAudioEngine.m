//
//  DLBAVAudioEngine.m
//  TestApp
//
//  Created by Tianlei on 2/22/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import "DLBAVAudioEngine.h"



@implementation DLBAVAudioEngine


+ (AVAudioEngine*)sharedEngine
{
    static dispatch_once_t once;
    static AVAudioEngine* result = nil;
    dispatch_once(&once, ^{
        result = [[AVAudioEngine alloc] init];
    });
    return result;
}


-(id) initWithAudio:(NSString *)path{
    
    if (!path) {
        NSLog(@"*** Error *** DLBAVAudioEngine init path is nil\n");
        return nil;
        
    }
    mError = 0;
    
    NSError *error = nil;
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    
    // set the session category
    bool success = [sessionInstance setCategory:AVAudioSessionCategoryMultiRoute withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    NSAssert(success, @"Error setting AVAudioSession category! %@", [error localizedDescription]);
    
    // activate the audio session
    success = [sessionInstance setActive:YES error:&error];
    NSAssert(success, @"Error setting AVAudioSession active! %@", [error localizedDescription]);
    
    // AVAudioEngine setup
    AVAudioEngine * audioengine = [self.class sharedEngine];
    AVAudioOutputNode *output = audioengine.outputNode;
    AVAudioMixerNode *mixer = audioengine.mainMixerNode;
    
    audioplayer = [[AVAudioPlayerNode alloc] init];
    [audioengine attachNode:audioplayer];
    
    // open the file to play
    NSURL* url = [NSURL fileURLWithPath:path];
    avFile = [[AVAudioFile alloc] initForReading:url error: &error];
    
    // make connections
    AVAudioFormat *outformat = [output outputFormatForBus:0];
    [audioengine connect:audioplayer to:mixer format:[avFile processingFormat]];
    [audioengine connect:mixer to:output format:outformat];
    
    // schedule the file on player
    @try {
        [audioplayer scheduleFile:avFile atTime:nil completionHandler:^{
            mEnd = YES;
        }];
    } @catch (NSException *exception) {
        NSLog(@"*** Error *** DLBAVAudioEngine catch exception: %@%@\n", [exception name], [exception reason]);
        mError = -1;
        return nil;
        
    } @finally {
    }
    
    // start engine and player
    success = [audioengine startAndReturnError:&error];
    NSAssert(success, @"Error starting engine! %@", [error localizedDescription]);
    
    [audioplayer play];
    mStarted = YES;
    mEnd = NO;
    
    return self;
    
}

-(int8_t)getPlayingStatus{
    
    if (mError < 0) {
        return mError;
    }
    
    return mStarted;
}

-(void)stopPlayback{
    
    if (!mStarted)
        return;
    
    mStarted = NO;
    mEnd = YES;
    mError = 0;
    
    [audioplayer stop];
    audioplayer = nil;
}

-(Float32)getCurrentPlaybackPos{
    
    if (mEnd) {
        return [self getFileDuration];
    }
    
    if (!mStarted) {
        return 0.0;
    }
    
    if (audioplayer.lastRenderTime > 0) {
        
        NSTimeInterval currentTime = ((NSTimeInterval)[audioplayer playerTimeForNodeTime:audioplayer.lastRenderTime].sampleTime / avFile.fileFormat.sampleRate);
        
        if (currentTime > 0) {
            return currentTime;
        }
    }
    
    return 0.0;
    
}

-(Float32)getFileDuration{
    
    double sr = avFile.fileFormat.sampleRate;
    if ( sr <= 0)
        return 0.0;
    
    return avFile.length/sr;
}

@end
