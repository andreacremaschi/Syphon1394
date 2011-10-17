//
//  TFLibDC1394Capture+CIImageFromDc1394Frame.m
//  Touché
//
//  Created by Georg Kaindl on 15/5/08.
//
//  Copyright (C) 2008 Georg Kaindl
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
//

#import "TFLibDC1394Capture+CIImageFromDc1394Frame.h"
#import <dc1394/dc1394.h>
#import <QuartzCore/QuartzCore.h>

#import "TFCapturePixelFormatConversions.h"
#import "TFIncludes.h"

#import "KCanvas.h"
#import "KBO.h"

#import <OpenGL/CGLMacro.h>

#if defined(_USES_IPP_)
#import <ipp.h>
#import <ippi.h>
#endif

typedef struct TFLibDC1394CaptureConversionContext {
	int width, height, rowBytes, bytesPerPixel, alignment, multiples;
	dc1394color_coding_t srcColorCoding;
	unsigned int destCVPixelFormat;
	void* data; // used as scratch space for pixel format conversions
} TFLibDC1394CaptureConversionContext;

typedef struct TFLibDC1394CaptureConversionResult {
	int success;	// zero or non-zero
	void* data;		// not owned by this structure
	unsigned int cvPixelFormat;
	int width, height, rowBytes, bytesPerPixel, alignment, totalSize;
} TFLibDC1394CaptureConversionResult;

// checks wether the given scratch space is appropriate for the given color conversion. If not,
// a new context is created (old one's free'd) and stored through the given pointer.
// the pointer to destCVPixelFormat will be filled with the CV pixel format to which srcColorCoding
// can be converted most efficiently.
void _TFLibDC1394CapturePrepareConversionContext(TFLibDC1394CaptureConversionContext** pContext,
												 dc1394color_coding_t srcColorCoding,
												 unsigned int* destCVPixelFormat,
												 int width,
												 int height);

// converts a frame with a given conversion context
TFLibDC1394CaptureConversionResult _TFLibDC1394CaptureConvert(TFLibDC1394CaptureConversionContext* context,
															  dc1394video_frame_t* frame,
															  void* outputData);

// returns an optimal value for rowBytes for a given image width and byterPerPixel value.
size_t _TFLibDC1394CaptureOptimalRowBytesForWidthAndBytesPerPixel(size_t width,
																  size_t bytesPerPixel);

// properly frees a pixel format conversion context
void _TFLibDC1394CaptureFreePixelFormatConversionContext(TFLibDC1394CaptureConversionContext* context);

@implementation TFLibDC1394Capture (CIImageFromDc1394Frame)

- (void)cleanUpCIImageCreator
{
	_TFLibDC1394CaptureFreePixelFormatConversionContext(_pixelConversionContext);
	_pixelConversionContext = NULL;	
}

- (NSString*)dc1394ColorCodingToString:(dc1394color_coding_t)coding
{
	switch (coding) {
		case DC1394_COLOR_CODING_MONO8:
			return @"DC1394_COLOR_CODING_MONO8";
		case DC1394_COLOR_CODING_YUV411:
			return @"DC1394_COLOR_CODING_YUV411";
		case DC1394_COLOR_CODING_YUV422:
			return @"DC1394_COLOR_CODING_YUV422";
		case DC1394_COLOR_CODING_YUV444:
			return @"DC1394_COLOR_CODING_YUV444";
		case DC1394_COLOR_CODING_RGB8:
			return @"DC1394_COLOR_CODING_RGB8";
		case DC1394_COLOR_CODING_MONO16:
			return @"DC1394_COLOR_CODING_MONO16";
		case DC1394_COLOR_CODING_RGB16:
			return @"DC1394_COLOR_CODING_RGB16";
		case DC1394_COLOR_CODING_MONO16S:
			return @"DC1394_COLOR_CODING_MONO16S";
		case DC1394_COLOR_CODING_RGB16S:
			return @"DC1394_COLOR_CODING_RGB16S";
		case DC1394_COLOR_CODING_RAW8:
			return @"DC1394_COLOR_CODING_RAW8";
		case DC1394_COLOR_CODING_RAW16:
			return @"DC1394_COLOR_CODING_RAW16";
		default:
			return @"(unknown pixelformat)";
	}
	
	return nil;
}

