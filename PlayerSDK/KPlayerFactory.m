//
//  KPlayerManager.m
//  KALTURAPlayerSDK
//
//  Created by Nissim Pardo on 3/16/15.
//  Copyright (c) 2015 Kaltura. All rights reserved.
//

#import "KPlayerFactory.h"
#import "KPLog.h"
#import "NSString+Utilities.h"
#ifdef IMA
#import "KPIMAPlayerViewController.h"
#endif
#import <MobileCoreServices/MobileCoreServices.h>  

@interface KPlayerFactory() <KPlayerDelegate>{
    NSString *key;
    BOOL isSeeked;
}

@property (nonatomic, strong) UIViewController *parentViewController;
#ifdef IMA
@property (nonatomic, strong) KPIMAPlayerViewController *adController;
#endif
@property (nonatomic) BOOL contentEnded;
@end

@implementation KPlayerFactory

- (instancetype)initWithPlayerClassName:(NSString *)className {
    self = [super init];
    if (self) {
        self.playerClassName = className;
        return self;
    }
    return nil;
}


- (void)addPlayerToController:(UIViewController *)parentViewController {
    _parentViewController = parentViewController;
    if (!self.player) {
        KPLogError(@"%@", @"NO PLAYER CREATED");
    } else if ([self.player respondsToSelector:@selector(setDRMKey:)]) {
        self.player.DRMKey = key;
//        self.player.DRMDict = @{@"WVDRMServerKey": key, @"WVPortalKey": @"kaltura"};
    }
}

- (id<KPlayer>)player {
    if (!_player) {
        Class class = NSClassFromString(_playerClassName);
        _player = [(id<KPlayer>)[class alloc] initWithParentView:_parentViewController.view];
        _player.delegate = self;
    }
    return _player;
}

- (NSString *)getMimeType:(NSURL * )mediaUrl {
    __block NSString *mimeType = nil;
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:mediaUrl]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               mimeType = [response MIMEType];
                           }];
    return mimeType;
}

- (NSArray *)getSortedPlayersList {
    
    return @[@"KPlayer",@"WVPlayer"];
}

- (void)setSrc:(NSString *)src {
//    NSString *mimeType = [self getMimeType:[NSURL URLWithString:src]];
//    NSArray *playersList = [self getSortedPlayersList];
    
//    Class className = NSClassFromString(@"WVPlayer");
//    [self removePlayer];
//    self.playerClassName = @"WVPlayer";
//    self.src = src;
    [self.player setPlayerSource:[NSURL URLWithString:src]];
//    
//    for (NSString *playerName in playersList) {
//        Class className = NSClassFromString(playerName);
//        SEL selector = @selector(isPlayableMIMEType:);
//        if ([className respondsToSelector:selector]) {
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//            BOOL isPlayable = [[className performSelector:selector withObject:mimeType] boolValue];
//            
//            if (isPlayable) {
//                self.playerClassName = playerName;
//                self.src = src;
//                [self.player setPlayerSource:[NSURL URLWithString:src]];
//            }
//#pragma clang diagnostic pop
//        }
//    }
}

- (void)setCurrentPlayBackTime:(NSTimeInterval)currentPlayBackTime {
    _player.currentPlaybackTime = currentPlayBackTime;
}

- (void)setAdTagURL:(NSString *)adTagURL {
#ifdef IMA
    if (!_adController) {
        _adController = [KPIMAPlayerViewController new];
        _adController.adPlayerHeight = _adPlayerHeight;
        _adController.locale = _locale;
        [_parentViewController addChildViewController:_adController];
        [_parentViewController.view addSubview:_adController.view];
        __weak KPlayerFactory *weakSelf = self;
        [_adController loadIMAAd:adTagURL
               withContentPlayer:_player
                  eventsListener:^(NSDictionary *adEventParams) {
                      if (adEventParams) {
                          [weakSelf.player.delegate player:weakSelf.player
                                                 eventName:adEventParams.allKeys.firstObject
                                                      JSON:adEventParams.allValues.firstObject];
                      } else if (weakSelf.contentEnded){
                          [weakSelf.delegate allAdsCompleted];
                      } else if (!adEventParams) {
                          [weakSelf.delegate allAdsCompleted];
                          [weakSelf.adController removeIMAPlayer];
                      }
                  }];
    }
#endif
}


- (void)switchPlayer:(NSString *)playerClassName key:(NSString *)_key {
    _playerClassName = playerClassName;
    key = _key;
}

- (void)changeSubtitleLanguage:(NSString *)isoCode {
    [_player changeSubtitleLanguage:isoCode];
}

- (void)removePlayer {
    [_player removePlayer];
    _player = nil;
#ifdef IMA
    [_adController removeIMAPlayer];
    _adController = nil;
#endif
}


#pragma mark KPlayerEventsDelegate
- (void)player:(id<KPlayer>)currentPlayer eventName:(NSString *)event value:(NSString *)value {
    static NSTimeInterval currentTime;

    if (key && currentPlayer.isKPlayer && (event.isPlay || event.isSeeked)) {
        currentTime = _player.currentPlaybackTime;
        [self removePlayer];
        [self addPlayerToController:_parentViewController];
        self.src = _src;
        isSeeked = event.isSeeked;
    } else if (!currentPlayer.isKPlayer && event.canPlay) {
        if (currentTime) {
            _player.currentPlaybackTime = currentTime;
        }
        if (!isSeeked) {
            [_player play];
        }
    } else {
        [_delegate player:currentPlayer eventName:event value:value];
    }
}

- (void)player:(id<KPlayer>)currentPlayer eventName:(NSString *)event JSON:(NSString *)jsonString {
    [_delegate player:currentPlayer eventName:event JSON:jsonString];
}

- (void)contentCompleted:(id<KPlayer>)currentPlayer {
    self.contentEnded = YES;
#ifdef IMA
    [_adController contentCompleted];
#endif
}

- (void)dealloc {
    KPLogInfo(@"Dealloc");
}

@end
