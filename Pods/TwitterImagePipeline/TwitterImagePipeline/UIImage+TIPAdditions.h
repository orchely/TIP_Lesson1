//
//  UIImage+TIPAdditions.h
//  TwitterImagePipeline
//
//  Created on 9/6/16.
//  Copyright © 2016 Twitter. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <UIKit/UIImage.h>

#import "TIPImageTypes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Additions to `UIImage` for _Twitter Image Pipeline_
 No custom `TIPImageCodec` implementations will be considered with these convenience methods.
 See `TIPImageContainer`, `TIPImageCodecCatalogue` and `TIPImageCodecs.h` for custom codec based
 support.
 @note these additions are built on __CoreGraphics__ and __ImageIO__ support.
 */
@interface UIImage (TIPAdditions)

#pragma mark Inferred Properties

/**
 The size of the image in pixels (not points).
 Effectively the size of the image with the image's scale applied.
 */
- (CGSize)tip_dimensions;

/**
 A best effort method to inspect the image to see if it has alpha.
 Inspecting the pixels is required if you want to go beyond just looking at the byte layout since it
 is possible to have an image with an alpha channel but all the pixels are opaque.
 @param inspectPixels provide `YES` for added rigor.  Can introduce a large cost (examining every pixel).
 @note At the moment, `CIImage` backed `UIImage` instances always return `YES`
 @note At the moment, if the image is animated (has `images` populated with multiple images), only
 the first image will be examined
 */
- (BOOL)tip_hasAlpha:(BOOL)inspectPixels;

/**
 Given an image _type_ (or `nil`) determine the number of images this image has.
 @param type the image type to base the counting on (or `nil` to just consider the `images`)
 @note does NOT take custom codecs supported by the `TIPImageCodecCatalogue` into consideration,
 just the image types supported natively by __ImageIO__
 */
- (NSUInteger)tip_imageCountBasedOnImageType:(nullable NSString *)type;

/**
 A best effort method to estimate the size in bytes this image will take up in memory when fully
 decoded
 */
- (NSUInteger)tip_estimatedSizeInBytes;

#pragma mark Inspection Methods

/**
 Determine what the "best" image type for encoding this `UIImage` as given the provided _options_
 @note does NOT take custom codecs supported by the `TIPImageCodecCatalogue` into consideration,
 just the image types supported natively by __ImageIO__
 */
- (NSString *)tip_recommendedImageType:(TIPRecommendedImageTypeOptions)options;

/**
 Match this `UIImage` with target sizing
 @param targetDimensions the dimensions (size in pixels) of the target to match
 @param targetContentMode the `UIViewContentMode` of the target to match
 @return `YES` if there's a match, `NO` otherwise.
 @note computed target dimensions will be pixel aligned (i.e. any fractional pixels will be rounded
 up, e.g. { 625.75, 724.001 } ==> { 626, 725 })
 */
- (BOOL)tip_matchesTargetDimensions:(CGSize)targetDimensions contentMode:(UIViewContentMode)targetContentMode;

#pragma mark Transform Methods

/**
 Return a copy of the image scaled
 @param targetDimensions the target size in pixels to scale to.
 @param targetContentMode the target `UIViewContentMode` used to confine the scaling
 */
- (UIImage *)tip_scaledImageWithTargetDimensions:(CGSize)targetDimensions contentMode:(UIViewContentMode)targetContentMode;

/**
 Return a copy of the `UIImage` but transformed such that its `imageOrientation` is
 `UIImageOrientationUp`.
 If the `UIImage` is already oriented _Up_, returns `self`.
 */
- (UIImage *)tip_orientationAdjustedImage;

/**
 Return a copy of the image backed by a `CGImage` (instead of a `CIImage`)
 @param error The error if one was encountered
 @return an image backed by `CGImage` on success
 */
- (nullable UIImage *)tip_CGImageBackedImageAndReturnError:(out NSError * __nullable * __nullable)error;

/**
 Return a copy of the image in grayscale
 @note image must be backed by a `CGImage` or `nil` will be returned
 @return a grayscale image or `nil` if there was an issue
 */
- (nullable UIImage *)tip_grayscaleImage;

#pragma mark Decode Methods

/**
 Construct an animated image from encoded _data_
 @param data    the encoded image data
 @param durationsOut    populated with the animation durations on success
 @param loopCountOut    populated with the number of loops on success
 @return a `UIImage` on success, `nil` on failure.  Ought to be an animated image, but depends on
 the data passed in.
 */
+ (nullable UIImage *)tip_imageWithAnimatedImageData:(NSData *)data
                                           durations:(out NSArray<NSNumber *> * __nullable * __nullable)durationsOut
                                           loopCount:(out NSUInteger * __nullable)loopCountOut;
