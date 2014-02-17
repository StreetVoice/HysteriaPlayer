//
//  HysteriaPlayer.m
//
//  Created by saiday on 13/1/8.
//
//

#import "HysteriaPlayer.h"
#import <AudioToolbox/AudioSession.h>
#import <objc/runtime.h>

static const void *Hysteriatag = &Hysteriatag;

@interface HysteriaPlayer ()
{
    BOOL routeChangedWhilePlaying;
    BOOL interruptedWhilePlaying;
    
    NSUInteger CHECK_AvoidPreparingSameItem;
    NSUInteger items_count;
    
    UIBackgroundTaskIdentifier bgTaskId;
    UIBackgroundTaskIdentifier removedId;
    
    dispatch_queue_t HBGQueue;
    
    Failed _failed;
    ReadyToPlay _readyToPlay;
    SourceAsyncGetter _sourceAsyncGetter;
    SourceSyncGetter _sourceSyncGetter;
    PlayerRateChanged _playerRateChanged;
    CurrentItemChanged _currentItemChanged;
    CurrentItemPreLoaded _currentItemPreLoaded;
    PlayerDidReachEnd _playerDidReachEnd;
}

@property (nonatomic, strong, readwrite) NSMutableArray *playerItems;
@property (nonatomic, readwrite) BOOL isInEmptySound;

/*
 * Private
 */

@property (nonatomic, strong) AVQueuePlayer *audioPlayer;
@property (nonatomic) BOOL PAUSE_REASON_ForcePause;
@property (nonatomic) BOOL PAUSE_REASON_Buffering;
@property (nonatomic) BOOL isPreBuffered;
@property (nonatomic) BOOL tookAudioFocus;
@property (nonatomic) PlayerRepeatMode repeatMode;
@property (nonatomic) PlayerShuffleMode shuffleMode;
@property (nonatomic) HysteriaPlayerStatus hysteriaPlayerStatus;
@property (nonatomic, strong) NSMutableSet *playedItems;

- (void)longTimeBufferBackground;
- (void)longTimeBufferBackgroundCompleted;
- (void)setHysteriaOrder:(AVPlayerItem *)item Key:(NSNumber *)order;

@end

@implementation HysteriaPlayer
@synthesize audioPlayer, playerItems, PAUSE_REASON_ForcePause, PAUSE_REASON_Buffering, isInEmptySound, isPreBuffered;


static HysteriaPlayer *sharedInstance = nil;
static dispatch_once_t onceToken;

#pragma mark -
#pragma mark ===========  Initialization, Setup  =========
#pragma mark -

+ (HysteriaPlayer *)sharedInstance {
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

+ (void)showAlertWithError:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Player errors"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
    [alert show];
}

- (id)init {
    self = [super init];
    if (self) {
        HBGQueue = dispatch_queue_create("com.hysteria.queue", NULL);
        playerItems = [NSMutableArray array];
        
        _repeatMode = RepeatMode_off;
        _shuffleMode = ShuffleMode_off;
        _hysteriaPlayerStatus = HysteriaPlayerStatusUnknown;
        
        _failed = nil;
        _readyToPlay = nil;
        _sourceAsyncGetter = nil;
        _sourceSyncGetter = nil;
        _playerRateChanged = nil;
        _playerDidReachEnd = nil;
        _currentItemChanged = nil;
        _currentItemPreLoaded = nil;
    }
    
    return self;
}

- (void)preAction
{
    self.tookAudioFocus = YES;
    
    [self backgroundPlayable];
    [self playEmptySound];
    [self AVAudioSessionNotification];
}

-(void)registerHandlerPlayerRateChanged:(PlayerRateChanged)playerRateChanged CurrentItemChanged:(CurrentItemChanged)currentItemChanged PlayerDidReachEnd:(PlayerDidReachEnd)playerDidReachEnd
{
    _playerRateChanged = playerRateChanged;
    _currentItemChanged = currentItemChanged;
    _playerDidReachEnd = playerDidReachEnd;
}

