#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

@interface DVGOglEffectAnimatedTrackFrameRemap : DVGOglEffectBase
@property DVGKeyframedAnimationScene* frameMovementAnimations;
@property DVGKeyframedAnimationScene* textureMovementAnimations;
@end
