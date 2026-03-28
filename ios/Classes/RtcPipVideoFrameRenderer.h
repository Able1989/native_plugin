#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoRenderer.h>

NS_ASSUME_NONNULL_BEGIN

/// 将远端 [RTCVideoTrack] 的 [RTCVideoFrame] 转为 CMSampleBuffer 并送入 [AVSampleBufferDisplayLayer]（供 PiP / 画中画内容区）。
@interface RtcPipVideoFrameRenderer : NSObject <RTCVideoRenderer>

- (instancetype)initWithDisplayLayer:(AVSampleBufferDisplayLayer *)displayLayer;

@end

NS_ASSUME_NONNULL_END
