#import "DVGOpenGLRenderer.h"
#import "DVGKeyframedAnimationScene.h"
#import "DVGStackableCompositionInstruction.h"
#import "math.h"

@interface DVGKeyframedAnimationRenderer : DVGOpenGLRenderer
@property DVGKeyframedAnimationScene* animationScene;
+ (void)applyAnimationScene:(DVGKeyframedAnimationScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView;
@end