- (void)registerHandlerCurrentItemPreLoaded:(CurrentItemPreLoaded)currentItemPreLoaded
{
    _currentItemPreLoaded = currentItemPreLoaded;
}

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay
{
    _readyToPlay = readyToPlay;
}

-(void)registerHandlerFailed:(Failed)failed
{
    _failed = failed;
}

- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSUInteger)count
{
    if (_sourceAsyncGetter != nil)
        _sourceAsyncGetter = nil;
    
    _sourceSyncGetter = itemBlock;
    items_count = count;
}

- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSUInteger)count
{
    if (_sourceSyncGetter != nil)
        _sourceSyncGetter = nil;
    
    _sourceAsyncGetter = asyncBlock;
    items_count = count;
}

- (void)setItemsCount:(NSUInteger)count
{
    items_count = count;
}

- (void)playEmptySound
{
    //play .1 sec empty sound
    NSString *filepath = [[NSBundle mainBundle]pathForResource:@"point1sec" ofType:@"mp3"];
    if ([[NSFileManager defaultManager]fileExistsAtPath:filepath]) {
        isInEmptySound = YES;
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filepath]];
        audioPlayer = [AVQueuePlayer queuePlayerWithItems:[NSArray arrayWithObject:playerItem]];
    }
}

- (void)backgroundPlayable
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    if (audioSession.category != AVAudioSessionCategoryPlayback) {
        UIDevice *device = [UIDevice currentDevice];
        if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
            if (device.multitaskingSupported) {
                
                NSError *aError = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayback error:&aError];
                if (aError) {
                    NSLog(@"set category error:%@",[aError description]);
                }
                aError = nil;
                [audioSession setActive:YES error:&aError];
                if (aError) {
                    NSLog(@"set active error:%@",[aError description]);
                }
                //audioSession.delegate = self;
            }
        }
    }else {
        NSLog(@"unable to register background playback");
    }
    
    [self longTimeBufferBackground];
}

/*
 * Tells OS this application starts one or more long-running tasks, should end background task when completed.
 */
-(void)longTimeBufferBackground
{
    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:removedId];
        bgTaskId = UIBackgroundTaskInvalid;
    }];
    
    if (bgTaskId != UIBackgroundTaskInvalid && removedId == 0 ? YES : (removedId != UIBackgroundTaskInvalid)) {
        [[UIApplication sharedApplication] endBackgroundTask: removedId];
    }
    removedId = bgTaskId;
}

-(void)longTimeBufferBackgroundCompleted
{
    if (bgTaskId != UIBackgroundTaskInvalid && removedId != bgTaskId) {
        [[UIApplication sharedApplication] endBackgroundTask: bgTaskId];
        removedId = bgTaskId;
    }
    
}

#pragma mark -
#pragma mark ===========  Runtime AssociatedObject  =========
#pragma mark -

- (void)setHysteriaOrder:(AVPlayerItem *)item Key:(NSNumber *)order {
    objc_setAssociatedObject(item, Hysteriatag, order, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)getHysteriaOrder:(AVPlayerItem *)item {
    return objc_getAssociatedObject(item, Hysteriatag);
}

#pragma mark -
#pragma mark ===========  AVAudioSession Notifications  =========
#pragma mark -

- (void)AVAudioSessionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interruption:)
                                                 name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    [audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
}

#pragma mark -
#pragma mark ===========  Player Methods  =========
#pragma mark -

- (void) fetchAndPlayPlayerItem: (NSUInteger )startAt
{
    if (!self.tookAudioFocus)
        [self preAction];
    
    BOOL findInPlayerItems = NO;
    
    [audioPlayer pause];
    [audioPlayer removeAllItems];
    
    // if in shuffle mode, record played songs.
    if (_playedItems)
        [self recordPlayedItems:startAt];
    
    findInPlayerItems = [self findSourceInPlayerItems:startAt];
    
    if (!findInPlayerItems) {
        NSAssert((_sourceSyncGetter != nil) || (_sourceAsyncGetter != nil),
                 @"please using setupSourceGetter:ItemsCount: to setup your datasource");
        if (_sourceSyncGetter != nil)
            [self getAndInsertMediaSource:startAt];
        else if (_sourceAsyncGetter != nil)
            _sourceAsyncGetter(startAt);
    }
}

