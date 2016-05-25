#import "DLBAudioQueuePlayer.h"

static UInt32 gBufferSizeBytes=0x10000;

@implementation DLBAudioQueuePlayer

//callback function for AudioQueueNewOutput
void AQOutputCallback(void * inUserData,
                      AudioQueueRef outAQ,
                      AudioQueueBufferRef outBuffer) {
                      
    //initial audio queue service with user data
    DLBAudioQueuePlayer *player = (__bridge DLBAudioQueuePlayer*)inUserData;
    
    
    UInt32 numBytes = gBufferSizeBytes;
    UInt32 numPackets=player->mNumPacketsToRead;
    
    //read packet from file
    OSStatus status = AudioFileReadPacketData(player->mAudioFile, NO, &numBytes, player->mPacketDescs, player->mPacketIndex,&numPackets, outBuffer->mAudioData);
    
    if (status != noErr && status != kAudioFileEndOfFileError) {
        return;
    }
    
    if (numPackets>0) {
        
        outBuffer->mAudioDataByteSize=numBytes;
        
        //send packet to audio queue
        status = AudioQueueEnqueueBuffer(outAQ, outBuffer, (player->mPacketDescs ? numPackets : 0 ), player->mPacketDescs);
        if (status != noErr) {
            NSLog(@"*** Error *** DLBAudioQueuePlayer - AudioQueueEnqueueBuffer failed,status=%d", (int)status);
        }
        
        player->mPacketIndex += numPackets;
    }
    
    //handle exceptions
    if (numPackets == 0 || status == kAudioFileEndOfFileError) {
        AudioQueueStop(outAQ,false);
        AudioFileClose(player->mAudioFile);
    }      
}

-(void)stopPlayback{    
    if (!mStarted)
        return;
    
    mStarted = NO;
    
    dispatch_queue_t sq = dispatch_queue_create("com.dolby.DLBAudioQueuePlayer", NULL);
    
    //stop playback asynchronously
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

//start playback with url
-(id) initWithAudio:(NSString *)path{
    
    if (!(self=[super init])) return nil;
    if (!path) {
        NSLog(@"*** Error *** DLBAudioQueuePlayer init path is nil");
        return nil;
        
    }
    
    UInt32 size;
    UInt32 maxPacketSize;
    char *cookie=nil;
    OSStatus status;
    
    mStarted = NO;
    
    //Open the audio file
    status=AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kAudioFileReadPermission, 0, &mAudioFile);
    if (status != noErr) {
        NSLog(@"*** Error *** DLBAudioQueuePlayer could not open audio file. Path was: %@", path);
        return nil;
    }
    
    //Get audio stream data format
    size = sizeof(mDataFormat);
    AudioFileGetProperty(mAudioFile, kAudioFilePropertyDataFormat, &size, &mDataFormat);
    
    //Create Audio Queue
    AudioQueueNewOutput(&mDataFormat, AQOutputCallback, (__bridge void *)(self),
                        nil, nil, 0, &mQueue);
    
    if (mDataFormat.mBytesPerPacket==0 || mDataFormat.mFramesPerPacket==0) {
        //in VBR case
        size=sizeof(maxPacketSize);
        AudioFileGetProperty(mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
        if (maxPacketSize > gBufferSizeBytes) {
            maxPacketSize= gBufferSizeBytes;
        }
        
        mNumPacketsToRead = gBufferSizeBytes/maxPacketSize;
        mPacketDescs=malloc(sizeof(AudioStreamPacketDescription)*mNumPacketsToRead);        
    }else {
        //in CBR case
        mNumPacketsToRead= gBufferSizeBytes/mDataFormat.mBytesPerPacket;
        mPacketDescs=NULL;
    }
    
    //Set Magic Cookie
    AudioFileGetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
    if (size >0) {
        cookie=malloc(sizeof(char)*size);
        AudioFileGetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
        AudioQueueSetProperty(mQueue, kAudioQueueProperty_MagicCookie, cookie, size);
        free(cookie);
    }
    
    //Set audio channel layout
    if (mDataFormat.mChannelsPerFrame > 2 ) {
        UInt32 sz = sizeof(UInt32);
        status = AudioFileGetProperty(mAudioFile, kAudioFilePropertyChannelLayout, &sz, NULL);
        if (noErr == status && sz > 0) {
            AudioChannelLayout *acl = malloc(sz);
            AudioFileGetProperty(mAudioFile, kAudioFilePropertyChannelLayout, &sz,acl);
            AudioQueueSetProperty(mQueue, kAudioQueueProperty_ChannelLayout, acl, sz);
            free(acl);
        }
    }
    
    //malloc buffer and read packages
    mPacketIndex=0;
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(mQueue, gBufferSizeBytes, &mBuffers[i]);
        AQOutputCallback((__bridge void *)self,mQueue,mBuffers[i]);
    }
    
    //Set volume [0,1],0:silence
    Float32 gain=1.0;
    AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, gain);
    
    AudioQueueStart(mQueue, NULL);
    
    mStarted = YES;
    
    return self;
}

//destruction
-(void)dealloc{
    
    NSLog(@"DLBAudioQueuePlayer dealloced!");
    
    if (mStarted ) {
        [self stopPlayback];
    }
}


@end
