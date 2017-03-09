//
//  TIPImageFetchDownload.m
//  TwitterImagePipeline
//
//  Created on 8/24/16.
//  Copyright © 2016 Twitter. All rights reserved.
//

#import "TIP_Project.h"
#import "TIPImageFetchDownloadInternal.h"

@class TIPImageFetchDownloadInternalURLSessionDelegate;
@class NSURLSessionTaskMetrics;

NSString * const TIPImageFetchDownloadConstructorExceptionName = @"TIPImageFetchDownloadConstructorException";

static NSURLSession *sTIPImageFetchDownloadInternalURLSession = nil;
static NSOperationQueue *sTIPImageFetchDownloadInternalOperationQueue = nil;
static TIPImageFetchDownloadInternalURLSessionDelegate *sTIPImageFetchDownloadInternalURLSessionDelegate = nil;

static float ConvertNSOperationQueuePriorityToNSURLSessionTaskPriority(NSOperationQueuePriority pri);

@interface TIPImageFetchDownloadInternalURLSessionDelegate : NSObject <NSURLSessionDataDelegate>
- (void)addDownload:(TIPImageFetchDownloadInternal *)download;
- (void)removeDownloadWithTask:(NSURLSessionDataTask *)task;
@end

@interface TIPImageFetchDownloadInternal ()

@property (nonatomic, readonly) NSURLSessionDataTask *task;
@property (nonatomic) id downloadMetrics;
@property (nonatomic, readonly) dispatch_queue_t contextQueue;

- (void)prepare;

@end

@implementation TIPImageFetchDownloadProviderInternal

- (id<TIPImageFetchDownload>)imageFetchDownloadWithContext:(id<TIPImageFetchDownloadContext>)context
{
    return [[TIPImageFetchDownloadInternal alloc] initWithContext:context];
}

@end

@implementation TIPImageFetchDownloadInternal
{
    NSOperationQueuePriority _priority;
    BOOL _started;
    NSURLSession *_session;
}

@synthesize context = _context;

- (instancetype)initWithContext:(id<TIPImageFetchDownloadContext>)context
{
    if (self = [super init]) {
        _context = context;
        _contextQueue = context.downloadQueue;
    }
    return self;
}

- (void)dealloc
{
    NSURLSessionDataTask *task = _task;
    if (task) {
        TIPImageFetchDownloadInternalURLSessionDelegate *delegate = (id)_session.delegate;
        [_session.delegateQueue addOperationWithBlock:^{
            if (task) {
                [delegate removeDownloadWithTask:task];
            }
        }];
    }
}

- (void)start
{
    if (_started) {
        return;
    }

    _started = YES;
    _session = [self URLSession];
    id<TIPImageFetchDownloadContext> context = self.context;
    [context.client imageFetchDownloadDidStart:self];
    [context.client imageFetchDownload:self hydrateRequest:context.originalRequest completion:^(NSError *error) {
        if (!error) {
            self->_task = [self->_session dataTaskWithRequest:context.hydratedRequest];
            [self->_session.delegateQueue addOperationWithBlock:^{
                [(TIPImageFetchDownloadInternalURLSessionDelegate *)self->_session.delegate addDownload:self];
            }];
            [self->_task resume];
        } else {
            [context.client imageFetchDownload:self didCompleteWithError:error];
        }
    }];
}

- (void)cancelWithDescription:(NSString *)cancelDescription
{
    [_task cancel];
}

#pragma mark Properties

- (void)discardContext
{
    _context = nil;
}

- (void)setPriority:(NSOperationQueuePriority)priority
{
    _priority = priority;
    _task.priority = ConvertNSOperationQueuePriorityToNSURLSessionTaskPriority(_priority);
}

- (NSOperationQueuePriority)priority
{
    return _priority;
}

- (NSURLRequest *)finalURLRequest
{
    return _task.currentRequest;
}

#pragma mark Private

