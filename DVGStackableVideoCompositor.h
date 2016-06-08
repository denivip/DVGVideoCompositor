#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DVGStackableCompositionInstruction.h"
#import "DVGKeyframedAnimationRenderer.h"

@interface DVGStackableVideoCompositor : NSObject <AVVideoCompositing>
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOpenGLRenderer*>*)effstack;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOpenGLRenderer*>*)effstack;

// Convinience methods for Typomatic, etc
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene;

@end

