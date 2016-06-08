#import "DVGStackableCompositionInstruction.h"
@implementation DVGStackableCompositionInstruction

- (id)initProcessingWithSourceTrackIDs:(NSArray *)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
		_requiredSourceTrackIDs = sourceTrackIDs;
		_passthroughTrackID = kCMPersistentTrackID_Invalid;
		_timeRange = timeRange;
		_containsTweening = TRUE;
		_enablePostProcessing = FALSE;
	}
	
	return self;
}

-(void)dealloc
{
    for(DVGOpenGLRenderer* renderer in self.renderersStack){
        [renderer releaseOglResources];
    }
}
@end
