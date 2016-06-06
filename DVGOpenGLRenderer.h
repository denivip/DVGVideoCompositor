#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKitBase.h>
#import <GLKit/GLKTextureLoader.h>

enum
{
	UNIFORM_SHADER_SAMPLER_RPL,
	UNIFORM_SHADER_COLORTINT_RPL,
	UNIFORM_RENDER_TRANSFORM_RPL,
   	NUM_UNIFORMS
};
extern GLint rpl_uniforms[NUM_UNIFORMS];

enum
{
	ATTRIB_VERTEX_RPL,
	ATTRIB_TEXCOORD_RPL,
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

@class DVGVideoCompositionInstruction;
@interface DVGOpenGLRenderer : NSObject

@property GLuint rplProgram;
@property CGAffineTransform renderTransform;
@property CVOpenGLESTextureCacheRef videoTextureCache;
@property EAGLContext *currentContext;
@property GLuint offscreenBufferHandle;

- (CVOpenGLESTextureRef)bgraTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer usingBackgroundSourceBuffer:(CVPixelBufferRef)backgroundPixelBuffer
          withInstruction:(DVGVideoCompositionInstruction*)currentInstruction atTime:(CGFloat)time;
+ (DVGGLRotationMode)orientationForPrefferedTransform:(CGAffineTransform)preferredTransform andSize:(CGSize)videoSize;
+ (CGSize)landscapeSizeForOrientation:(DVGGLRotationMode)orientation andSize:(CGSize)videoSize;
+ (const GLfloat *)textureCoordinatesForRotation:(DVGGLRotationMode)rotationMode;
+ (GLKTextureInfo*)createGLKTextureFromCGImage:(CGImageRef)image;
+ (CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image;

@end