- (void)prepare
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        dispatch_queue_t queue = dispatch_queue_create("TIPImageFetchDownloadInternal.queue", DISPATCH_QUEUE_SERIAL);
        sTIPImageFetchDownloadInternalOperationQueue = [[NSOperationQueue alloc] init];
        sTIPImageFetchDownloadInternalOperationQueue.maxConcurrentOperationCount = 1;
        sTIPImageFetchDownloadInternalOperationQueue.underlyingQueue = queue;

        sTIPImageFetchDownloadInternalURLSessionDelegate = [[TIPImageFetchDownloadInternalURLSessionDelegate alloc] init];

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPCookieStorage = nil;
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        config.HTTPShouldSetCookies = NO;
        config.URLCache = nil;
        config.timeoutIntervalForResource = 60 * 3;

        sTIPImageFetchDownloadInternalURLSession = [NSURLSession sessionWithConfiguration:config delegate:sTIPImageFetchDownloadInternalURLSessionDelegate delegateQueue:sTIPImageFetchDownloadInternalOperationQueue];
    });
}

- (NSURLSession *)URLSession
{
    if ((__bridge void *)sTIPImageFetchDownloadInternalURLSession == nil) {
        [self prepare];
    }

    return sTIPImageFetchDownloadInternalURLSession;
}

@end

@implementation TIPImageFetchDownloadInternalURLSessionDelegate
{
    NSMapTable<NSNumber *, TIPImageFetchDownloadInternal *> *_downloadContexts;
}

- (instancetype)init
{
    if (self = [super init]) {
        _downloadContexts = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (void)addDownload:(TIPImageFetchDownloadInternal *)download
{
    [_downloadContexts setObject:download forKey:@(download.task.taskIdentifier)];
}

- (void)removeDownloadWithTask:(NSURLSessionDataTask *)task
{
    [_downloadContexts removeObjectForKey:@(task.taskIdentifier)];
}

#pragma mark Delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    TIPImageFetchDownloadInternal *download = [_downloadContexts objectForKey:@(dataTask.taskIdentifier)];
    if (download) {
        dispatch_async(download.contextQueue, ^{
            [download.context.client imageFetchDownload:download didReceiveURLResponse:(NSHTTPURLResponse *)response];
        });
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    TIPImageFetchDownloadInternal *download = [_downloadContexts objectForKey:@(dataTask.taskIdentifier)];
    if (download) {
        dispatch_async(download.contextQueue, ^{
            [download.context.client imageFetchDownload:download didReceiveData:data];
        });
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    TIPImageFetchDownloadInternal *download = [_downloadContexts objectForKey:@(task.taskIdentifier)];
    if (download) {
        dispatch_async(download.contextQueue, ^{
            [download.context.client imageFetchDownload:download didCompleteWithError:error];
        });
        [_downloadContexts removeObjectForKey:@(task.taskIdentifier)];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics;
{
    TIPImageFetchDownloadInternal *download = [_downloadContexts objectForKey:@(task.taskIdentifier)];
    if (download) {
        dispatch_async(download.contextQueue, ^{
            download.downloadMetrics = metrics;
        });
    }
}

@end

@implementation NSHTTPURLResponse (TIPStubbingSupport)

+ (instancetype)tip_responseWithRequestURL:(NSURL *)requestURL dataLength:(NSUInteger)dataLength responseMIMEType:(NSString *)MIMEType
{
    NSInteger statusCode = 404;
    NSMutableDictionary *headerFields = [[NSMutableDictionary alloc] init];
    if (dataLength > 0) {
        statusCode = 200;
        headerFields[@"Accept-Ranges"] = @"bytes";
        headerFields[@"Last-Modified"] = @"Wed, 15 Nov 1995 04:58:08 GMT";
    }
    if (MIMEType) {
        headerFields[@"Content-Type"] = MIMEType;
    }

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestURL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    return response;
}

@end

static float ConvertNSOperationQueuePriorityToNSURLSessionTaskPriority(NSOperationQueuePriority pri)
{
    NSInteger priShifted = pri + 9;
    if (priShifted < 0) {
        priShifted = 0;
    }

    float taskPri = priShifted / 18;
    if (taskPri > 1.f) {
        taskPri = 1.f;
    }

    return taskPri;
}
