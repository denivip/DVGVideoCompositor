#import "DVGOglEffectDirectionalBlur.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum
{
    UNIFORM_BLUR_TEXELWO,
    UNIFORM_BLUR_TEXELHO,
    UNIFORM_BLUR_TEXELWEI
};

@interface DVGOglEffectDirectionalBlur ()
{
    GLfloat texelWidthOffset, texelHeightOffset;
}
@end

@implementation DVGOglEffectDirectionalBlur
- (id)init
{
    self = [super init];
    if(self) {
        self.blurRadiusInPixels = 1;
        self.blurXScale = 1.0;
        self.blurYScale = 0.0;
        self.blurBlendingWeight = 1.0;
    }
    
    return self;
}

+ (NSString *)vertexShaderForOptimizedBlurOfRadius:(NSUInteger)blurRadius sigma:(CGFloat)sigma;
{
    if (blurRadius < 1)
    {
        //return kGPUImageVertexShaderString;
        blurRadius = 1;
    }
    
    // From these weights we calculate the offsets to read interpolated values from
    NSUInteger numberOfOptimizedOffsets = MIN(blurRadius / 2 + (blurRadius % 2), 7);
    
    NSMutableString *shaderString = [[NSMutableString alloc] init];
    // Header
    [shaderString appendFormat:@"\
     attribute vec4 position;\n\
     attribute vec4 inputTextureCoordinate;\n\
     \n\
     uniform float texelWidthOffset;\n\
     uniform float texelHeightOffset;\n\
     \n\
     varying vec2 blurCoordinates[%lu];\n\
     \n\
     void main()\n\
     {\n\
     gl_Position = position;\n\
     \n\
     vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);\n", (unsigned long)(1 + (numberOfOptimizedOffsets * 2))];
    
    // Inner offset loop
    [shaderString appendString:@"blurCoordinates[0] = inputTextureCoordinate.xy;\n"];
    for (NSUInteger currentOptimizedOffset = 0; currentOptimizedOffset < numberOfOptimizedOffsets; currentOptimizedOffset++)
    {
        GLfloat optimizedOffset = (GLfloat)(currentOptimizedOffset * 2) + 1.5;
        
        [shaderString appendFormat:@"\
         blurCoordinates[%lu] = inputTextureCoordinate.xy + singleStepOffset * %f;\n\
         blurCoordinates[%lu] = inputTextureCoordinate.xy - singleStepOffset * %f;\n", (unsigned long)((currentOptimizedOffset * 2) + 1), optimizedOffset, (unsigned long)((currentOptimizedOffset * 2) + 2), optimizedOffset];
    }
    
    // Footer
    [shaderString appendString:@"}\n"];
    
    return shaderString;
}

+ (NSString *)fragmentShaderForOptimizedBlurOfRadius:(NSUInteger)blurRadius sigma:(CGFloat)sigma;
{
    if (blurRadius < 1)
    {
        //return kGPUImagePassthroughFragmentShaderString;
        blurRadius = 1;
    }
    
    NSUInteger numberOfOptimizedOffsets = MIN(blurRadius / 2 + (blurRadius % 2), 7);
    NSUInteger trueNumberOfOptimizedOffsets = blurRadius / 2 + (blurRadius % 2);
    
    NSMutableString *shaderString = [[NSMutableString alloc] init];
    
    [shaderString appendFormat:@"\
     uniform sampler2D inputImageTexture;\n\
     uniform highp float texelWidthOffset;\n\
     uniform highp float texelHeightOffset;\n\
     uniform highp float texelBlendingWeight;\n\
     \n\
     varying highp vec2 blurCoordinates[%lu];\n\
     \n\
     void main()\n\
     {\n\
     lowp vec4 sum = vec4(0.0);\n", (unsigned long)(1 + (numberOfOptimizedOffsets * 2)) ];
    
    GLfloat boxWeight = 1.0 / (GLfloat)((blurRadius * 2) + 1);
    
    // Inner texture loop
    [shaderString appendFormat:@"sum += texture2D(inputImageTexture, blurCoordinates[0]) * %f;\n", boxWeight];
    
    for (NSUInteger currentBlurCoordinateIndex = 0; currentBlurCoordinateIndex < numberOfOptimizedOffsets; currentBlurCoordinateIndex++)
    {
        [shaderString appendFormat:@"sum += texture2D(inputImageTexture, blurCoordinates[%lu]) * %f;\n", (unsigned long)((currentBlurCoordinateIndex * 2) + 1), boxWeight * 2.0];
        [shaderString appendFormat:@"sum += texture2D(inputImageTexture, blurCoordinates[%lu]) * %f;\n", (unsigned long)((currentBlurCoordinateIndex * 2) + 2), boxWeight * 2.0];
    }
    
    // If the number of required samples exceeds the amount we can pass in via varyings, we have to do dependent texture reads in the fragment shader
    if (trueNumberOfOptimizedOffsets > numberOfOptimizedOffsets)
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        [shaderString appendString:@"highp vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);\n"];
#else
        [shaderString appendString:@"vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);\n"];
#endif
        
        for (NSUInteger currentOverlowTextureRead = numberOfOptimizedOffsets; currentOverlowTextureRead < trueNumberOfOptimizedOffsets; currentOverlowTextureRead++)
        {
            GLfloat optimizedOffset = (GLfloat)(currentOverlowTextureRead * 2) + 1.5;
            
            [shaderString appendFormat:@"sum += texture2D(inputImageTexture, blurCoordinates[0] + singleStepOffset * %f) * %f;\n", optimizedOffset, boxWeight * 2.0];
            [shaderString appendFormat:@"sum += texture2D(inputImageTexture, blurCoordinates[0] - singleStepOffset * %f) * %f;\n", optimizedOffset, boxWeight * 2.0];
        }
    }
    
    // Footer
    [shaderString appendString:@"\
     gl_FragColor = vec4(sum.r*texelBlendingWeight,sum.g*texelBlendingWeight,sum.b*texelBlendingWeight,texelBlendingWeight);\n\
     }\n"];
    
    return shaderString;
}

