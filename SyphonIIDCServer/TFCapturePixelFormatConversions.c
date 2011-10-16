//
// TFLibDC1394CapturePixelFormatConversions.h
// Touché
//
//  Created by Georg Kaindl on 24/3/09.
//
//  Copyright (C) 2009 Georg Kaindl
//
//  This file is part of Touché.
//
//  Touché is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as
//  published by the Free Software Foundation, either version 3 of
//  the License, or (at your option) any later version.
//
//  Touché is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with Touché. If not, see <http://www.gnu.org/licenses/>.
//

#import "TFCapturePixelFormatConversions.h"

#import <stdint.h>
#import <stdlib.h>
#import <string.h>

#if defined(_USES_IPP_)
#import <ipp.h>
#import <ippi.h>
#else
#import <Accelerate/Accelerate.h>
#endif


void TFCapturePixelFormatConvertInitialize()
{
#if defined(_USES_IPP_)
	static int ippInitialized = 0;
	
	if (!ippInitialized) {
		ippStaticInit();
		ippInitialized = 1;
	}
#endif
}

// taken from libdc1394
#define YUV2RGB(y, u, v, r, g, b) {		\
	r = y + ((v*1436) >> 10);			\
	g = y - ((u*352 + v*731) >> 10);	\
	b = y + ((u*1814) >> 10);			\
	r = r < 0 ? 0 : r;					\
	g = g < 0 ? 0 : g;					\
	b = b < 0 ? 0 : b;					\
	r = r > 255 ? 255 : r;				\
	g = g > 255 ? 255 : g;				\
	b = b > 255 ? 255 : b; }

#if 0	// the Intel C/C++ and GCC can't vectorize this, which is what libdc1394 uses,
		// though I've rewritten it to loop upwards rather than downwards for better
		// cache utilization.
		// Therefore, I've changed it in a way that can be vectorized. I'm keeping
		// this original libdc1394 code here for reference purposes only.
		// The actual implementation of the vectorizable version is below.
int TFLibDC1394PixelFormatConvertYUV411toARGB8(void* src,
											   void* dst,
											   int width,
											   int height)
{	
	uint8_t* restrict srcBuf = src;
	uint8_t* restrict dstBuf = dst;
	
	int k = (width*height) + ( (width*height) >> 1 )-1;
	int j = 0, i = 0;
	int y0, y1, y2, y3, u, v, r, g, b;
	
    for (i; i<=k; i+=6) {
		u  = (uint8_t) srcBuf[i] - 128;
		y0 = (uint8_t) srcBuf[i+1];
		y1 = (uint8_t) srcBuf[i+2];
		v  = (uint8_t) srcBuf[i+3] - 128;
		y2 = (uint8_t) srcBuf[i+4];
		y3 = (uint8_t) srcBuf[i+5];
        YUV2RGB (y0, u, v, r, g, b);
		dstBuf[j++] = UINT8_MAX;
		dstBuf[j++] = (uint8_t)r;
		dstBuf[j++] = (uint8_t)g;
		dstBuf[j++] = (uint8_t)b;
		YUV2RGB (y1, u, v, r, g, b);
		dstBuf[j++] = UINT8_MAX;
		dstBuf[j++] = (uint8_t)r;
		dstBuf[j++] = (uint8_t)g;
		dstBuf[j++] = (uint8_t)b;
        YUV2RGB (y2, u, v, r, g, b);
		dstBuf[j++] = UINT8_MAX;
		dstBuf[j++] = (uint8_t)r;
		dstBuf[j++] = (uint8_t)g;
		dstBuf[j++] = (uint8_t)b;
		YUV2RGB (y3, u, v, r, g, b);
		dstBuf[j++] = UINT8_MAX;
		dstBuf[j++] = (uint8_t)r;
		dstBuf[j++] = (uint8_t)g;
		dstBuf[j++] = (uint8_t)b;
    }
			
	return 1;
}
#endif // 0

