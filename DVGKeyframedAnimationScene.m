#import "DVGOpenGLRenderer.h"
#import <Foundation/Foundation.h>
#import "DVGKeyframedAnimationScene.h"

#include "DVGEasing.h"
CGFloat kDefaultValuesForKeys[kDVGVITimelineKeyLast] = {0,0,0,1,1,1,0};

@implementation DVGKeyframedAnimationSceneObject
+(DVGKeyframedAnimationSceneObject *)sceneObjectWithImage:(UIImage*)image relativeSize:(CGSize)size
{
    DVGKeyframedAnimationSceneObject *sceneObject = [DVGKeyframedAnimationSceneObject new];
    sceneObject.objectImage = image;
    sceneObject.relativeSize = size;
    return sceneObject;
}
@end

@implementation DVGKeyframedAnimationTimelineKeyframe
+(DVGKeyframedAnimationTimelineKeyframe *)keyframeWithTime:(CGFloat)time value:(CGFloat)value easing:(DVGVITimelineKeyInterpolationType)easing
{
    DVGKeyframedAnimationTimelineKeyframe *keyframe = [DVGKeyframedAnimationTimelineKeyframe new];
    
    keyframe.time = time;
    keyframe.value = value;
    keyframe.easing = easing;
    
    return keyframe;
}
@end

@implementation DVGKeyframedAnimationTimeline
-(CGFloat)getValueForTime:(CGFloat)time {
    NSInteger keyframes_count = [self.keyframes count];
    if(keyframes_count == 0){
        return kDefaultValuesForKeys[self.timeline_key];
    }
    for(NSInteger i=keyframes_count-1; i>= 0; i--){
        DVGKeyframedAnimationTimelineKeyframe* keyframe = [self.keyframes objectAtIndex:i];
        if(time < keyframe.time){
            continue;
        }
        // We found it!
        if(i == keyframes_count-1){
            // No interpolation,just value
            break;
        }
        DVGKeyframedAnimationTimelineKeyframe* keyframe_next = [self.keyframes objectAtIndex:i+1];
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
    DVGKeyframedAnimationTimelineKeyframe* keyframe_last = [self.keyframes objectAtIndex:keyframes_count-1];
    CGFloat res = keyframe_last.value;
    if(isnan(res)){
        res = kDefaultValuesForKeys[self.timeline_key];
    }
    return res;
}

+(DVGKeyframedAnimationTimeline *)timelineWithKey:(DVGVITimelineKeyType)key objectIndex:(NSInteger)objectIndex keyFrames:(NSArray<DVGKeyframedAnimationTimelineKeyframe *>*)keyframes;
{
    DVGKeyframedAnimationTimeline *timeline = [DVGKeyframedAnimationTimeline new];
    
    timeline.timeline_key = key;
    timeline.sceneobject_index = objectIndex;
    timeline.keyframes = keyframes;
    
    return timeline;
}
@end

//==========================
@implementation DVGKeyframedAnimationScene

-(instancetype)init {
    if (self = [super init]) {
        self.timeSpeed = 1.0f;
        self.timeShift = 0.0f;
    }
    return self;
}

-(void)fetchKeyedValues:(CGFloat*)values atTime:(CGFloat)timeOrigin forObject:(NSInteger)objectIndex
{
    CGFloat time = timeOrigin*self.timeSpeed + self.timeShift;
    memcpy(values,kDefaultValuesForKeys,sizeof(CGFloat)*kDVGVITimelineKeyLast);
    for(int i=kDVGVITimelineUnknownKey+1; i<kDVGVITimelineKeyLast; i++){
        for(DVGKeyframedAnimationTimeline* tl in self.timelines){
            if(tl.timeline_key == i && tl.sceneobject_index == objectIndex){
                values[i] = [tl getValueForTime:time];
                break;
            }
        }
    }
    return;
}

@end