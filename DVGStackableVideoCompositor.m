#import "DVGStackableCompositionInstruction.h"
#import "DVGStackableVideoCompositor.h"
#import "DVGOglEffectKeyframedAnimation.h"
#import "DVGOglEffectBase.h"
#import <CoreVideo/CoreVideo.h>
#import "DVGEasing.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;
NSString* kCompEffectOptionExportSize = @"kCompEffectOptionExportSize";
NSString* kCompEffectOptionProgressBlock = @"kCompEffectOptionProgressBlock";
dispatch_queue_t renderingQueue;
dispatch_queue_t renderContextQueue;

@interface DVGStackableVideoCompositor()
{
	BOOL								_shouldCancelAllRequests;
	BOOL								_renderContextDidChange;
    CVPixelBufferRef					_previousBuffer;
	AVVideoCompositionRenderContext*	_renderContext;
}

@end

static __weak DVGStackableVideoCompositor* g_activeCompositor;
static BOOL g_IsCompositingActive = YES;
@implementation DVGStackableVideoCompositor

#pragma mark - AVVideoCompositing protocol
+ (void) initialize
{
    renderingQueue = dispatch_queue_create("com.denivip.DVGStackableVideoCompositor.renderingqueue", DISPATCH_QUEUE_SERIAL);
    renderContextQueue = dispatch_queue_create("com.denivip.DVGStackableVideoCompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
}

- (id)init
{
	self = [super init];
	if (self)
	{
        _previousBuffer = nil;
		_renderContextDidChange = NO;
        g_activeCompositor = self;
	}
	return self;
}

+ (DVGStackableVideoCompositor*)getActiveVideoProcessingCompositor {
    return g_activeCompositor;
}

+ (void)enableCompositingGlobally:(BOOL)bEnable {
    g_IsCompositingActive = bEnable;
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
	dispatch_sync(renderContextQueue, ^() {
		_renderContext = newRenderContext;
		_renderContextDidChange = YES;
	});
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
	@autoreleasepool {
		dispatch_async(renderingQueue,^() {
			
			// Check if all pending requests have been cancelled
			if (_shouldCancelAllRequests || !g_IsCompositingActive) {
				[request finishCancelledRequest];
			} else {
				NSError *err = nil;
				// Get the next rendererd pixel buffer
				CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
				if (resultPixels) {
					// The resulting pixelbuffer from OpenGL renderer is passed along to the request
					[request finishWithComposedVideoFrame:resultPixels];
					CVPixelBufferRelease(resultPixels);
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
	
	dispatch_barrier_async(renderingQueue, ^() {
		// start accepting requests again
		_shouldCancelAllRequests = NO;
	});
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
    DVGStackableCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
    
    // tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
    // 0.0 indicates the time at first frame in that videoComposition timeRange
    // 1.0 indicates the time at last frame in that videoComposition timeRange
    CGFloat time = CMTimeGetSeconds(request.compositionTime);
    CMTime elapsed = CMTimeSubtract(request.compositionTime, request.videoCompositionInstruction.timeRange.start);
    float tweenFactor = CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(request.videoCompositionInstruction.timeRange.duration);
    currentInstruction.actualRenderSize = _renderContext.size;
    currentInstruction.actualRenderTime = time;
    currentInstruction.actualRenderProgress = tweenFactor;
    currentInstruction.actualRenderTransform = nil;
    if(currentInstruction.onBeforeRenderingFrame){
        currentInstruction.onBeforeRenderingFrame(currentInstruction);
        time = currentInstruction.actualRenderTime;
        tweenFactor = currentInstruction.actualRenderProgress;
    }
    if(_renderContextDidChange){
        currentInstruction.actualRenderTransform = [NSValue valueWithCGAffineTransform:_renderContext.renderTransform];
    }
    DVGStackableCompositionInstructionFrameBufferFabricator ibf = currentInstruction.onTrackFrameNeeded;
    if (ibf == nil){
        ibf = ^(CMPersistentTrackID effectTrackID){
            return [request sourceFrameByTrackID:effectTrackID];
        };
    }
    _renderContextDidChange = NO;
    return [DVGStackableVideoCompositor renderSingleFrameWithInstruction:currentInstruction trackFrameFabricator:ibf];
}

+ (CVPixelBufferRef)renderSingleFrameWithInstruction:(DVGStackableCompositionInstruction*)currentInstruction
                                trackFrameFabricator:(DVGStackableCompositionInstructionFrameBufferFabricator)ibf
{
    BOOL isOkRendered = YES;
    CVPixelBufferRef prevBuffer = nil;
    CVPixelBufferRef dstPixels = nil;
    //if(currentInstruction.lastOkRenderedPixels){isOkRendered = NO;}else{// DBG
    for(DVGOglEffectBase* renderer in currentInstruction.renderersStack){
        CGSize renderSize = currentInstruction.actualRenderSize;
        // Destination pixel buffer into which we render the output
        //if(renderer.effectRenderingUpscale != 1.0f){
        int videoWidth = renderSize.width*renderer.effectRenderingUpscale;
        int videoHeight = renderSize.height*renderer.effectRenderingUpscale;
        CVPixelBufferPoolRef bufferPool = (__bridge CVPixelBufferPoolRef)[currentInstruction getPixelBufferPoolForWidth:videoWidth andHeight:videoHeight];
        CVPixelBufferPoolCreatePixelBuffer(NULL, bufferPool, &dstPixels);
        //}else
        //{
        //    dstPixels = [rc newPixelBuffer];
        //}
        CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(dstPixels), CVPixelBufferGetHeight(dstPixels));
        // Recompute normalized render transform everytime the render context changes
        if (currentInstruction.actualRenderTransform != nil) {
            // The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
            // But since in this sample we render using OpenGLES which has its coordinate system between [-1, 1] we compute a normalized transform
            CGAffineTransform renderContextTransform = {renderSize.width/2, 0, 0, renderSize.height/2, renderSize.width/2, renderSize.height/2};
            CGAffineTransform destinationTransform = {2/destinationSize.width, 0, 0, 2/destinationSize.height, -1, -1};
            CGAffineTransform normalizedRenderTransform = CGAffineTransformConcat(CGAffineTransformConcat(renderContextTransform, [currentInstruction.actualRenderTransform CGAffineTransformValue]), destinationTransform);
            [renderer prepareTransform:normalizedRenderTransform];
        }

        CVPixelBufferRef trackBuffer = nil;
        DVGGLRotationMode trackOrientation = kDVGGLNoRotation;
        if(ibf && renderer.effectTrackID != kCMPersistentTrackID_Invalid){
            trackBuffer = ibf(renderer.effectTrackID);//[request sourceFrameByTrackID:renderer.effectTrackID];
            trackOrientation = renderer.effectTrackOrientation;
            if(trackBuffer == nil){
                isOkRendered = NO;
                NSLog(@"No frame for track %i, time: %0.02f. Falling back to last Ok frame", renderer.effectTrackID, currentInstruction.actualRenderTime);
                break;
            }
        }
        if(g_IsCompositingActive){
            [renderer renderIntoPixelBuffer:dstPixels
                                 prevBuffer:prevBuffer
                                trackBuffer:trackBuffer
                                trackOrient:trackOrientation
                                     atTime:currentInstruction.actualRenderTime
                                  withTween:currentInstruction.actualRenderProgress];
        }
        if(prevBuffer){
            CVPixelBufferRelease(prevBuffer);
            prevBuffer = nil;
        }
        prevBuffer = dstPixels;
    }
    //}
    // Do NOT releasing prevBuffer - it is == dstPixels, which will be freed on upper levels
    if(isOkRendered){
        if(currentInstruction.lastOkRenderedPixels){
            CVPixelBufferRelease(currentInstruction.lastOkRenderedPixels);
        }
        currentInstruction.lastOkRenderedPixels = dstPixels;
        CVPixelBufferRetain(currentInstruction.lastOkRenderedPixels);
    }else{
        if(dstPixels){
            CVPixelBufferRelease(dstPixels);
        }
        dstPixels = currentInstruction.lastOkRenderedPixels;
        CVPixelBufferRetain(dstPixels);
    }
	return dstPixels;
}

+ (AVAssetExportSession*)createExportSessionWithAsset:(AVAsset*)asset andAnimationScene:(DVGKeyframedAnimationScene*)animscene
{
    DVGOglEffectKeyframedAnimation* kar = [[DVGOglEffectKeyframedAnimation alloc] init];
    kar.animationScene = animscene;
    kar.adjustScaleForAspectRatio = YES;
    return [DVGStackableVideoCompositor createExportSessionWithAssets:@[asset] andEffectsStack:@[kar] options:nil];
}

+ (AVAssetExportSession*)createExportSessionWithAssets:(NSArray<AVAsset*>*)assets andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack options:(NSDictionary*)svcOptions
{
    if([assets count] == 0){
        return nil;
    }
    AVAsset* asset = [assets objectAtIndex:0];
    NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([videoTracks count] == 0){
        return nil;
    }
    CGSize outsize = CGSizeMake(0, 0);
    if(svcOptions && [svcOptions valueForKey:kCompEffectOptionExportSize] != nil){
        outsize = [[svcOptions valueForKey:kCompEffectOptionExportSize] CGSizeValue];
    }
    AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
    CGSize videoSize = [videoTrack naturalSize];
    CGAffineTransform videoTransform = [videoTrack preferredTransform];
    AVMutableComposition *composition = [AVMutableComposition composition];
    DVGGLRotationMode inputRotation = [DVGOglEffectBase orientationForPrefferedTransform:videoTransform andSize:videoSize];
    videoSize = [DVGOglEffectBase landscapeSizeForOrientation:inputRotation andSize:videoSize];
    if(outsize.width > 0 && outsize.height > 0){
        videoSize = outsize;
    }
    composition.naturalSize = videoSize;
    AVMutableVideoComposition *videoComposition = nil;
    videoComposition = [AVMutableVideoComposition videoComposition];
    [DVGStackableVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andEffectsStack:effstack
                                          forAssets:assets
                                           withSize:videoSize
                                    withOrientation:inputRotation
                                        withOptions:svcOptions];
    
    if (videoComposition) {
        AVAssetExportSession* exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        CMTime frameDur = videoTrack.minFrameDuration;// Preserving ORIGINAL fps!
        if(CMTIME_IS_INVALID(frameDur)){
            frameDur = CMTimeMake(1, 30); // 30 fps
        }
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = frameDur;
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
    kar.adjustScaleForAspectRatio = YES;
    return [DVGStackableVideoCompositor createPlayerItemWithAssets:@[asset] andEffectsStack:@[kar] options:nil];
}

+ (AVPlayerItem*)createPlayerItemWithAssets:(NSArray<AVAsset*>*)assets andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack options:(NSDictionary*)svcOptions
{
    if([assets count] == 0){
        return nil;
    }
    AVAsset* asset = [assets objectAtIndex:0];
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
    [DVGStackableVideoCompositor prepareComposition:composition andVideoComposition:videoComposition andEffectsStack:effstack
                                          forAssets:assets
                                           withSize:videoSize
                                    withOrientation:inputRotation
                                        withOptions:svcOptions];
    
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
           andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack_raw
                 forAssets:(NSArray<AVAsset*>*)assets
                   withSize:(CGSize)videoSize
                  withOrientation:(DVGGLRotationMode)orientation
               withOptions:(NSDictionary*)svcOptions
{
    if([assets count] == 0){
        return NO;
    }
    AVAsset* asset = [assets objectAtIndex:0];
    NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([videoTracks count] == 0){
        return NO;
    }
    AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
    AVMutableCompositionTrack *compositionVideoTrack;
    compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, [asset duration]);
    [compositionVideoTrack insertTimeRange:timeRangeInAsset ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    CGSize videoOrigSize = [videoTrack naturalSize];
    DDLogWarn(@"prepareComposition: Adding base track, origsize: %0.02f:%0.02f, duration: %0.02fs", videoOrigSize.width, videoOrigSize.height, CMTimeGetSeconds([asset duration]));
    NSArray* audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if([audioTracks count] > 0){
        AVMutableCompositionTrack *compositionAudioTrack;
        compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
        [compositionAudioTrack insertTimeRange:timeRangeInAsset ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    }
    NSMutableArray *instructions = [NSMutableArray array];
    NSArray *effstack = [effstack_raw filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id effect, NSDictionary *bindings) {
        return [effect isKindOfClass:[DVGOglEffectBase class]];
    }]];
    NSMutableArray* compositionTracks = @[@(compositionVideoTrack.trackID)].mutableCopy;
    if([assets count] > 1){
        for(int ti = 1;ti<[assets count];ti++){
            AVAsset* asset2 = [assets objectAtIndex:ti];
            NSArray* videoTracks2 = [asset2 tracksWithMediaType:AVMediaTypeVideo];
            if([videoTracks2 count] == 0){
                continue;
            }
            AVAssetTrack* videoTrack2 = [videoTracks2 objectAtIndex:0];
            AVMutableCompositionTrack *compositionVideoTrack2;
            compositionVideoTrack2 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            CMTimeRange timeRangeInAsset2 = CMTimeRangeMake(kCMTimeZero, [asset2 duration]);
            DDLogWarn(@"prepareComposition: Adding track %i, duration: %0.02fs", compositionVideoTrack2.trackID, CMTimeGetSeconds([asset2 duration]));
            NSError* insertErr = nil;
            [compositionVideoTrack2 insertTimeRange:timeRangeInAsset2 ofTrack:videoTrack2 atTime:kCMTimeZero error:&insertErr];
            if(insertErr){
                DDLogError(@"prepareComposition: Can`t insert track %@", videoTrack2);
            }else{
                [compositionTracks addObject:@(compositionVideoTrack2.trackID)];
            }
        }
    }
    if([effstack count]>0){
        videoComposition.customVideoCompositorClass = [DVGStackableVideoCompositor class];
        DVGStackableCompositionInstruction *videoInstruction = [[DVGStackableCompositionInstruction alloc] initProcessingWithSourceTrackIDs:compositionTracks
                                                                                                                               forTimeRange:timeRangeInAsset];
        if(svcOptions != nil){
            videoInstruction.onBeforeRenderingFrame = [svcOptions objectForKey:kCompEffectOptionProgressBlock];
        }
        int renderers = 0;
        for(DVGOglEffectBase* renderer in effstack){
            NSInteger trackIdx = renderer.effectTrackIndex;
            if(renderers == 0 && trackIdx == kCMPersistentTrackID_Invalid)
            {
                trackIdx = 1;
            }
            if(trackIdx <= 0 || trackIdx-1 >= [compositionTracks count]){
                trackIdx = 0;
            }
            renderer.effectTrackID = (trackIdx>0)?[[compositionTracks objectAtIndex:trackIdx-1] intValue]:kCMPersistentTrackID_Invalid;
            renderer.effectTrackOrientation = orientation;
            renderers++;
        }
        videoInstruction.renderersStack = effstack;
        [instructions addObject:videoInstruction];
    }else{
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        passThroughInstruction.timeRange = timeRangeInAsset;
        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayer];
        [instructions addObject:passThroughInstruction];
    }
    videoComposition.instructions = instructions;
    return YES;
}

+ (UIImage*)renderSingleFrameWithImage:(UIImage*)frame andEffectsStack:(NSArray<DVGOglEffectBase*>*)effstack options:(NSDictionary*)svcOptions {
    __block  UIImage* res = nil;
    dispatch_sync(renderingQueue,^() {
        if(g_IsCompositingActive){
            DVGStackableCompositionInstruction *videoInstruction = [[DVGStackableCompositionInstruction alloc] initProcessingZero];
            videoInstruction.actualRenderSize = frame.size;
            videoInstruction.actualRenderTime = 0;
            videoInstruction.actualRenderProgress = 0;
            videoInstruction.actualRenderTransform = nil;
            videoInstruction.renderersStack = effstack;
            videoInstruction.actualRenderTransform = [NSValue valueWithCGAffineTransform:CGAffineTransformIdentity];
            UIImage* frameFlipped = frame;//[DVGOglEffectBase imageWithFlippedRGBOfImage:frame];
            CGImageRef frameFlippedCG = [frameFlipped CGImage];
            CVPixelBufferRef frameBuffer = [DVGOglEffectBase createPixelBufferFromCGImage:frameFlippedCG];
            DVGStackableCompositionInstructionFrameBufferFabricator ibf = ^(CMPersistentTrackID effectTrackID){
                return frameBuffer;
            };
            
            //CVPixelBufferRef buff = ibf(0);CFRetain(buff);
            CVPixelBufferRef buff = [DVGStackableVideoCompositor renderSingleFrameWithInstruction:videoInstruction trackFrameFabricator:ibf];
            CGImageRef cgImage = [DVGOglEffectBase createCGImageFromPixelBuffer:buff];
            if(cgImage != nil){
                res = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];
            }
            if(buff != nil){
                CVPixelBufferRelease(buff);
                
            }
            if(cgImage != nil){
                CGImageRelease(cgImage);
            }
            if(frameBuffer != nil){
                CVPixelBufferRelease(frameBuffer);
            }
        }
    });
    return res;
}

@end
