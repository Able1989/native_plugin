#import "RtcPipVideoFrameRenderer.h"

#import <WebRTC/RTCI420Buffer.h>
#import <WebRTC/RTCYUVHelper.h>
#import <WebRTC/RTCYUVPlanarBuffer.h>
#import <WebRTC/WebRTC.h>

@interface RtcPipVideoFrameRenderer ()

@property(nonatomic, weak) AVSampleBufferDisplayLayer *displayLayer;

@end

@implementation RtcPipVideoFrameRenderer

- (instancetype)initWithDisplayLayer:(AVSampleBufferDisplayLayer *)displayLayer {
  self = [super init];
  if (self) {
    _displayLayer = displayLayer;
  }
  return self;
}

- (void)setSize:(CGSize)size {
  (void)size;
}

static id<RTCI420Buffer> RtcPipCorrectRotationI420(id<RTCI420Buffer> src,
                                                    RTCVideoRotation rotation) {
  int rotatedWidth = src.width;
  int rotatedHeight = src.height;
  if (rotation == RTCVideoRotation_90 || rotation == RTCVideoRotation_270) {
    int t = rotatedWidth;
    rotatedWidth = rotatedHeight;
    rotatedHeight = t;
  }
  id<RTCI420Buffer> buffer =
      [[RTCI420Buffer alloc] initWithWidth:rotatedWidth height:rotatedHeight];
  [RTCYUVHelper I420Rotate:src.dataY
                srcStrideY:src.strideY
                      srcU:src.dataU
                srcStrideU:src.strideU
                      srcV:src.dataV
                srcStrideV:src.strideV
                      dstY:(uint8_t *)buffer.dataY
                dstStrideY:buffer.strideY
                      dstU:(uint8_t *)buffer.dataU
                dstStrideU:buffer.strideU
                      dstV:(uint8_t *)buffer.dataV
                dstStrideV:buffer.strideV
                     width:src.width
                    height:src.height
                      mode:rotation];
  return buffer;
}

static CVPixelBufferRef RtcPipCreateBGRAPixelBufferFromFrame(RTCVideoFrame *frame) {
  id<RTCI420Buffer> raw = [frame.buffer toI420];
  if (raw == nil) {
    return NULL;
  }
  id<RTCI420Buffer> i420 = RtcPipCorrectRotationI420(raw, frame.rotation);
  if (!i420) {
    return NULL;
  }
  CVPixelBufferRef outputPixelBuffer = NULL;
  size_t w = (size_t)i420.width;
  size_t h = (size_t)i420.height;
  NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
  CVReturn cvret =
      CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                          (__bridge CFDictionaryRef)pixelAttributes,
                          &outputPixelBuffer);
  if (cvret != kCVReturnSuccess || outputPixelBuffer == NULL) {
    return NULL;
  }
  CVPixelBufferLockBaseAddress(outputPixelBuffer, 0);
  uint8_t *dst = CVPixelBufferGetBaseAddress(outputPixelBuffer);
  const size_t bytesPerRow = CVPixelBufferGetBytesPerRow(outputPixelBuffer);

  [RTCYUVHelper I420ToARGB:i420.dataY
                srcStrideY:i420.strideY
                      srcU:i420.dataU
                srcStrideU:i420.strideU
                      srcV:i420.dataV
                srcStrideV:i420.strideV
                   dstARGB:dst
             dstStrideARGB:(int)bytesPerRow
                     width:i420.width
                    height:i420.height];

  CVPixelBufferUnlockBaseAddress(outputPixelBuffer, 0);
  return outputPixelBuffer;
}

static CMSampleBufferRef RtcPipMakeSampleBuffer(CVPixelBufferRef pixelBuffer) {
  if (!pixelBuffer) {
    return NULL;
  }
  CMVideoFormatDescriptionRef formatDesc = NULL;
  OSStatus err = CMVideoFormatDescriptionCreateForImageBuffer(
      kCFAllocatorDefault, pixelBuffer, &formatDesc);
       if (err != noErr) {
    return NULL;
  }
  CMTime pts = CMClockGetTime(CMClockGetHostTimeClock());
  CMSampleTimingInfo timing = {
      .duration = kCMTimeInvalid,
      .presentationTimeStamp = pts,
      .decodeTimeStamp = kCMTimeInvalid,
  };
  CMSampleBufferRef sampleBuffer = NULL;
  err = CMSampleBufferCreateReadyWithImageBuffer(
      kCFAllocatorDefault, pixelBuffer, formatDesc, &timing, &sampleBuffer);
  CFRelease(formatDesc);
  if (err != noErr) {
    return NULL;
  }
  return sampleBuffer;
}

- (void)renderFrame:(RTCVideoFrame *_Nullable)frame {
  if (frame == nil || self.displayLayer == nil) {
    return;
  }
  CVPixelBufferRef pb = RtcPipCreateBGRAPixelBufferFromFrame(frame);
  if (pb == NULL) {
    return;
  }

  AVSampleBufferDisplayLayer *layer = self.displayLayer;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (layer.status == AVQueuedSampleBufferRenderingStatusFailed) {
      [layer flush];
    }
    CMSampleBufferRef sb = RtcPipMakeSampleBuffer(pb);
    CVPixelBufferRelease(pb);
    if (sb == NULL) {
      return;
    }
    if (layer.status != AVQueuedSampleBufferRenderingStatusFailed) {
      [layer enqueueSampleBuffer:sb];
    }
    CFRelease(sb);
  });
}

@end
