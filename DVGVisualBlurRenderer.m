#import "DVGVisualBlurRenderer.h"

@interface DVGVisualBlurRenderer ()
@end

@implementation DVGVisualBlurRenderer
- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                 sourceBuffer:(CVPixelBufferRef)trackBuffer
                 sourceOrient:(DVGGLRotationMode)trackOrientation
                   atTime:(CGFloat)time withTween:(float)tweenFactor
{
}

@end
