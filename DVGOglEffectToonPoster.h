#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectToonPoster : DVGOglEffectBase
/** The threshold at which to apply the edges, default of 0.2
 */
@property(readwrite, nonatomic) CGFloat threshold;

/** The levels of quantization for the posterization of colors within the scene, with a default of 10.0
 */
@property(readwrite, nonatomic) CGFloat quantizationLevels;

// The texel width and height determines how far out to sample from this texel. By default, this is the normalized width of a pixel, but this can be overridden for different effects.
@property(readwrite, nonatomic) CGFloat texelWidth;
@property(readwrite, nonatomic) CGFloat texelHeight;

@end
