#import "DVGOglEffectBase.h"
#import "DVGStackableCompositionInstruction.h"

@implementation DVGOglEffectShader

- (id)init
{
    self = [super init];
    if(self) {
        self.rplUniforms = malloc(sizeof(GLint)*MAX_UNIFORMS_COUNT);
    }
    return self;
}

- (void)dealloc
{
    free(self.rplUniforms);
}
@end

@interface DVGOglEffectBase ()
@property NSMutableArray<DVGOglEffectShader*>* shaders;
@property CVOpenGLESTextureCacheRef rplTextureCache;
@property CGAffineTransform rplRenderTransform;
@property GLuint offscreenBufferHandle;
@property BOOL oglResourcesPrepared;
@property int activeShader;

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type source:(NSString *)source;
- (BOOL)linkProgram:(GLuint)prog;
@end

@implementation DVGOglEffectBase

- (id)init
{
    self = [super init];
    if(self) {
        self.rplContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.effectTrackID = kCMPersistentTrackID_Invalid;
        self.effectTrackIndex = kCMPersistentTrackID_Invalid;
        self.rplRenderTransform = CGAffineTransformIdentity;
        self.effectRenderingBlendMode = DVGGLBlendNormal;
        self.effectTrackOrientation = kDVGGLNoRotation;
        self.effectRenderingUpscale = 1.0;
        self.shaders = @[].mutableCopy;
        self.activeShader = 0;
    }
    return self;
}

- (void)dealloc
{
    [self releaseOglResources];
}

- (void)prepareContextForRendering
{
    [EAGLContext setCurrentContext:self.rplContext];
    if(!self.oglResourcesPrepared){
        self.oglResourcesPrepared = YES;
        [self prepareOglResources];
    }
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    if(self.effectRenderingBlendMode == DVGGLBlendAdd){
        glBlendEquation(GL_FUNC_ADD);
        //glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        glBlendFunc(GL_ONE, GL_ONE);
    }else{
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);
}

-(void)releaseContextForRendering
{
    glUseProgram(0);
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(self.rplTextureCache, 0);
    [EAGLContext setCurrentContext:nil];
}

- (void)prepareOglResources
{
    //-- Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (_rplTextureCache) {
        CFRelease(_rplTextureCache);
        _rplTextureCache = NULL;
    }
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _rplContext, NULL, &_rplTextureCache);
    if (err != noErr) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
    }

    glGenFramebuffers(1, &_offscreenBufferHandle);
    //glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
}

- (void)releaseOglResources
{
    [EAGLContext setCurrentContext:self.rplContext];
    glUseProgram(0);
    for(DVGOglEffectShader* shader in self.shaders){
        glDeleteProgram(shader.rplProgram);
        shader.rplProgram = 0;
    }
    if (_rplTextureCache) {
        // Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(_rplTextureCache, 0);
        CFRelease(_rplTextureCache);
        _rplTextureCache = nil;
    }
    if (_offscreenBufferHandle) {
        glDeleteFramebuffers(1, &_offscreenBufferHandle);
        _offscreenBufferHandle = 0;
    }
    [EAGLContext setCurrentContext:nil];
    self.rplContext = nil;
    self.oglResourcesPrepared = NO;
}

- (void)prepareTransform:(CGAffineTransform)normalizedRenderTransform
{
    self.rplRenderTransform = normalizedRenderTransform;
}

- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                  trackBuffer:(CVPixelBufferRef)trackBuffer
                  trackOrient:(DVGGLRotationMode)trackOrientation
                       atTime:(CGFloat)time withTween:(float)tweenFactor
{
    // Should not be called
	[self doesNotRecognizeSelector:_cmd];
}

//=====================
- (void)activateContextShader:(int)shaderid
{
    self.activeShader = shaderid - 1;
    DVGOglEffectShader* shader = [self.shaders objectAtIndex:self.activeShader];
    glUseProgram(shader.rplProgram);
    // Set the render transform
    GLKMatrix4 renderTransform = GLKMatrix4Make(
                                                self.rplRenderTransform.a, self.rplRenderTransform.b, self.rplRenderTransform.tx, 0.0,
                                                self.rplRenderTransform.c, self.rplRenderTransform.d, self.rplRenderTransform.ty, 0.0,
                                                0.0,					   0.0,										1.0, 0.0,
                                                0.0,					   0.0,										0.0, 1.0
                                                );
    glUniformMatrix4fv(shader.rplUniforms[UNIFORM_RENDER_TRANSFORM_RPL], 1, GL_FALSE, renderTransform.m);
}

- (int)getActiveShaderUniform:(int)uniform {
    DVGOglEffectShader* shader = [self.shaders objectAtIndex:self.activeShader];
    return shader.rplUniforms[uniform];
}

