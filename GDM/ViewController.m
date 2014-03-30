//
//  ViewController.m
//  GDM
//
//  Created by Daniel Farmer on 1/10/14.
//  Copyright (c) 2014 drayfar. All rights reserved.
//
//  This software is based on code written and shared by Matt Gallagher. The
//  code has been modified from the version accessed on Jan 12, 2014. The
//  original license is copied below:
//
//  Created by Matt Gallagher on 27/09/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import "ViewController.h"
#import "AudioStreamer.h"
#import "Reachability.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static const NSString *PlayerItemStatusContext;

@interface ViewController ()

@property AVAsset *asset;
@property AVPlayerItem *playerItem;
@property AVPlayer *player;
@property (nonatomic, strong) id itemEndObserver;
@property BOOL isPlaying;
@property BOOL shouldAutoplay;
@property NSDate *lastPaused;
@property BOOL isUsingWifi;
@property MPMediaItemArtwork *artwork;
@property NSTimer *statusTimer;

@end

@implementation ViewController

@synthesize playButton;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setNeedsStatusBarAppearanceUpdate];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:@"gdmEnterBackground" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(leaveBackground) name:@"gdmLeaveBackground" object:nil];
    
    [playButton setEnabled:NO];
    
    [self updateStatusWithTitle:@"Loading..." artist:@"GDM Radio"];
    
    self.mpVolumeViewParentView.backgroundColor = [UIColor clearColor];
    MPVolumeView *mpVolumeView = [[MPVolumeView alloc] initWithFrame:self.mpVolumeViewParentView.bounds];
    [self.mpVolumeViewParentView addSubview:mpVolumeView];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    self.shouldAutoplay = NO;
    self.isPlaying = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaServerWasResetNotification:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    Reachability * reach = [Reachability reachabilityWithHostname:@"icecast.gdmradio.com"];
    [reach startNotifier];
    
    self.artwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"AlbumImage"]];
    
    NSLog(@"%@", @"View controller setup completed successfully.");
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (void)didReceiveMemoryWarning
{
    if (!self.isPlaying) {
        [self resetPlayer];
    }
    
    [super didReceiveMemoryWarning];
}

- (IBAction)togglePlay:(id)sender {
    if (self.isPlaying) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)enterBackground {
    NSLog(@"%@", @"Entering background mode.");
    if (!self.isPlaying) {
        NSLog(@"%@", @"Nothing's playing, so resetting player.");
        [self resetPlayer];
    }
}

- (void)leaveBackground {
    NSLog(@"%@", @"Returning from background mode");
    [self prepareToPlay];
}

- (void)resetPlayer {
    if (self.player == nil) {
        return;
    }
    
    NSLog(@"%@", @"Resetting player.");
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
    if (self.isPlaying) {
        self.shouldAutoplay = YES;
    }
    [self pause];
    [self.asset cancelLoading];
    self.player = nil;
    self.playerItem = nil;
    self.asset = nil;
    [self.statusTimer invalidate];
    self.statusTimer = nil;
}

- (void)prepareToPlay {
    if (self.playerItem) {
        return;
    }
    
    [self updateStatusWithTitle:@"Loading..." artist:@"GDM Radio"];
    
    NSLog(@"%@", @"Preparing player.");
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    self.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"http://icecast.gdmradio.com:8000/128.mp3"]];
    
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.asset];
    
    [self.playerItem addObserver:self forKeyPath:@"status" options:0 context:&PlayerItemStatusContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStalledNotification:) name:AVPlayerItemPlaybackStalledNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedToPlayToEndNotification:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
	[self addItemEndObserverForPlayerItem:self.playerItem];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.allowsExternalPlayback = NO;
}

- (void)addItemEndObserverForPlayerItem:(AVPlayerItem *)playerItem {
	__weak id weakSelf = self;
	self.itemEndObserver = [[NSNotificationCenter defaultCenter]
                            addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                            object:playerItem queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification *notification)
                            {
                                [weakSelf pause];
                                [[weakSelf player] seekToTime:kCMTimeZero];
                            }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == &PlayerItemStatusContext) {
        if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
            [self.playerItem removeObserver:self forKeyPath:@"status" context:&PlayerItemStatusContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [self enablePlay];
                NSLog(@"%@", @"Player ready.");
                
                [self getStatus:nil];
                self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(getStatus:) userInfo:nil repeats:YES];
                
                if (self.shouldAutoplay && [self.lastPaused timeIntervalSinceNow] > -60) { // Don't autoplay if it's been more than 1 minute
                    NSLog(@"Autoplaying after %.2f seconds", -[self.lastPaused timeIntervalSinceNow]);
                    [self play];
                } else if (self.shouldAutoplay) {
                    NSLog(@"Didn't autoplay because interval %.2f was greater than 60 seconds", -[self.lastPaused timeIntervalSinceNow]);
                }
            });
        } else if (self.playerItem.status == AVPlayerItemStatusFailed) {
            [self.playerItem removeObserver:self forKeyPath:@"status" context:&PlayerItemStatusContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", @"Player item failed to load.");
                [self resetPlayer];
            });
        }
	}
}

- (void) enablePlay {
    [playButton setEnabled:YES];
}

- (void) disablePlay {
    [playButton setEnabled:NO];
}

- (void) pause {
    NSLog(@"%@", @"Pausing playback.");
    [self.player pause];
    self.isPlaying = NO;
    self.playButton.selected = NO;
    self.lastPaused = [NSDate date];
    
    [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(stop) userInfo:nil repeats:NO];
}