- (CIImage*)ciImageWithDc1394Frame: (dc1394video_frame_t*) frame 
                             error: (NSError**) error
{
	if (NULL == frame)
		return nil;
	
	if (NULL != error)
		*error = nil;
	
	switch (frame->color_coding) {
		case DC1394_COLOR_CODING_YUV411:
		case DC1394_COLOR_CODING_YUV422:
		case DC1394_COLOR_CODING_YUV444:
		case DC1394_COLOR_CODING_RGB8:
		case DC1394_COLOR_CODING_MONO8: {
			if (_pixelBufferPoolNeedsUpdating) {
				if (NULL != _pixelBufferPool) {
					CVPixelBufferPoolRelease(_pixelBufferPool);
					_pixelBufferPool = NULL;
				}
				
				unsigned int pixelFormat = -1;
				unsigned int pixelAlignment = 0;
								
				switch (frame->color_coding) {
					case DC1394_COLOR_CODING_YUV422:
						pixelFormat = (DC1394_BYTE_ORDER_UYVY == frame->yuv_byte_order) ? k2vuyPixelFormat :
																						  kYUVSPixelFormat;
						break;
					case DC1394_COLOR_CODING_YUV411:
					case DC1394_COLOR_CODING_YUV444:
					case DC1394_COLOR_CODING_RGB8:
					case DC1394_COLOR_CODING_MONO8:
						_TFLibDC1394CapturePrepareConversionContext(&_pixelConversionContext,
																	frame->color_coding,
																	&pixelFormat,
																	frame->size[0],
																	frame->size[1]);
						pixelAlignment = _pixelConversionContext->alignment;
						break;
				}
				
			/*	NSDictionary* poolAttr = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSNumber numberWithUnsignedInt:pixelFormat], (id)kCVPixelBufferPixelFormatTypeKey,
											[NSNumber numberWithUnsignedInt:frame->size[0]], (id)kCVPixelBufferWidthKey,
											[NSNumber numberWithUnsignedInt:frame->size[1]], (id)kCVPixelBufferHeightKey,
											[NSNumber numberWithUnsignedInt:pixelAlignment], (id)kCVPixelBufferBytesPerRowAlignmentKey,
											nil]; 
								
				CVReturn err = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (CFDictionaryRef)poolAttr, &_pixelBufferPool);
				if (kCVReturnSuccess != err) {
					// TODO: report error
				}
								
				_pixelBufferPoolNeedsUpdating = NO;*/
			}
			
			/*CVPixelBufferRef pixelBuffer = nil;
			CVReturn err = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pixelBufferPool, &pixelBuffer);
			
			if (kCVReturnSuccess != err) {
				if (NULL != error)
					*error = [NSError errorWithDomain:SICErrorDomain
												 code:SICErrorDc1394CVPixelBufferCreationFailed
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													   NSLocalizedString(@"TFDc1394PixelBufferCreationErrorDesc", @"TFDc1394PixelBufferCreationErrorDesc"),
														NSLocalizedDescriptionKey,
													   NSLocalizedString(@"TFDc1394PixelBufferCreationErrorReason", @"TFDc1394PixelBufferCreationErrorReason"),
														NSLocalizedFailureReasonErrorKey,
													   NSLocalizedString(@"TFDc1394PixelBufferCreationErrorRecovery", @"TFDc1394PixelBufferCreationErrorRecovery"),
														NSLocalizedRecoverySuggestionErrorKey,
													   [NSNumber numberWithInteger:NSUTF8StringEncoding],
														NSStringEncodingErrorKey,
													   nil]];

				return nil;
			}
						
			err = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
			
			if (kCVReturnSuccess != err) {
				// TODO: report error
			}
			
			unsigned char* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
			*/
            
            
			// do pixel format conversion if needed.
			/*if (DC1394_COLOR_CODING_YUV444 == frame->color_coding		||
				DC1394_COLOR_CODING_YUV411 == frame->color_coding		||
				DC1394_COLOR_CODING_RGB8 == frame->color_coding			||
				DC1394_COLOR_CODING_MONO8 == frame->color_coding) {
				
				TFLibDC1394CaptureConversionResult conversionResult =
					_TFLibDC1394CaptureConvert(_pixelConversionContext, frame, baseAddress);
				
				if (!conversionResult.success) {
					// TODO: report error
				}
			} else {
				memcpy(baseAddress, frame->image, frame->image_bytes);
			}
			
			err = CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
			
			if (kCVReturnSuccess != err) {
				// TODO: report error
			}*/
			
			CIImage* image = nil;
			/*if (_delegateCapabilities.hasWantedCIImageColorSpace) {
				id colorSpace = (id)[delegate wantedCIImageColorSpaceForCapture:self];
				if (nil == colorSpace)
					colorSpace = [NSNull null];
				
				image = [CIImage imageWithCVImageBuffer:pixelBuffer
												options:[NSDictionary dictionaryWithObject:colorSpace
																					forKey:kCIImageColorSpace]];
			} else*/
            
            
            
            
            
			//	image = [CIImage imageWithCVImageBuffer:pixelBuffer];
            
		//	CVPixelBufferRelease(pixelBuffer);
					
            CGSize size = CGSizeMake(frame->size[0], frame->size[1]);
            static KCanvas *canvas = nil;
            if (nil==canvas) {
                canvas = [KCanvas canvasWithSize: size];
            }
                
            if (!CGSizeEqualToSize(size, canvas.size)) [canvas setSize: size];
            
            
            CGLContextObj cgl_ctx = canvas.openGLContext.CGLContextObj;
            CGLLockContext(cgl_ctx);
            {
                
                [canvas.bo attachPBO];
                

                
                glBufferDataARB(GL_PIXEL_UNPACK_BUFFER, frame->total_bytes, frame->image, GL_STREAM_DRAW_ARB);
                glDrawPixels(frame->size[0],  frame->size[1], GL_LUMINANCE,  GL_UNSIGNED_BYTE, frame->image);
                glFlush();
                
                [canvas.bo detachPBO];

            }
            CGLUnlockContext(cgl_ctx);
            
            
			return canvas.image;
		}
	}
	
	if (NULL != error)
		*error = [NSError errorWithDomain:SICErrorDomain
									 code:SICErrorDc1394UnsupportedPixelFormat
								 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										   NSLocalizedString(@"TFDc1394PixelFormatErrorDesc", @"TFDc1394PixelFormatErrorDesc"),
										   NSLocalizedDescriptionKey,
										   NSLocalizedString(@"TFDc1394PixelFormatErrorReason", @"TFDc1394PixelFormatErrorReason"),
										   NSLocalizedFailureReasonErrorKey,
										   NSLocalizedString(@"TFDc1394PixelFormatErrorRecovery", @"TFDc1394PixelFormatErrorRecovery"),
										   NSLocalizedRecoverySuggestionErrorKey,
										   [NSNumber numberWithInteger:NSUTF8StringEncoding],
										   NSStringEncodingErrorKey,
										   nil]];

	return nil;
}

