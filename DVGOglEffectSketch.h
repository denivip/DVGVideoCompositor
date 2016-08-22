#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectSketch : DVGOglEffectBase
/** The threshold at which to apply the edges, default of 0.2
 */
@property(readwrite, nonatomic) CGFloat threshold;


// The texel width and height determines how far out to sample from this texel. By default, this is the normalized width of a pixel, but this can be overridden for different effects.
@property(readwrite, nonatomic) CGFloat texelWidth;
@property(readwrite, nonatomic) CGFloat texelHeight;

@end