#if defined(__LITTLE_ENDIAN__)
#define UNPACK32(i32, a, b, c, d)	{							\
										a = (i32) & 0xff;		\
										b = (i32 >> 8) & 0xff;	\
										c = (i32 >> 16) & 0xff;	\
										d = (i32 >> 24) & 0xff;	\
									}
#else
#define UNPACK32(i32, a, b, c, d)	{							\
										a = (i32 >> 24) & 0xff;	\
										b = (i32 >> 16) & 0xff;	\
										c = (i32 >> 8) & 0xff;	\
										d = i32 & 0xff;			\
									}
#endif

#if defined(__LITTLE_ENDIAN__)
#define PACKARGB(a, r, g, b)	(((a) & 0xff)			|	\
								(((r) & 0xff) << 8)		|	\
								(((g) & 0xff) << 16)	|	\
								(((b) & 0xff) << 24))
#else
#define PACKARGB(a, r, g, b)	((((a) & 0xff) << 24)	|	\
								(((r) & 0xff) << 16)	|	\
								(((g) & 0xff) << 8)		|	\
								((b) & 0xff))
#endif

// icc 11.0 and (hopefully) gcc can vectorize this
int TFCapturePixelFormatConvertYUV411toARGB8(void* src,
											   void* dst,
											   int width,
											   int height)
{
	uint32_t* restrict srcBuf = src;
	uint32_t* restrict dstBuf = dst;
	
	int k = ((width*height) + ( (width*height) >> 1 ) + 3)/4;
	int j = 0, i = 0;
	int y0, y1, y2, y3, y4, y5, y6, y7, u0, v0, u1, v1, r, g, b;
	int i1, i2, i3;
	
    for (i; i <= k; i+=3) {
		i1 = srcBuf[i];
		UNPACK32(i1, u0, y0, y1, v0);
		u0 -= 128;
		v0 -= 128;
		i2 = srcBuf[i+1];
		UNPACK32(i2, y2, y3, u1, y4);
		u1 -= 128;
		i3 = srcBuf[i+2];
		UNPACK32(i3, y5, v1, y6, y7);
		v1 -= 128;
		
		YUV2RGB (y0, u0, v0, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y1, u0, v0, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y2, u0, v0, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y3, u0, v0, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y4, u1, v1, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y5, u1, v1, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y6, u1, v1, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
		YUV2RGB (y7, u1, v1, r, g, b);
		dstBuf[j++] = PACKARGB(UINT8_MAX, r, g, b);
    }
	
	return 1;
}

int TFCapturePixelFormatConvertYUV444toARGB8(uint8_t* srcBuf,
											   int srcRowBytes,
											   uint8_t* dstBuf,
											   int dstRowBytes,
											   uint8_t* intermediateBuf,
											   int intermediateRowBytes,
											   int width,
											   int height)
{
#if defined(_USES_IPP_)
	IppiSize roiSize = { width, height };
	
	// ippi conversion function expects YUV, but IIDC spec is UYV
	int uyvPermuteMap[] = { 1, 0, 2 };
	
	ippiSwapChannels_8u_C3IR(srcBuf,
							 srcRowBytes,
							 roiSize,
							 uyvPermuteMap);
	
	ippiYUVToRGB_8u_C3R(srcBuf,
						srcRowBytes,
						intermediateBuf,
						intermediateRowBytes,
						roiSize);
	
	ippiCopy_8u_C3AC4R(intermediateBuf,
					   intermediateRowBytes,
					   dstBuf,
					   dstRowBytes,
					   roiSize);
	
	int argbPermuteMap[] = { 3, 0, 1, 2 };
	
	ippiSwapChannels_8u_C4IR(dstBuf,
							 dstRowBytes,
							 roiSize,
							 argbPermuteMap);	
#else
	vImage_Buffer vInter, vSrc, vDst;
	
	vInter.data = intermediateBuf;
	vInter.width = width;
	vInter.height = height;
	vInter.rowBytes = intermediateRowBytes;
	
	vSrc.data = srcBuf;
	vSrc.width = width;
	vSrc.height = height;
	vSrc.rowBytes = srcRowBytes;
	
	vDst.data = dstBuf;
	vDst.width = width;
	vDst.height = height;
	vDst.rowBytes = dstRowBytes;
	
	vImageConvert_RGB888toARGB8888(&vSrc,
								   NULL,
								   0,
								   &vInter,
								   false,
								   0);
	
	int16_t prebias[] = { 0, -128, -16, -128};
	int16_t matrix[] = { 100,   0,   0,   0,
						   0,   0, -39, 203 ,
						   0, 100, 100, 100,
						   0, 114, -58,   0 };
	
	vImageMatrixMultiply_ARGB8888(&vInter,
								  &vDst,
								  matrix,
								  100,
								  prebias,
								  NULL,
								  0);
#endif
	
	return 1;
}

// returns non-zero on success, zero on failure
int TFCapturePixelFormatConvertRGB8toARGB8(uint8_t* srcBuf,
											 int srcRowBytes,
											 uint8_t* dstBuf,
											 int dstRowBytes,
											 int width,
											 int height)
{
#if defined(_USES_IPP_)
	IppiSize roiSize = { width, height };
	
	ippiCopy_8u_C3AC4R(srcBuf,
					   srcRowBytes,
					   dstBuf,
					   dstRowBytes,
					   roiSize);
	
	int permuteMap[] = { 3, 0, 1, 2 };
	
	ippiSwapChannels_8u_C4IR(dstBuf,
							 dstRowBytes,
							 roiSize,
							 permuteMap);	
#else
	vImage_Buffer vSrc, vDst;
	
	vSrc.data = srcBuf;
	vSrc.width = width;
	vSrc.height = height;
	vSrc.rowBytes = srcRowBytes;
	
	vDst.data = dstBuf;
	vDst.width = width;
	vDst.height = height;
	vDst.rowBytes = dstRowBytes;
	
	vImageConvert_RGB888toARGB8888(&vSrc,
								   NULL,
								   UINT8_MAX,
								   &vDst,
								   false,
								   0);
#endif
	
	return 1;
}

int TFCapturePixelFormatConvertMono8toARGB8(uint8_t* srcBuf,
											  int srcRowBytes,
											  uint8_t* dstBuf,
											  int dstRowBytes,
											  uint8_t* tmpBuf,
											  int tmpRowBytes,
											  int width,
											  int height)
{
	if (0 == *tmpBuf)
		memset(tmpBuf, UINT8_MAX, tmpRowBytes * height);

#if defined(_USES_IPP_)
	IppiSize roiSize = { width, height };
	const uint8_t* channels[] = { tmpBuf, srcBuf, srcBuf, srcBuf };
	
	ippiCopy_8u_P4C4R(channels,
					  srcRowBytes,
					  dstBuf,
					  dstRowBytes,
					  roiSize);	
#else
	vImage_Buffer aSrc, mSrc, argbDest;
	
	aSrc.data = tmpBuf;
	aSrc.width = width;
	aSrc.height = height;
	aSrc.rowBytes = tmpRowBytes;
	
	mSrc.data = srcBuf;
	mSrc.width = width;
	mSrc.height = height;
	mSrc.rowBytes = srcRowBytes;
	
	argbDest.data = dstBuf;
	argbDest.width = width;
	argbDest.height = height;
	argbDest.rowBytes = dstRowBytes;
	
	vImageConvert_Planar8toARGB8888(&aSrc,
									&mSrc,
									&mSrc,
									&mSrc,
									&argbDest,
									0);
#endif
	
	return 1;
}

unsigned TFCapturePixelFormatOptimalRowBytesForWidthAndBytesPerPixel(unsigned width,
																	 unsigned bytesPerPixel)
{
	unsigned rowBytes = width * bytesPerPixel;
	
	// Widen rowBytes out to a integer multiple of 16 bytes
	rowBytes = (rowBytes + 15) & ~15;
	
	// Make sure we are not an even power of 2 wide. 
	// Will loop a few times for rowBytes <= 16.
	while(0 == (rowBytes & (rowBytes - 1)))
		rowBytes += 16;
	
	return rowBytes;
}

