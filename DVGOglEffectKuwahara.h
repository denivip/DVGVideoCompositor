#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectKuwahara : DVGOglEffectBase
/// The radius to sample from when creating the brush-stroke effect, with a default of 3. The larger the radius, the slower the filter.
@property(readwrite, nonatomic) NSUInteger radius;
@end