- (void) stop {
    if (self.isPlaying) {
        return;
    } else {
        [self resetPlayer];
    }
}

- (void) play {
    if (!self.playerItem) {
        self.shouldAutoplay = true;
        self.lastPaused = [NSDate date];
        [self prepareToPlay];
        return;
    }
    
    NSLog(@"Starting playback at %lld.", self.playerItem.currentTime.value);
    [self.player play];
    self.isPlaying = YES;
    self.playButton.selected = YES;
    self.shouldAutoplay = NO;
}

- (void) getStatus:(id)timer {
    NSURL *url = [NSURL URLWithString:@"http://cloudcast.gdmradio.com/service/status.json"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:4.0f];
    [request setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc]init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if ([data length] > 0 && connectionError == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self parseStatus:data];
            });
        }
    }];
}

- (void) parseStatus:(NSData *)data {
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (jsonObject != nil && error == nil) {
        NSString *title;
        NSMutableString *artist;
        @try {
            title = [jsonObject valueForKey:@"current_file_title"];
            artist = [[NSMutableString alloc]initWithString:[jsonObject valueForKey:@"current_file_artist"]];
        }
        @catch (NSException *exception) {
            title = @"GDM Radio";
            artist = [[NSMutableString alloc]initWithString:@"GDM Radio"];
        }
        
        if (title == nil) {
            title = @"GDM Radio";
        }
        
        if (artist == nil) {
            artist = [[NSMutableString alloc]initWithString:@"GDM Radio"];
        }
        
        [artist appendString:@" - GDM Radio"];
        
        [self updateStatusWithTitle:title artist:artist];
    } else if (error != nil) {
        NSLog(@"Error parsing status JSON: %@", error.localizedDescription);
    } else {
        NSLog(@"%@", @"Error parsing status JSON, no NSError object.");
    }
}

- (void) reachabilityChanged:(NSNotification *)notification {
    Reachability * reach = [notification object];

    if(![reach isReachable])
    {
        NSLog(@"%@", @"Network is unreachable.");
        [self setNetworkUnreachable];
    } else {
        NSLog(@"Network is reachable over %@.", [reach isReachableViaWiFi] ? @"wifi" : @"wwan");
        if ([reach isReachableViaWiFi] && !self.isUsingWifi) {
            [self resetPlayer]; // If we're not using wifi and it's available, reset the player to get it to connect via wifi.
            self.isUsingWifi = true;
        } else {
            self.isUsingWifi = false;
        }
        [self setNetworkReachable];
    }
}

- (void) updateStatusWithTitle:(NSString*)title artist:(NSString*)artist {
    self.titleLabel.text = title;
    self.artistLabel.text = artist;
    
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    
    if (playingInfoCenter) {
        MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
        NSDictionary *songInfo = [NSDictionary dictionaryWithObjectsAndKeys:artist, MPMediaItemPropertyArtist, title, MPMediaItemPropertyTitle, self.artwork, MPMediaItemPropertyArtwork, nil];
        center.nowPlayingInfo = songInfo;
    }
}

- (void) setNetworkUnreachable {
    [self resetPlayer];
    self.titleLabel.text = @"No internet connection.";
    self.artistLabel.text = @"Ensure Airplane Mode is disabled.";
}

- (void) setNetworkReachable {
    [self prepareToPlay];
}

- (void) remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause: {
                NSLog(@"%@", @"Remote Control Event Received: TogglePlayPause.");
                [self togglePlay:nil];
                break;
            }
            case UIEventSubtypeRemoteControlPlay: {
                NSLog(@"%@", @"Remote Control Event Received: Play.");
                [self play];
                break;
            }
            case UIEventSubtypeRemoteControlPause: {
                NSLog(@"%@", @"Remote Control Event Received: Pause.");
                [self pause];
                break;
            }
            default: {
                NSLog(@"%@", @"Other remote control event recieved, ignoring.");
                break;
            }
        }
    }
}

- (void) interruptionNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo != nil) {
        NSNumber *interruptionType = [userInfo objectForKey:AVAudioSessionInterruptionTypeKey];
        if ([interruptionType unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan) {
            NSLog(@"Interruption notification received: %lu.", (unsigned long)[interruptionType unsignedIntegerValue]);
            if (self.isPlaying) {
                [self pause];
                self.shouldAutoplay = YES;
            }
        } else {
            BOOL shouldResume = [[userInfo objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue] == AVAudioSessionInterruptionOptionShouldResume;
            NSLog(@"Interruption end notification received. Should resume: %d, should autoplay: %d.", shouldResume, self.shouldAutoplay);
            if (shouldResume && self.shouldAutoplay) {
                [self play];
            }
        }
    }
}

- (void) mediaServerWasResetNotification:(NSNotification *)notification {
    [self pause];
    self.shouldAutoplay = YES;
    [self prepareToPlay];
    NSLog(@"%@", @"Media server was reset, play resumed.");
}

- (void) playbackStalledNotification:(NSNotification *)notification {
    NSLog(@"%@", @"Playback stalled.");
    [self resetPlayer];
    [self prepareToPlay];
}

- (void) failedToPlayToEndNotification:(NSNotification *)notification {
    NSLog(@"%@", @"Playback failed to play to end.");
    [self resetPlayer];
    [self prepareToPlay];
}

@end