- (void)getAndInsertMediaSource:(NSUInteger)index
{
    dispatch_async(HBGQueue, ^{
        NSAssert(items_count > 0, @"your items count is zero, please check setupWithGetterBlock: or setItemsCount:");
        [self setupPlayerItem:_sourceSyncGetter(index) Order:index];
    });
}

- (void)setupPlayerItem:(NSString *)url Order:(NSUInteger)index
{
    [self setupPlayerItemWithUrl:[NSURL URLWithString:url] Order:index];
}

- (void)setupPlayerItemWithUrl:(NSURL *)url Order:(NSUInteger)index
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    if (!item)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:index]];
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [playerItems addObject:item];
        [self insertPlayerItem:item];
    });
}


- (BOOL)findSourceInPlayerItems:(NSUInteger)index
{
    for (AVPlayerItem *item in playerItems) {
        NSInteger checkIndex = [[self getHysteriaOrder:item] integerValue];
        if (checkIndex == index) {
            [item seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                [self insertPlayerItem:item];
            }];
            return YES;
        }
    }
    return NO;
}

- (void) recordPlayedItems:(NSUInteger)order
{
    [_playedItems addObject:[NSNumber numberWithInteger:order]];
    
    if ([_playedItems count] == items_count)
        _playedItems = [NSMutableSet set];
}

- (void) prepareNextPlayerItem
{
    // check before added, prevent add the same songItem
    NSNumber *CHECK_Order = [self getHysteriaOrder:audioPlayer.currentItem];
    NSUInteger nowIndex = [CHECK_Order integerValue];
    BOOL findInPlayerItems = NO;
    
    if (CHECK_Order) {
        if (_shuffleMode == ShuffleMode_on || _repeatMode == RepeatMode_one) {
            return;
        }
        if (nowIndex + 1 < items_count) {
            findInPlayerItems = [self findSourceInPlayerItems:nowIndex +1];
            
            if (!findInPlayerItems) {
                if (_sourceSyncGetter != nil)
                    [self getAndInsertMediaSource:nowIndex + 1];
                else if (_sourceAsyncGetter != nil)
                    _sourceAsyncGetter(nowIndex + 1);
            }
        }else if (items_count > 1){
            if (_repeatMode == RepeatMode_on) {
                findInPlayerItems = [self findSourceInPlayerItems:0];
                if (!findInPlayerItems) {
                    if (_sourceSyncGetter != nil)
                        [self getAndInsertMediaSource:0];
                    else if (_sourceAsyncGetter != nil)
                        _sourceAsyncGetter(0);
                }
            }
        }
    }
}

- (void)insertPlayerItem:(AVPlayerItem *)item
{
    if ([audioPlayer.items count] > 1) {
        for (int i = 1 ; i < [audioPlayer.items count] ; i ++) {
            [audioPlayer removeItem:[audioPlayer.items objectAtIndex:i]];
        }
    }
    if ([audioPlayer canInsertItem:item afterItem:nil]) {
        [audioPlayer insertItem:item afterItem:nil];
    }
}

- (void)removeAllItems
{
    for (AVPlayerItem *obj in playerItems) {
        [obj seekToTime:kCMTimeZero];
        [obj removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
        [obj removeObserver:self forKeyPath:@"status" context:nil];
    }
    
    [playerItems removeAllObjects];
    [audioPlayer removeAllItems];
}

- (void)removeQueuesAtPlayer
{
    while (audioPlayer.items.count > 1) {
        [audioPlayer removeItem:[audioPlayer.items objectAtIndex:1]];
    }
}

- (void)removeItemAtIndex:(NSUInteger)order
{
    for (AVPlayerItem *item in [NSArray arrayWithArray:playerItems]) {
        NSUInteger CHECK_order = [[self getHysteriaOrder:item] integerValue];
        if (CHECK_order == order) {
            [playerItems removeObject:item];
            
            if ([audioPlayer.items indexOfObject:item] != NSNotFound) {
                [audioPlayer removeItem:item];
            }
        }else if (CHECK_order > order){
            [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:CHECK_order -1]];
        }
    }
    
    items_count --;
}

