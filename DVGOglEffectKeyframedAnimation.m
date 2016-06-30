#import "DVGOglEffectKeyframedAnimation.h"
#define kMaxLayersPerFrame 50

enum
{
    UNIFORM_KEYFA_SAMPLER2_RPL
};

static NSString* kEffect2VertexShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texCoord;
 attribute vec2 texCoord2;

 uniform mat4 renderTransform;
 varying vec2 texCoordVarying1;
 varying vec2 texCoordVarying2;
 void main()
 {
     gl_Position = position * renderTransform;
     texCoordVarying1 = texCoord;
     texCoordVarying2 = texCoord2;
 }
 );

static NSString* kEffect2FragmentShader = SHADER_STRING
(
 uniform highp vec4 rplColorTint;
 varying highp vec2 texCoordVarying1;
 varying highp vec2 texCoordVarying2;
 uniform sampler2D rplSampler;
 uniform sampler2D rplSampler2;
 void main()
 {
     highp vec4 textColor1 = texture2D(rplSampler, texCoordVarying1);
     highp vec4 textColor2 = texture2D(rplSampler2, texCoordVarying2);
     gl_FragColor = rplColorTint*textColor1*textColor2;
 }
 );

static NSString* kEffectVertexShader = SHADER_STRING
(
    attribute vec4 position;
    attribute vec2 texCoord;
    uniform mat4 renderTransform;
    varying vec2 texCoordVarying;
    void main()
    {
        gl_Position = position * renderTransform;
        texCoordVarying = texCoord;
    }
);

static NSString* kEffectFragmentShader = SHADER_STRING
(
    varying highp vec2 texCoordVarying;
    uniform highp vec4 rplColorTint;
    uniform sampler2D rplSampler;
    void main()
    {
        highp vec4 textColor = texture2D(rplSampler, texCoordVarying);
        gl_FragColor = rplColorTint*textColor;
    }
);

@interface DVGOglEffectKeyframedAnimation ()
@property NSMutableArray* objectsOglBuffers;
@end

@implementation DVGOglEffectKeyframedAnimation
-(GLKTextureInfo*)fetchOGLTextureForObject:(NSInteger)objectIndex
{
    id bf = [self.objectsOglBuffers objectAtIndex:objectIndex];
    if(bf == [NSNull null]){
        return nil;
    }
    return (GLKTextureInfo*)bf;
}

-(void)prepareOglResources
{
    [super prepareOglResources];
    [self prepareVertexShader:kEffectVertexShader withFragmentShader:kEffectFragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"texCoord"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"rplSampler"],
                                @[@(UNIFORM_SHADER_COLORTINT_RPL), @"rplColorTint"]
                                ]
     ];
    [self prepareVertexShader:kEffect2VertexShader withFragmentShader:kEffect2FragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"texCoord"],
                                @[@(ATTRIB_TEXCOORD2_RPL), @"texCoord2"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"rplSampler"],
                                @[@(UNIFORM_KEYFA_SAMPLER2_RPL), @"rplSampler2"],
                                @[@(UNIFORM_SHADER_COLORTINT_RPL), @"rplColorTint"]
                                ]
     ];
    self.objectsOglBuffers = @[].mutableCopy;
    for(DVGKeyframedAnimationSceneObject* obj in self.animationScene.objects){
        CGImageRef imageRef=[obj.objectImage CGImage];
        GLKTextureInfo* bf = [DVGOglEffectBase createGLKTextureFromCGImage:imageRef];
        if(bf){
            [self.objectsOglBuffers addObject:bf];
        }else{
            [self.objectsOglBuffers addObject:[NSNull null]];
        }
    }
}

-(void)releaseOglResources
{
    for(int i=0;i<[self.objectsOglBuffers count];i++){
        GLKTextureInfo* ti = [self fetchOGLTextureForObject:i];
        if(ti){
            GLuint name = ti.name;
            glDeleteTextures(1, &name);
        }
    }
    self.objectsOglBuffers = nil;
    [super releaseOglResources];
}

- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                  trackBuffer:(CVPixelBufferRef)trackBuffer
                  trackOrient:(DVGGLRotationMode)trackOrientation
                       atTime:(CGFloat)time withTween:(float)tweenFactor
{
    [self prepareContextForRendering];
    CVPixelBufferRef trackBufferOriginal = trackBuffer;
    if(prevBuffer != nil){
        trackBuffer = prevBuffer;
        trackOrientation = kDVGGLNoRotation;
    }
    //CVOpenGLESTextureRef layersTextures[kMaxLayersPerFrame] = {0};
    NSInteger layersCount = MIN(kMaxLayersPerFrame,[self.animationScene.objects count]);
    if (trackBuffer != NULL) {
        CVOpenGLESTextureRef trckBGRATexture = [self bgraTextureForPixelBuffer:trackBuffer];
        CVOpenGLESTextureRef destBGRATexture = [self bgraTextureForPixelBuffer:destBuffer];
        CVOpenGLESTextureRef trcoBGRATexture = nil;
        if(self.objectsRenderingMode == kDVGOEKA_trackAsTexture){
            trcoBGRATexture = [self bgraTextureForPixelBuffer:trackBufferOriginal];
        }
        // Attach the destination texture as a color attachment to the off screen frame buffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destBGRATexture), CVOpenGLESTextureGetName(destBGRATexture), 0);
        CGFloat vport_w = CVPixelBufferGetWidth(destBuffer);//CVPixelBufferGetWidthOfPlane(destBuffer, 0);// ios8 compatible way
        CGFloat vport_h = CVPixelBufferGetHeight(destBuffer);//CVPixelBufferGetHeightOfPlane(destBuffer, 0);// ios8 compatible way
        glViewport(0, 0, (int)vport_w, (int)vport_h);
		
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(trckBGRATexture), CVOpenGLESTextureGetName(trckBGRATexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
			NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
			goto bail;
		}
		
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

        [self activateContextShader:1];
        if(self.objectsRenderingMode != kDVGOEKA_trackAsTexture || prevBuffer != nil){
            static const GLfloat backgroundVertices[] = {
                -1.0f, -1.0f,
                1.0f, -1.0f,
                -1.0f,  1.0f,
                1.0f,  1.0f,
            };
            
            glUniform1i([self getActiveShaderUniform:UNIFORM_SHADER_SAMPLER_RPL], 0);
            glVertexAttribPointer(ATTRIB_VERTEX_RPL, 2, GL_FLOAT, 0, 0, backgroundVertices);
            glEnableVertexAttribArray(ATTRIB_VERTEX_RPL);
            glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, [DVGOglEffectBase textureCoordinatesForRotation:trackOrientation]);
            glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
            
            GLfloat basecolortint[4] = {1,1,1,1};
            glUniform4fv([self getActiveShaderUniform:UNIFORM_SHADER_COLORTINT_RPL], 1, basecolortint);
            
            // Draw the background frame
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }
        
        if(self.objectsRenderingMode == kDVGOEKA_trackAsTexture){
            if(trcoBGRATexture){
                [self activateContextShader:2];
                glUniform1i([self getActiveShaderUniform:UNIFORM_KEYFA_SAMPLER2_RPL], 1);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(CVOpenGLESTextureGetTarget(trcoBGRATexture), CVOpenGLESTextureGetName(trcoBGRATexture));
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            }
        }
        for(int i=0; i < layersCount; i++){
            //CVPixelBufferRef bf = [currentInstruction.animationScene fetchOGLBufferForObject:i];
            //CVOpenGLESTextureRef layerBGRATexture = [self bgraTextureForPixelBuffer:bf];
            GLKTextureInfo *layerBGRATexture = [self fetchOGLTextureForObject:i];
            if(layerBGRATexture){
                DVGKeyframedAnimationSceneObject* layerObj = [self.animationScene.objects objectAtIndex:i];
                CGFloat layerObjWidth = layerObj.relativeSize.width;
                CGFloat layerObjHeigth = layerObj.relativeSize.height;
                CGFloat layerObjAspect = 1;
                if(layerObjWidth <= 0){
                    // calcualting from height
                    layerObjAspect = vport_w/vport_h;
                    layerObjWidth = layerObjHeigth*layerObj.objectImage.size.width/layerObj.objectImage.size.height;
                }else if(layerObjHeigth <= 0){
                    // calcualting from width
                    layerObjAspect = vport_w/vport_h;
                    layerObjHeigth = layerObjWidth*layerObj.objectImage.size.height/layerObj.objectImage.size.width;
                }
                CGFloat layerValues[kDVGVITimelineKeyLast] = {0};
                [self.animationScene fetchKeyedValues:layerValues atTime:time forObject:i];
                //#warning Ignoring scale
                //layerValues[kDVGVITimelineXScaleKey]=layerValues[kDVGVITimelineYScaleKey]=1.0;
                //NSLog(@"layer pos: %.02f:%.02f at %.02f",layerValues[kDVGVITimelineXPosKey],layerValues[kDVGVITimelineYPosKey],time);
                CGAffineTransform modelMatrix = CGAffineTransformIdentity;
                modelMatrix = CGAffineTransformTranslate(modelMatrix, layerValues[kDVGVITimelineXPosKey] , layerValues[kDVGVITimelineYPosKey]);
                modelMatrix = CGAffineTransformScale(modelMatrix, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]*layerObjAspect);
                modelMatrix = CGAffineTransformRotate(modelMatrix, layerValues[kDVGVITimelineRotationKey]);
                modelMatrix = CGAffineTransformScale(modelMatrix, layerObjWidth, layerObjHeigth);
                
                CGPoint p1 = CGPointApplyAffineTransform(CGPointMake(-1.0f, -1.0f), modelMatrix);
                CGPoint p2 = CGPointApplyAffineTransform(CGPointMake(1.0f, -1.0f), modelMatrix);
                CGPoint p3 = CGPointApplyAffineTransform(CGPointMake(-1.0f,  1.0f), modelMatrix);
                CGPoint p4 = CGPointApplyAffineTransform(CGPointMake(1.0f,  1.0f), modelMatrix);
                GLfloat layerVertices[] = {
                    p1.x, p1.y,
                    p2.x, p2.y,
                    p3.x, p3.y,
                    p4.x, p4.y
                };
                
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(layerBGRATexture.target, layerBGRATexture.name);
                
                // PMA needed!!!
                GLfloat layercolortint[4] = {layerValues[kDVGVITimelineAlphaKey],layerValues[kDVGVITimelineAlphaKey],layerValues[kDVGVITimelineAlphaKey],layerValues[kDVGVITimelineAlphaKey]};
                glUniform4fv([self getActiveShaderUniform:UNIFORM_SHADER_COLORTINT_RPL], 1, layercolortint);
                glUniform1i([self getActiveShaderUniform:UNIFORM_SHADER_SAMPLER_RPL], 0);
                
                glVertexAttribPointer(ATTRIB_VERTEX_RPL, 2, GL_FLOAT, 0, 0, layerVertices);
                glEnableVertexAttribArray(ATTRIB_VERTEX_RPL);
                
                const GLfloat *textureCoords = [DVGOglEffectBase textureCoordinatesForRotation:kDVGGLNoRotation];
                glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, textureCoords);
                glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
                
                if(trcoBGRATexture && self.objectsRenderingMode == kDVGOEKA_trackAsTexture)
                {
                    GLfloat const* textureCoords2 = [DVGOglEffectBase textureCoordinatesForRotation:trackOrientation];
                    CGPoint tp1 = CGPointMake(textureCoords2[0]-0.5, textureCoords2[1]-0.5);
                    CGPoint tp2 = CGPointMake(textureCoords2[2]-0.5, textureCoords2[3]-0.5);
                    CGPoint tp3 = CGPointMake(textureCoords2[4]-0.5, textureCoords2[5]-0.5);
                    CGPoint tp4 = CGPointMake(textureCoords2[6]-0.5, textureCoords2[7]-0.5);

                    // reverting tranforms to make texture stay in place in screen space
                    CGAffineTransform modelMatrixI = CGAffineTransformIdentity;
                    modelMatrixI = CGAffineTransformTranslate(modelMatrixI, layerValues[kDVGVITimelineXPosKey]*0.5, layerValues[kDVGVITimelineYPosKey]*0.5);
                    modelMatrixI = CGAffineTransformScale(modelMatrixI, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]*layerObjAspect);
                    // Applying difference between object rect and whole viewport rect
                    CGFloat trco_w = CVPixelBufferGetWidth(trackBufferOriginal);
                    CGFloat trco_h = CVPixelBufferGetHeight(trackBufferOriginal);
                    modelMatrixI = CGAffineTransformScale(modelMatrixI, layerObj.objectImage.size.width/trco_w, layerObj.objectImage.size.height/trco_h);
                    tp1 = CGPointApplyAffineTransform(tp1, modelMatrixI);
                    tp2 = CGPointApplyAffineTransform(tp2, modelMatrixI);
                    tp3 = CGPointApplyAffineTransform(tp3, modelMatrixI);
                    tp4 = CGPointApplyAffineTransform(tp4, modelMatrixI);
                    GLfloat textureCoordsModified[] = {
                        tp1.x+0.5, tp1.y+0.5,
                        tp2.x+0.5, tp2.y+0.5,
                        tp3.x+0.5, tp3.y+0.5,
                        tp4.x+0.5, tp4.y+0.5,
                    };
                    
                    glVertexAttribPointer(ATTRIB_TEXCOORD2_RPL, 2, GL_FLOAT, 0, 0, textureCoordsModified);
                    glEnableVertexAttribArray(ATTRIB_TEXCOORD2_RPL);
                }
                
                // Draw the layer
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            }
        }
        glFlush();
		
	bail:
        if(trcoBGRATexture){
            CFRelease(trcoBGRATexture);
        }
        if(trckBGRATexture){
            CFRelease(trckBGRATexture);
        }
        if(destBGRATexture){
            CFRelease(destBGRATexture);
        }
        [self releaseContextForRendering];
    }
}

