//
//  DLBAUGraphPlayer.m
//  TestApp
//
//  Created by Tianlei on 2/18/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import "DLBAUGraphPlayer.h"

@implementation DLBAUGraphPlayer


OSStatus checkError(OSStatus err, const char * msg)
{
    if (noErr == err)
        return noErr;
    
    char errStr[30]={0};
    
    *(UInt32 *)(errStr + 1) = CFSwapInt32HostToBig(err);
    
    if (isprint(errStr[1]) && isprint(errStr[2]) && isprint(errStr[3]) && isprint(errStr[4]))
    {
        errStr[0]=errStr[5]='\'';
        errStr[6]='\0';
    }
    else {
        sprintf(errStr,"%d",(int)err);
    }
    
    NSLog(@"*** Error *** %s, (%s) \n",msg,errStr);
    
    return err;
}

static OSStatus renderNotification(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    
    if (*ioActionFlags == kAudioUnitRenderAction_PostRender) {
        
        AudioBufferDataPtr data = (AudioBufferDataPtr)inRefCon;
        //DLBAUGraphPlayer *player = (__bridge DLBAUGraphPlayer *)data->player;
        
        data->frameNum += inNumberFrames;

    }

    
    return noErr;
}

-(id)createDLBAUGraph
{
    //Create AUGraph
    if (noErr != checkError(NewAUGraph(&mGraph), "NewAUGraph failed") )
        return nil;
    
    //Create description for output
    AudioComponentDescription outputDesc = {0};
    outputDesc.componentType = kAudioUnitType_Output;
    outputDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    //Create description for file player
    AudioComponentDescription playerDesc = {0};
    playerDesc.componentType = kAudioUnitType_Generator;
    playerDesc.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    playerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    //Add output node
    if (noErr != checkError(AUGraphAddNode(mGraph, &outputDesc, &mOutputNode), "AUGraphAddNode failed, adding output node"))
        return nil;
    
    //Add player node
    
    if (noErr != checkError(AUGraphAddNode(mGraph, &playerDesc, &mPlayerNode), "AUGraphAddNode failde, add player node"))
        return nil;
    
    //Open the graph
    if (noErr != checkError(AUGraphOpen(mGraph), "AUGraphOpen failde"))
        return nil;
    
    //Get the AudioUnit object
    if (noErr != checkError(AUGraphNodeInfo(mGraph, mPlayerNode, NULL, &mPlayerAU), "AUGraphNodeInfo failed"))
        return nil;
    
    //Connect player node to output
    if (noErr != checkError(AUGraphConnectNodeInput(mGraph, mPlayerNode, 0, mOutputNode, 0),"AUGraphConnectNodeInput failed"))
        return nil;
    
    //Add render notification after the render operation is complete
    AUGraphAddRenderNotify(mGraph, renderNotification, &mAudioData);
    
    //Init the graph
    if (noErr != checkError(AUGraphInitialize(mGraph),"AUGraphInitialize failed"))
        return nil;
    
    
    return self;
}