- (void)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to
{
    for (AVPlayerItem *item in playerItems) {
        NSUInteger CHECK_index = [[self getHysteriaOrder:item] integerValue];
        if (CHECK_index == from || CHECK_index == to) {
            NSNumber *replaceOrder = CHECK_index == from ? [NSNumber numberWithInteger:to] : [NSNumber numberWithInteger:from];
            [self setHysteriaOrder:item Key:replaceOrder];
        }
    }
}

- (void)seekToTime:(double)seconds
{
    [audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
}

- (void)seekToTime:(double)seconds withCompletionBlock:(void (^)(BOOL))completionBlock
{
    [audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        if (completionBlock) {
            completionBlock(finished);
        }
    }];
}

- (AVPlayerItem *)getCurrentItem
{
    return [audioPlayer currentItem];
}

- (void)play
{
    [audioPlayer play];
}

- (void)pause
{
    [audioPlayer pause];
}

- (void)playNext
{
    if (_shuffleMode == ShuffleMode_on) {
        [self fetchAndPlayPlayerItem:[self getRandomSong]];
    } else {
        NSInteger nowIndex = [[self getHysteriaOrder:audioPlayer.currentItem] integerValue];
        if (nowIndex + 1 < items_count) {
            [self fetchAndPlayPlayerItem:(nowIndex + 1)];
        } else {
            if (_repeatMode == RepeatMode_off) {
                [self pausePlayerForcibly:YES];
                if (_playerDidReachEnd != nil)
                    _playerDidReachEnd();
            }
            [self fetchAndPlayPlayerItem:0];
        }
    }
}

- (void)playPrevious
{
    NSInteger nowIndex = [[self getHysteriaOrder:audioPlayer.currentItem] integerValue];
    if (nowIndex == 0)
    {
        if (_repeatMode == RepeatMode_on) {
            [self fetchAndPlayPlayerItem:items_count - 1];
        } else {
            [audioPlayer.currentItem seekToTime:kCMTimeZero];
        }
    } else {
        [self fetchAndPlayPlayerItem:(nowIndex - 1)];
    }
}

- (CMTime)playerItemDuration
{
    NSError *err = nil;
    if ([audioPlayer.currentItem.asset statusOfValueForKey:@"duration" error:&err] == AVKeyValueStatusLoaded) {
        AVPlayerItem *playerItem = [audioPlayer currentItem];
        NSArray *loadedRanges = playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0)
        {
            CMTimeRange range = [[loadedRanges objectAtIndex:0] CMTimeRangeValue];
            //Float64 duration = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
            return (range.duration);
        }else {
            return (kCMTimeInvalid);
        }
    } else {
        return (kCMTimeInvalid);
    }
}

- (void)setPlayerRepeatMode:(PlayerRepeatMode)mode
{
    switch (mode) {
        case RepeatMode_off:
            _repeatMode = RepeatMode_off;
            break;
        case RepeatMode_on:
            _repeatMode = RepeatMode_on;
            break;
        case RepeatMode_one:
            _repeatMode = RepeatMode_one;
            break;
        default:
            break;
    }
}

- (PlayerRepeatMode)getPlayerRepeatMode
{
    switch (_repeatMode) {
        case RepeatMode_one:
            return RepeatMode_one;
            break;
        case RepeatMode_on:
            return RepeatMode_on;
            break;
        case RepeatMode_off:
            return RepeatMode_off;
            break;
        default:
            return RepeatMode_off;
            break;
    }
}

