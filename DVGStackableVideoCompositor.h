#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DVGStackableCompositionInstruction.h"
#import "DVGOglEffectKeyframedAnimation.h"
#import "DVGOglEffectDirectionalBlur.h"
#import "DVGOglEffectColorSaturation.h"
#import "DVGOglEffectAnimatedTrackFrameRemap.h"
#import "DVGOglEffectAnimatedRainbowMask.h"
#import "DVGEasing.h"

extern NSString* kCompEffectOptionExportSize;
extern NSString* kCompEffectOptionProgressBlock;

@interface DVGStackableVideoCompositor : NSObject <AVVideoCompositing>
+ (AVPlayerItem*)createPlayerItemWithAssets:(NSArray<AVAsset*>*)assets andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack options:(NSDictionary*)svcOptions;
+ (AVAssetExportSession*)createExportSessionWithAssets:(NSArray<AVAsset*>*)assets andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack options:(NSDictionary*)svcOptions;

// Convinience methods for Typomatic, etc
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;
+ (DVGStackableVideoCompositor*)getActiveVideoProcessingCompositor;
@end

