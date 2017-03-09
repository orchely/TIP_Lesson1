//
//  TIPGlobalConfiguration+Project.h
//  TwitterImagePipeline
//
//  Created on 10/1/15.
//  Copyright © 2015 Twitter. All rights reserved.
//

#import "TIPGlobalConfiguration.h"
#import "TIPImageCache.h"

@protocol TIPImageFetchDownload;
@protocol TIPImageFetchDownloadContext;

NS_ASSUME_NONNULL_BEGIN

@interface TIPGlobalConfiguration ()

// only accessible from queueForDiskCaches
@property (nonatomic) SInt16 internalMaxCountForAllDiskCaches;
@property (nonatomic) SInt64 internalMaxBytesForAllDiskCaches;
@property (nonatomic) SInt64 internalMaxBytesForDiskCacheEntry;
@property (nonatomic) SInt16 internalTotalCountForAllDiskCaches;
@property (nonatomic) SInt64 internalTotalBytesForAllDiskCaches;

// only accessible from queueForMemoryCaches
@property (nonatomic) SInt16 internalMaxCountForAllMemoryCaches;
@property (nonatomic) SInt64 internalMaxBytesForAllMemoryCaches;
@property (nonatomic) SInt64 internalMaxBytesForMemoryCacheEntry;
@property (nonatomic) SInt16 internalTotalCountForAllMemoryCaches;
@property (nonatomic) SInt64 internalTotalBytesForAllMemoryCaches;

// only accessible from main thread
@property (nonatomic) SInt16 internalMaxCountForAllRenderedCaches;
@property (nonatomic) SInt64 internalMaxBytesForAllRenderedCaches;
@property (nonatomic) SInt64 internalMaxBytesForRenderedCacheEntry;
@property (nonatomic) SInt16 internalTotalCountForAllRenderedCaches;
@property (nonatomic) SInt64 internalTotalBytesForAllRenderedCaches;

// shared queues
@property (nonatomic, readonly) dispatch_queue_t queueForMemoryCaches;
@property (nonatomic, readonly) dispatch_queue_t queueForDiskCaches;

// other properties
@property (atomic, nonnull, readonly) NSArray<id<TIPImagePipelineObserver>> *allImagePipelineObservers;
@property (atomic, nullable, strong) id<TIPLogger> internalLogger;
@property (nonatomic, readonly) BOOL imageFetchDownloadProviderSupportsStubbing;

// per cache type accessors
- (dispatch_queue_t)queueForCachesOfType:(TIPImageCacheType)type;
- (SInt16)internalMaxCountForAllCachesOfType:(TIPImageCacheType)type;
- (SInt16)internalTotalCountForAllCachesOfType:(TIPImageCacheType)type;
- (SInt64)internalMaxBytesForAllCachesOfType:(TIPImageCacheType)type;
- (SInt64)internalTotalBytesForAllCachesOfType:(TIPImageCacheType)type;
- (SInt64)internalMaxBytesForCacheEntryOfType:(TIPImageCacheType)type;

// methods

- (void)enqueueImagePipelineOperation:(NSOperation *)op;

- (void)postProblem:(NSString *)problemName userInfo:(NSDictionary<NSString *, id> *)userInfo;
- (void)accessedCGContext:(BOOL)seriallyAccessed duration:(NSTimeInterval)duration;

 // must call from correct queue (queueForMemoryCaches for memory caches, queueForDiskCaches for disk caches and main queue for rendered caches)
- (void)pruneAllCachesOfType:(TIPImageCacheType)type withPriorityCache:(nullable id<TIPImageCache>)priorityCache;
- (void)pruneAllCachesOfType:(TIPImageCacheType)type withPriorityCache:(nullable id<TIPImageCache>)priorityCache toGlobalMaxBytes:(SInt64)globalMaxBytes toGlobalMaxCount:(SInt16)globalMaxCount;

- (id<TIPImageFetchDownload>)createImageFetchDownloadWithContext:(id<TIPImageFetchDownloadContext>)context;

@end

NS_ASSUME_NONNULL_END
