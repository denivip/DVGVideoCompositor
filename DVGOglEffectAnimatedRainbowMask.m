#import "DVGOglEffectAnimatedRainbowMask.h"
enum
{
    UNIFORM_RMASKA_BLN_RPL,
    UNIFORM_RMASKA_SAMPLER2_RPL,
    UNIFORM_RMASKA_SIDESAMPL_STEP_RPL,
};

static NSString* kEffectFallthrouVertexShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

static NSString* kEffectFallthrouFragmentShader = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

static NSString* kEffectVertexShader = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
);

static NSString* kEffectFragmentShader = SHADER_STRING
(
 const highp float kEps = 0.001;
 varying highp vec2 textureCoordinate;
 uniform highp vec2 rmaskCoordinateStep;
 uniform sampler2D inputRMaskTexture;
 uniform sampler2D inputPhotoTexture;
 uniform lowp float blendingFactor;
 void main()
 {
     highp vec4 rmaskColor = texture2D(inputRMaskTexture, textureCoordinate);
     highp vec4 photoColor = vec4(0,0,0,0);
     if(rmaskColor.b > kEps)
     {
         highp vec4 rmaskColor1 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x+rmaskCoordinateStep.x*2.0,textureCoordinate.y+rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor2 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x-rmaskCoordinateStep.x*2.0,textureCoordinate.y-rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor3 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x+rmaskCoordinateStep.x*2.0,textureCoordinate.y-rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor4 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x-rmaskCoordinateStep.x*2.0,textureCoordinate.y+rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor5 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x+rmaskCoordinateStep.x*4.0,textureCoordinate.y+rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor6 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x-rmaskCoordinateStep.x*4.0,textureCoordinate.y-rmaskCoordinateStep.y*2.0));
         highp vec4 rmaskColor7 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x+rmaskCoordinateStep.x*2.0,textureCoordinate.y+rmaskCoordinateStep.y*4.0));
         highp vec4 rmaskColor8 = texture2D(inputRMaskTexture, vec2(textureCoordinate.x-rmaskCoordinateStep.x*2.0,textureCoordinate.y-rmaskCoordinateStep.y*4.0));
         highp float ptc_ok = 1.0;
         highp float ptc_x = rmaskColor.r;
         highp float ptc_y = rmaskColor.g;
         if(rmaskColor1.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor1.r;
             ptc_y = ptc_y+rmaskColor1.g;
         }
         if(rmaskColor2.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor2.r;
             ptc_y = ptc_y+rmaskColor2.g;
         }
         if(rmaskColor3.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor3.r;
             ptc_y = ptc_y+rmaskColor3.g;
         }
         if(rmaskColor4.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor4.r;
             ptc_y = ptc_y+rmaskColor4.g;
         }
         if(rmaskColor5.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor5.r;
             ptc_y = ptc_y+rmaskColor5.g;
         }
         if(rmaskColor6.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor6.r;
             ptc_y = ptc_y+rmaskColor6.g;
         }
         if(rmaskColor7.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor7.r;
             ptc_y = ptc_y+rmaskColor7.g;
         }
         if(rmaskColor8.b > kEps){
             ptc_ok = ptc_ok+1.0;
             ptc_x = ptc_x+rmaskColor8.r;
             ptc_y = ptc_y+rmaskColor8.g;
         }
         //highp vec2 photoColorTex = vec2(rmaskColor.r, rmaskColor.g);
         highp vec2 photoColorTex = vec2(ptc_x/ptc_ok, ptc_y/ptc_ok);
         photoColor = texture2D(inputPhotoTexture, photoColorTex);
     }
     highp vec4 finalColor = vec4(photoColor.r*blendingFactor*rmaskColor.b,photoColor.g*blendingFactor*rmaskColor.b,photoColor.b*blendingFactor*rmaskColor.b,blendingFactor*rmaskColor.b);
     gl_FragColor = finalColor;
 }
);

@interface DVGOglEffectAnimatedRainbowMask ()
@property NSMutableArray* objectsOglBuffers;
@end

