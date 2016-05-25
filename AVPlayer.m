- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.mShownImage setImage:getImage()];
    [self.mProgressStatusLabel setText:@"0.00:0.00"];
    [self.mShowName setText:self.selectedItem.filename];
    mCurSeconds = 0.0;
    mDuration = 0.0;
    
    if ([self.selectedItem.module isEqual: @"AVPlayer"]){
	
		//Creates an instance of AVAsset URL that points the Dolby Digital Plus (E-AC3) encoded file
        NSURL *movieURL = [[NSBundle mainBundle] URLForResource:self.selectedItem.filename withExtension:self.selectedItem.extension];
        AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:movieURL options:nil];
		
		//Create an AVPlayerItem with a pointer to the Asset to play
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
        player = [AVPlayer playerWithPlayerItem:playerItem];
		
		//Create a player layer to direct the video content
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        playerLayer.frame = self.view.layer.bounds;
		
		//Attach layer into layer hierarchy 
        [self.view.layer addSublayer:playerLayer];
		
		//Play the audio/video content
        [player play];
        
        mDuration = CMTimeGetSeconds(movieAsset.duration);
        
    }