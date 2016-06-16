#import "DVGOglEffectAnimatedTrackFrameRemap.h"
enum
{
    UNIFORM_ANIMREMAP_BLN
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
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform lowp float blendingFactor;
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     textureColor = vec4(textureColor.r*blendingFactor,textureColor.g*blendingFactor,textureColor.b*blendingFactor,blendingFactor);
     gl_FragColor = textureColor;
 }
);

@interface DVGOglEffectAnimatedTrackFrameRemap ()
@end

@implementation DVGOglEffectAnimatedTrackFrameRemap
- (id)init
{
    self = [super init];
    if(self) {
    }
    
    return self;
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
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"inputImageTexture"],
                                @[@(UNIFORM_ANIMREMAP_BLN), @"blendingFactor"]
                                ]
     ];
}

-(void)releaseOglResources
{
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

    if(prevBuffer != nil){
        CVOpenGLESTextureRef prevBGRATexture = [self bgraTextureForPixelBuffer:prevBuffer];
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
        trf = CGAffineTransformScale(trf, 1.0, track_w/track_h);// Accounting for aspect ration
        trf = CGAffineTransformTranslate(trf, layerValues[kDVGVITimelineXPosKey], layerValues[kDVGVITimelineYPosKey]);
        trf = CGAffineTransformScale(trf, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]);
        trf = CGAffineTransformRotate(trf, layerValues[kDVGVITimelineRotationKey]);
        trf = CGAffineTransformScale(trf, 1.0, track_h/track_w);// Unwrapping aspect ration
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
    CGPoint tp1 = CGPointMake(textureCoords[0]-0.5, textureCoords[1]-0.5);
    CGPoint tp2 = CGPointMake(textureCoords[2]-0.5, textureCoords[3]-0.5);
    CGPoint tp3 = CGPointMake(textureCoords[4]-0.5, textureCoords[5]-0.5);
    CGPoint tp4 = CGPointMake(textureCoords[6]-0.5, textureCoords[7]-0.5);
    if(self.textureMovementAnimations != nil){
        CGFloat layerValues[kDVGVITimelineKeyLast] = {0};
        [self.textureMovementAnimations fetchKeyedValues:layerValues atTime:time];
        CGAffineTransform trf = CGAffineTransformIdentity;
        trf = CGAffineTransformScale(trf, 1.0, track_w/track_h);// Accounting for aspect ration
        trf = CGAffineTransformTranslate(trf, layerValues[kDVGVITimelineXPosKey], layerValues[kDVGVITimelineYPosKey]);
        trf = CGAffineTransformScale(trf, layerValues[kDVGVITimelineXScaleKey], layerValues[kDVGVITimelineYScaleKey]);
        trf = CGAffineTransformRotate(trf, layerValues[kDVGVITimelineRotationKey]);
        trf = CGAffineTransformScale(trf, 1.0, track_h/track_w);// Unwrapping aspect ration
        tp1 = CGPointApplyAffineTransform(tp1, trf);
        tp2 = CGPointApplyAffineTransform(tp2, trf);
        tp3 = CGPointApplyAffineTransform(tp3, trf);
        tp4 = CGPointApplyAffineTransform(tp4, trf);
        blendFactor = blendFactor * layerValues[kDVGVITimelineAlphaKey];
    }
    GLfloat textureCoordsModified[] = {
        tp1.x+0.5, tp1.y+0.5,
        tp2.x+0.5, tp2.y+0.5,
        tp3.x+0.5, tp3.y+0.5,
        tp4.x+0.5, tp4.y+0.5,
    };
    glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, textureCoordsModified);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
    glUniform1f([self getActiveShaderUniform:UNIFORM_ANIMREMAP_BLN], blendFactor);
    // Draw the background frame
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFlush();
    
bail:
    if(trckBGRATexture){
        CFRelease(trckBGRATexture);
    }
    if(destBGRATexture){
        CFRelease(destBGRATexture);
    }

    [self releaseContextForRendering];
}

