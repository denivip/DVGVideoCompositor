#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectPixellate : DVGOglEffectBase
/** The fractional width of the image to use as a size for the pixels in the resulting image. Values below one pixel width in the source image are ignored.
 */
@property(readwrite, nonatomic) CGFloat pixellationFraction;
@end
