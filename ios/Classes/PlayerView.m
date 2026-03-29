#import "PlayerView.h"

#import "FlutterWebRTCPlugin.h"
#import "RtcPipVideoFrameRenderer.h"

#import <AVFoundation/AVFoundation.h>
#import <WebRTC/WebRTC.h>

@interface PlayerView ()

@property(nonatomic, strong)
    AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property(nonatomic, weak, nullable) UILabel *statusLabel;
@property(nonatomic, strong, nullable) RtcPipVideoFrameRenderer *pipVideoRenderer;
@property(nonatomic, strong, nullable) RTCVideoTrack *pipVideoTrack;

@end

@implementation PlayerView

+ (Class)layerClass {
  return [AVSampleBufferDisplayLayer class];
}

- (AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer {
  return (AVSampleBufferDisplayLayer *)self.layer;
}

- (void)rtc_attachTimebase {
  // RtcPipVideoFrameRenderer 的 PTS 使用 CMClockGetHostTimeClock() 的绝对时间。
  // 若将 controlTimebase 锚在 kCMTimeZero，与上述 PTS 不在同一时间线，层会认为帧尚未到点，
  // PiP / 内联预览会卡住或几乎不刷新。nil 表示按文档立即展示入队样本（适合实时 WebRTC）。
  self.sampleBufferDisplayLayer.controlTimebase = nil;
}

/// PiP 过渡用的轻量源视图（与 FLNativeView 配合）。
- (instancetype)init {
  if (self = [super init]) {
    [self rtc_attachTimebase];
    self.backgroundColor = [UIColor whiteColor];
    [self play];
  }
  return self;
}

/// 视频：挂载与 Android [RtcOverlayVideoController] 相同的 [RTCVideoTrack] id，帧送入 [AVSampleBufferDisplayLayer]（管线：VideoTrack → RTCVideoFrame → CVPixelBuffer → CMSampleBuffer → layer；PiP 仍由 [Pip] 插件的 AVPictureInPictureController 承载）。
- (instancetype)initWithRemoteVideoTrackId:(NSString *)trackId {
  if (self = [super init]) {
    [self rtc_attachTimebase];
    self.backgroundColor = [UIColor blackColor];
    self.clipsToBounds = YES;
    self.userInteractionEnabled = YES;

    FlutterWebRTCPlugin *plugin = [FlutterWebRTCPlugin sharedSingleton];
    RTCMediaStreamTrack *track =
        [plugin trackForId:trackId peerConnectionId:nil];
    if (track != nil && [track isKindOfClass:[RTCVideoTrack class]]) {
      self.pipVideoTrack = (RTCVideoTrack *)track;
      self.pipVideoRenderer = [[RtcPipVideoFrameRenderer alloc]
          initWithDisplayLayer:self.sampleBufferDisplayLayer];
      [self.pipVideoTrack addRenderer:self.pipVideoRenderer];
    } else {
      NSLog(@"[PlayerView] PiP: 无法解析 RTCVideoTrack，trackId=%@", trackId);
    }

    [self rtc_installTapGestures];
    [self play];
  }
  return self;
}

/// 与 Android 语音悬浮窗类似的卡片 UI：白底、绿描边、图标 + 状态。
- (instancetype)initWithVoiceOverlayStatus:(NSString *)status
                              iconPngData:(NSData *)iconPngData {
  if (self = [super init]) {
    [self rtc_attachTimebase];

    self.backgroundColor = [UIColor whiteColor];
    self.layer.cornerRadius = 12.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithRed:7 / 255.0
                                             green:193 / 255.0
                                              blue:96 / 255.0
                                             alpha:0.53]
                                 .CGColor;
    self.clipsToBounds = YES;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconView.widthAnchor constraintEqualToConstant:32.0].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:32.0].active = YES;
    if (iconPngData != nil && iconPngData.length > 0) {
      iconView.image = [UIImage imageWithData:iconPngData];
    }

    UILabel *statusLab = [[UILabel alloc] init];
    statusLab.text = status ?: @"";
    statusLab.textAlignment = NSTextAlignmentCenter;
    statusLab.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    statusLab.textColor = [UIColor colorWithRed:18 / 255.0
                                          green:107 / 255.0
                                           blue:246 / 255.0
                                          alpha:1.0];
    statusLab.numberOfLines = 0;

    self.statusLabel = statusLab;

    [stack addArrangedSubview:iconView];
    [stack addArrangedSubview:statusLab];

    [self addSubview:stack];
    CGFloat pad = 12.0;
    [NSLayoutConstraint activateConstraints:@[
      [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                          constant:pad],
      [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                           constant:-pad],
    ]];

    [self rtc_installTapGestures];

    [self play];
  }
  return self;
}

- (void)updateStatus:(NSString *)status {
  UILabel *lab = self.statusLabel;
  if (lab != nil) {
    lab.text = status ?: @"";
  }
}

/// 单击：与 Android 悬窗一致，通过 chatto 深链拉起应用并由 AppDelegate 转发 openCallPage。
/// 双击：消耗掉，减轻系统 PiP 连点放大（边框仍由系统处理）。
- (void)rtc_installTapGestures {
  UITapGestureRecognizer *doubleTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(rtc_absorbDoubleTap:)];
  doubleTap.numberOfTapsRequired = 2;
  doubleTap.cancelsTouchesInView = YES;
  [self addGestureRecognizer:doubleTap];

  UITapGestureRecognizer *singleTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(rtc_onReturnToAppTap:)];
  singleTap.numberOfTapsRequired = 1;
  [singleTap requireGestureRecognizerToFail:doubleTap];
  [self addGestureRecognizer:singleTap];
}

- (void)rtc_absorbDoubleTap:(UITapGestureRecognizer *)sender {
  (void)sender;
}

- (void)rtc_onReturnToAppTap:(UITapGestureRecognizer *)sender {
  (void)sender;
  // 与 Android MainActivity.handleRtcOverlayNavIntent 使用同一套 host/path
  NSURL *url = [NSURL URLWithString:@"chatto://com.im.app.flutter/main"];
  if (url == nil) {
    return;
  }
  UIApplication *app = [UIApplication sharedApplication];
  if (@available(iOS 10.0, *)) {
    [app openURL:url
        options:@{}
        completionHandler:nil];
  }
}

- (void)play {
}

- (void)pause {
  if (self.pipVideoTrack != nil && self.pipVideoRenderer != nil) {
    [self.pipVideoTrack removeRenderer:self.pipVideoRenderer];
    self.pipVideoRenderer = nil;
    self.pipVideoTrack = nil;
  }
  AVSampleBufferDisplayLayer *layer = self.sampleBufferDisplayLayer;
  if (layer != nil) {
    [layer flushAndRemoveImage];
  }
}

@end