// we prefer video modes that don't need to be converted for core image (rgb8) or are easy to convert
+ (int)rankingForVideoMode:(dc1394video_mode_t)mode
{
	switch (mode) {
		case DC1394_VIDEO_MODE_640x480_RGB8:
		case DC1394_VIDEO_MODE_800x600_RGB8:
		case DC1394_VIDEO_MODE_1024x768_RGB8:
		case DC1394_VIDEO_MODE_1280x960_RGB8:
		case DC1394_VIDEO_MODE_1600x1200_RGB8:
			return 0;
		
		case DC1394_VIDEO_MODE_640x480_MONO8:
		case DC1394_VIDEO_MODE_800x600_MONO8:
		case DC1394_VIDEO_MODE_1024x768_MONO8:
		case DC1394_VIDEO_MODE_1280x960_MONO8:
		case DC1394_VIDEO_MODE_1600x1200_MONO8:
			return 1;
		
		case DC1394_VIDEO_MODE_320x240_YUV422:
		case DC1394_VIDEO_MODE_640x480_YUV422:
		case DC1394_VIDEO_MODE_800x600_YUV422:
		case DC1394_VIDEO_MODE_1024x768_YUV422:
		case DC1394_VIDEO_MODE_1280x960_YUV422:
		case DC1394_VIDEO_MODE_1600x1200_YUV422:
			return 2;
		
		case DC1394_VIDEO_MODE_160x120_YUV444:
			return 3;
		
		case DC1394_VIDEO_MODE_640x480_YUV411:
			return 4;
	}
	
	return INT_MAX;
}