- (int)prepareVertexShader:(NSString*)vertShaderSource withFragmentShader:(NSString*)fragShaderSource withAttribs:(NSArray*)attribPairs withUniforms:(NSArray*)uniformPairs;
{
	GLuint vertShader, fragShader;
    DVGOglEffectShader* shader = [DVGOglEffectShader new];
    shader.rplProgramAttPairs = attribPairs;
    shader.rplProgramUniPairs = uniformPairs;
	// Create the shader program.
	shader.rplProgram = glCreateProgram();
	
	// Create and compile the vertex shader.
	if (![self compileShader:&vertShader type:GL_VERTEX_SHADER source:vertShaderSource]) {
		NSLog(@"Failed to compile vertex shader");
		return -1;
	}
	
	// Create and compile Y fragment shader.
	if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER source:fragShaderSource]) {
		NSLog(@"Failed to compile Y fragment shader");
		return -1;
	}
	
	// Attach vertex shader to rplProgram.
	glAttachShader(shader.rplProgram, vertShader);
	
	// Attach fragment shader to rplProgram.
	glAttachShader(shader.rplProgram, fragShader);

	// Bind attribute locations. This needs to be done prior to linking.
	//glBindAttribLocation(_rplProgram, ATTRIB_VERTEX_RPL, "position");
	//glBindAttribLocation(_rplProgram, ATTRIB_TEXCOORD_RPL, "texCoord");
    for(NSArray* attpair in shader.rplProgramAttPairs){
        glBindAttribLocation(shader.rplProgram, [[attpair objectAtIndex:0] intValue], [[attpair objectAtIndex:1] cStringUsingEncoding:NSASCIIStringEncoding]);
    }
	   
	// Link the program.
	if (![self linkProgram:shader.rplProgram]) {
		NSLog(@"Failed to link program: %d", shader.rplProgram);
		
		if (vertShader) {
			glDeleteShader(vertShader);
			vertShader = 0;
		}
		if (fragShader) {
			glDeleteShader(fragShader);
			fragShader = 0;
		}

		if (shader.rplProgram) {
			glDeleteProgram(shader.rplProgram);
			shader.rplProgram = 0;
		}
		
		return -1;
	}
	
	// Get uniform locations.
    for(NSArray* attpair in shader.rplProgramUniPairs){
        shader.rplUniforms[[[attpair objectAtIndex:0] intValue]] = glGetUniformLocation(shader.rplProgram, [[attpair objectAtIndex:1] cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
	// Release vertex and fragment shaders.
	if (vertShader) {
		glDetachShader(shader.rplProgram, vertShader);
		glDeleteShader(vertShader);
	}
	if (fragShader) {
		glDetachShader(shader.rplProgram, fragShader);
		glDeleteShader(fragShader);
	}
    [self.shaders addObject:shader];
    int shaderid = (int)[self.shaders count];
    return shaderid;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type source:(NSString *)sourceString
{
    if (sourceString == nil) {
		NSLog(@"Failed to load vertex shader: Empty source string");
        return NO;
    }
    
	GLint status;
	const GLchar *source;
	source = (GLchar *)[sourceString UTF8String];
	
	*shader = glCreateShader(type);
	glShaderSource(*shader, 1, &source, NULL);
	glCompileShader(*shader);
	
#if defined(DEBUG)
	GLint logLength;
	glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetShaderInfoLog(*shader, logLength, &logLength, log);
		NSLog(@"Shader compile log:\n%s", log);
		free(log);
	}
#endif
	
	glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
	if (status == 0) {
		glDeleteShader(*shader);
		return NO;
	}
	
	return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
	GLint status;
	glLinkProgram(prog);
	
#if defined(DEBUG)
	GLint logLength;
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(prog, logLength, &logLength, log);
		NSLog(@"Program link log:\n%s", log);
		free(log);
	}
#endif
	
	glGetProgramiv(prog, GL_LINK_STATUS, &status);
	if (status == 0) {
		return NO;
	}
	
	return YES;
}

- (CVOpenGLESTextureRef)bgraTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if(!pixelBuffer){
        return nil;
    }
    CVOpenGLESTextureRef bgraTexture = NULL;
    CVReturn err;
    
    if (!_rplTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }
    
    // CVOpenGLTextureCacheCreateTextureFromImage will create GL texture optimally from CVPixelBufferRef.
    // Y
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _rplTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RGBA,//GL_RED_EXT,
                                                       (int)CVPixelBufferGetWidth(pixelBuffer),
                                                       (int)CVPixelBufferGetHeight(pixelBuffer),
                                                       GL_RGBA,//GL_BGRA,//GL_RED_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &bgraTexture);
    
    if (!bgraTexture || err) {
        NSLog(@"Error at creating texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
bail:
    return bgraTexture;
}

- (NSInteger)getMaxTextureSize {
    int max;
    [EAGLContext setCurrentContext:self.rplContext];
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max);
    return max;
}

+ (CGSize)landscapeSizeForOrientation:(DVGGLRotationMode)rotation andSize:(CGSize)videoSize
{
    if((rotation) == kDVGGLRotateLeft || (rotation) == kDVGGLRotateRight || (rotation) == kDVGGLRotateRightFlipVertical || (rotation) == kDVGGLRotateRightFlipHorizontal){
        videoSize = CGSizeMake(videoSize.height,videoSize.width);
    }
    return videoSize;
}

+ (DVGGLRotationMode)orientationForPrefferedTransform:(CGAffineTransform)preferredTransform andSize:(CGSize)videoSize
{
    DVGGLRotationMode orient = kDVGGLNoRotation;
    if (preferredTransform.a == 0.f && preferredTransform.b == -1.f &&
        preferredTransform.c == 1.f && preferredTransform.d == 0.f) {
        if(videoSize.height > videoSize.width){
            orient = kDVGGLRotateLeft;
        }else{
            orient = kDVGGLFlipVertical;
        }
    }else if (preferredTransform.a == -1.f && preferredTransform.b == 0.f &&
                  preferredTransform.c == 0.f && preferredTransform.d == -1.f) {
        orient = kDVGGLRotate180;
    }else if (preferredTransform.a == 0.f && preferredTransform.d == 0.f &&
              (preferredTransform.b == 1.f || preferredTransform.b == -1.f) &&
              (preferredTransform.c == 1.f || preferredTransform.c == -1.f)) {
        orient = kDVGGLRotateRight;
    }
    return orient;
}

+ (const GLfloat *)traformRSForRotation:(DVGGLRotationMode)rotationMode
{
    // Rotation, scaleX, scaleY
    static const GLfloat noRotationTransformRS[] = {
        0.0f, 1.0f, 1.0f
    };
    static const GLfloat rotateRightTransformRS[] = {
        M_PI_2, 1.0f, 1.0f
    };
    static const GLfloat rotateLeftTransformRS[] = {
        -M_PI_2, 1.0f, 1.0f
    };
    static const GLfloat rotate180TransformRS[] = {
        M_PI, 1.0f, 1.0f
    };
    switch(rotationMode)
    {
        case kDVGGLNoRotation: return noRotationTransformRS;
        case kDVGGLRotateLeft: return rotateLeftTransformRS;
        case kDVGGLRotateRight: return rotateRightTransformRS;
//      case kDVGGLFlipVertical: return verticalFlipTextureCoordinates;
//      case kDVGGLFlipHorizonal: return horizontalFlipTextureCoordinates;
//      case kDVGGLRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
//      case kDVGGLRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kDVGGLRotate180: return rotate180TransformRS;
        default: return noRotationTransformRS;
    }
}

+ (const GLfloat *)textureCoordinatesForRotation:(DVGGLRotationMode)rotationMode
{
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f,  0.0f,
        1.0f,  0.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f,  1.0f,
        0.0f,  1.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    switch(rotationMode)
    {
        case kDVGGLNoRotation: return noRotationTextureCoordinates;
        case kDVGGLRotateLeft: return rotateLeftTextureCoordinates;
        case kDVGGLRotateRight: return rotateRightTextureCoordinates;
        case kDVGGLFlipVertical: return verticalFlipTextureCoordinates;
        case kDVGGLFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kDVGGLRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kDVGGLRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kDVGGLRotate180: return rotate180TextureCoordinates;
    }
}

+ (GLKTextureInfo*)createGLKTextureFromCGImage:(CGImageRef)image
{
    NSError *error;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], GLKTextureLoaderOriginBottomLeft, nil];
    GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithCGImage:image options:options error:&error];
    if (textureInfo == nil) {
        NSLog(@"[SF] Texture Error:%@", error);
    }
    return textureInfo;
}

