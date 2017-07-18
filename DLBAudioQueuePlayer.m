//
//  DLBAudioQueuePlayer.m
//  TestApp
//
//  Created by Tianlei on 2/18/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "DLBAudioQueuePlayer.h"

static UInt32 gBufferSizeBytes=0x10000;

@implementation DLBAudioQueuePlayer


void AQOutputCallback(void * inUserData,
                      AudioQueueRef outAQ,
                      AudioQueueBufferRef outBuffer) {
    
    DLBAudioQueuePlayer *player = (__bridge DLBAudioQueuePlayer*)inUserData;
    
    if (!player->mStarted)
        return;
    
    
    UInt32 numBytes = gBufferSizeBytes;
    UInt32 numPackets=player->mNumPacketsToRead;
    
    OSStatus status = AudioFileReadPacketData(player->mAudioFile, NO, &numBytes, player->mPacketDescs, player->mPacketIndex,&numPackets, outBuffer->mAudioData);
    
    if (status != noErr && status != kAudioFileEndOfFileError) {
        return;
    }
    
    NSLog(@"Current pos:%f",[player getCurrentPlaybackPos]);
    
    if (numPackets>0) {
        
        outBuffer->mAudioDataByteSize=numBytes;
        
        status = AudioQueueEnqueueBuffer(outAQ, outBuffer, (player->mPacketDescs ? numPackets : 0 ), player->mPacketDescs);
        if (status != noErr) {
            NSLog(@"*** Error *** DLBAudioQueuePlayer - AudioQueueEnqueueBuffer failed,status=%d", (int)status);
        }
        
        player->mPacketIndex += numPackets;
        
    }
    
    if (numPackets == 0 || status == kAudioFileEndOfFileError) {
        AudioQueueStop(outAQ,false);
        AudioFileClose(player->mAudioFile);
        player->mEnd = YES;
    }
    
    
}

-(void)stopPlayback{
    
    
    if (!mStarted)
        return;
    
    mStarted = NO;
    mError = -0;
    
    dispatch_queue_t sq = dispatch_queue_create("com.dolby.DLBAudioQueuePlayer", NULL);
    
    dispatch_async(sq, ^{
        AudioQueueDispose(mQueue, true);
        AudioFileClose(mAudioFile);
        
        for (int i=0; i<NUM_BUFFERS; i++) {
            AudioQueueFreeBuffer(mQueue, mBuffers[i]);
        }
        
        if (mPacketDescs)
            free(mPacketDescs);
    });
}

