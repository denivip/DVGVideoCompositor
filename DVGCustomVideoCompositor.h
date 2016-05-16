#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DVGVideoCompositionInstruction.h"
#import "DVGKeyframedLayerRenderer.h"

@interface DVGCustomVideoCompositor : NSObject <AVVideoCompositing>
+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGVideoInstructionScene*)animscene;
+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGVideoInstructionScene*)animscene;
@end


@interface DVGKeyframedLayerCompositor : DVGCustomVideoCompositor
@end
