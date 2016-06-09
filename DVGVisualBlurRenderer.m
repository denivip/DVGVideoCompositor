#import "DVGVisualBlurRenderer.h"

@interface DVGVisualBlurRenderer ()
@end

@implementation DVGVisualBlurRenderer
- (void)renderIntoPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer
                   prevBuffer:(CVPixelBufferRef)prevBuffer
                 sourceBuffer:(CVPixelBufferRef)trackBuffer
                 sourceOrient:(DVGGLRotationMode)trackOrientation
                   atTime:(CGFloat)time withTween:(float)tweenFactor
{
    // http://iphonedevelopment.blogspot.ru/2009/05/opengl-es-from-ground-up-part-6_25.html
    [EAGLContext setCurrentContext:self.currentContext];
    if(prevBuffer != nil){
        trackBuffer = prevBuffer;
        trackOrientation = kDVGGLNoRotation;
    }
    if (trackBuffer != NULL) {
        glEnable(GL_TEXTURE_2D);
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        CVOpenGLESTextureRef backgroundBGRATexture = [self bgraTextureForPixelBuffer:trackBuffer];
        CVOpenGLESTextureRef destBGRATexture = [self bgraTextureForPixelBuffer:destinationPixelBuffer];
        glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);
        // Attach the destination texture as a color attachment to the off screen frame buffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destBGRATexture), CVOpenGLESTextureGetName(destBGRATexture), 0);
        CGFloat vport_w = CVPixelBufferGetWidth(destinationPixelBuffer);//CVPixelBufferGetWidthOfPlane(destinationPixelBuffer, 0);// ios8 compatible way
        CGFloat vport_h = CVPixelBufferGetHeight(destinationPixelBuffer);//CVPixelBufferGetHeightOfPlane(destinationPixelBuffer, 0);// ios8 compatible way
        
		glUseProgram(self.rplProgram);
		
		// Set the render transform
		GLKMatrix4 renderTransform = GLKMatrix4Make(
			self.renderTransform.a, self.renderTransform.b, self.renderTransform.tx, 0.0,
			self.renderTransform.c, self.renderTransform.d, self.renderTransform.ty, 0.0,
			0.0,					   0.0,										1.0, 0.0,
			0.0,					   0.0,										0.0, 1.0
		);
		
		glUniformMatrix4fv(self.rplUniforms[UNIFORM_RENDER_TRANSFORM_RPL], 1, GL_FALSE, renderTransform.m);
        
        glViewport(0, 0, (int)vport_w, (int)vport_h);
		
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(backgroundBGRATexture), CVOpenGLESTextureGetName(backgroundBGRATexture));
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
        
        GLfloat basecolortint[4] = {1,1,1,1};
        glUniform4fv(self.rplUniforms[UNIFORM_SHADER_COLORTINT_RPL], 1, basecolortint);
        glUniform1i(self.rplUniforms[UNIFORM_SHADER_SAMPLER_RPL], 0);
        
        glVertexAttribPointer(ATTRIB_VERTEX_RPL, 2, GL_FLOAT, 0, 0, backgroundVertices);
        glEnableVertexAttribArray(ATTRIB_VERTEX_RPL);
        
        glVertexAttribPointer(ATTRIB_TEXCOORD_RPL, 2, GL_FLOAT, 0, 0, [DVGOpenGLRenderer textureCoordinatesForRotation:trackOrientation]);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD_RPL);
        
		// Draw the background frame
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        
		
        glFlush();
		
	bail:
		CFRelease(backgroundBGRATexture);
		CFRelease(destBGRATexture);
		CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);
		
		[EAGLContext setCurrentContext:nil];
    }
}

@end