-(id) initWithAudio:(NSString *)path{
    
    if (!(self=[super init])) return nil;
    if (!path) {
        NSLog(@"*** Error *** DLBAudioQueuePlayer init path is nil");
        mError = -1;
        return nil;
        
    }
    
    UInt32 size;
    UInt32 maxPacketSize;
    char *cookie=nil;
    OSStatus status;
    
    mStarted = NO;
    mEnd = NO;
    mError = 0;
    
    //Open the audio file
    status = AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kAudioFileReadPermission, 0, &mAudioFile);
    if (status != noErr) {
        NSLog(@"*** Error *** DLBAudioQueuePlayer could not open audio file. Path was: %@", path);
        mError = -1;
        return nil;
    }
    
    //Get audio stream data format
    size = sizeof(mDataFormat);
    AudioFileGetProperty(mAudioFile, kAudioFilePropertyDataFormat, &size, &mDataFormat);
    NSLog(@"Input channels:%d",(unsigned int)mDataFormat.mChannelsPerFrame);
    
    
    NSTimeInterval sec;
    size = sizeof(sec);
    if (noErr == AudioFileGetProperty(mAudioFile, kAudioFilePropertyEstimatedDuration, &size, &sec)) {
        mDuration = [[NSNumber alloc] initWithDouble:sec];
    }
    NSLog(@"File duration:%f",[self getFileDuration]);
    
    
    //Create Audio Queue
    AudioQueueNewOutput(&mDataFormat, AQOutputCallback, (__bridge void *)(self),
                        nil, nil, 0, &mQueue);
    
    //Check data format
    NSLog(@"mDataFormat.mFormatID=%d",(unsigned int)mDataFormat.mFormatID);
    
    switch (mDataFormat.mFormatID) {
        case kAudioFormatAC3:
            NSLog(@"is DD file");
            break;
        case kAudioFormatEnhancedAC3:
            NSLog(@"is DDP file");
            break;
        default:
            break;
    }
    
    
    //VBR
    if (mDataFormat.mBytesPerPacket==0 || mDataFormat.mFramesPerPacket==0) {
        size=sizeof(maxPacketSize);
        AudioFileGetProperty(mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
        if (maxPacketSize > gBufferSizeBytes) {
            maxPacketSize= gBufferSizeBytes;
        }
        
        mNumPacketsToRead = gBufferSizeBytes/maxPacketSize;
        mPacketDescs=malloc(sizeof(AudioStreamPacketDescription)*mNumPacketsToRead);
        
        NSLog(@"file Is VBR");
        
    }else {
        //CBR
        mNumPacketsToRead= gBufferSizeBytes/mDataFormat.mBytesPerPacket;
        mPacketDescs=NULL;
        
        NSLog(@"file is CBR");
    }
    
    //Set Magic Cookie
    AudioFileGetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
    if (size >0) {
        cookie=malloc(sizeof(char)*size);
        AudioFileGetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
        AudioQueueSetProperty(mQueue, kAudioQueueProperty_MagicCookie, cookie, size);
        free(cookie);
    }
    
    //Set AudioQueueChannelAssignment
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* outport in [route outputs])
    {
        NSLog(@"PortName=%@,Type=%@,UID=%@,Channels=%@", outport.portName, outport.portType, outport.UID, outport.channels);
        AudioQueueChannelAssignment *outchannel = malloc(sizeof(AudioQueueChannelAssignment));
        size = sizeof(outchannel);
        outchannel->mDeviceUID = (__bridge CFStringRef _Nonnull)(outport.UID);
        
        for (AVAudioSessionChannelDescription* channels in [outport channels])
        {
            outchannel->mChannelNumber = channels.channelNumber; //mDataFormat.mChannelsPerFrame;
        }
        
        NSLog(@"UID=%@,Numbers=%u", outchannel->mDeviceUID, (unsigned int)outchannel->mChannelNumber);
        status = AudioQueueSetProperty(mQueue, kAudioQueueProperty_ChannelAssignments, outchannel, size);
        if (status != noErr) {
            NSLog(@"kAudioQueueProperty_ChannelAssignments setting error");
        }
    }
    

    //Set audio channel layout
    if (mDataFormat.mChannelsPerFrame > 2 ) {
        UInt32 sz = sizeof(UInt32);
        AudioChannelLayout al;
        status = AudioFileGetProperty(mAudioFile, kAudioFilePropertyChannelLayout, &sz, &al);
        if (noErr == status && sz > 0) {
            AudioChannelLayout *acl = malloc(sz);
            AudioFileGetProperty(mAudioFile, kAudioFilePropertyChannelLayout, &sz,acl);
            AudioQueueSetProperty(mQueue, kAudioQueueProperty_ChannelLayout, acl, sz);
            free(acl);
        }
    }

    mStarted = YES;
    
    // malloc buffer and read packages
    mPacketIndex=0;
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(mQueue, gBufferSizeBytes, &mBuffers[i]);
        AQOutputCallback((__bridge void *)self,mQueue,mBuffers[i]);
    }
    
    //Set volume [0,1],0:silence
    Float32 gain=1.0;
    AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, gain);
    
    AudioQueueStart(mQueue, NULL);
    

    return self;
}

-(int8_t)getPlayingStatus{
    
    if (mError < 0) {
        return mError;
    }
    
    return mStarted;
}

-(Float32)getCurrentPlaybackPos{
    
    AudioTimeStamp ts;
    
    if (mEnd) {
        return [self getFileDuration];
    }
    
    if (noErr == AudioQueueGetCurrentTime(mQueue, NULL, &ts,NULL)) {
        return ts.mSampleTime / mDataFormat.mSampleRate;
    }
    
    return 0.0;
    
}

-(Float32)getFileDuration{
    return mDuration.doubleValue;
}

-(void)dealloc{
    
    NSLog(@"DLBAudioQueuePlayer dealloced!");
    
    if (mStarted ) {
        [self stopPlayback];
    }
}


@end