- (void)setPlayerShuffleMode:(PlayerShuffleMode)mode
{
    switch (mode) {
        case ShuffleMode_off:
            _shuffleMode = ShuffleMode_off;
            [_playedItems removeAllObjects];
            _playedItems = nil;
            break;
        case ShuffleMode_on:
            _shuffleMode = ShuffleMode_on;
            _playedItems = [NSMutableSet set];
            [self recordPlayedItems:[[self getHysteriaOrder:audioPlayer.currentItem] integerValue]];
            break;
        default:
            break;
    }
}

- (PlayerShuffleMode)getPlayerShuffleMode
{
    switch (_shuffleMode) {
        case ShuffleMode_on:
            return ShuffleMode_on;
            break;
        case ShuffleMode_off:
            return ShuffleMode_off;
            break;
        default:
            return ShuffleMode_off;
            break;
    }
}

- (void)pausePlayerForcibly:(BOOL)forcibly
{
    if (forcibly)
        PAUSE_REASON_ForcePause = YES;
    else
        PAUSE_REASON_ForcePause = NO;
}
#pragma mark -
#pragma mark ===========  Player info  =========
#pragma mark -

- (BOOL)isPlaying
{
    if (!isInEmptySound)
        return [audioPlayer rate] != 0.f;
    else
        return NO;
}

- (HysteriaPlayerStatus)getHysteriaPlayerStatus
{
    if ([self isPlaying])
        return HysteriaPlayerStatusPlaying;
    else if (PAUSE_REASON_ForcePause)
        return HysteriaPlayerStatusForcePause;
    else if (PAUSE_REASON_Buffering)
        return HysteriaPlayerStatusBuffering;
    else
        return HysteriaPlayerStatusUnknown;
}

- (float)getPlayerRate
{
    return audioPlayer.rate;
}

- (NSDictionary *)getPlayerTime
{
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:0.0], HYSTERIAPLAYER_CURRENT_TIME, [NSNumber numberWithDouble:0.0], HYSTERIAPLAYER_DURATION_TIME, nil];
    }
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration)) {
		double time = CMTimeGetSeconds([audioPlayer currentTime]);
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:time], HYSTERIAPLAYER_CURRENT_TIME, [NSNumber numberWithDouble:duration], HYSTERIAPLAYER_DURATION_TIME, nil];
	} else {
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:0.0], HYSTERIAPLAYER_CURRENT_TIME, [NSNumber numberWithDouble:0.0], HYSTERIAPLAYER_DURATION_TIME, nil];
    }
}

#pragma mark -
#pragma mark ===========  Interruption, Route changed  =========
#pragma mark -

- (void)interruption:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSUInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (interuptionType == AVAudioSessionInterruptionTypeBegan && !PAUSE_REASON_ForcePause) {
        interruptedWhilePlaying = YES;
        [self pausePlayerForcibly:YES];
        [self pause];
    } else if (interuptionType == AVAudioSessionInterruptionTypeEnded && interruptedWhilePlaying) {
        interruptedWhilePlaying = NO;
        [self pausePlayerForcibly:NO];
        [self play];
    }
    NSLog(@"HysteriaPlayer interruption: %@", interuptionType == AVAudioSessionInterruptionTypeBegan ? @"began" : @"end");
}

