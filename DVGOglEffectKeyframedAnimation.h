#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

typedef enum {
    kDVGOEKA_singlecolor,
    kDVGOEKA_trackAsTexture,
    kDVGOEKA_trackAsTextureColorKey
} DVGOEKAmode;

@interface DVGOglEffectKeyframedAnimation : DVGOglEffectBase
@property DVGKeyframedAnimationScene* animationScene;
@property DVGOEKAmode objectsRenderingMode;
@property BOOL adjustScaleForAspectRatio;
@property CGFloat colorKeyForMask_r;
@property CGFloat colorKeyForMask_g;
@property CGFloat colorKeyForMask_b;
+ (void)applyAnimationScene:(DVGKeyframedAnimationScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView;
@end
