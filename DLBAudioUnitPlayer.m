//
//  DlbAudioUnitPlayer.m
//  testApp
//
//  Created by Gan, Lei on 1/13/16.
//  Copyright © 2016 Gan, Lei. All rights reserved.
//

#import "DLBAudioUnitPlayer.h"
#import <libkern/OSAtomic.h>
#import <AVFoundation/AVFoundation.h>

@implementation DLBAudioUnitPlayer

//Declared as AURenderCallback in AudioUnit/AUComponent.h. See Audio Unit Component Services Reference.
static OSStatus playbackCallback (
                                  void                        *inRefCon,
                                  AudioUnitRenderActionFlags  *ioActionFlags,
                                  const AudioTimeStamp        *inTimeStamp,
                                  UInt32                      inBusNumber,
                                  UInt32                      inNumberFrames,
                                  AudioBufferList             *ioData
                                  ) {
    
    stAudioUnitSampleData *audioSampleData = (stAudioUnitSampleData *)inRefCon;
    
    if (audioSampleData->mFreeBuffers == audioSampleData->mBufferCount )
        return noErr;
		
    audioSampleData->mCallbackFrames = inNumberFrames;
	
    // Screen sleeps (sleep/wake crash), buffer changes from 1024 to 4096
    if ( 4096 == inNumberFrames) {
        
        if (audioSampleData->mFramesPerBuffer < (audioSampleData->mFramesReaded + inNumberFrames)) {
            
            UInt64 frameOffset = audioSampleData->mFramesPerBuffer - audioSampleData->mFramesReaded;
            
            for (UInt32 i = 0; i < frameOffset; ++i) {
                
                for (int ch=0; ch < audioSampleData->mAudioChannels; ++ch) {
                    ((SInt32 *)(ioData->mBuffers[ch].mData))[i] = audioSampleData->mAudioUnitSamples[ch][audioSampleData->mCurrentBufferIdx][audioSampleData->mFramesReaded];
                }
               
                
                ++audioSampleData->mFramesReaded;
            }
            
            // move to next buffer
            if (++audioSampleData->mCurrentBufferIdx == audioSampleData->mBufferCount)
                audioSampleData->mCurrentBufferIdx = 0;
            
            // request one more buffer
            OSAtomicAdd32(1,&audioSampleData->mFreeBuffers);
            
            UInt32 continueSampleNumber = 0;
            for (UInt64 i = frameOffset; i < inNumberFrames; ++i) {
                
                for (int ch=0; ch < audioSampleData->mAudioChannels; ++ch) {
                    ((SInt32 *)(ioData->mBuffers[ch].mData))[i] = audioSampleData->mAudioUnitSamples[ch][audioSampleData->mCurrentBufferIdx][continueSampleNumber];
                }
                
                ++continueSampleNumber;
            }
            
            audioSampleData->mFramesReaded = continueSampleNumber;
            
            return noErr;
        }
        else {
            
            for (UInt32 i = 0; i < inNumberFrames; ++i) {
                
                for (int ch=0; ch < audioSampleData->mAudioChannels; ++ch) {
                    ((SInt32 *)(ioData->mBuffers[ch].mData))[i] = audioSampleData->mAudioUnitSamples[ch][audioSampleData->mCurrentBufferIdx][audioSampleData->mFramesReaded];
                }
 
                ++audioSampleData->mFramesReaded;
            }
        }
        audioSampleData->mPlayedFrames += 4096;
    } //4096
    else {
        
        for (UInt32 i = 0; i < audioSampleData->mCallbackFrames; ++i) {
            
            for (int ch=0; ch < audioSampleData->mAudioChannels; ++ch) {
                ((SInt32 *)(ioData->mBuffers[ch].mData))[i] = audioSampleData->mAudioUnitSamples[ch][audioSampleData->mCurrentBufferIdx][audioSampleData->mFramesReaded];
            }
            
            ++audioSampleData->mFramesReaded;
        }
        audioSampleData->mPlayedFrames += audioSampleData->mCallbackFrames;
    }
    
    // the current buffer is used up
    if (audioSampleData->mFramesReaded == audioSampleData->mFramesPerBuffer) {
        
        if (++audioSampleData->mCurrentBufferIdx == audioSampleData->mBufferCount)
            audioSampleData->mCurrentBufferIdx = 0;
        
        OSAtomicAdd32(1,&audioSampleData->mFreeBuffers);
        audioSampleData->mFramesReaded = 0;
    }
    
    //   if (audioSampleData->mPlayedFrames > audioSampleData->mConvertedFileFrames) {
    //       return noErr;
    //   }
    
    return noErr;
}



