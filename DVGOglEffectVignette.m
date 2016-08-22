#import "DVGOglEffectVignette.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum
{
    UNIFORM_OGL_CENTER,
    UNIFORM_OGL_COLOR,
    UNIFORM_OGL_START,
    UNIFORM_OGL_END,
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
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform lowp vec2 vignetteCenter;
 uniform lowp vec3 vignetteColor;
 uniform highp float vignetteStart;
 uniform highp float vignetteEnd;
 
 void main()
 {
     lowp vec4 sourceImageColor = texture2D(inputImageTexture, textureCoordinate);
     lowp float d = distance(textureCoordinate, vec2(vignetteCenter.x, vignetteCenter.y));
     lowp float percent = smoothstep(vignetteStart, vignetteEnd, d);
     gl_FragColor = vec4(mix(sourceImageColor.rgb, vignetteColor, percent), sourceImageColor.a);
 }
);

@interface DVGOglEffectVignette ()
{
}
@end

@implementation DVGOglEffectVignette
- (id)init
{
    self = [super init];
    if(self) {
        self.vignetteCenter = (CGPoint){ 0.5f, 0.5f };
        self.vignetteColorR = 0.0f;
        self.vignetteColorG = 0.0f;
        self.vignetteColorB = 0.0f;
        self.vignetteStart = 0.3;
        self.vignetteEnd = 0.75;
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
                                @[@(UNIFORM_OGL_CENTER), @"vignetteCenter"],
                                @[@(UNIFORM_OGL_COLOR), @"vignetteColor"],
                                @[@(UNIFORM_OGL_START), @"vignetteStart"],
                                @[@(UNIFORM_OGL_END), @"vignetteEnd"]
                                ]
     ];
}

-(void)releaseOglResources
{
    [super releaseOglResources];
}

- (void)setupFilterForSize:(CGSize)filterFrameSize
{
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
    glUniform1f([self getActiveShaderUniform:UNIFORM_OGL_START], self.vignetteStart);
    glUniform1f([self getActiveShaderUniform:UNIFORM_OGL_END], self.vignetteEnd);
    GLfloat positionArray[2];
    positionArray[0] = self.vignetteCenter.x;
    positionArray[1] = self.vignetteCenter.y;
    glUniform2fv([self getActiveShaderUniform:UNIFORM_OGL_CENTER], 1, positionArray);
    GLfloat colorArray[3];
    colorArray[0] = self.vignetteColorR;
    colorArray[1] = self.vignetteColorG;
    colorArray[2] = self.vignetteColorB;
    glUniform2fv([self getActiveShaderUniform:UNIFORM_OGL_COLOR], 1, colorArray);
    
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