@implementation DVGOglEffectAnimatedRainbowMask
- (id)init
{
    self = [super init];
    if(self) {
    }
    
    return self;
}

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
    [self prepareVertexShader:kEffectFallthrouVertexShader withFragmentShader:kEffectFallthrouFragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"inputTextureCoordinate"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"inputImageTexture"]
                                ]
     ];
    [self prepareVertexShader:kEffectVertexShader withFragmentShader:kEffectFragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"inputTextureCoordinate"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"inputRMaskTexture"],
                                @[@(UNIFORM_RMASKA_SAMPLER2_RPL), @"inputPhotoTexture"],
                                @[@(UNIFORM_RMASKA_BLN_RPL), @"blendingFactor"],
                                @[@(UNIFORM_RMASKA_SIDESAMPL_STEP_RPL), @"rmaskCoordinateStep"]
                                ]
     ];
    self.objectsOglBuffers = @[].mutableCopy;
    for(UIImage* img in self.rainbowMappedPhotos){
        CGImageRef imageRef=[img CGImage];
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
    if(trackBuffer == nil){
        // Adjusting previous frame, not track
        trackBuffer = prevBuffer;
        trackOrientation = kDVGGLNoRotation;
    }
    CVOpenGLESTextureRef trckBGRATexture = [self bgraTextureForPixelBuffer:trackBuffer];
    CVOpenGLESTextureRef destBGRATexture = [self bgraTextureForPixelBuffer:destBuffer];
    // Attach the destination texture as a color attachment to the off screen frame buffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destBGRATexture), CVOpenGLESTextureGetName(destBGRATexture), 0);
    CGFloat vport_w = CVPixelBufferGetWidth(destBuffer);//CVPixelBufferGetWidthOfPlane(destBuffer, 0);// ios8 compatible way
    CGFloat vport_h = CVPixelBufferGetHeight(destBuffer);//CVPixelBufferGetHeightOfPlane(destBuffer, 0);// ios8 compatible way
    glViewport(0, 0, (int)vport_w, (int)vport_h);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CVOpenGLESTextureRef prevBGRATexture = nil;
    if(prevBuffer != nil){
        prevBGRATexture = [self bgraTextureForPixelBuffer:prevBuffer];
        [self activateContextShader:1];
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(prevBGRATexture), CVOpenGLESTextureGetName(prevBGRATexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
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
        
        // Draw the background frame
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(CVOpenGLESTextureGetTarget(trckBGRATexture), CVOpenGLESTextureGetName(trckBGRATexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    GLKTextureInfo *layerBGRATexture = [self fetchOGLTextureForObject:0];
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        goto bail;
    }
    
    [self activateContextShader:2];
    
    CGFloat blendFactor = 1.0;
    CGFloat track_w = CVPixelBufferGetWidth(trackBuffer);
    CGFloat track_h = CVPixelBufferGetHeight(trackBuffer);
    CGPoint p1 = CGPointMake(-1.0f, -1.0f);
    CGPoint p2 = CGPointMake(1.0f, -1.0f);
    CGPoint p3 = CGPointMake(-1.0f, 1.0f);
    CGPoint p4 = CGPointMake(1.0f, 1.0f);
    if(self.frameMovementAnimations != nil){
        CGFloat layerValues[kDVGVITimelineKeyLast] = {0};
        [self.frameMovementAnimations fetchKeyedValues:layerValues atTime:time];
        CGAffineTransform trf = CGAffineTransformIdentity;
        trf = CGAffineTransformTranslate(trf, layerValues[kDVGVITimelineXPosKey], layerValues[kDVGVITimelineYPosKey]);
        if(self.adjustScaleForAspectRatio){
            trf = CGAffineTransformScale(trf, 1.0, track_w/track_h);// Accounting for aspect ratio
        }
        trf = CGAffineTransformScale(trf, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]);
        trf = CGAffineTransformRotate(trf, layerValues[kDVGVITimelineRotationKey]);
        if(self.adjustScaleForAspectRatio){
            trf = CGAffineTransformScale(trf, 1.0, track_h/track_w);// Unwrapping aspect ratio
        }
        p1 = CGPointApplyAffineTransform(p1, trf);
        p2 = CGPointApplyAffineTransform(p2, trf);
        p3 = CGPointApplyAffineTransform(p3, trf);
        p4 = CGPointApplyAffineTransform(p4, trf);
        blendFactor = blendFactor * layerValues[kDVGVITimelineAlphaKey];
    }
    
    GLfloat backgroundVertices[] = {
        p1.x, p1.y,
        p2.x, p2.y,
        p3.x, p3.y,
        p4.x, p4.y,
    };
    glUniform1i([self getActiveShaderUniform:UNIFORM_SHADER_SAMPLER_RPL], 0);
    glVertexAttribPointer(ATTRIB_VERTEX_RPL, 2, GL_FLOAT, 0, 0, backgroundVertices);
    glEnableVertexAttribArray(ATTRIB_VERTEX_RPL);
    
    GLfloat const* textureCoords = [DVGOglEffectBase textureCoordinatesForRotation:trackOrientation];
//    CGPoint tp1 = CGPointMake(textureCoords[0]-0.5, textureCoords[1]-0.5);
//    CGPoint tp2 = CGPointMake(textureCoords[2]-0.5, textureCoords[3]-0.5);
//    CGPoint tp3 = CGPointMake(textureCoords[4]-0.5, textureCoords[5]-0.5);
//    CGPoint tp4 = CGPointMake(textureCoords[6]-0.5, textureCoords[7]-0.5);
//    if(self.textureMovementAnimations != nil){
//        CGFloat layerValues[kDVGVITimelineKeyLast] = {0};
//        [self.textureMovementAnimations fetchKeyedValues:layerValues atTime:time];
//        CGAffineTransform trf = CGAffineTransformIdentity;
//        trf = CGAffineTransformScale(trf, 1.0, track_w/track_h);// Accounting for aspect ration
//        trf = CGAffineTransformTranslate(trf, layerValues[kDVGVITimelineXPosKey], layerValues[kDVGVITimelineYPosKey]);
//        trf = CGAffineTransformScale(trf, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]);
//        trf = CGAffineTransformRotate(trf, layerValues[kDVGVITimelineRotationKey]);
//        trf = CGAffineTransformScale(trf, 1.0, track_h/track_w);// Unwrapping aspect ration
//        tp1 = CGPointApplyAffineTransform(tp1, trf);
//        tp2 = CGPointApplyAffineTransform(tp2, trf);
//        tp3 = CGPointApplyAffineTransform(tp3, trf);
//        tp4 = CGPointApplyAffineTransform(tp4, trf);
//        blendFactor = blendFactor * layerValues[kDVGVITimelineAlphaKey];
//    }
//    GLfloat textureCoordsModified[] = {
//        tp1.x+0.5, tp1.y+0.5,
//        tp2.x+0.5, tp2.y+0.5,
//        tp3.x+0.5, tp3.y+0.5,
//        tp4.x+0.5, tp4.y+0.5,
//    };
    glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, textureCoords);//textureCoordsModified
    glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
    glUniform1f([self getActiveShaderUniform:UNIFORM_RMASKA_BLN_RPL], blendFactor);
    if(layerBGRATexture){
        CGFloat layerTexW = 1.0/layerBGRATexture.width;
        CGFloat layerTexH = 1.0/layerBGRATexture.height;
        GLfloat rmaskTextXYStep[2] = {layerTexW,layerTexH};
        glUniform2fv([self getActiveShaderUniform:UNIFORM_RMASKA_SIDESAMPL_STEP_RPL], 1, rmaskTextXYStep);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(layerBGRATexture.target, layerBGRATexture.name);
        glUniform1i([self getActiveShaderUniform:UNIFORM_RMASKA_SAMPLER2_RPL], 1);
    }
    // Draw the background frame
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFlush();
    
bail:
    if(prevBGRATexture){
        CFRelease(prevBGRATexture);
    }
    if(trckBGRATexture){
        CFRelease(trckBGRATexture);
    }
    if(destBGRATexture){
        CFRelease(destBGRATexture);
    }

    [self releaseContextForRendering];
}

@end
