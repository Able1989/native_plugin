#import "NativePlugin.h"
#import "FLNativeView.h"
#import "PlayerView.h"

#import <Flutter/Flutter.h>

@interface NativePlugin ()

@property(nonatomic, strong) NSMutableArray *_Nonnull pipContentViewArray;

@end

@implementation NativePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // 勿在 register 或 createPipContentView 里把 AVAudioSession 设为 Playback：
  // 会压过 WebRTC/LiveKit 的 PlayAndRecord，导致 iOS 通话无声音。
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
    // PiP 宽高比（9:16 / 1:1）与捏合缩放由 packages/pip 的 PipOptions.isVideoCall
    // 在 PipController（iOS）中处理；此处仅负责通话内容渲染视图。
    // 切勿在此处把 AVAudioSession 改为 Playback：会与 LiveKit/WebRTC 的
    // PlayAndRecord 争抢，导致语音/视频通话双方听不到声音（见 registerWithRegistrar 注释）。
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
        NSData *iconData = nil;
        id rawIcon = args[@"iconPng"];
        if ([rawIcon isKindOfClass:[FlutterStandardTypedData class]]) {
          iconData = ((FlutterStandardTypedData *)rawIcon).data;
        }
        playerView =
            [[PlayerView alloc] initWithVoiceOverlayStatus:status
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