OSStatus checkStatus(OSStatus err, const char * msg)
{
    if (noErr == err)
        return noErr;
    
    char errStr[30]={0};
    
    *(UInt32 *)(errStr + 1) = CFSwapInt32HostToBig(err);
    
    if (isprint(errStr[1]) && isprint(errStr[2]) && isprint(errStr[3]) && isprint(errStr[4])) {
        errStr[0]=errStr[5]='\'';
        errStr[6]='\0';
    }
    else {
        sprintf(errStr,"%d",(int)err);
    }
    
    NSLog(@"*** Error *** %s, (%s) \n", msg, errStr);
    
    return err;
}

-(void)cycleFillBufferFromFile{
    
    // a buffer is free
    if (mAudioUnitSampleData.mFreeBuffers != 0) {
        
        unsigned char curBuffer = mAudioUnitSampleData.mCurrentBufferIdx;
        int32_t freeBuffers = mAudioUnitSampleData.mFreeBuffers;

        do {
            --mReadingIteras;
            
            if (mRemainingFramesInFile != 0) {
                
                [self setCurrentBuffers:(curBuffer - freeBuffers)];
                
                if (mRemainingFramesInFile >= (UInt32)mFramesToReadIntoBuffer) {
                    [self readFramesFromFile:mFramesToReadIntoBuffer];
                }
                else {
                    [self readLastFramesFromFile];	
                }
            }
            else if (mReadingIteras <= -mAudioUnitSampleData.mBufferCount) {
                
                // All of audio data buffer are outputed, stop remote i/o audio unit
                [self stopPlayback];
                
                mAudioUnitSampleData.mFreeBuffers = 0;
                
                return;
            }
            else {
                //Read all of data, while remote io does not output them all.
				
                signed char requestedBuffer = curBuffer - freeBuffers;
                
                if (requestedBuffer < 0) {
                    requestedBuffer += mAudioUnitSampleData.mBufferCount;
                }
                
				for (int ch = 0; ch < mAudioUnitSampleData.mAudioChannels; ++ch) {
                    memset(mAudioUnitSampleData.mAudioUnitSamples[ch][requestedBuffer],0,(mFramesToReadIntoBuffer * 4));
                }
            }
            
            OSAtomicAdd32(-1,&mAudioUnitSampleData.mFreeBuffers);
        }
        while (--freeBuffers > 0);
    }
}

-(void) setCurrentBuffers:(signed int)request{
    
    if (request < 0) {
        request += mAudioUnitSampleData.mBufferCount;
    }
	
	//Set the audio data buffer pointer
	for (int i=0; i< mAudioBufferList->mNumberBuffers; ++i) {
	    mAudioBufferList->mBuffers[i].mData = mAudioUnitSampleData.mAudioUnitSamples[i][request];
	}
	
};

-(UInt32) readFramesFromFile:(UInt32)frames{
    
    if (!mStarted)
        return 0;
    
    OSStatus status = ExtAudioFileRead (mAudioFile, &frames, mAudioBufferList);
  
    if (noErr == checkStatus(status,"ExtAudioFileRead failed, read audio data from file")) {
	    mRemainingFramesInFile -= frames;
		
		// End of file
		if ( 0 == frames ) {
		    mRemainingFramesInFile = 0;
			NSLog(@"Reach the end of file.\n");
		}
	}
   
    return frames;
}

-(void) readLastFramesFromFile{
    
    if (!mStarted)
        return;
    
    for (int i=0; i< mAudioBufferList->mNumberBuffers; ++i) {
        memset(mAudioBufferList->mBuffers[i].mData,0,(mFramesToReadIntoBuffer * 4));
    }
    
    [self readFramesFromFile:(UInt32)mRemainingFramesInFile];
	
    mRemainingFramesInFile = 0;
	
}


