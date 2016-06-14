#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKitBase.h>
#import <GLKit/GLKTextureLoader.h>
#import <AVFoundation/AVFoundation.h>
#include <GLKit/GLKMath.h>
#import "math.h"

enum
{
	UNIFORM_SHADER_SAMPLER_RPL,
	UNIFORM_SHADER_COLORTINT_RPL,
	UNIFORM_RENDER_TRANSFORM_RPL,
   	NUM_UNIFORMS
};

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
static int NUM_UNIFORMS_COUNT = 100;

@class DVGStackableCompositionInstruction;
@interface DVGOpenGLRenderer : NSObject

// effects stuff
@property CMPersistentTrackID effectTrackID;
@property DVGGLRotationMode effectTrackOrientation;

// opengl stuff
@property EAGLContext *rplContext;
- (void)prepareTransform:(CGAffineTransform)transf;
- (void)prepareOglResources;
- (void)releaseOglResources;
- (void)prepareContextForRendering;
- (void)releaseContextForRendering;
- (BOOL)prepareVertexShader:(const char*)vshader
         withFragmentShader:(const char*)fshader
                withAttribs:(NSArray*)attribPairs
               withUniforms:(NSArray*)uniformPairs;
- (int)getUniform:(int)uniform;

// utility functions
- (CVOpenGLESTextureRef)bgraTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                 sourceBuffer:(CVPixelBufferRef)trackBuffer
                 sourceOrient:(DVGGLRotationMode)trackOrientation
                       atTime:(CGFloat)time withTween:(float)tweenFactor;
+ (DVGGLRotationMode)orientationForPrefferedTransform:(CGAffineTransform)preferredTransform andSize:(CGSize)videoSize;
+ (CGSize)landscapeSizeForOrientation:(DVGGLRotationMode)orientation andSize:(CGSize)videoSize;
+ (const GLfloat *)textureCoordinatesForRotation:(DVGGLRotationMode)rotationMode;
+ (GLKTextureInfo*)createGLKTextureFromCGImage:(CGImageRef)image;
+ (CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image;

@end