/**
 Construct an animated image with a file path
 @param filePath the path to an animated image file
 @param durationsOut the durations of the animated image that was loaded (`NULL` to ignore)
 @param loopCountOut the number of loops of the animated image that was loaded (`NULL` to ignore)
 @return an animated image or `nil` if there was an error
 */
+ (nullable UIImage *)tip_imageWithAnimatedImageFile:(NSString *)filePath
                                           durations:(out NSArray<NSNumber *> * __nullable * __nullable)durationsOut
                                           loopCount:(out NSUInteger * __nullable)loopCountOut;

#pragma mark Encode Methods

/**
 Write the target `UIImage` to an `NSData` instance
 @param type the image type to encode with.  Pass `nil` for automatic behavior.
 @param encodingOptions the `TIPImageEncodingOptions` to encode with
 @param quality the quality to encode with.  Pass `1.f` for lossless.  See `TIPImageTypes.h` for
 some constants that are better suited for encoding _JPEG_ images with.
 @param animationLoopCount the number of animation loops (if the image is animated).
 @param animationFrameDurations the durations for each frame (if the image is animated).  If the
 array's count doesn't match the number of frames, this argument is ignored.
 @param error the error if one was encountered
 @return the encoded image as an `NSData` or `nil` if there was an error
 @note does NOT take custom codecs supported by the `TIPImageCodecCatalogue` into consideration,
 just the image types supported natively by __ImageIO__
 */
- (nullable NSData *)tip_writeToDataWithType:(nullable NSString *)type
                             encodingOptions:(TIPImageEncodingOptions)encodingOptions
                                     quality:(float)quality
                          animationLoopCount:(NSUInteger)animationLoopCount
                     animationFrameDurations:(nullable NSArray<NSNumber *> *)animationFrameDurations
                                       error:(out NSError * __nullable * __nullable)error;

/**
 Write the target `UIImage` to file path
 @param filePath the path to write the image to
 @param type the image type to encode with.  Pass `nil` for automatic behavior.
 @param encodingOptions the `TIPImageEncodingOptions` to encode with
 @param quality the quality to encode with.  Pass `1.f` for lossless.  See `TIPImageTypes.h` for
 some constants that are better suited for encoding _JPEG_ images with.
 @param animationLoopCount the number of animation loops (if the image is animated).
 @param animationFrameDurations the durations for each frame (if the image is animated).
 If the array's count doesn't match the number of frames, this argument is ignored.
 @param error the error if one was encountered
 @param atomic if the writing of the file should be atomic
 @return `YES` on success, `NO` on failure
 @note does NOT take custom codecs supported by the `TIPImageCodecCatalogue` into consideration,
 just the image types supported natively by __ImageIO__
 */
- (BOOL)tip_writeToFile:(NSString *)filePath
                   type:(nullable NSString *)type
        encodingOptions:(TIPImageEncodingOptions)encodingOptions
                quality:(float)quality
     animationLoopCount:(NSUInteger)animationLoopCount
animationFrameDurations:(nullable NSArray<NSNumber *> *)animationFrameDurations
             atomically:(BOOL)atomic
                  error:(out NSError * __nullable * __nullable)error;

#pragma mark Other Methods

/**
 Simply decodes the underlying image so that it can be rendered to screen.
 Explicit decoding in the background saves from implicit decoding happening on the main thread which
 can lead to FPS drop.
 */
- (void)tip_decode;

@end

@interface UIImage (TIPAdditions_CGImage)

/**
 Construct an animated image with a `CGImageSourceRef`
 @param imageSource the `CGImageSourceRef` to load from
 @param durationsOut the durations of the animated image that was loaded (`NULL` to ignore)
 @param loopCountOut the number of loops of the animated image that was loaded (`NULL` to ignore)
 @return an animated image or `nil` if there was an error
 */
+ (nullable UIImage *)tip_imageWithAnimatedImageSource:(CGImageSourceRef)imageSource
                                             durations:(out NSArray<NSNumber *> * __nullable * __nullable)durationsOut
                                             loopCount:(out NSUInteger * __nullable)loopCountOut;

/**
 Write an image to a `CGImageDestinationRef`
 @param destinationRef          the destination to write to
 @param type                    the image type
 @param options                 the `TIPImageEncodingOptions` to write with
 @param quality                 the quality to write as (if supported)
 @param animationLoopCount      the number of loops to animate (if animated)
 @param animationFrameDurations the durations for each frame of the animation (if animated)
 @param error                   populate if an error was encountered
 @return `YES` on success, `NO` on error
 */
- (BOOL)tip_writeToCGImageDestination:(CGImageDestinationRef)destinationRef
                                 type:(NSString *)type
                      encodingOptions:(TIPImageEncodingOptions)options
                              quality:(float)quality
                   animationLoopCount:(NSUInteger)animationLoopCount
              animationFrameDurations:(nullable NSArray<NSNumber *> *)animationFrameDurations
                                error:(out NSError * __nullable * __nullable)error;
@end

NS_ASSUME_NONNULL_END