-(id) initWithAudio:(NSString *)path{
    
    if (!(self=[super init])) return nil;
    if (!path) {
        NSLog(@"*** Error *** DlbAudioUnitPlayer init path is nil");
        mError = -1;
        return nil;
        
    }
    
    mStarted = NO;
    mError = 0;
	
	mFramesToReadIntoBuffer = 16384;  //4096*4
	
	mAudioUnitSampleData.mBufferCount = 3;
	mAudioUnitSampleData.mCurrentBufferIdx = 0;	
	mAudioUnitSampleData.mFreeBuffers = mAudioUnitSampleData.mBufferCount;
    mAudioUnitSampleData.mFramesReaded = 0;
    mAudioUnitSampleData.mPlayedFrames = 0;

	OSStatus result;
	
    //Get hardware sample rate that remote io audio unit needed, by default 44100.0
    AVAudioSession * session = [AVAudioSession sharedInstance];
    NSError *audioSessionError = nil;
    [session setActive:YES error:&audioSessionError];
    

    mHWChannels = session.maximumOutputNumberOfChannels;
    mHwSampleRate = session.sampleRate;
    

    result = ExtAudioFileOpenURL ((__bridge CFURLRef)[NSURL fileURLWithPath:path], &mAudioFile);
    if (noErr != checkStatus(result,"ExtAudioFileOpenURL failed")) {
        mError = -1;
        return nil;
    }
    
    //Get data format
    UInt32 szff = sizeof(mFileFormat);
    result = ExtAudioFileGetProperty(mAudioFile, kExtAudioFileProperty_FileDataFormat ,&szff,&mFileFormat);
    NSLog(@"AudioFile Channels:%d",(unsigned int)mFileFormat.mChannelsPerFrame);
    
    mAudioUnitSampleData.mAudioChannels = mFileFormat.mChannelsPerFrame;
    

    // Check the max channels
    if ( mAudioUnitSampleData.mAudioChannels > 8 )
        return nil;
    // iPhone supports only mono or stereo
    if ( mAudioUnitSampleData.mAudioChannels > 2 )
        mAudioUnitSampleData.mAudioChannels = 2;

    
    //Set remote io format
	UInt32 bytesPerSample = sizeof (SInt32);
    mOutputFormat.mFormatID = kAudioFormatLinearPCM;
    mOutputFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;//kAudioFormatFlagsAudioUnitCanonical;
    mOutputFormat.mChannelsPerFrame =  mAudioUnitSampleData.mAudioChannels;
    mOutputFormat.mFramesPerPacket = 1;
    mOutputFormat.mBitsPerChannel = 8 * bytesPerSample;
    mOutputFormat.mBytesPerPacket = mOutputFormat.mBytesPerFrame = bytesPerSample;
    // should be same as the hardware
    mOutputFormat.mSampleRate = mHwSampleRate;
	
	SInt64 fileFrames = 0;
	UInt32 size = sizeof (fileFrames);
	result = ExtAudioFileGetProperty(mAudioFile, kExtAudioFileProperty_FileLengthFrames,&size,&fileFrames);
    if (noErr != checkStatus(result,"ExtAudioFileGetProperty failed, get file frames")) {
	     mError = -1;
        return nil;
    }

	
	result = ExtAudioFileSetProperty(mAudioFile, kExtAudioFileProperty_ClientDataFormat,sizeof (mOutputFormat),&mOutputFormat);
    if (noErr != checkStatus(result,"ExtAudioFileSetProperty failed, set client format")) {
	    mError = -1;
        return nil;
    }
    
	SInt64 extAFSOffset = 0;
	result = ExtAudioFileTell(mAudioFile,&extAFSOffset);
    if (noErr != checkStatus(result,"ExtAudioFileTell failed")) {
	    mError = -1;
        return nil;
    }
	
	fileFrames = fileFrames - extAFSOffset;
	
	if (fileFrames <= mFramesToReadIntoBuffer) {
		mFramesToReadIntoBuffer = (UInt32)fileFrames;
	}
    
    mAudioUnitSampleData.mFramesPerBuffer = mFramesToReadIntoBuffer;
    
    mAudioUnitSampleData.mFileFrames = fileFrames;
	
	mRemainingFramesInFile = fileFrames;
    
    // sample rate conversion
    mAudioUnitSampleData.mConvertedFileFrames = fileFrames * (mHwSampleRate/mFileFormat.mSampleRate);

	
	mReadingIteras = floor(fileFrames / mFramesToReadIntoBuffer) - mAudioUnitSampleData.mBufferCount;
	
	//setup Remote IO Unit Player
	mError = [self setupRioAudioUnitPlayer];
	
    //Alloc the buffers
	for (int i = 0; i < mAudioUnitSampleData.mAudioChannels; ++i) {
        mAudioUnitSampleData.mAudioUnitSamples[i] = malloc(mAudioUnitSampleData.mBufferCount * sizeof(SInt32 *));
    }
	
	//alloc the audio sample buffer memory
	for (int i = 0; i < mAudioUnitSampleData.mBufferCount; ++i) {
        for (int ch = 0; ch < mAudioUnitSampleData.mAudioChannels; ++ch) {
		    mAudioUnitSampleData.mAudioUnitSamples[ch][i] = calloc (mFramesToReadIntoBuffer, sizeof (SInt32));
        }
	}
    
    mAudioBufferList = malloc(sizeof(AudioBufferList) +  mAudioUnitSampleData.mAudioChannels * sizeof(AudioBuffer));
    mAudioBufferList->mNumberBuffers = mAudioUnitSampleData.mAudioChannels;
    for (int ch = 0; ch < mAudioUnitSampleData.mAudioChannels; ++ch) {
        mAudioBufferList->mBuffers[ch].mData = mAudioUnitSampleData.mAudioUnitSamples[ch][0];
        mAudioBufferList->mBuffers[ch].mNumberChannels = mAudioUnitSampleData.mAudioChannels;
        mAudioBufferList->mBuffers[ch].mDataByteSize = mFramesToReadIntoBuffer * sizeof (SInt32);
        
    }
    
	[self startRioAudioUnitPlayer];
	
    return self;
    
}

