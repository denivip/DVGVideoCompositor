#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectDirectionalBlur : DVGOglEffectBase
/** A radius in pixels to use for the blur, with a default of 2.0. This adjusts the sigma variable in the Gaussian distribution function.
 */
@property (readwrite, nonatomic) CGFloat blurRadiusInPixels;
@property (readwrite, nonatomic) CGFloat blurXScale;
@property (readwrite, nonatomic) CGFloat blurYScale;
@property (readwrite, nonatomic) CGFloat blurBlendingWeight;
@end
