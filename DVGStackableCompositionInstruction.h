#import <Foundation/Foundation.h>
#import "DVGOpenGLRenderer.h"

#import "DVGKeyframedAnimationRenderer.h"

@interface DVGStackableCompositionInstruction : NSObject <AVVideoCompositionInstruction>
// AVVideoCompositionInstruction traits
@property (nonatomic) CMPersistentTrackID passthroughTrackID;
@property (nonatomic) CMTimeRange timeRange;
@property (nonatomic) BOOL enablePostProcessing;
@property (nonatomic) BOOL containsTweening;
@property (nonatomic) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, strong) NSArray<DVGOpenGLRenderer *> *renderersStack;

- (id)initProcessingWithSourceTrackIDs:(NSArray*)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange;

@end