+(DVGKeyframedAnimationScene*)staticSceneWithScale:(NSArray*)scaleXY andOffset:(NSArray*)offsetXY andRotation:(CGFloat)rotation {
    CGFloat pscale1x = [[scaleXY objectAtIndex:0] doubleValue];
    CGFloat pscale1y = [[scaleXY objectAtIndex:1] doubleValue];
    CGFloat poffset1x = [[offsetXY objectAtIndex:0] doubleValue];
    CGFloat poffset1y = [[offsetXY objectAtIndex:1] doubleValue];
    DVGKeyframedAnimationScene* scene = [[DVGKeyframedAnimationScene alloc] init];
    DVGKeyframedAnimationTimeline* tlr = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineRotationKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:rotation easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlx = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineXPosKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:poffset1x easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tly = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineYPosKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:poffset1y easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlsx = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineXScaleKey objectIndex:0
                                                                               keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:pscale1x easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlsy = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineYScaleKey objectIndex:0
                                                                               keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:pscale1y easing:kDVGVITimelineInterpolationLinear]]];
    scene.timelines = @[tlr, tlx, tly, tlsx, tlsy];
    return scene;
}

+(DVGKeyframedAnimationScene*)slideSceneWithScale:(NSArray*)scaleXYXY andOffset:(NSArray*)offsetXYXY andRotation:(NSArray*)rotations forTime:(CGFloat)d {
    CGFloat pscale1x = [[[scaleXYXY objectAtIndex:0] objectAtIndex:0] doubleValue];
    CGFloat pscale1y = [[[scaleXYXY objectAtIndex:0] objectAtIndex:1] doubleValue];
    CGFloat pscale2x = [[[scaleXYXY objectAtIndex:1] objectAtIndex:0] doubleValue];
    CGFloat pscale2y = [[[scaleXYXY objectAtIndex:1] objectAtIndex:1] doubleValue];
    CGFloat poffset1x = [[[offsetXYXY objectAtIndex:0] objectAtIndex:0] doubleValue];
    CGFloat poffset1y = [[[offsetXYXY objectAtIndex:0] objectAtIndex:1] doubleValue];
    CGFloat poffset2x = [[[offsetXYXY objectAtIndex:1] objectAtIndex:0] doubleValue];
    CGFloat poffset2y = [[[offsetXYXY objectAtIndex:1] objectAtIndex:1] doubleValue];
    CGFloat r1 = [[rotations objectAtIndex:0] doubleValue];
    CGFloat r2 = [[rotations objectAtIndex:1] doubleValue];
    DVGKeyframedAnimationScene* scene = [[DVGKeyframedAnimationScene alloc] init];
    DVGKeyframedAnimationTimeline* tlr = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineRotationKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:r1 easing:kDVGVITimelineInterpolationLinear],
                                                                                          [DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:d value:r2 easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlx = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineXPosKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:poffset1x easing:kDVGVITimelineInterpolationLinear],
                                                                                          [DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:d value:poffset2x easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tly = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineYPosKey objectIndex:0
                                                                              keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:poffset1y easing:kDVGVITimelineInterpolationLinear],
                                                                                          [DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:d value:poffset2y easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlsx = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineXScaleKey objectIndex:0
                                                                               keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:pscale1x easing:kDVGVITimelineInterpolationLinear],
                                                                                           [DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:d value:pscale2x easing:kDVGVITimelineInterpolationLinear]]];
    DVGKeyframedAnimationTimeline* tlsy = [DVGKeyframedAnimationTimeline timelineWithKey:kDVGVITimelineYScaleKey objectIndex:0
                                                                               keyFrames:@[[DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:0 value:pscale1y easing:kDVGVITimelineInterpolationLinear],
                                                                                           [DVGKeyframedAnimationTimelineKeyframe keyframeWithTime:d value:pscale2y easing:kDVGVITimelineInterpolationLinear]]];
    scene.timelines = @[tlr, tlx, tly, tlsx, tlsy];
    return scene;
}
@end
