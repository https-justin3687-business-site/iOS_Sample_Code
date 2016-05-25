@implementation DLBAVAudioPlayer

-(id) initWithAudio:(NSString *)path{
    
    if (!path) {
        NSLog(@"*** Error *** DLBAVAudioPlayer init path is nil\n");
        return nil;
    }
    
    mError = 0;
    
	//Creates an audio player with the URL pointing to the Dolby Digital Plus (E-AC3) file 
    audioplayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
	
	//Play the audio content
    [audioplayer play];
    
    mStarted = YES;
    mEnd = NO;
    
    return self;
    
}