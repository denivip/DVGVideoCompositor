#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

typedef enum {
    kDVGOEKA_singlecolor,
    kDVGOEKA_trackAsTexture
} DVGOEKAmode;

@interface DVGOglEffectKeyframedAnimation : DVGOglEffectBase
@property DVGKeyframedAnimationScene* animationScene;
@property DVGOEKAmode objectsRenderingMode;
@property BOOL adjustScaleForAspectRatio;
+ (void)applyAnimationScene:(DVGKeyframedAnimationScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView;
+(UIImage *)imageWithFlippedRGBOfImage:(UIImage *)image;
@end
