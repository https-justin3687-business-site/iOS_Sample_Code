//
//  DLBAVPlayer.m
//  TestApp
//
//  Created by Tianlei on 2/18/16.
//  Copyright © 2016 Dolby. All rights reserved.
//

#import "DLBAVPlayer.h"

@implementation DLBAVPlayer

-(id) initWithPath:(NSString *)path{
    
    if (!(self=[super init])) return nil;
    if (!path) {
        NSLog(@"*** Error *** DLBAVPlayer init path is nil\n");
        return nil;
    }
/*
    //NSURL *movieURL = [[NSBundle mainBundle] URLForResource:@"2ch_dd_audio" withExtension:@"mp4"];
    NSURL *movieURL = [NSURL fileURLWithPath:path];
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:movieURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.frame = self.view.layer.bounds;
    
    [self.view.layer addSublayer:playerLayer];
    [player play];
*/    
    return self;
    
}

@end
