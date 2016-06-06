#import "DVGVideoCompositionInstruction.h"

#import "DVGCustomVideoCompositor.h"
#import "DVGKeyframedLayerRenderer.h"
#import "DVGOpenGLRenderer.h"
#import <CoreVideo/CoreVideo.h>

@interface DVGCustomVideoCompositor()
{
	BOOL								_shouldCancelAllRequests;
	BOOL								_renderContextDidChange;
	dispatch_queue_t					_renderingQueue;
	dispatch_queue_t					_renderContextQueue;
	AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
}

@property (nonatomic, strong) DVGOpenGLRenderer *oglRenderer;

@end


@implementation DVGKeyframedLayerCompositor

- (id)init
{
	self = [super init];
	
	if (self) {
		self.oglRenderer = [[DVGKeyframedLayerRenderer alloc] init];
	}
	
	return self;
}

@end

@implementation DVGCustomVideoCompositor

#pragma mark - AVVideoCompositing protocol

- (id)init
{
	self = [super init];
	if (self)
	{
		_renderingQueue = dispatch_queue_create("com.apple.DVGCustomVideoCompositor.renderingqueue", DISPATCH_QUEUE_SERIAL); 
		_renderContextQueue = dispatch_queue_create("com.apple.DVGCustomVideoCompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
		_renderContextDidChange = NO;
	}
	return self;
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)],
             (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES};
	//return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
	//		  (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)],
             (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES};
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
	dispatch_sync(_renderContextQueue, ^() {
		_renderContext = newRenderContext;
		_renderContextDidChange = YES;
	});
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
	@autoreleasepool {
		dispatch_async(_renderingQueue,^() {
			
			// Check if all pending requests have been cancelled
			if (_shouldCancelAllRequests) {
				[request finishCancelledRequest];
			} else {
				NSError *err = nil;
				// Get the next rendererd pixel buffer
				CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
				
				if (resultPixels) {
					// The resulting pixelbuffer from OpenGL renderer is passed along to the request
					[request finishWithComposedVideoFrame:resultPixels];
					CFRelease(resultPixels);
				} else {
					[request finishWithError:err];
				}
			}
		});
	}
}

- (void)cancelAllPendingVideoCompositionRequests
{
	// pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
	_shouldCancelAllRequests = YES;
	
	dispatch_barrier_async(_renderingQueue, ^() {
		// start accepting requests again
		_shouldCancelAllRequests = NO;
	});
}

#pragma mark - Utilities

//static Float64 factorForTimeInRange(CMTime time, CMTimeRange range) /* 0.0 -> 1.0 */
//{
//	CMTime elapsed = CMTimeSubtract(time, range.start);
//	return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
//}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
	CVPixelBufferRef dstPixels = nil;
	
	// tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
	// 0.0 indicates the time at first frame in that videoComposition timeRange
	// 1.0 indicates the time at last frame in that videoComposition timeRange
	//float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
	
	DVGVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
	
	// Source pixel buffers are used as inputs while rendering the transition
	//CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.foregroundTrackID];
	CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.backgroundTrackID];
	
	// Destination pixel buffer into which we render the output
	dstPixels = [_renderContext newPixelBuffer];
	
	// Recompute normalized render transform everytime the render context changes
	if (_renderContextDidChange) {
		// The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
		// But since in this sample we render using OpenGLES which has its coordinate system between [-1, 1] we compute a normalized transform
		CGSize renderSize = _renderContext.size;
		CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(dstPixels), CVPixelBufferGetHeight(dstPixels));
		CGAffineTransform renderContextTransform = {renderSize.width/2, 0, 0, renderSize.height/2, renderSize.width/2, renderSize.height/2};
		CGAffineTransform destinationTransform = {2/destinationSize.width, 0, 0, 2/destinationSize.height, -1, -1};
		CGAffineTransform normalizedRenderTransform = CGAffineTransformConcat(CGAffineTransformConcat(renderContextTransform, _renderContext.renderTransform), destinationTransform);
		_oglRenderer.renderTransform = normalizedRenderTransform;
		
		_renderContextDidChange = NO;
	}
    CGFloat time = CMTimeGetSeconds(request.compositionTime);
    [_oglRenderer renderPixelBuffer:dstPixels usingBackgroundSourceBuffer:backgroundSourceBuffer withInstruction:currentInstruction atTime:time];
	
	return dstPixels;
}

+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGVideoInstructionScene*)animscene {
    CGSize videoSize = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
    CGAffineTransform videoTransform = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] preferredTransform];
    AVMutableComposition *composition = [AVMutableComposition composition];
    DVGGLRotationMode inputRotation = [DVGOpenGLRenderer orientationForPrefferedTransform:videoTransform andSize:videoSize];
    videoSize = [DVGOpenGLRenderer landscapeSizeForOrientation:inputRotation andSize:videoSize];
    composition.naturalSize = videoSize;
    AVMutableVideoComposition *videoComposition = nil;
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.customVideoCompositorClass = [DVGKeyframedLayerCompositor class];
    [DVGCustomVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andAnimationScene:animscene forAsset:asset];
    
    if (videoComposition) {
        AVAssetExportSession* exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
        exportSession.videoComposition = videoComposition;
        return exportSession;
    }
    return nil;
}

+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGVideoInstructionScene*)animscene
{
    CGSize videoSize = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
    CGAffineTransform videoTransform = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] preferredTransform];
    AVMutableComposition *composition = [AVMutableComposition composition];
    DVGGLRotationMode inputRotation = [DVGOpenGLRenderer orientationForPrefferedTransform:videoTransform andSize:videoSize];
    videoSize = [DVGOpenGLRenderer landscapeSizeForOrientation:inputRotation andSize:videoSize];
    composition.naturalSize = videoSize;
    AVMutableVideoComposition *videoComposition = nil;
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.customVideoCompositorClass = [DVGKeyframedLayerCompositor class];
    [DVGCustomVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andAnimationScene:animscene forAsset:asset];
    
    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }
    
    //self.composition = composition;
    //self.videoComposition = videoComposition;
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:composition];
    playerItem.videoComposition = videoComposition;
    return playerItem;
}


+ (void) prepareComposition:(AVMutableComposition *)composition
        andVideoComposition:(AVMutableVideoComposition *)videoComposition
          andAnimationScene:(DVGVideoInstructionScene*)animscene
                   forAsset:(AVAsset*)asset
{
    CGSize videoSize = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
    CGAffineTransform videoTransform = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] preferredTransform];
    AVMutableCompositionTrack *compositionVideoTrack;
    AVMutableCompositionTrack *compositionAudioTrack;
    compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, [asset duration]);
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    [compositionVideoTrack insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:kCMTimeZero error:nil];
    AVAssetTrack *clipAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    [compositionAudioTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:kCMTimeZero error:nil];
    NSMutableArray *instructions = [NSMutableArray array];
    DVGVideoCompositionInstruction *videoInstruction = [[DVGVideoCompositionInstruction alloc] initProcessingWithSourceTrackIDs:@[@(compositionVideoTrack.trackID)]
                                                                                                              andAnimationScene:animscene
                                                                                                                   forTimeRange:timeRangeInAsset];
    videoInstruction.backgroundTrackID = compositionVideoTrack.trackID;
    videoInstruction.backgroundTrackOrientation = [DVGOpenGLRenderer orientationForPrefferedTransform:videoTransform andSize:videoSize];
    [instructions addObject:videoInstruction];
    
    videoComposition.instructions = instructions;
}

@end
