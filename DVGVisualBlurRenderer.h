#import "DVGOpenGLRenderer.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGVisualBlurRenderer : DVGOpenGLRenderer
/** A radius in pixels to use for the blur, with a default of 2.0. This adjusts the sigma variable in the Gaussian distribution function.
 */
@property (readwrite, nonatomic) CGFloat blurRadiusInPixels;
@end