-(int8_t)startPlayback:(NSString *)path{
    
    //Open the audio file
    if (noErr != checkError(AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kAudioFileReadPermission, 0, &mAudioFile),"AudioFileOpenURL failed"))
        return -1;
    
    
    UInt32 nSize = sizeof(mAudioDataFormat);
    if (noErr != checkError(AudioFileGetProperty(mAudioFile, kAudioFilePropertyDataFormat, &nSize, &mAudioDataFormat), "AudioFileGetProperty failed, get audio data format"))
        return -1;
    
    NSTimeInterval sec;
    nSize = sizeof(sec);
    if (noErr == AudioFileGetProperty(mAudioFile, kAudioFilePropertyEstimatedDuration, &nSize, &sec)) {
        mDuration = [[NSNumber alloc] initWithDouble:sec];
    }
    NSLog(@"File duration:%f",[self getFileDuration]);
    
    mAudioData.maxNumFrames = sec * mAudioDataFormat.mSampleRate;
    mAudioData.frameNum = 0;
    mAudioData.player = (__bridge void *)(self);
    
    UInt64 nPackets;
    nSize = sizeof(nPackets);
    if (noErr != checkError(AudioFileGetProperty(mAudioFile, kAudioFilePropertyAudioDataPacketCount, &nSize, &nPackets), "AudioFileGetProperty failed, get file packets count"))
        return -1;
    
    if (nil == [self createDLBAUGraph])
        return -1;
    
    //Set AudioFileId for FilePlayer Unit
    if (noErr != checkError(AudioUnitSetProperty(mPlayerAU, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &mAudioFile, sizeof(mAudioFile)), "AudioUnitSetProperty failed, set AudioFileId"))
        return -1;
 
    //Set the FilePlayer Unit region to whole file
    ScheduledAudioFileRegion afrgn;
    memset(&afrgn.mTimeStamp, 0, sizeof(afrgn.mTimeStamp));
    afrgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    afrgn.mTimeStamp.mSampleTime = 0;
    afrgn.mCompletionProc = NULL;
    afrgn.mCompletionProcUserData = NULL;
    afrgn.mAudioFile = mAudioFile;
    afrgn.mLoopCount = 0;
    afrgn.mStartFrame = 0;
    afrgn.mFramesToPlay = (UInt32)nPackets * mAudioDataFormat.mFramesPerPacket;

    if (noErr != checkError(AudioUnitSetProperty(mPlayerAU, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &afrgn, sizeof(afrgn)), "AudioUnitSetProperty failed, set file region"))
        return -1;

    
    //Prime
    UInt32 val = 0;
    if (noErr != checkError(AudioUnitSetProperty(mPlayerAU, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &val, sizeof(val)), "AudioUnitSetProperty failed, prime the player"))
        return -1;
    
    
    AudioTimeStamp startTS;
    memset(&startTS,0,sizeof(startTS));
    startTS.mFlags = kAudioTimeStampSampleTimeValid;
    startTS.mSampleTime = -1;
    if (noErr != checkError(AudioUnitSetProperty(mPlayerAU, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTS, sizeof(startTS)), "AudioUnitSetProperty failed, set start timestamp"))
        return -1;
    
    //Start the graph
    if (noErr != checkError(AUGraphStart(mGraph), "AUGraphStart failed"))
        return -1;

    mStarted = YES;
    
    return 0;
}

-(id) initWithAudio:(NSString *)path{
    
    if (!(self=[super init])) return nil;
    if (!path) {
        NSLog(@"*** Error *** DLBAUGraphPlayer init path is nil\n");
        return nil;
        
    }
    mError = 0;
    
    mStarted = NO;
    
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setPreferredOutputNumberOfChannels:8 error:&error];
    bool success = [session setActive:YES error:&error];
    NSAssert(success, @"Error setting AVAudioSession active! %@", [error localizedDescription]);
    
    NSUInteger channels = session.maximumOutputNumberOfChannels;
    NSLog(@"channels:%lu", (unsigned long)channels);
    mError = [self startPlayback:path];
    
    return self;
    
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
    
    Float32 pos = mAudioData.frameNum / 44100.0;
    
    if (pos > mDuration.doubleValue) {
        return mDuration.doubleValue;
    }
    
    return pos;
    
}

-(Float32)getFileDuration{
    
    return mDuration.doubleValue;
}

-(void)stopPlayback{
    
    if (!mStarted)
        return;
    
    mStarted = NO;
    mError = 0;
    AUGraphStop(mGraph);
    AUGraphUninitialize(mGraph);
    AUGraphClose(mGraph);
    AudioFileClose(mAudioFile);
    
}

-(void)dealloc{
    NSLog(@"DLBAUGraphPlayer dealloced!");
    if (mStarted ) {
        [self stopPlayback];
    }

}

@end
