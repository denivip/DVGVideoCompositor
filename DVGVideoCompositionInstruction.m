#include "DVGEasing.h"
#import "DVGVideoCompositionInstruction.h"
CGFloat kDefaultValuesForKeys[kDVGVITimelineKeyLast] = {0,0,0,1,1,1,0};

@implementation DVGVideoInstructionSceneObject
+(DVGVideoInstructionSceneObject *)sceneObjectWithImage:(UIImage*)image relativeSize:(CGSize)size
{
    DVGVideoInstructionSceneObject *sceneObject = [DVGVideoInstructionSceneObject new];
    sceneObject.objectImage = image;
    sceneObject.relativeSize = size;
    return sceneObject;
}
@end

@implementation DVGVideoInstructionTimelineKeyframe
+(DVGVideoInstructionTimelineKeyframe *)keyframeWithTime:(CGFloat)time value:(CGFloat)value easing:(DVGVITimelineKeyInterpolationType)easing
{
    DVGVideoInstructionTimelineKeyframe *keyframe = [DVGVideoInstructionTimelineKeyframe new];
    
    keyframe.time = time;
    keyframe.value = value;
    keyframe.easing = easing;
    
    return keyframe;
}
@end

@implementation DVGVideoInstructionTimeline
-(CGFloat)getValueForTime:(CGFloat)time {
    NSInteger keyframes_count = [self.keyframes count];
    if(keyframes_count == 0){
        return kDefaultValuesForKeys[self.timeline_key];
    }
    for(NSInteger i=keyframes_count-1; i>= 0; i--){
        DVGVideoInstructionTimelineKeyframe* keyframe = [self.keyframes objectAtIndex:i];
        if(time < keyframe.time){
            continue;
        }
        // We found it!
        if(i == keyframes_count-1){
            // No interpolation,just value
            break;
        }
        DVGVideoInstructionTimelineKeyframe* keyframe_next = [self.keyframes objectAtIndex:i+1];
        CGFloat timedist = keyframe_next.time-keyframe.time;
        if(timedist <= 0.0001){
            // nextvalue
            return keyframe_next.value;
        }
        CGFloat needle = (time-keyframe.time)/timedist;
        // applying easing
        switch(keyframe.easing){
            case kDVGVITimelineEasingIn:
                needle = DVGCubicEaseIn(needle);
                break;
            case kDVGVITimelineEasingOut:
                needle = DVGCubicEaseOut(needle);
                break;
            case kDVGVITimelineEasingInOut:
                needle = DVGCubicEaseInOut(needle);
                break;
            case kDVGVITimelineInterpolationNone:
                needle = 0;
            default:
                break;
        }
        CGFloat res = keyframe.value+(keyframe_next.value - keyframe.value)*needle;
        if(isnan(res)){
            res = kDefaultValuesForKeys[self.timeline_key];
        }
        return res;
    }
    DVGVideoInstructionTimelineKeyframe* keyframe_last = [self.keyframes objectAtIndex:keyframes_count-1];
    CGFloat res = keyframe_last.value;
    if(isnan(res)){
        res = kDefaultValuesForKeys[self.timeline_key];
    }
    return res;
}

+(DVGVideoInstructionTimeline *)timelineWithKey:(DVGVITimelineKeyType)key objectIndex:(NSInteger)objectIndex keyFrames:(NSArray<DVGVideoInstructionTimelineKeyframe *>*)keyframes;
{
    DVGVideoInstructionTimeline *timeline = [DVGVideoInstructionTimeline new];
    
    timeline.timeline_key = key;
    timeline.sceneobject_index = objectIndex;
    timeline.keyframes = keyframes;
    
    return timeline;
}
@end

@interface DVGVideoInstructionScene ()
@property NSMutableArray* objectsOglBuffers;
@end

@implementation DVGVideoInstructionScene
-(void)fetchKeyedValues:(CGFloat*)values atTime:(CGFloat)time forObject:(NSInteger)objectIndex
{
    memcpy(values,kDefaultValuesForKeys,sizeof(CGFloat)*kDVGVITimelineKeyLast);
    for(int i=kDVGVITimelineUnknownKey+1; i<kDVGVITimelineKeyLast; i++){
        for(DVGVideoInstructionTimeline* tl in self.timelines){
            if(tl.timeline_key == i && tl.sceneobject_index == objectIndex){
                values[i] = [tl getValueForTime:time];
                break;
            }
        }
    }
    return;
}

-(GLKTextureInfo*)fetchOGLTextureForObject:(NSInteger)objectIndex
{
    id bf = [self.objectsOglBuffers objectAtIndex:objectIndex];
    if(bf == [NSNull null]){
        return nil;
    }
    return (GLKTextureInfo*)bf;
}

-(void)prepareForRendering
{
    if(self.objectsOglBuffers != nil){
        return;
    }
    self.objectsOglBuffers = @[].mutableCopy;
    for(DVGVideoInstructionSceneObject* obj in self.objects){
        CGImageRef imageRef=[obj.objectImage CGImage];
        GLKTextureInfo* bf = [DVGOpenGLRenderer createGLKTextureFromCGImage:imageRef];
        if(bf){
            [self.objectsOglBuffers addObject:bf];
        }else{
            [self.objectsOglBuffers addObject:[NSNull null]];
        }
    }
}

-(void)releaseAfterRendering
{
    for(int i=0;i<[self.objectsOglBuffers count];i++){
        GLKTextureInfo* ti = [self fetchOGLTextureForObject:i];
        if(ti){
            GLuint name = ti.name;
            glDeleteTextures(1, &name);
        }
    }
    self.objectsOglBuffers = nil;
}

-(void)dealloc {
    [self releaseAfterRendering];
}
@end

@implementation DVGVideoCompositionInstruction

@synthesize timeRange = _timeRange;
@synthesize enablePostProcessing = _enablePostProcessing;
@synthesize containsTweening = _containsTweening;
@synthesize requiredSourceTrackIDs = _requiredSourceTrackIDs;
@synthesize passthroughTrackID = _passthroughTrackID;

- (id)initPassThroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
		_passthroughTrackID = passthroughTrackID;
		_requiredSourceTrackIDs = nil;
		_timeRange = timeRange;
		_containsTweening = FALSE;
		_enablePostProcessing = FALSE;
        self.animationScene = nil;
	}
	
	return self;
}

- (id)initProcessingWithSourceTrackIDs:(NSArray *)sourceTrackIDs andAnimationScene:(DVGVideoInstructionScene*)animscene forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
		_requiredSourceTrackIDs = sourceTrackIDs;
		_passthroughTrackID = kCMPersistentTrackID_Invalid;
		_timeRange = timeRange;
		_containsTweening = TRUE;
		_enablePostProcessing = FALSE;
        self.animationScene = animscene;
	}
	
	return self;
}

-(void)dealloc
{
    self.animationScene = nil;
}
@end
