#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DVGOpenGLRenderer.h"
#import <GLKit/GLKitBase.h>
#import <GLKit/GLKTextureLoader.h>

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
@interface DVGVideoInstructionSceneObject : NSObject
@property UIImage* objectImage;
@property CGSize relativeSize;
+(DVGVideoInstructionSceneObject *)sceneObjectWithImage:(UIImage*)image relativeSize:(CGSize)size;
@end

// keyframe - point in time with specific value and easing
// - value is in [-1:1] for kDVGVITimelineXPosKey/kDVGVITimelineYPosKey, [0:1] for others
// - easing work between CURRENT keyframe and the NEXT one
// kDVGVITimelineXPosKey/kDVGVITimelineYPosKey examples:
//  - [0,0] means center of image at the center of video
//  - [1,1] means center of image at the right-bottom corner of video
// default value 1 for kDVGVITimelineXScaleKey/kDVGVITimelineYScaleKey/kDVGVITimelineAlphaKey
// default value 0 for all others
@interface DVGVideoInstructionTimelineKeyframe : NSObject
@property CGFloat time;
@property CGFloat value;
@property DVGVITimelineKeyInterpolationType easing;
+(DVGVideoInstructionTimelineKeyframe *)keyframeWithTime:(CGFloat)time value:(CGFloat)value easing:(DVGVITimelineKeyInterpolationType)easing;
 @end

// Single animatable object parameter (such as x,y,alpha,etc) and keyframes
@interface DVGVideoInstructionTimeline : NSObject
@property DVGVITimelineKeyType timeline_key;
@property NSArray<DVGVideoInstructionTimelineKeyframe*>* keyframes;
@property NSInteger sceneobject_index;
+(DVGVideoInstructionTimeline *)timelineWithKey:(DVGVITimelineKeyType)key objectIndex:(NSInteger)objectIndex keyFrames:(NSArray<DVGVideoInstructionTimelineKeyframe *>*)keyframes;
-(CGFloat)getValueForTime:(CGFloat)time;
@end

// objects and timelines for this objects
@interface DVGVideoInstructionScene : NSObject
@property NSArray<DVGVideoInstructionSceneObject*>* objects;
@property NSArray<DVGVideoInstructionTimeline*>* timelines;
-(void)fetchKeyedValues:(CGFloat*)values atTime:(CGFloat)time forObject:(NSInteger)objectIndex;
-(GLKTextureInfo*)fetchOGLTextureForObject:(NSInteger)objectIndex;
-(void)prepareForRendering;
-(void)releaseAfterRendering;
@end


@interface DVGVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction>
@property DVGVideoInstructionScene* animationScene;
@property CMPersistentTrackID backgroundTrackID;
@property DVGGLRotationMode backgroundTrackOrientation;

- (id)initPassThroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange;
- (id)initProcessingWithSourceTrackIDs:(NSArray*)sourceTrackIDs andAnimationScene:(DVGVideoInstructionScene*)animscene forTimeRange:(CMTimeRange)timeRange;

@end
