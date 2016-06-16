#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

@interface DVGOglEffectAnimatedTrackFrameRemap : DVGOglEffectBase
@property DVGKeyframedAnimationScene* frameMovementAnimations;
@property DVGKeyframedAnimationScene* textureMovementAnimations;
+(DVGKeyframedAnimationScene*)staticSceneWithScale:(NSArray*)scaleXY andOffset:(NSArray*)offsetXY andRotation:(CGFloat)rotation;
+(DVGKeyframedAnimationScene*)slideSceneWithScale:(NSArray*)scaleXYXY andOffset:(NSArray*)offsetXYXY andRotation:(NSArray*)rotations forTime:(CGFloat)duration;
@end
