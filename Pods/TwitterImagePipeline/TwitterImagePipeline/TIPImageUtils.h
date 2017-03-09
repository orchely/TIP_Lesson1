//
//  TIPImageUtils.h
//  TwitterImagePipeline
//
//  Created on 2/18/15.
//  Copyright (c) 2015 Twitter, Inc. All rights reserved.
//

#import <ImageIO/CGImageProperties.h>
#import <ImageIO/CGImageSource.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIView.h>

#import "TIPImageTypes.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark Constants

/**
 When lossily encoding an image with Apple's ImageIO framework (which includes
 `UIImageJPEGRepresentation`), Apple uses a different metric for quality than the values commonly
 associated with JPEG images (the JFIF quality property).
 Since these differ and are complicated to dynamically compute, TIP provides some common static
 quality values for encoding an image with ImageIO that will align with JFIF qualities.
 */

//! JFIF 100% quality (with 4:2:0 chroma subsampling, 1.0f would yield an unsampled image)
static const float kTIPAppleQualityValueRepresentingJFIFQuality100  = 0.999f;
//! JFIF 95% quality
static const float kTIPAppleQualityValueRepresentingJFIFQuality95   = 0.830f;
//! JFIF 85% quality -- recommended
static const float kTIPAppleQualityValueRepresentingJFIFQuality85   = 0.575f;
//! JFIF 75% quality
static const float kTIPAppleQualityValueRepresentingJFIFQuality75   = 0.465f;
//! JFIF 65% quality
static const float kTIPAppleQualityValueRepresentingJFIFQuality65   = 0.400f;

#pragma mark Functions

//! Convert size (in points) to dimensions (in pixels)
NS_INLINE CGSize TIPDimensionsFromSizeScaled(CGSize size, CGFloat scale)
{
    size.width *= scale;
    size.height *= scale;
    return size;
}

//! Get dimensions (in pixels) from `UIView`
NS_INLINE CGSize TIPDimensionsFromView(UIView * __nullable view)
{
    if (!view) {
        return CGSizeZero;
    }

    return TIPDimensionsFromSizeScaled(view.bounds.size, [UIScreen mainScreen].scale);
}

//! Estimate byte size of a decoded `UIImage` with the given settings
FOUNDATION_EXTERN NSUInteger TIPEstimateMemorySizeOfImageWithSettings(CGSize size,
                                                                      CGFloat scale,
                                                                      NSUInteger componentsPerPixel,
                                                                      NSUInteger frameCount);

/**
 Compare size with target sizing info
 Computed target dimensions will be pixel aligned
 (i.e. any fractional pixels will be rounded up, e.g. { 625.75, 724.001 } ==> { 626, 725 })
 */
FOUNDATION_EXTERN BOOL TIPSizeMatchesTargetSizing(CGSize size,
                                                  CGSize targetSize,
                                                  UIViewContentMode targetContentMode,
                                                  CGFloat scale);

//! Best effort alpha check on a `CGImageRef`
FOUNDATION_EXTERN BOOL TIPCGImageHasAlpha(CGImageRef imageRef, BOOL inspectPixels);
//! Best effort alpha check on a `CIImage`
FOUNDATION_EXTERN BOOL TIPCIImageHasAlpha(CIImage *image, BOOL inspectPixels);
//! Scale a size to target sizing info
FOUNDATION_EXTERN CGSize TIPSizeScaledToTargetSizing(CGSize sizeToScale,
                                                     CGSize targetSizeOrZero,
                                                     UIViewContentMode targetContentMode,
                                                     CGFloat scale);
//! Scale dimensions to target sizing info
FOUNDATION_EXTERN CGSize TIPDimensionsScaledToTargetSizing(CGSize dimensionsToScale,
                                                           CGSize targetDimensionsOrZero,
                                                           UIViewContentMode targetContentMode);
//! Convert from `UIImageOrientation` to CGImage orientation
FOUNDATION_EXTERN CGImagePropertyOrientation TIPCGImageOrientationFromUIImageOrientation(UIImageOrientation orientation) __attribute__((const));
//! Convert from CGImage orientation to `UIImageOrientation`
FOUNDATION_EXTERN UIImageOrientation TIPUIImageOrientationFromCGImageOrientation(CGImagePropertyOrientation cgOrientation) __attribute__((const));

/**
 Execute CGContext (or heavy memory cost) code.
 When `[TIPGlobalConfiguration serializeCGContextAccess]` is `YES`, this function will serialize
 execution across threads.
 */
FOUNDATION_EXTERN void TIPExecuteCGContextBlock(dispatch_block_t block);

NS_ASSUME_NONNULL_END
