#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"


@interface DVGOglEffectAnimatedRainbowMask : DVGOglEffectBase
@property DVGKeyframedAnimationScene* frameMovementAnimations;
@property BOOL adjustScaleForAspectRatio;
@property NSArray<UIImage*>* rainbowMappedPhotos;
@end