+ (void)applyAnimationScene:(DVGKeyframedAnimationScene*)animationScene atTime:(CGFloat)time withPlaceholders:(NSArray<UIView*>*)uiPlaceholders forCanvas:(UIView*)canvasView {
    NSInteger layersCount = MIN(kMaxLayersPerFrame,[animationScene.objects count]);
    CGRect canvasRect = canvasView.frame;// Is is EXPECTED that origin = (0,0), as in video
    CGSize canvasSize = canvasRect.size;
    if(canvasSize.width < 1 || canvasSize.height < 1){
        return;
    }
    for(int i=0; i < layersCount; i++){
        if(i >= [uiPlaceholders count]){
            break;
        }
        id uiobj = [uiPlaceholders objectAtIndex:i];
        if(uiobj == [NSNull null]){
            continue;
        }
        UIView* uiObj = (UIView*)uiobj;
        DVGKeyframedAnimationSceneObject* layerObj = [animationScene.objects objectAtIndex:i];
        CGFloat layerObjWidth = layerObj.relativeSize.width;
        CGFloat layerObjHeigth = layerObj.relativeSize.height;
        CGFloat layerObjAspect = 1;
        if(layerObjWidth <= 0){
            if(layerObj.objectImage == nil){
                NSLog(@"applyAnimationScene: Cant calc object size, skipping #%i",i);
                continue;
            }
            // calcualting from height
            layerObjAspect = canvasSize.width/canvasSize.height;
            layerObjWidth = layerObjHeigth*layerObj.objectImage.size.width/layerObj.objectImage.size.height;
        }else if(layerObjHeigth <= 0){
            if(layerObj.objectImage == nil){
                NSLog(@"applyAnimationScene: Cant calc object size, skipping #%i",i);
                continue;
            }
            // calcualting from width
            layerObjAspect = canvasSize.width/canvasSize.height;
            layerObjHeigth = layerObjWidth*layerObj.objectImage.size.height/layerObj.objectImage.size.width;
        }
        CGFloat layerValues[kDVGVITimelineKeyLast] = {0};
        [animationScene fetchKeyedValues:layerValues atTime:time forObject:i];
        
        uiObj.transform = CGAffineTransformIdentity;
        CGFloat w = canvasSize.width*layerObjWidth*layerValues[kDVGVITimelineXScaleKey];
        CGFloat h = canvasSize.height*layerObjHeigth*layerValues[kDVGVITimelineYScaleKey]*layerObjAspect;
        CGRect uiObjRect = CGRectMake(0, 0, w, h);
        uiObj.frame = uiObjRect;
        uiObj.bounds = uiObjRect;
        uiObj.alpha = layerValues[kDVGVITimelineAlphaKey];
        CGAffineTransform rotation = CGAffineTransformIdentity;
        rotation = CGAffineTransformTranslate(rotation, -uiObjRect.size.width/2, -uiObjRect.size.height/2);
        rotation = CGAffineTransformRotate(rotation, layerValues[kDVGVITimelineRotationKey]);
        CGAffineTransform position = CGAffineTransformMakeTranslation(canvasSize.width/2 + layerValues[kDVGVITimelineXPosKey]*canvasSize.width/2,
                                                                      canvasSize.height/2 + layerValues[kDVGVITimelineYPosKey]*canvasSize.height/2);
        CGAffineTransform final = CGAffineTransformConcat(rotation,position);
        uiObj.transform = final;
        //NSLog(@"x%f y%f r%f a%f",
        //layerValues[kDVGVITimelineXPosKey],layerValues[kDVGVITimelineYPosKey],
        //layerValues[kDVGVITimelineRotationKey],layerValues[kDVGVITimelineAlphaKey]);
    }
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
@end