-(int8_t)getPlayingStatus{
    
    if (mError < 0) {
        return mError;
    }
    
    return mStarted;
}

-(Float32)getCurrentPlaybackPos{

   if (mAudioUnitSampleData.mPlayedFrames >= mAudioUnitSampleData.mConvertedFileFrames) {
       return [self getFileDuration];
   }
    
   return mAudioUnitSampleData.mPlayedFrames/mHwSampleRate;
    
}

-(Float32)getFileDuration{
    return mAudioUnitSampleData.mFileFrames /mFileFormat.mSampleRate;
}

-(int8_t)setupRioAudioUnitPlayer{
	
	AudioComponentDescription rioUnitDesc;
	rioUnitDesc.componentType = kAudioUnitType_Output;
	rioUnitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
	rioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
	rioUnitDesc.componentFlags = 0;
	rioUnitDesc.componentFlagsMask = 0;

	AudioComponent comp = AudioComponentFindNext(NULL, &rioUnitDesc);

	if (noErr != checkStatus(AudioComponentInstanceNew(comp, &mRioAudioUnit),"AudioComponentInstanceNew failed, new RIO Unit"))
	    return -1;
	
    //Query the StreamFormat from the output
    AudioStreamBasicDescription mFormat;
    UInt32 size = sizeof(mFormat);
    OSStatus result = AudioUnitGetProperty(mRioAudioUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           0,
                                           &mFormat,
                                           &size);
    if (noErr != checkStatus(result,"Failed to set kAudioUnitProperty_StreamFormat"))
        return -1;
    
    NSLog(@"ChannelsPerFrame=%u", (unsigned int)mFormat.mChannelsPerFrame);
    mOutputFormat.mChannelsPerFrame =  mFormat.mChannelsPerFrame;
    
    if (mHWChannels > 2) {
        NSLog(@"mHWChannels:%lu", (unsigned long)mHWChannels);
        SInt32 *channelMap =NULL;
        UInt32 numOfChannels = mHWChannels;
        UInt32 mapSize = numOfChannels *sizeof(SInt32);

        channelMap = (SInt32 *)malloc(mapSize);

        //for each channel of desired input, map the channel from the device's output channel.
        for(UInt32 i=0; i<numOfChannels; i++)
        {
                channelMap[i] = -1;
        }

        //channelMap[0] = 0;
        //channelMap[1] = 1;
        //channelMap[2] = 2;
        //channelMap[3] = 3;
        //channelMap[4] = 4;
        //channelMap[5] = 5;
        //channelMap[6] = 6;
        //channelMap[7] = 5;
        
        result = AudioUnitSetProperty(mRioAudioUnit,
                                kAudioOutputUnitProperty_ChannelMap,
                                kAudioUnitScope_Input,
                                1,
                                channelMap,
                                mapSize);
        if (noErr != checkStatus(result,"Failed to set kAudioOutputUnitProperty_ChannelMap"))
            return -1;
        
        free(channelMap);
    }
    
	// Enable IO for playback
	UInt32 output = 1;
	result = AudioUnitSetProperty(mRioAudioUnit,
								  kAudioOutputUnitProperty_EnableIO, 
								  kAudioUnitScope_Output, 
								  0,
								  &output, 
								  sizeof(output));
	if (noErr != checkStatus(result,"AudioUnitSetProperty failed, enable output for RemoteIO Unit"))
	    return -1;
		
	// Set up the playback  callback
	AURenderCallbackStruct playCallbackStru;
	playCallbackStru.inputProc = playbackCallback;
	playCallbackStru.inputProcRefCon = &mAudioUnitSampleData;
	
	result = AudioUnitSetProperty(mRioAudioUnit, 
								  kAudioUnitProperty_SetRenderCallback, 
								  kAudioUnitScope_Global, 
								  0,
								  &playCallbackStru, 
								  sizeof(playCallbackStru));
	if (noErr != checkStatus(result,"AudioUnitSetProperty failed, set up RemoteIO callback function"))
	    return -1;
	
	result = AudioUnitSetProperty(mRioAudioUnit, 
                                kAudioUnitProperty_StreamFormat, 
                                kAudioUnitScope_Input, 
                                0, 
                                &mOutputFormat, 
                                sizeof(mOutputFormat));
								
	if (noErr != checkStatus(result,"AudioUnitSetProperty failed, set up RemoteIO stream format"))
	    return -1;
		
	result = AudioUnitInitialize(mRioAudioUnit);
	if (noErr != checkStatus(result,"AudioUnitSetProperty failed, initialize RemoteIO Unit"))
	    return -1;
    
    return 0;
	
}