@end

void _TFLibDC1394CapturePrepareConversionContext(TFLibDC1394CaptureConversionContext** pContext,
												 dc1394color_coding_t srcColorCoding,
												 unsigned int *destCVPixelFormat,
												 int width,
												 int height)
{
	if (NULL == pContext)
		return;
	
	static int converterInitialized = 0;
	if (!converterInitialized) {
		TFCapturePixelFormatConvertInitialize();
		converterInitialized = 1;
	}
	
	TFLibDC1394CaptureConversionContext* context = *pContext;
	
	int wantedBytesPerPixel = 0;
	BOOL wantsAlignedRowBytes = YES;
	unsigned int selectedCVFormat;
	unsigned int multiples = 0;
	
	switch (srcColorCoding) {
		case DC1394_COLOR_CODING_YUV411:
			wantsAlignedRowBytes = NO;
			selectedCVFormat = k32ARGBPixelFormat;
			wantedBytesPerPixel = 4;
			multiples = 0;
			break;
		
		case DC1394_COLOR_CODING_YUV444:
			wantsAlignedRowBytes = YES;
			selectedCVFormat = k32ARGBPixelFormat;
			wantedBytesPerPixel = 4;
			multiples = 1;
			break;
		
		case DC1394_COLOR_CODING_RGB8:
			wantsAlignedRowBytes = YES;
			selectedCVFormat = k32ARGBPixelFormat;
			wantedBytesPerPixel = 4;
			multiples = 0;
			break;
		
		case DC1394_COLOR_CODING_MONO8:
			wantsAlignedRowBytes = YES;
			selectedCVFormat = k32ARGBPixelFormat;
			wantedBytesPerPixel = 4;
			multiples = 1;
			break;
					
		default:
			break;
	}
	
	if (0 == wantedBytesPerPixel)
		return;

	if (NULL != destCVPixelFormat)
		*destCVPixelFormat = selectedCVFormat;
	
	if (NULL != context) {
		if (context->srcColorCoding != srcColorCoding		||
			context->width != width							||
			context->height != height						||
			context->bytesPerPixel != wantedBytesPerPixel	||
			context->multiples != multiples) {
			_TFLibDC1394CaptureFreePixelFormatConversionContext(context);
			context = NULL;
		}
	}
	
	// context is fine for this conversion, don't do anything
	if (NULL != context)
		return;
	
	// allocate a new context.
	// TODO: some unchecked malloc's here...
	context = (TFLibDC1394CaptureConversionContext*)
						malloc(sizeof(TFLibDC1394CaptureConversionContext));
	
	context->width = width;
	context->height = height;
	context->srcColorCoding = srcColorCoding;
	context->destCVPixelFormat = selectedCVFormat;
	context->bytesPerPixel = wantedBytesPerPixel;
	context->multiples = multiples;

	if (wantsAlignedRowBytes) {
#if defined(_USES_IPP_)
		int m = multiples > 0 ? multiples : 1;
		// TODO: if we support other formats than k32ARGBPixelFormat, we need to use th
		// specific ippiMalloc() variant for that.
		context->data = ippiMalloc_8u_AC4(width, height * m, &context->rowBytes);
		
		if (multiples > 0) {
			int size = multiples * context->rowBytes * height;
			memset(context->data, 0, size);
		} else {
			ippiFree(context->data);
			context->data = NULL;
		}

		// ippiMalloc returns memory aligned to 32-byte boundaries
		context->alignment = 32;
#else
		context->rowBytes = _TFLibDC1394CaptureOptimalRowBytesForWidthAndBytesPerPixel(width,
																							wantedBytesPerPixel);

		if (multiples > 0) {
			int size = multiples * context->rowBytes * height;
			context->data = malloc(size);
			memset(context->data, 0, size);
		} else
			context->data = NULL;
		
		// on OSX, malloc allows returns 16-byte aligned memory, and the optimal rowbytes function respects
		// this alignment, too.
		context->alignment = 16;
#endif
	} else {
		context->rowBytes = wantedBytesPerPixel * width;

		if (multiples > 0) {
			int size = multiples * context->rowBytes * height;
			context->data = malloc(size);
			memset(context->data, 0, size);
		} else
			context->data = NULL;

		context->alignment = 0;
	}
	
	*pContext = context;
}

