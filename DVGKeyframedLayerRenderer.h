#import "DVGOpenGLRenderer.h"
#import "DVGVideoCompositionInstruction.h"
#import "math.h"

@interface DVGKeyframedLayerRenderer : DVGOpenGLRenderer
+ (void)applyAnimationScene:(DVGVideoInstructionScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView;
@end