static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    CVPixelBufferRelease( pixelBuffer );
}

+ (CGImageRef)createCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    OSStatus err = noErr;
    size_t width, height, sourceRowBytes;
    void *sourceBaseAddr = NULL;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big;
    CGColorSpaceRef colorspace = NULL;
    CGDataProviderRef provider = NULL;
    CGImageRef image = NULL;
    
//    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
//    if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
//        bitmapInfo = kCGBitmapByteOrder32Big;// | kCGImageAlphaNoneSkipFirst;
//    else if ( kCVPixelFormatType_32RGBA == sourcePixelFormat )
//        bitmapInfo = kCGBitmapByteOrder32Little;// | kCGImageAlphaNoneSkipFirst;
//    else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
//        bitmapInfo = kCGBitmapByteOrder32Little;// | kCGImageAlphaNoneSkipFirst;
//    else
//        return nil;//-95014; // only uncompressed pixel formats
    
    sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
    width = CVPixelBufferGetWidth( pixelBuffer );
    height = CVPixelBufferGetHeight( pixelBuffer );
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
    colorspace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRetain( pixelBuffer );
    provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
    image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
    
    if ( err && image ) {
        CGImageRelease( image );
        image = NULL;
    }
    if ( provider ) CGDataProviderRelease( provider );
    if ( colorspace ) CGColorSpaceRelease( colorspace );

    return image;
}

