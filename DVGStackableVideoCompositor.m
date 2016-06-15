#import "DVGStackableCompositionInstruction.h"

#import "DVGStackableVideoCompositor.h"
#import "DVGOglEffectKeyframedAnimation.h"
#import "DVGOglEffectBase.h"
#import <CoreVideo/CoreVideo.h>

@interface DVGStackableVideoCompositor()
{
	BOOL								_shouldCancelAllRequests;
	BOOL								_renderContextDidChange;
	dispatch_queue_t					_renderingQueue;
	dispatch_queue_t					_renderContextQueue;
    CVPixelBufferRef					_previousBuffer;
	AVVideoCompositionRenderContext*	_renderContext;
}

@end

@implementation DVGStackableVideoCompositor

#pragma mark - AVVideoCompositing protocol

- (id)init
{
	self = [super init];
	if (self)
	{
		_renderingQueue = dispatch_queue_create("com.denivip.DVGStackableVideoCompositor.renderingqueue", DISPATCH_QUEUE_SERIAL);
		_renderContextQueue = dispatch_queue_create("com.denivip.DVGStackableVideoCompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
		_renderContextDidChange = NO;
	}
	return self;
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)],
             (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @[@(kCVPixelFormatType_32BGRA)],
             (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES
             //(NSString *)kCVPixelBufferWidthKey: @(100),
             //(NSString *)kCVPixelBufferHeightKey: @(100)
             };
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

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
	DVGStackableCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
    CVPixelBufferRef dstPixels = nil;
	
	// tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
	// 0.0 indicates the time at first frame in that videoComposition timeRange
	// 1.0 indicates the time at last frame in that videoComposition timeRange
    CGFloat time = CMTimeGetSeconds(request.compositionTime);
    CMTime elapsed = CMTimeSubtract(request.compositionTime, request.videoCompositionInstruction.timeRange.start);
    float tweenFactor = CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(request.videoCompositionInstruction.timeRange.duration);

    CVPixelBufferRef prevBuffer = nil;
    for(DVGOglEffectBase* renderer in currentInstruction.renderersStack){
        if(prevBuffer){
            CFRelease(prevBuffer);
            prevBuffer = nil;
        }
        prevBuffer = dstPixels;
        CGSize renderSize = _renderContext.size;
        // Destination pixel buffer into which we render the output
        if(renderer.effectRenderingUpscale != 1.0f){
            int videoWidth = renderSize.width*renderer.effectRenderingUpscale;
            int videoHeight = renderSize.height*renderer.effectRenderingUpscale;
            CVPixelBufferPoolRef bufferPool = (__bridge CVPixelBufferPoolRef)[currentInstruction getPixelBufferPoolForWidth:videoWidth andHeight:videoHeight];
            CVPixelBufferPoolCreatePixelBuffer(NULL, bufferPool, &dstPixels);
            
            //CVPixelBufferLockBaseAddress(dstPixels,0);
            //UInt8 * baseAddress = CVPixelBufferGetBaseAddress(dstPixels);
            ////memcpy(baseAddress, bgraData, bytesByRow * videoHeight);
            //memset(baseAddress, 0, bytesByRow * videoHeight)
            //CVPixelBufferUnlockBaseAddress(dstPixels,0);
        }else{
            dstPixels = [_renderContext newPixelBuffer];
        }
        CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(dstPixels), CVPixelBufferGetHeight(dstPixels));

        // Recompute normalized render transform everytime the render context changes
        if (_renderContextDidChange) {
            // The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
            // But since in this sample we render using OpenGLES which has its coordinate system between [-1, 1] we compute a normalized transform
            CGAffineTransform renderContextTransform = {renderSize.width/2, 0, 0, renderSize.height/2, renderSize.width/2, renderSize.height/2};
            CGAffineTransform destinationTransform = {2/destinationSize.width, 0, 0, 2/destinationSize.height, -1, -1};
            CGAffineTransform normalizedRenderTransform = CGAffineTransformConcat(CGAffineTransformConcat(renderContextTransform, _renderContext.renderTransform), destinationTransform);
            [renderer prepareTransform:normalizedRenderTransform];
        }

        
        CVPixelBufferRef trackBuffer = nil;
        DVGGLRotationMode trackOrientation = kDVGGLNoRotation;
        if(renderer.effectTrackID != kCMPersistentTrackID_Invalid){
            trackBuffer = [request sourceFrameByTrackID:renderer.effectTrackID];
            trackOrientation = renderer.effectTrackOrientation;
        }
        [renderer renderIntoPixelBuffer:dstPixels
                             prevBuffer:prevBuffer
                           sourceBuffer:trackBuffer
                           sourceOrient:trackOrientation
                                 atTime:time withTween:tweenFactor];
    }
    if(prevBuffer){
        CFRelease(prevBuffer);
        prevBuffer = nil;
    }
    _renderContextDidChange = NO;
	return dstPixels;
}

