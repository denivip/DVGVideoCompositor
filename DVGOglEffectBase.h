#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKitBase.h>
#import <GLKit/GLKTextureLoader.h>
#import <AVFoundation/AVFoundation.h>
#include <GLKit/GLKMath.h>
#import "math.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

enum
{
	UNIFORM_RENDER_TRANSFORM_RPL = 100,
    UNIFORM_SHADER_SAMPLER_RPL,
	UNIFORM_SHADER_COLORTINT_RPL,
   	MAX_UNIFORMS_COUNT
};

enum
{
	ATTRIB_VERTEX_RPL,
	ATTRIB_TEXCOORD_RPL,
    ATTRIB_TEXCOORD2_RPL,
   	NUM_ATTRIBUTES
};

typedef enum {
    kDVGGLNoRotation,
    kDVGGLRotateLeft,
    kDVGGLRotateRight,
    kDVGGLFlipVertical,
    kDVGGLFlipHorizonal,
    kDVGGLRotateRightFlipVertical,
    kDVGGLRotateRightFlipHorizontal,
    kDVGGLRotate180
} DVGGLRotationMode;

typedef enum {
    DVGGLBlendNormal,
    DVGGLBlendAdd
} DVGGLBlendMode;

@interface DVGOglEffectShader : NSObject
@property GLuint rplProgram;
@property NSArray* rplProgramAttPairs;
@property NSArray* rplProgramUniPairs;
@property GLint* rplUniforms;
@end

@class DVGStackableCompositionInstruction;
@interface DVGOglEffectBase : NSObject

// effects stuff
@property NSInteger effectTrackIndex;
@property CGFloat effectRenderingUpscale;
@property DVGGLBlendMode effectRenderingBlendMode;

// opengl stuff
@property DVGGLRotationMode effectTrackOrientation;
@property CMPersistentTrackID effectTrackID;
@property EAGLContext *rplContext;
- (void)prepareTransform:(CGAffineTransform)transf;
- (void)prepareOglResources;
- (void)releaseOglResources;
- (void)prepareContextForRendering;
- (void)activateContextShader:(int)shaderindex;
- (void)releaseContextForRendering;
- (int)prepareVertexShader:(NSString*)vertShaderSource
         withFragmentShader:(NSString*)fragShaderSource
                withAttribs:(NSArray*)attribPairs
               withUniforms:(NSArray*)uniformPairs;
- (int)getActiveShaderUniform:(int)uniform;
- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                  trackBuffer:(CVPixelBufferRef)trackBuffer
                  trackOrient:(DVGGLRotationMode)trackOrientation
                       atTime:(CGFloat)time withTween:(float)tweenFactor;

// utility functions
- (NSInteger)getMaxTextureSize;
- (CVOpenGLESTextureRef)bgraTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (DVGGLRotationMode)orientationForPrefferedTransform:(CGAffineTransform)preferredTransform andSize:(CGSize)videoSize;
+ (CGSize)landscapeSizeForOrientation:(DVGGLRotationMode)orientation andSize:(CGSize)videoSize;
+ (const GLfloat *)textureCoordinatesForRotation:(DVGGLRotationMode)rotationMode;
+ (GLKTextureInfo*)createGLKTextureFromCGImage:(CGImageRef)image;
+ (CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image;
+ (CGImageRef)createCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (GLKMatrix3)CGAffineTransformToGLKMatrix3:(CGAffineTransform)affineTransform;
+(UIImage *)imageWithFlippedRGBOfImage:(UIImage *)image;
@end
