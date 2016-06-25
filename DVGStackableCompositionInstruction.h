#import <Foundation/Foundation.h>
#import "DVGOglEffectBase.h"

#import "DVGOglEffectKeyframedAnimation.h"

@interface DVGStackableCompositionInstruction : NSObject <AVVideoCompositionInstruction>
// AVVideoCompositionInstruction traits
@property (nonatomic) CMPersistentTrackID passthroughTrackID;
@property (nonatomic) CMTimeRange timeRange;
@property (nonatomic) BOOL enablePostProcessing;
@property (nonatomic) BOOL containsTweening;
@property (nonatomic) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, strong) NSArray<DVGOglEffectBase *> *renderersStack;
@property (nonatomic) NSMutableDictionary* pools;
@property (nonatomic) CVPixelBufferRef lastOkRenderedPixels;

- (id)initProcessingWithSourceTrackIDs:(NSArray*)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange;
- (id)getPixelBufferPoolForWidth:(int)w andHeight:(int)h;
@end
