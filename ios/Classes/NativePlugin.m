#import "NativePlugin.h"
#import "FLNativeView.h"
#import "PlayerView.h"

#import <AVKit/AVKit.h>
#import <Flutter/Flutter.h>

@interface NativePlugin ()

@property(nonatomic, strong) NSMutableArray *_Nonnull pipContentViewArray;

@end

@implementation NativePlugin

+ (void)updateAudioSession {
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *categoryError = nil;
  if (@available(iOS 14.5, *)) {
    [audioSession
        setCategory:AVAudioSessionCategoryPlayback
               mode:AVAudioSessionModeMoviePlayback
            options:
                AVAudioSessionCategoryOptionOverrideMutedMicrophoneInterruption
              error:&categoryError];
  } else {
    // Fallback on earlier versions
  }
  if (categoryError) {
    NSLog(@"Set audio session category error: %@",
          categoryError.localizedDescription);
  }
  NSError *activeError = nil;
  [audioSession setActive:YES error:&activeError];
  if (activeError) {
    NSLog(@"Set audio session active error: %@",
          activeError.localizedDescription);
  }
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // PiP 所需的 session 在 createPipContentView 时再配置；启动时若设为 Playback，
  // 会压过 WebRTC 通话需要的 PlayAndRecord，导致 iOS 无远端声音。
  // 参考 https://github.com/jazzychad/PiPBugDemo

  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"native_plugin"
                                  binaryMessenger:[registrar messenger]];
  NativePlugin *instance = [[NativePlugin alloc] init];

  FLNativeViewFactory *factory =
      [[FLNativeViewFactory alloc] initWithMessenger:registrar.messenger];
  [registrar registerViewFactory:factory withId:@"native_view"];

  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _pipContentViewArray = [NSMutableArray array];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS "
        stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"createPipContentView" isEqualToString:call.method]) {
    [NativePlugin updateAudioSession];
    PlayerView *playerView = nil;
    if ([call.arguments isKindOfClass:[NSDictionary class]]) {
      NSDictionary *args = call.arguments;
      NSString *videoTrackId = args[@"videoTrackId"];
      if ([videoTrackId isKindOfClass:[NSString class]] &&
          [(NSString *)videoTrackId length] > 0) {
        playerView = [[PlayerView alloc]
            initWithRemoteVideoTrackId:(NSString *)videoTrackId];
      } else {
        NSString *status = args[@"status"] ?: @"";
        NSString *hint = args[@"hint"] ?: @"点击返回应用";
        NSData *iconData = nil;
        id rawIcon = args[@"iconPng"];
        if ([rawIcon isKindOfClass:[FlutterStandardTypedData class]]) {
          iconData = ((FlutterStandardTypedData *)rawIcon).data;
        }
        playerView =
            [[PlayerView alloc] initWithVoiceOverlayStatus:status
                                                      hint:hint
                                              iconPngData:iconData];
      }
    } else {
      playerView = [[PlayerView alloc] init];
    }

    [playerView play];
    [self.pipContentViewArray addObject:playerView];

    result(@((uint64_t)playerView));
  } else if ([@"updatePipContentView" isEqualToString:call.method]) {
    if ([call.arguments isKindOfClass:[NSDictionary class]]) {
      NSDictionary *args = call.arguments;
      uint64_t viewId = [args[@"viewId"] unsignedLongLongValue];
      NSString *status = args[@"status"] ?: @"";
      for (PlayerView *v in self.pipContentViewArray) {
        if ((uint64_t)v == viewId) {
          [v updateStatus:status];
          break;
        }
      }
    }
    result(nil);
  } else if ([@"disposePipContentView" isEqualToString:call.method]) {
    uint64_t viewId = [call.arguments unsignedLongLongValue];
    for (PlayerView *playerView in self.pipContentViewArray) {
      if ((uint64_t)playerView == viewId) {
        [playerView pause];
        [self.pipContentViewArray removeObject:playerView];
        break;
      }
    }
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
