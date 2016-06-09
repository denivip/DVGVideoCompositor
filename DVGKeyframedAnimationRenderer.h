#import "DVGOpenGLRenderer.h"
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationScene.h"

@interface DVGKeyframedAnimationRenderer : DVGOpenGLRenderer
@property DVGKeyframedAnimationScene* animationScene;
+ (void)applyAnimationScene:(DVGKeyframedAnimationScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView;
@end
