#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DVGStackableCompositionInstruction.h"
#import "DVGOglEffectKeyframedAnimation.h"
#import "DVGOglEffectDirectionalBlur.h"
#import "DVGOglEffectColorSaturation.h"
#import "DVGOglEffectAnimatedTrackFrameRemap.h"
#import "DVGEasing.h"

@interface DVGStackableVideoCompositor : NSObject <AVVideoCompositing>
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack forSize:(CGSize)outsize;

// Convinience methods for Typomatic, etc
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;

@end

