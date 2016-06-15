#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

@interface DVGOglEffectColorSaturation : DVGOglEffectBase
/** Brightness shift ranges, from -1.0 to 1.0. Default is 0.0
 */
@property(readwrite, nonatomic) CGFloat brightness;
/** Saturation ranges from 0.0 (fully desaturated) to 2.0 (max saturation), with 1.0 as the normal level
 */
@property(readwrite, nonatomic) CGFloat saturation;
@end