+ (CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image
{
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = @{
                              (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                              (NSString *)kCVPixelBufferOpenGLCompatibilityKey: @YES,
                              (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
                             // (__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
                             // (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
                              //(__bridge NSString *)kCVPixelBufferOpenGLCompatibilityKey: @(YES)
                             };
    CVPixelBufferRef pixelBuffer;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameSize.width,
                                          frameSize.height,
                                          kCVPixelFormatType_32BGRA,//preflipped for opengl + GL_RGBA
                                          (__bridge CFDictionaryRef) options,
                                          &pixelBuffer);
    if (status != kCVReturnSuccess) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, frameSize.width, frameSize.height,
                                                 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace,
                                                 (CGBitmapInfo) kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

+ (GLKMatrix3)CGAffineTransformToGLKMatrix3:(CGAffineTransform)affineTransform
{
    return GLKMatrix3Make(affineTransform.a,  affineTransform.b,  0,
                          affineTransform.c,  affineTransform.d,  0,
                          affineTransform.tx, affineTransform.ty, 1 );
}

+(UIImage *)imageWithFlippedRGBOfImage:(UIImage *)image
{
    // ??? vImageConvert_RGB888toARGB8888
    // ??? http://stackoverflow.com/questions/11607753/cvopenglestexturecachecreatetexturefromimage-on-ipad2-is-too-slow-it-needs-almo
    CGSize layerPixelSize = image.size;
    CGImageRef imageRef = image.CGImage;
    size_t width                    = (int)layerPixelSize.width;//CGImageGetWidth(imageRef);
    size_t height                   = (int)layerPixelSize.height;//CGImageGetHeight(imageRef);
    size_t bitsPerComponent         = 8;//CGImageGetBitsPerComponent(imageRef);
    size_t bitsPerPixel             = 32;//CGImageGetBitsPerPixel(imageRef);
    size_t bytesPerPixel            = 4;
    size_t bytesPerRow              = (int)width * bytesPerPixel;//CGImageGetBytesPerRow(imageRef);
    CGBitmapInfo bitmapInfo         = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;//CGImageGetBitmapInfo(imageRef);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    size_t imageDataLen = height * width * bytesPerPixel;
    unsigned char *imageData = (unsigned char*) calloc(imageDataLen, sizeof(unsigned char));
    CGContextRef context = CGBitmapContextCreate(imageData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorspace,
                                                 bitmapInfo);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // run through every pixel, a scan line at a time...
    for(int y = 0; y < (int)layerPixelSize.height; y++)
    {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &imageData[y * ((int)layerPixelSize.width) * 4];
        
        // step through the pixels one by one...
        for(int x = 0; x < (int)layerPixelSize.width; x++)
        {
            int r, g, b;
            r = linePointer[0];
            g = linePointer[1];
            b = linePointer[2];
            linePointer[0] = b;
            linePointer[1] = g;
            linePointer[2] = r;
            linePointer += 4;
        }
    }
    
    // create a new image from the modified pixel data
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, imageData, imageDataLen, NULL);
    CGImageRef newImageRef = CGImageCreate (
                                            width,
                                            height,
                                            bitsPerComponent,
                                            bitsPerPixel,
                                            bytesPerRow,
                                            colorspace,
                                            bitmapInfo,
                                            provider,
                                            NULL,
                                            false,
                                            kCGRenderingIntentDefault
                                            );
    // the modified image
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    CGColorSpaceRelease(colorspace);
    CGDataProviderRelease(provider);
    CGImageRelease(newImageRef);
    //free(imageData);// should not be freed, or UIImage will be BROKEN!!!
    return newImage;
}

+ (void)applyTransform:(CGAffineTransform)trf toCoords:(GLfloat*)textureCoords amount:(int)c center:(CGPoint)center {
    for(int i=0; i < c*2; i += 2){
        CGPoint tp1 = CGPointMake(textureCoords[i]-center.x, textureCoords[i+1]-center.y);
        tp1 = CGPointApplyAffineTransform(tp1, trf);
        textureCoords[i] = tp1.x+center.x;
        textureCoords[i+1] = tp1.y+center.y;
    }
}
@end
