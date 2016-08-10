#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

typedef enum {
    DVGOglEffectATFRBlendingMethodAlpha,
    DVGOglEffectATFRBlendingMethodBrightness
} DVGOglEffectATFRBlendingMethod;

@interface DVGOglEffectAnimatedTrackFrameRemap : DVGOglEffectBase
@property DVGKeyframedAnimationScene* frameMovementAnimations;
@property DVGKeyframedAnimationScene* textureMovementAnimations;
@property BOOL adjustScaleForAspectRatio;
@property DVGOglEffectATFRBlendingMethod layerBlendingMethod;
+(DVGKeyframedAnimationScene*)staticSceneWithScale:(NSArray*)scaleXY andOffset:(NSArray*)offsetXY andRotation:(CGFloat)rotation;
+(DVGKeyframedAnimationScene*)slideSceneWithScale:(NSArray*)scaleXYXY andOffset:(NSArray*)offsetXYXY andRotation:(NSArray*)rotations forTime:(CGFloat)duration;
@end
