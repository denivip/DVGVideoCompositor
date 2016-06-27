#import <Foundation/Foundation.h>
#import "DVGOglEffectBase.h"

#import "DVGOglEffectKeyframedAnimation.h"

@class DVGStackableCompositionInstruction;
typedef void (^DVGStackableCompositionInstructionProgressBlock)(DVGStackableCompositionInstruction*);

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
@property (nonatomic) DVGStackableCompositionInstructionProgressBlock onBeforeRenderingFrame;
@property (nonatomic) CGFloat actualRenderTime;
@property (nonatomic) CGFloat actualRenderProgress;

- (id)initProcessingWithSourceTrackIDs:(NSArray*)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange;
- (id)getPixelBufferPoolForWidth:(int)w andHeight:(int)h;
@end