+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene {
    DVGOglEffectKeyframedAnimation* kar = [[DVGOglEffectKeyframedAnimation alloc] init];
    kar.animationScene = animscene;
    return [DVGStackableVideoCompositor createExportSessionWithAsset:asset andEffectsStack:@[kar]];
}

+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack {
    NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([videoTracks count] == 0){
        return nil;
    }
    AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
    CGSize videoSize = [videoTrack naturalSize];
    CGAffineTransform videoTransform = [videoTrack preferredTransform];
    AVMutableComposition *composition = [AVMutableComposition composition];
    DVGGLRotationMode inputRotation = [DVGOglEffectBase orientationForPrefferedTransform:videoTransform andSize:videoSize];
    videoSize = [DVGOglEffectBase landscapeSizeForOrientation:inputRotation andSize:videoSize];
    composition.naturalSize = videoSize;
    AVMutableVideoComposition *videoComposition = nil;
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.customVideoCompositorClass = [DVGStackableVideoCompositor class];
    [DVGStackableVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andEffectsStack:effstack forAsset:asset];
    
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

+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene
{
    DVGOglEffectKeyframedAnimation* kar = [[DVGOglEffectKeyframedAnimation alloc] init];
    kar.animationScene = animscene;
    return [DVGStackableVideoCompositor createPlayerItemWithAsset:asset andEffectsStack:@[kar]];
}

+ (AVPlayerItem*)createPlayerItemWithAsset:(AVAsset*)asset andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack
{
    NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([videoTracks count] == 0){
        return nil;
    }
    AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
    CGSize videoSize = [videoTrack naturalSize];
    if(videoSize.width < 1 || videoSize.height < 1){
        // wtf ??? ??? ??? ???
        videoSize = CGSizeMake(1360,768);
    }
    CGAffineTransform videoTransform = [videoTrack preferredTransform];
    AVMutableComposition *composition = [AVMutableComposition composition];
    DVGGLRotationMode inputRotation = [DVGOglEffectBase orientationForPrefferedTransform:videoTransform andSize:videoSize];
    videoSize = [DVGOglEffectBase landscapeSizeForOrientation:inputRotation andSize:videoSize];
    composition.naturalSize = videoSize;
    AVMutableVideoComposition *videoComposition = nil;
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.customVideoCompositorClass = [DVGStackableVideoCompositor class];
    [DVGStackableVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andEffectsStack:effstack forAsset:asset];
    
    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:composition];
    playerItem.videoComposition = videoComposition;
    return playerItem;
}


+ (BOOL)prepareComposition:(AVMutableComposition *)composition
        andVideoComposition:(AVMutableVideoComposition *)videoComposition
           andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack
                   forAsset:(AVAsset*)asset
{
    NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([videoTracks count] == 0){
        return NO;
    }
    AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
    CGSize videoSize = [videoTrack naturalSize];
    CGAffineTransform videoTransform = [videoTrack preferredTransform];
    CMTime videoDuration = [asset duration];
    AVMutableCompositionTrack *compositionVideoTrack;
    compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, videoDuration);
    [compositionVideoTrack insertTimeRange:timeRangeInAsset ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    
    NSArray* audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if([audioTracks count] > 0){
        AVMutableCompositionTrack *compositionAudioTrack;
        compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
        [compositionAudioTrack insertTimeRange:timeRangeInAsset ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    }
    NSMutableArray *instructions = [NSMutableArray array];
    DVGStackableCompositionInstruction *videoInstruction = [[DVGStackableCompositionInstruction alloc] initProcessingWithSourceTrackIDs:@[@(compositionVideoTrack.trackID)]
                                                                                                                   forTimeRange:timeRangeInAsset];
    for(DVGOglEffectBase* renderer in effstack){
        renderer.effectTrackID = compositionVideoTrack.trackID;
        renderer.effectTrackOrientation = [DVGOglEffectBase orientationForPrefferedTransform:videoTransform andSize:videoSize];
    }
    videoInstruction.renderersStack = effstack;
    [instructions addObject:videoInstruction];
    
    videoComposition.instructions = instructions;
    return YES;
}

@end
