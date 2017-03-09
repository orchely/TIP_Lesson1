//
//  TIPImageFetchMetrics+Project.h
//  TwitterImagePipeline
//
//  Created on 6/19/15.
//  Copyright (c) 2015 Twitter. All rights reserved.
//

#import "TIPImageFetchMetrics.h"

@class TIPPartialImage;

@interface TIPImageFetchMetrics ()

- (nonnull instancetype)initProject;

- (void)startWithSource:(TIPImageLoadSource)source;
- (void)endSource;
- (void)cancelSource;

- (void)convertNetworkMetricsToResumedNetworkMetrics;
- (void)addNetworkMetrics:(nullable id)metrics forRequest:(nonnull NSURLRequest *)request imageType:(nullable NSString *)imageType imageSizeInBytes:(NSUInteger)sizeInBytes imageDimensions:(CGSize)dimensions;

- (void)previewWasHit:(NSTimeInterval)renderLatency;
- (void)progressiveFrameWasHit:(NSTimeInterval)renderLatency;
- (void)finalWasHit:(NSTimeInterval)renderLatency;

@end

@interface TIPImageFetchMetricInfo ()

- (nonnull instancetype)initWithSource:(TIPImageLoadSource)source startTime:(uint64_t)startMachTime;

- (void)end;
- (void)cancel;
- (void)hit:(TIPImageFetchLoadResult)result renderLatency:(NSTimeInterval)renderLatency;
- (void)addNetworkMetrics:(nullable id)metrics forRequest:(nonnull NSURLRequest *)request imageType:(nullable NSString *)imageType imageSizeInBytes:(NSUInteger)sizeInBytes imageDimensions:(CGSize)dimensions;
- (void)flipLoadSourceFromNetworkToNetworkResumed;

@end
