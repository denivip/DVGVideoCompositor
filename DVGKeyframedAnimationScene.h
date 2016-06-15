//
//  DVGKeyframedAnimationHelper.h
//  Together
//
//  Created by IPv6 on 08/06/16.
//  Copyright © 2016 DENIVIP Group. All rights reserved.
//

#ifndef DVGKeyframedAnimationScene_h
#define DVGKeyframedAnimationScene_h

typedef enum {
    kDVGVITimelineUnknownKey,
    kDVGVITimelineXPosKey,
    kDVGVITimelineYPosKey,
    kDVGVITimelineXScaleKey,
    kDVGVITimelineYScaleKey,
    kDVGVITimelineAlphaKey,
    kDVGVITimelineRotationKey,
    kDVGVITimelineKeyLast
} DVGVITimelineKeyType;

typedef enum {
    kDVGVITimelineInterpolationLinear,
    kDVGVITimelineEasingIn,
    kDVGVITimelineEasingOut,
    kDVGVITimelineEasingInOut,
    kDVGVITimelineInterpolationNone,
} DVGVITimelineKeyInterpolationType;

// Visual object, that can be animated over video
// relativeSize is relative to rendering "canvas"
// canvas is viewport, that will be mapped onto video frame
// so relative size [1:1] is mapped to whole viewport area
// it is possible to leave one of dimensions as zero (width OR height)
// it will be recalculated according to aspect ration of target canvas and image sizes (width/height in pixels)
@interface DVGKeyframedAnimationSceneObject : NSObject
@property UIImage* objectImage;
@property CGSize relativeSize;
+(DVGKeyframedAnimationSceneObject *)sceneObjectWithImage:(UIImage*)image relativeSize:(CGSize)size;
@end

// keyframe - point in time with specific value and easing
// - value is in [-1:1] for kDVGVITimelineXPosKey/kDVGVITimelineYPosKey, [0:1] for others
// - easing work between CURRENT keyframe and the NEXT one
// kDVGVITimelineXPosKey/kDVGVITimelineYPosKey examples:
//  - [0,0] means center of image at the center of video
//  - [1,1] means center of image at the right-bottom corner of video
// default value 1 for kDVGVITimelineXScaleKey/kDVGVITimelineYScaleKey/kDVGVITimelineAlphaKey
// default value 0 for all others
@interface DVGKeyframedAnimationTimelineKeyframe : NSObject
@property CGFloat time;
@property CGFloat value;
@property DVGVITimelineKeyInterpolationType easing;
+(DVGKeyframedAnimationTimelineKeyframe *)keyframeWithTime:(CGFloat)time value:(CGFloat)value easing:(DVGVITimelineKeyInterpolationType)easing;
@end

// Single animatable object parameter (such as x,y,alpha,etc) and keyframes
@interface DVGKeyframedAnimationTimeline : NSObject
@property DVGVITimelineKeyType timeline_key;
@property NSArray<DVGKeyframedAnimationTimelineKeyframe*>* keyframes;
@property NSInteger sceneobject_index;
+(DVGKeyframedAnimationTimeline *)timelineWithKey:(DVGVITimelineKeyType)key objectIndex:(NSInteger)objectIndex keyFrames:(NSArray<DVGKeyframedAnimationTimelineKeyframe *>*)keyframes;
-(CGFloat)getValueForTime:(CGFloat)time;
@end

@interface DVGKeyframedAnimationScene : NSObject
@property CGFloat timeSpeed;
@property CGFloat timeShift;

@property NSArray<DVGKeyframedAnimationSceneObject*>* objects;
@property NSArray<DVGKeyframedAnimationTimeline*>* timelines;
-(void)fetchKeyedValues:(CGFloat*)values atTime:(CGFloat)time;
-(void)fetchKeyedValues:(CGFloat*)values atTime:(CGFloat)time forObject:(NSInteger)objectIndex;
@end

#endif /* DVGKeyframedAnimationScene_h */