-(void)prepareOglResources
{
    [super prepareOglResources];
    NSUInteger calculatedSampleRadius = 0;
    if (_blurRadiusInPixels >= 1) // Avoid a divide-by-zero error here
    {
        // Calculate the number of pixels to sample from by setting a bottom limit for the contribution of the outermost pixel
        CGFloat minimumWeightToFindEdgeOfSamplingArea = 1.0/256.0;
        calculatedSampleRadius = floor(sqrt(-2.0 * pow(_blurRadiusInPixels, 2.0) * log(minimumWeightToFindEdgeOfSamplingArea * sqrt(2.0 * M_PI * pow(_blurRadiusInPixels, 2.0))) ));
        calculatedSampleRadius += calculatedSampleRadius % 2; // There's nothing to gain from handling odd radius sizes, due to the optimizations I use
    }

    NSString *currentGaussianBlurVertexShader = [[self class] vertexShaderForOptimizedBlurOfRadius:calculatedSampleRadius sigma:_blurRadiusInPixels];
    NSString *currentGaussianBlurFragmentShader = [[self class] fragmentShaderForOptimizedBlurOfRadius:calculatedSampleRadius sigma:_blurRadiusInPixels];
    
    int shaderIndex = [self prepareVertexShader:currentGaussianBlurVertexShader withFragmentShader:currentGaussianBlurFragmentShader
                  withAttribs:@[
                                @[@(ATTRIB_VERTEX_RPL), @"position"],
                                @[@(ATTRIB_TEXCOORD_RPL), @"inputTextureCoordinate"]
                                ]
                 withUniforms:@[
                                @[@(UNIFORM_RENDER_TRANSFORM_RPL), @"renderTransform"],
                                @[@(UNIFORM_SHADER_SAMPLER_RPL), @"inputImageTexture"],
                                @[@(UNIFORM_BLUR_TEXELWO), @"texelWidthOffset"],
                                @[@(UNIFORM_BLUR_TEXELHO), @"texelHeightOffset"],
                                @[@(UNIFORM_BLUR_TEXELWEI), @"texelBlendingWeight"],
                                ]
     ];
    if(shaderIndex < 0){
        DDLogError(@"DVGOglEffectDirectionalBlur: prepareOglResources: shaders compilation failed: \n\n%@ \n\n%@", currentGaussianBlurVertexShader, currentGaussianBlurFragmentShader);
    }
}

-(void)releaseOglResources
{
    [super releaseOglResources];
}

- (void)setupFilterForSize:(CGSize)filterFrameSize
{
    texelHeightOffset = self.blurXScale * 1.0 / filterFrameSize.height;
    texelWidthOffset = self.blurYScale * 1.0 / filterFrameSize.width;
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
    glUniform1f([self getActiveShaderUniform:UNIFORM_BLUR_TEXELWO], texelWidthOffset);
    glUniform1f([self getActiveShaderUniform:UNIFORM_BLUR_TEXELHO], texelHeightOffset);
    glUniform1f([self getActiveShaderUniform:UNIFORM_BLUR_TEXELWEI], self.blurBlendingWeight);
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