- (void)routeChange:(NSNotification *)notification
{
    NSDictionary *routeChangeDict = notification.userInfo;
    NSUInteger routeChangeType = [[routeChangeDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    if (routeChangeType == AVAudioSessionRouteChangeReasonOldDeviceUnavailable && !PAUSE_REASON_ForcePause) {
        routeChangedWhilePlaying = YES;
        [self pausePlayerForcibly:YES];
    } else if (routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable && routeChangedWhilePlaying) {
        routeChangedWhilePlaying = NO;
        [self pausePlayerForcibly:NO];
        [self play];
    }
    NSLog(@"HysteriaPlayer routeChanged: %@", routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable ? @"New Device Available" : @"Old Device Unavailable");
}

#pragma mark -
#pragma mark ===========  KVO  =========
#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == audioPlayer && [keyPath isEqualToString:@"status"]) {
        if (audioPlayer.status == AVPlayerStatusReadyToPlay) {
            if (_readyToPlay != nil) {
                _readyToPlay(HysteriaPlayerReadyToPlayPlayer);
            }
            if (![self isPlaying]) {
                [audioPlayer play];
            }
        } else if (audioPlayer.status == AVPlayerStatusFailed) {
            NSLog(@"%@",audioPlayer.error);
            
            if (self.showErrorMessages)
                [HysteriaPlayer showAlertWithError:audioPlayer.error];
            
            if (_failed != nil) {
                _failed(HysteriaPlayerFailedPlayer, audioPlayer.error);
            }
        }
    }
    
    if(object == audioPlayer && [keyPath isEqualToString:@"rate"]){
        if (!isInEmptySound && _playerRateChanged)
            _playerRateChanged();
        else if (isInEmptySound && [audioPlayer rate] == 0.f)
            isInEmptySound = NO;
    }
    
    if(object == audioPlayer && [keyPath isEqualToString:@"currentItem"]){
        if (_currentItemChanged != nil) {
            AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
            if (newPlayerItem != (id)[NSNull null])
                _currentItemChanged(newPlayerItem);
        }
    }
    
    if (object == audioPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        isPreBuffered = NO;
        if (audioPlayer.currentItem.status == AVPlayerItemStatusFailed) {
            if (self.showErrorMessages)
                [HysteriaPlayer showAlertWithError:audioPlayer.currentItem.error];

            if (_failed)
                _failed(HysteriaPlayerFailedCurrentItem, audioPlayer.currentItem.error);
        }else if (audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            if (_readyToPlay != nil) {
                _readyToPlay(HysteriaPlayerReadyToPlayCurrentItem);
            }
            if (![self isPlaying] && !PAUSE_REASON_ForcePause) {
                [audioPlayer play];
            }
        }
    }
    
    if (audioPlayer.items.count > 1 && object == [audioPlayer.items objectAtIndex:1] && [keyPath isEqualToString:@"loadedTimeRanges"])
        isPreBuffered = YES;
    
    if(object == audioPlayer.currentItem && [keyPath isEqualToString:@"loadedTimeRanges"]){
        if (audioPlayer.currentItem.hash != CHECK_AvoidPreparingSameItem) {
            [self prepareNextPlayerItem];
            CHECK_AvoidPreparingSameItem = audioPlayer.currentItem.hash;
        }
        
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange=[[timeRanges objectAtIndex:0]CMTimeRangeValue];
            
            if (_currentItemPreLoaded)
                _currentItemPreLoaded(CMTimeAdd(timerange.start, timerange.duration));
            
            
            if (audioPlayer.rate == 0 && !PAUSE_REASON_ForcePause) {
                PAUSE_REASON_Buffering = YES;
                
                [self longTimeBufferBackground];
                
                CMTime bufferdTime = CMTimeAdd(timerange.start, timerange.duration);
                CMTime milestone = CMTimeAdd(audioPlayer.currentTime, CMTimeMakeWithSeconds(5.0f, timerange.duration.timescale));
                
                if (CMTIME_COMPARE_INLINE(bufferdTime , >, milestone) && audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay && !interruptedWhilePlaying && !routeChangedWhilePlaying) {
                    if (![self isPlaying]) {
                        NSLog(@"resume from buffering..");
                        PAUSE_REASON_Buffering = NO;
                        
                        [audioPlayer play];
                        [self longTimeBufferBackgroundCompleted];
                    }
                }
            }
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    NSNumber *CHECK_Order = [self getHysteriaOrder:audioPlayer.currentItem];
    if (CHECK_Order) {
        if (_repeatMode == RepeatMode_one) {
            NSInteger currentIndex = [CHECK_Order integerValue];
            [self fetchAndPlayPlayerItem:currentIndex];
        } else if (_shuffleMode == ShuffleMode_on){
            [self fetchAndPlayPlayerItem:[self getRandomSong]];
        } else {
            if (audioPlayer.items.count == 1 || !isPreBuffered) {
                NSInteger nowIndex = [CHECK_Order integerValue];
                if (nowIndex + 1 < items_count) {
                    [self playNext];
                } else {
                    if (_repeatMode == RepeatMode_off) {
                        [self pausePlayerForcibly:YES];
                        if (_playerDidReachEnd != nil)
                            _playerDidReachEnd();
                    }
                    [self fetchAndPlayPlayerItem:0];
                }
            }
        }
    }
}

- (NSUInteger)getRandomSong
{
    NSUInteger index;
    do {
        index = arc4random() % items_count;
    } while ([_playedItems containsObject:[NSNumber numberWithInteger:index]]);
    
    return index;
}

#pragma mark -
#pragma mark ===========   Deprecation  =========
#pragma mark -

- (void)deprecatePlayer
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [audioPlayer removeObserver:self forKeyPath:@"status" context:nil];
    [audioPlayer removeObserver:self forKeyPath:@"rate" context:nil];
    [audioPlayer removeObserver:self forKeyPath:@"currentItem" context:nil];
    
    [self removeAllItems];
    
    _failed = nil;
    _readyToPlay = nil;
    _sourceAsyncGetter = nil;
    _sourceSyncGetter = nil;
    _playerRateChanged = nil;
    _playerDidReachEnd = nil;
    _currentItemChanged = nil;
    _currentItemPreLoaded = nil;
    
    [audioPlayer pause];
    audioPlayer = nil;
    
    onceToken = 0;
}

