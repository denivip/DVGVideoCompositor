#import "DVGStackableCompositionInstruction.h"
@implementation DVGStackableCompositionInstruction

- (id)initProcessingWithSourceTrackIDs:(NSArray *)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
        self.pools = @{}.mutableCopy;
		_requiredSourceTrackIDs = sourceTrackIDs;
		_passthroughTrackID = kCMPersistentTrackID_Invalid;
		_timeRange = timeRange;
		_containsTweening = TRUE;
		_enablePostProcessing = FALSE;
	}
	
	return self;
}

- (id)getPixelBufferPoolForWidth:(int)w andHeight:(int)h {
    NSString* key = [NSString stringWithFormat:@"pixpool_%i_%i",w,h];
    NSValue* pool = [self.pools objectForKey:key];
    if(pool == nil){
        CVPixelBufferPoolRef bufferPool = nil;
        NSMutableDictionary* attributes;
        attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
        NSDictionary *IOSurfaceProperties = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESFBOCompatibility",[NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESTextureCompatibility",nil];
        [attributes setObject:IOSurfaceProperties forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &bufferPool);
        pool = [NSValue valueWithPointer:bufferPool];
        [self.pools setObject:pool forKey:key];
    }
    return [pool pointerValue];
}

-(void)dealloc
{
    for (NSString* key in self.pools) {
        id value = [self.pools objectForKey:key];
        // do stuff
        if([key containsString:@"pixpool_"]){
            CVPixelBufferPoolRef bufferPool = [value pointerValue];
            CVPixelBufferPoolRelease(bufferPool);
        }
    }
    self.pools = nil;
    for(DVGOglEffectBase* renderer in self.renderersStack){
        [renderer releaseOglResources];
    }
}
@end
