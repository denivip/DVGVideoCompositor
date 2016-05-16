//
//  easing.c
//
//  Copyright (c) 2011, Auerhaus Development, LLC
//
//  This program is free software. It comes without any warranty, to
//  the extent permitted by applicable law. You can redistribute it
//  and/or modify it under the terms of the Do What The Fuck You Want
//  To Public License, Version 2, as published by Sam Hocevar. See
//  http://sam.zoy.org/wtfpl/COPYING for more details.
//

#include <math.h>
#include "DVGEasing.h"

// Modeled after the line y = x
DVGFloat DVGLinearInterpolation(DVGFloat p)
{
	return p;
}

// Modeled after the parabola y = x^2
DVGFloat DVGQuadraticEaseIn(DVGFloat p)
{
	return p * p;
}

// Modeled after the parabola y = -x^2 + 2x
DVGFloat DVGQuadraticEaseOut(DVGFloat p)
{
	return -(p * (p - 2));
}

// Modeled after the piecewise quadratic
// y = (1/2)((2x)^2)             ; [0, 0.5)
// y = -(1/2)((2x-1)*(2x-3) - 1) ; [0.5, 1]
DVGFloat DVGQuadraticEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 2 * p * p;
	}
	else
	{
		return (-2 * p * p) + (4 * p) - 1;
	}
}

// Modeled after the cubic y = x^3
DVGFloat DVGCubicEaseIn(DVGFloat p)
{
	return p * p * p;
}

// Modeled after the cubic y = (x - 1)^3 + 1
DVGFloat DVGCubicEaseOut(DVGFloat p)
{
	DVGFloat f = (p - 1);
	return f * f * f + 1;
}

// Modeled after the piecewise cubic
// y = (1/2)((2x)^3)       ; [0, 0.5)
// y = (1/2)((2x-2)^3 + 2) ; [0.5, 1]
DVGFloat DVGCubicEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 4 * p * p * p;
	}
	else
	{
		DVGFloat f = ((2 * p) - 2);
		return 0.5 * f * f * f + 1;
	}
}

// Modeled after the quartic x^4
DVGFloat DVGQuarticEaseIn(DVGFloat p)
{
	return p * p * p * p;
}

// Modeled after the quartic y = 1 - (x - 1)^4
DVGFloat DVGQuarticEaseOut(DVGFloat p)
{
	DVGFloat f = (p - 1);
	return f * f * f * (1 - p) + 1;
}

// Modeled after the piecewise quartic
// y = (1/2)((2x)^4)        ; [0, 0.5)
// y = -(1/2)((2x-2)^4 - 2) ; [0.5, 1]
DVGFloat DVGQuarticEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 8 * p * p * p * p;
	}
	else
	{
		DVGFloat f = (p - 1);
		return -8 * f * f * f * f + 1;
	}
}

// Modeled after the quintic y = x^5
DVGFloat DVGQuinticEaseIn(DVGFloat p)
{
	return p * p * p * p * p;
}

// Modeled after the quintic y = (x - 1)^5 + 1
DVGFloat DVGQuinticEaseOut(DVGFloat p)
{
	DVGFloat f = (p - 1);
	return f * f * f * f * f + 1;
}

// Modeled after the piecewise quintic
// y = (1/2)((2x)^5)       ; [0, 0.5)
// y = (1/2)((2x-2)^5 + 2) ; [0.5, 1]
DVGFloat DVGQuinticEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 16 * p * p * p * p * p;
	}
	else
	{
		DVGFloat f = ((2 * p) - 2);
		return  0.5 * f * f * f * f * f + 1;
	}
}

// Modeled after quarter-cycle of sine wave
DVGFloat DVGSineEaseIn(DVGFloat p)
{
	return sin((p - 1) * M_PI_2) + 1;
}

// Modeled after quarter-cycle of sine wave (different phase)
DVGFloat DVGSineEaseOut(DVGFloat p)
{
	return sin(p * M_PI_2);
}

// Modeled after half sine wave
DVGFloat DVGSineEaseInOut(DVGFloat p)
{
	return 0.5 * (1 - cos(p * M_PI));
}

// Modeled after shifted quadrant IV of unit circle
DVGFloat DVGCircularEaseIn(DVGFloat p)
{
	return 1 - sqrt(1 - (p * p));
}

// Modeled after shifted quadrant II of unit circle
DVGFloat DVGCircularEaseOut(DVGFloat p)
{
	return sqrt((2 - p) * p);
}

