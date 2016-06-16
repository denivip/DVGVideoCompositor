#import "DVGOglEffectColorSaturation.h"

enum
{
    UNIFORM_COLORSAT_SAT,
    UNIFORM_COLORSAT_BRI
};


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
 uniform lowp float saturationFactor;
 uniform lowp vec3 brightnessFactor;
 const mediump vec3 luminanceWeighting = vec3(0.2125, 0.7154, 0.0721);
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     lowp float luminance = dot(textureColor.rgb, luminanceWeighting);
     lowp vec3 greyScaleColor = vec3(luminance);
     lowp vec4 outputColor = textureColor;
     outputColor = vec4(mix(greyScaleColor, outputColor.rgb, saturationFactor), outputColor.w);
     outputColor = vec4((outputColor.rgb) + brightnessFactor, outputColor.w);
     outputColor = clamp(outputColor, 0.0, 1.0);
     gl_FragColor = outputColor;
 }
);

@interface DVGOglEffectColorSaturation ()
@end

@implementation DVGOglEffectColorSaturation
- (id)init
{
    self = [super init];
    if(self) {
        self.brightness = 0.0;
        self.saturation = 1.0;
    }
    
    return self;
}

-(void)prepareOglResources
{
    [super prepareOglResources];
    [self prepareVertexShader:kEffectVertexShader withFragmentShader:kEffectFragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"inputTextureCoordinate"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"inputImageTexture"],
                                @[@(UNIFORM_COLORSAT_SAT), @"saturationFactor"],
                                @[@(UNIFORM_COLORSAT_BRI), @"brightnessFactor"],
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
    if(prevBuffer != nil){
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
    
    static const GLfloat backgroundVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    [self activateContextShader:1];
    glUniform1i([self getActiveShaderUniform:UNIFORM_SHADER_SAMPLER_RPL], 0);
    glVertexAttribPointer(ATTRIB_VERTEX_RPL, 2, GL_FLOAT, 0, 0, backgroundVertices);
    glEnableVertexAttribArray(ATTRIB_VERTEX_RPL);
    glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, [DVGOglEffectBase textureCoordinatesForRotation:trackOrientation]);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
    
    glUniform1f([self getActiveShaderUniform:UNIFORM_COLORSAT_SAT], self.saturation);
    GLfloat brightnessShift[3] = {self.brightness,self.brightness,self.brightness};
    glUniform3fv([self getActiveShaderUniform:UNIFORM_COLORSAT_BRI], 1, brightnessShift);
    
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

@end
