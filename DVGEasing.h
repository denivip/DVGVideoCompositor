#ifndef DVGEASING_H
#define DVGEASING_H

#if defined(__LP64__) && !defined(AH_EASING_USE_DBL_PRECIS)
#define DVGFloat double
#else
#define DVGFloat float
#endif

#if defined __cplusplus
extern "C" {
#endif

typedef DVGFloat (*DVGEasingFunction)(DVGFloat);

// Linear interpolation (no easing)
DVGFloat DVGLinearInterpolation(DVGFloat p);

// Quadratic easing; p^2
DVGFloat DVGQuadraticEaseIn(DVGFloat p);
DVGFloat DVGQuadraticEaseOut(DVGFloat p);
DVGFloat DVGQuadraticEaseInOut(DVGFloat p);

// Cubic easing; p^3
DVGFloat DVGCubicEaseIn(DVGFloat p);
DVGFloat DVGCubicEaseOut(DVGFloat p);
DVGFloat DVGCubicEaseInOut(DVGFloat p);

// Quartic easing; p^4
DVGFloat DVGQuarticEaseIn(DVGFloat p);
DVGFloat DVGQuarticEaseOut(DVGFloat p);
DVGFloat DVGQuarticEaseInOut(DVGFloat p);

// Quintic easing; p^5
DVGFloat DVGQuinticEaseIn(DVGFloat p);
DVGFloat DVGQuinticEaseOut(DVGFloat p);
DVGFloat DVGQuinticEaseInOut(DVGFloat p);

// Sine wave easing; sin(p * PI/2)
DVGFloat DVGSineEaseIn(DVGFloat p);
DVGFloat DVGSineEaseOut(DVGFloat p);
DVGFloat DVGSineEaseInOut(DVGFloat p);

// Circular easing; sqrt(1 - p^2)
DVGFloat DVGCircularEaseIn(DVGFloat p);
DVGFloat DVGCircularEaseOut(DVGFloat p);
DVGFloat DVGCircularEaseInOut(DVGFloat p);

// Exponential easing, base 2
DVGFloat DVGExponentialEaseIn(DVGFloat p);
DVGFloat DVGExponentialEaseOut(DVGFloat p);
DVGFloat DVGExponentialEaseInOut(DVGFloat p);

// Exponentially-damped sine wave easing
DVGFloat DVGElasticEaseIn(DVGFloat p);
DVGFloat DVGElasticEaseOut(DVGFloat p);
DVGFloat DVGElasticEaseInOut(DVGFloat p);

// Overshooting cubic easing; 
DVGFloat DVGBackEaseIn(DVGFloat p);
DVGFloat DVGBackEaseOut(DVGFloat p);
DVGFloat DVGBackEaseInOut(DVGFloat p);

// Exponentially-decaying bounce easing
DVGFloat DVGBounceEaseIn(DVGFloat p);
DVGFloat DVGBounceEaseOut(DVGFloat p);
DVGFloat DVGBounceEaseInOut(DVGFloat p);

#ifdef __cplusplus
}
#endif

#endif