// Modeled after the piecewise circular function
// y = (1/2)(1 - sqrt(1 - 4x^2))           ; [0, 0.5)
// y = (1/2)(sqrt(-(2x - 3)*(2x - 1)) + 1) ; [0.5, 1]
DVGFloat DVGCircularEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 0.5 * (1 - sqrt(1 - 4 * (p * p)));
	}
	else
	{
		return 0.5 * (sqrt(-((2 * p) - 3) * ((2 * p) - 1)) + 1);
	}
}

// Modeled after the exponential function y = 2^(10(x - 1))
DVGFloat DVGExponentialEaseIn(DVGFloat p)
{
	return (p == 0.0) ? p : pow(2, 10 * (p - 1));
}

// Modeled after the exponential function y = -2^(-10x) + 1
DVGFloat DVGExponentialEaseOut(DVGFloat p)
{
	return (p == 1.0) ? p : 1 - pow(2, -10 * p);
}

// Modeled after the piecewise exponential
// y = (1/2)2^(10(2x - 1))         ; [0,0.5)
// y = -(1/2)*2^(-10(2x - 1))) + 1 ; [0.5,1]
DVGFloat DVGExponentialEaseInOut(DVGFloat p)
{
	if(p == 0.0 || p == 1.0) return p;
	
	if(p < 0.5)
	{
		return 0.5 * pow(2, (20 * p) - 10);
	}
	else
	{
		return -0.5 * pow(2, (-20 * p) + 10) + 1;
	}
}

// Modeled after the damped sine wave y = sin(13pi/2*x)*pow(2, 10 * (x - 1))
DVGFloat DVGElasticEaseIn(DVGFloat p)
{
	return sin(13 * M_PI_2 * p) * pow(2, 10 * (p - 1));
}

// Modeled after the damped sine wave y = sin(-13pi/2*(x + 1))*pow(2, -10x) + 1
DVGFloat DVGElasticEaseOut(DVGFloat p)
{
	return sin(-13 * M_PI_2 * (p + 1)) * pow(2, -10 * p) + 1;
}

// Modeled after the piecewise exponentially-damped sine wave:
// y = (1/2)*sin(13pi/2*(2*x))*pow(2, 10 * ((2*x) - 1))      ; [0,0.5)
// y = (1/2)*(sin(-13pi/2*((2x-1)+1))*pow(2,-10(2*x-1)) + 2) ; [0.5, 1]
DVGFloat DVGElasticEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 0.5 * sin(13 * M_PI_2 * (2 * p)) * pow(2, 10 * ((2 * p) - 1));
	}
	else
	{
		return 0.5 * (sin(-13 * M_PI_2 * ((2 * p - 1) + 1)) * pow(2, -10 * (2 * p - 1)) + 2);
	}
}

// Modeled after the overshooting cubic y = x^3-x*sin(x*pi)
DVGFloat DVGBackEaseIn(DVGFloat p)
{
	return p * p * p - p * sin(p * M_PI);
}

// Modeled after overshooting cubic y = 1-((1-x)^3-(1-x)*sin((1-x)*pi))
DVGFloat DVGBackEaseOut(DVGFloat p)
{
	DVGFloat f = (1 - p);
	return 1 - (f * f * f - f * sin(f * M_PI));
}

// Modeled after the piecewise overshooting cubic function:
// y = (1/2)*((2x)^3-(2x)*sin(2*x*pi))           ; [0, 0.5)
// y = (1/2)*(1-((1-x)^3-(1-x)*sin((1-x)*pi))+1) ; [0.5, 1]
DVGFloat DVGBackEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		DVGFloat f = 2 * p;
		return 0.5 * (f * f * f - f * sin(f * M_PI));
	}
	else
	{
		DVGFloat f = (1 - (2*p - 1));
		return 0.5 * (1 - (f * f * f - f * sin(f * M_PI))) + 0.5;
	}
}

DVGFloat DVGBounceEaseIn(DVGFloat p)
{
	return 1 - DVGBounceEaseOut(1 - p);
}

DVGFloat DVGBounceEaseOut(DVGFloat p)
{
	if(p < 4/11.0)
	{
		return (121 * p * p)/16.0;
	}
	else if(p < 8/11.0)
	{
		return (363/40.0 * p * p) - (99/10.0 * p) + 17/5.0;
	}
	else if(p < 9/10.0)
	{
		return (4356/361.0 * p * p) - (35442/1805.0 * p) + 16061/1805.0;
	}
	else
	{
		return (54/5.0 * p * p) - (513/25.0 * p) + 268/25.0;
	}
}

DVGFloat DVGBounceEaseInOut(DVGFloat p)
{
	if(p < 0.5)
	{
		return 0.5 * DVGBounceEaseIn(p*2);
	}
	else
	{
		return 0.5 * DVGBounceEaseOut(p * 2 - 1) + 0.5;
	}
}
