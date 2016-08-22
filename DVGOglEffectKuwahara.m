#import "DVGOglEffectKuwahara.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum
{
    UNIFORM_OGL_RADIUS
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
 uniform int radius;
 
 precision highp float;
 
 const vec2 src_size = vec2 (1.0 / 768.0, 1.0 / 1024.0);
 
 void main (void)
 {
     vec2 uv = textureCoordinate;
     float n = float((radius + 1) * (radius + 1));
     int i; int j;
     vec3 m0 = vec3(0.0); vec3 m1 = vec3(0.0); vec3 m2 = vec3(0.0); vec3 m3 = vec3(0.0);
     vec3 s0 = vec3(0.0); vec3 s1 = vec3(0.0); vec3 s2 = vec3(0.0); vec3 s3 = vec3(0.0);
     vec3 c;
     
     for (j = -radius; j <= 0; ++j)  {
         for (i = -radius; i <= 0; ++i)  {
             c = texture2D(inputImageTexture, uv + vec2(i,j) * src_size).rgb;
             m0 += c;
             s0 += c * c;
         }
     }
     
     for (j = -radius; j <= 0; ++j)  {
         for (i = 0; i <= radius; ++i)  {
             c = texture2D(inputImageTexture, uv + vec2(i,j) * src_size).rgb;
             m1 += c;
             s1 += c * c;
         }
     }
     
     for (j = 0; j <= radius; ++j)  {
         for (i = 0; i <= radius; ++i)  {
             c = texture2D(inputImageTexture, uv + vec2(i,j) * src_size).rgb;
             m2 += c;
             s2 += c * c;
         }
     }
     
     for (j = 0; j <= radius; ++j)  {
         for (i = -radius; i <= 0; ++i)  {
             c = texture2D(inputImageTexture, uv + vec2(i,j) * src_size).rgb;
             m3 += c;
             s3 += c * c;
         }
     }
     
     
     float min_sigma2 = 1e+2;
     m0 /= n;
     s0 = abs(s0 / n - m0 * m0);
     
     float sigma2 = s0.r + s0.g + s0.b;
     if (sigma2 < min_sigma2) {
         min_sigma2 = sigma2;
         gl_FragColor = vec4(m0, 1.0);
     }
     
     m1 /= n;
     s1 = abs(s1 / n - m1 * m1);
     
     sigma2 = s1.r + s1.g + s1.b;
     if (sigma2 < min_sigma2) {
         min_sigma2 = sigma2;
         gl_FragColor = vec4(m1, 1.0);
     }
     
     m2 /= n;
     s2 = abs(s2 / n - m2 * m2);
     
     sigma2 = s2.r + s2.g + s2.b;
     if (sigma2 < min_sigma2) {
         min_sigma2 = sigma2;
         gl_FragColor = vec4(m2, 1.0);
     }
     
     m3 /= n;
     s3 = abs(s3 / n - m3 * m3);
     
     sigma2 = s3.r + s3.g + s3.b;
     if (sigma2 < min_sigma2) {
         min_sigma2 = sigma2;
         gl_FragColor = vec4(m3, 1.0);
     }
 }
 );

@interface DVGOglEffectKuwahara ()
{
}
@end

@implementation DVGOglEffectKuwahara
- (id)init
{
    self = [super init];
    if(self) {
        self.radius = 3;
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
                                @[@(UNIFORM_OGL_RADIUS), @"radius"]
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
    glUniform1i([self getActiveShaderUniform:UNIFORM_OGL_RADIUS], self.radius);
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