TFLibDC1394CaptureConversionResult _TFLibDC1394CaptureConvert(TFLibDC1394CaptureConversionContext* context,
															  dc1394video_frame_t* frame,
															  void* outputData)
{
	if (NULL == context) {
		TFLibDC1394CaptureConversionResult r = { 0, NULL, 0, 0, 0, 0, 0, 0 };
		return r;
	}
		
	TFLibDC1394CaptureConversionResult result = { 0,
												  outputData,
												  context->destCVPixelFormat,
												  context->width,
												  context->height,
												  context->rowBytes,
												  context->bytesPerPixel,
												  context->alignment,
												  context->rowBytes * context->height };
	
	if (frame->color_coding == context->srcColorCoding) {
		if (DC1394_COLOR_CODING_YUV411 == frame->color_coding	&&
			k32ARGBPixelFormat == context->destCVPixelFormat) {
			
			TFCapturePixelFormatConvertYUV411toARGB8(frame->image,
													   outputData,
													   context->width,
													   context->height);
			
			result.success = 1;
		} else if (DC1394_COLOR_CODING_YUV444 == frame->color_coding	&&
			k32ARGBPixelFormat == context->destCVPixelFormat) {
		
			TFCapturePixelFormatConvertYUV444toARGB8(frame->image,
													   3*frame->size[0],
													   outputData,
													   context->rowBytes,
													   context->data,
													   context->rowBytes,
													   context->width,
													   context->height);
					
		} else if (DC1394_COLOR_CODING_RGB8 == frame->color_coding	&&
				   k32ARGBPixelFormat == context->destCVPixelFormat) {
		
			TFCapturePixelFormatConvertRGB8toARGB8(frame->image,
													 3*frame->size[0],
													 outputData,
													 context->rowBytes,
													 context->width,
													 context->height);
		
		} else if (DC1394_COLOR_CODING_MONO8 == frame->color_coding &&
				   k32ARGBPixelFormat == context->destCVPixelFormat) {
		
			TFCapturePixelFormatConvertMono8toARGB8(frame->image,
													  frame->size[0],
													  outputData,
													  context->rowBytes,
													  context->data,
													  context->rowBytes,
													  context->width,
													  context->height);
		
		}
	}
	
	return result;
}

size_t _TFLibDC1394CaptureOptimalRowBytesForWidthAndBytesPerPixel(size_t width, size_t bytesPerPixel)
{
	size_t rowBytes = width * bytesPerPixel;
	
	// Widen rowBytes out to a integer multiple of 16 bytes
	rowBytes = (rowBytes + 15) & ~15;
	
	// Make sure we are not an even power of 2 wide. 
	// Will loop a few times for rowBytes <= 16.
	while(0 == (rowBytes & (rowBytes - 1)))
		rowBytes += 16;
	
	return rowBytes;
}

void _TFLibDC1394CaptureFreePixelFormatConversionContext(TFLibDC1394CaptureConversionContext* context)
{
	if (NULL != context) {
		if (NULL != context->data)
#if defined(_USES_IPP_)
			ippiFree(context->data);
#else
		free(context->data);
#endif
		
		free(context);
		context = NULL;
	}
}
