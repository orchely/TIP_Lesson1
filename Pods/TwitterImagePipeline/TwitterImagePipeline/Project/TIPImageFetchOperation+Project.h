//
//  TIPImageFetchOperation+Project.h
//  TwitterImagePipeline
//
//  Created on 3/6/15.
//  Copyright (c) 2015 Twitter. All rights reserved.
//

#import "TIPImageDownloader.h"
#import "TIPImageFetchOperation.h"

@class TIPImagePipeline;
@class TIPImageCacheEntry;

@interface TIPImageFetchOperation (Project) <TIPImageDownloadDelegate>

@property (nonatomic, readonly, copy) NSString *imageIdentifier;
@property (nonatomic, readonly) NSURL *imageURL;

- (instancetype)initWithImagePipeline:(TIPImagePipeline *)pipeline request:(id<TIPImageFetchRequest>)request delegate:(id<TIPImageFetchDelegate>)delegate;

- (void)earlyCompleteOperationWithImageEntry:(TIPImageCacheEntry *)entry;
- (void)willEnqueue;
- (BOOL)supportsLoadingFromSource:(TIPImageLoadSource)source;

@end

@interface TIPImageFetchOperation (Testing)
- (id<TIPImageDownloadContext>)associatedDownloadContext;
@end
