# v002-Glitch

Unsupported v002 Glitch

Code is a mess - needs a lot of work to be brought up to recent v002 plugin standards / wrappers.

Note that macOS 10.12 introduced OpenGL Context memory protection (kCGLCPSupportSeparateAddressSpace) which defaults to yes - meaning that plugins like Core Video, FBO etc which use uncleared GPU memory no longer function as expected.

Should your application have a CGContext globally shared with other Core Image, Core Video, OpenGL or CALayer based rendering using pooled memory you may have working 'glitches' - however, you will likely not see video elements from other applications as previously was the case (prior to kCGLCPSupportSeparateAddressSpace).

Oh well. Progess.
