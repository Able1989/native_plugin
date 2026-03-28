#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// PiP 源视图用 [init]；语音画中画内容区用 [initWithVoiceOverlayStatus:hint:iconPngData:]；
/// 视频与 Android 一致：同一套 WebRTC [RTCVideoTrack]（Flutter / LiveKit 与 [mediaStreamTrack.id] 一致）→ 本类 [AVSampleBufferDisplayLayer]。
@interface PlayerView : UIView

- (instancetype)init;

- (instancetype)initWithRemoteVideoTrackId:(NSString *)trackId;

- (instancetype)initWithVoiceOverlayStatus:(NSString *)status
                                      hint:(NSString *)hint
                              iconPngData:(nullable NSData *)iconPngData;

- (void)updateStatus:(NSString *)status;

- (void)play;

- (void)pause;

@end

NS_ASSUME_NONNULL_END
