#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@interface DVGOglEffectPolkaDot : DVGOglEffectBase
@property(readwrite, nonatomic) CGFloat pixellationFraction;
@property(readwrite, nonatomic) CGFloat dotScaling;

@end