#pragma mark -
#pragma mark ===========   Memory cached  =========
#pragma mark -

- (BOOL) isMemoryCached
{
    return (playerItems == nil);
}

- (void) enableMemoryCached:(BOOL)isMemoryCached
{
    if (playerItems == nil && isMemoryCached) {
        playerItems = [NSMutableArray array];
    }else if (playerItems != nil && !isMemoryCached){
        playerItems = nil;
    }
}

#pragma mark -
#pragma mark ===========   Deprecated Methods  =========
#pragma mark -

- (id)initWithHandlerPlayerReadyToPlay:(PlayerReadyToPlay)playerReadyToPlay PlayerRateChanged:(PlayerRateChanged)playerRateChanged CurrentItemChanged:(CurrentItemChanged)currentItemChanged ItemReadyToPlay:(ItemReadyToPlay)itemReadyToPlay PlayerPreLoaded:(PlayerPreLoaded)playerPreLoaded PlayerFailed:(PlayerFailed)playerFailed PlayerDidReachEnd:(PlayerDidReachEnd)playerDidReachEnd
{
    return nil;
}

- (HysteriaPlayerStatus)pauseReason
{
    return [self getHysteriaPlayerStatus];
}

- (void)setupWithGetterBlock:(SourceItemGetter)itemBlock ItemsCount:(NSUInteger)count
{
    NSLog(@"this method is deprecated, use setupSourceGetter:ItemsCount: instead");
}

#pragma mark -
#pragma mark ===========   iOS 5 under Interruption  =========
#pragma mark -

//   iOS6 deprecated!
//- (void)beginInterruption
//{
//    if ([self isPlaying]) {
//        manul_pause = YES;
//        [player pause];
//        interruptedWhilePlaying = YES;
//        NSLog(@"begin interrupting");
//    }
//}

//- (void)endInterruption
//{
//    NSLog(@"end interrupitng");
//
//    if (interruptedWhilePlaying) {
//        double delayInSeconds = 2.0;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds  *NSEC_PER_SEC);
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//            NSError *activationError = nil;
//            [[AVAudioSession sharedInstance]setActive:YES error:&activationError];
//            if (activationError != nil) {
//                NSLog(@"unable to resume playback after interruption");
//                NSLog(@"%@",activationError.description);
//
//                interruptedWhilePlaying = NO;
//                manul_pause = NO;
//                [player play];
//
//            }else {
//                NSLog(@"resume from interrtuption");
//                interruptedWhilePlaying = NO;
//                manul_pause = NO;
//                [player play];
//            }
//        });
//
//    }
//
//}
@end