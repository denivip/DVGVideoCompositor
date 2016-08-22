#import "DVGOglEffectPolkaDot.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum
{
    UNIFORM_OGL_ASPRAT,
    UNIFORM_OGL_PIXFRAC,
    UNIFORM_OGL_DOTFRC
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
 
 uniform lowp float fractionalWidthOfPixel;
 uniform lowp float aspectRatio;
 uniform lowp float dotScaling;
 void main()
 {
     lowp vec2 sampleDivisor = vec2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
     lowp vec2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + 0.5 * sampleDivisor;
     lowp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     lowp vec2 adjustedSamplePos = vec2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     lowp float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
     lowp float checkForPresenceWithinDot = step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * dotScaling);
     lowp vec4 inputColor = texture2D(inputImageTexture, samplePos);
     
     gl_FragColor = vec4(inputColor.rgb * checkForPresenceWithinDot, inputColor.a);
     
 }
 );

@interface DVGOglEffectPolkaDot ()
{
    GLfloat fractionalWidthOfPixel, aspectRatio;
}
@end

@implementation DVGOglEffectPolkaDot
- (id)init
{
    self = [super init];
    if(self) {
        self.pixellationFraction = 0.05;
        self.dotScaling = 0.90;
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
                                @[@(UNIFORM_OGL_ASPRAT), @"aspectRatio"],
                                @[@(UNIFORM_OGL_PIXFRAC), @"fractionalWidthOfPixel"],
                                @[@(UNIFORM_OGL_DOTFRC), @"dotScaling"]
                                ]
     ];
}

-(void)releaseOglResources
{
    [super releaseOglResources];
}

- (void)setupFilterForSize:(CGSize)filterFrameSize
{
    aspectRatio = filterFrameSize.height/filterFrameSize.width;
    CGFloat singlePixelSpacing;
    if (filterFrameSize.width != 0.0)
    {
        singlePixelSpacing = 1.0 / filterFrameSize.width;
    }
    else
    {
        singlePixelSpacing = 1.0 / 2048.0;
    }
    
    if (self.pixellationFraction < singlePixelSpacing){
        fractionalWidthOfPixel = singlePixelSpacing;
    }
    else{
        fractionalWidthOfPixel = self.pixellationFraction;
    }
    
}

- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                  trackBuffer:(CVPixelBufferRef)trackBuffer
                  trackOrient:(DVGGLRotationMode)trackOrientation
                       atTime:(CGFloat)time withTween:(float)tweenFactor
{
    CGFloat vport_w = CVPixelBufferGetWidth(destBuffer);
    CGFloat vport_h = CVPixelBufferGetHeight(destBuffer);
    [self setupFilterForSize:CGSizeMake(vport_w, vport_h)];
    [self prepareContextForRendering];
    if(prevBuffer != nil){
        trackBuffer = prevBuffer;
        trackOrientation = kDVGGLNoRotation;
    }
    
    CVOpenGLESTextureRef trckBGRATexture = [self bgraTextureForPixelBuffer:trackBuffer];
    CVOpenGLESTextureRef destBGRATexture = [self bgraTextureForPixelBuffer:destBuffer];
    // Attach the destination texture as a color attachment to the off screen frame buffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destBGRATexture), CVOpenGLESTextureGetName(destBGRATexture), 0);
    glViewport(0, 0, (int)vport_w, (int)vport_h);

    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(CVOpenGLESTextureGetTarget(trckBGRATexture), CVOpenGLESTextureGetName(trckBGRATexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    
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
    
    // Draw the background frame
    glUniform1f([self getActiveShaderUniform:UNIFORM_OGL_ASPRAT], aspectRatio);
    glUniform1f([self getActiveShaderUniform:UNIFORM_OGL_PIXFRAC], fractionalWidthOfPixel);
    glUniform1f([self getActiveShaderUniform:UNIFORM_OGL_DOTFRC], self.dotScaling);
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
