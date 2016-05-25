#import "DLBAVAudioEngine.h"

AVAudioEngine *audioengine;
AVAudioPlayerNode *audioplayernode;

@implementation DLBAVAudioEngine

//start playback with URL that points to a Dolby Digital Plus encoded file
-(id) initWithAudio:(NSString *)path{
    
    if (!path) {
        NSLog(@"*** Error *** DLBAVAudioEngine init path is nil\n");
        return nil;
        
    }
    
    dispatch_queue_t stateChangeQueue = dispatch_queue_create("DLBAVAudioEngine.stateChangeQueue", DISPATCH_QUEUE_SERIAL);
    
    audioengine = [[AVAudioEngine alloc] init];
    
    audioplayernode = [[AVAudioPlayerNode alloc] init];
    
    [audioengine attachNode:audioplayernode];
    
    NSURL* url = [NSURL fileURLWithPath:path];
    
    NSError* file_error = nil;
    AVAudioFile* file = [[AVAudioFile alloc] initForReading:url error: &file_error];
    
    //build up audioengine pipeline
    [audioengine connect:audioplayernode to:audioengine.mainMixerNode format:file.processingFormat];
    
    NSError* audioSession_error = nil;
    //register an callback funtion for reporting error message
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioSession_error];
    
    dispatch_sync(stateChangeQueue, ^{
        //active audiosession
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        NSError *error = nil;
        BOOL success = [audioengine startAndReturnError:&error];
        NSAssert(success, @"%@", [error localizedDescription]);
        
        @try {
            //set file for audio source node and register a callback funtion for reaching the end of play
            [audioplayernode scheduleFile:file atTime:nil completionHandler:nil];
        } @catch (NSException *exception) {
            NSLog(@"*** Error *** DLBAVAudioEngine catch exception: %@%@\n", [exception name], [exception reason]);
            return;
        } @finally {
            //return;
        }
        
        [audioplayernode play];
    });
    
    return self;
    
}

//stop playback
-(void)stopPlayback{
    
    NSLog(@"DLBAVAudioEngine dealloced!");
    
    [audioplayernode stop];
    [audioengine stop];
    
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

@end