-(void)startRioAudioUnitPlayer{

    void (^cycleFillBufferBlock)(void) = ^(void){
            [self cycleFillBufferFromFile];
            };
	
    mDispatchQueue = dispatch_queue_create("com.dolby.audiounitplayer.dispathqueue", NULL);
	
	mDispatchSourceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mDispatchQueue);
    dispatch_source_set_timer(mDispatchSourceTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.15 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(mDispatchSourceTimer,cycleFillBufferBlock);
    dispatch_resume(mDispatchSourceTimer);
        
    AudioOutputUnitStart(mRioAudioUnit);
    
    mStarted = YES;

}

-(void)stopPlayback{
    
    if (!mStarted)
        return;
	
    mStarted = NO;
    
	AudioOutputUnitStop(mRioAudioUnit);
    
    [[AVAudioSession sharedInstance] setActive:NO error:nil];

    dispatch_source_cancel(mDispatchSourceTimer);
    
    
    for (int i = 0; i < mAudioUnitSampleData.mBufferCount; ++i) {
        for (int ch = 0; ch < mAudioUnitSampleData.mAudioChannels; ++ch) {
            free(mAudioUnitSampleData.mAudioUnitSamples[ch][i]);
        }
    }

    
    for (int i = 0; i < mAudioUnitSampleData.mAudioChannels; ++i) {
        free(mAudioUnitSampleData.mAudioUnitSamples[i] );
    }
	
	if (mAudioBufferList != NULL) {
		free(mAudioBufferList);
        mAudioBufferList = 0;
    }
	
}

-(void)dealloc{
    
    NSLog(@"DLBAudioUnitPlayer dealloc.");
    
    if (mStarted ) {
        [self stopPlayback];
    }
    
}

@end
