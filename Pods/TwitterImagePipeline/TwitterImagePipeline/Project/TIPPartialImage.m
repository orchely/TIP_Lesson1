//
//  TIPPartialImage.m
//  TwitterImagePipeline
//
//  Created on 3/6/15.
//  Copyright (c) 2015 Twitter. All rights reserved.
//

#import "TIP_Project.h"
#import "TIPImageCodecCatalogue.h"
#import "TIPPartialImage.h"

@interface TIPPartialImageCodecDetector : NSObject
@property (nullable, nonatomic, readonly) NSMutableData *codecDetectionBuffer;
@property (nullable, nonatomic, readonly) id<TIPImageCodec> detectedCodec;
@property (nullable, nonatomic, readonly, copy) NSString *detectedImageType;
- (instancetype)initWithExpectedDataLength:(NSUInteger)expectedDataLength;
- (BOOL)appendData:(NSData *)data final:(BOOL)final;
@end

static const float kUnfinishedImageProgressCap = 0.999f;

@interface TIPPartialImage ()
@property (nonatomic, readwrite) TIPPartialImageState state;
@end

@implementation TIPPartialImage
{
    TIPPartialImageCodecDetector *_codecDetector;
    id<TIPImageCodec> _codec;
    id<TIPImageDecoder> _decoder;
    id<TIPImageDecoderContext> _decoderContext;
    dispatch_queue_t _renderQueue;
}

// the following getters may appear superfluous, and would be if it weren't for the need to
// annotate them with __attribute__((no_sanitize("thread")).  the getters make the @synthesize
// lines necessary.
//
// the reason these are thread safe is that the ivars are assigned/mutated in
// _tip_extractState, which is only ever called from within _tip_appendData:
// within a dispatch_sync{_renderQueue, ^{...}),  making their access thread safe via nonatomic.

@synthesize byteCount = _byteCount;
@synthesize dimensions = _dimensions;
@synthesize frameCount = _frameCount;

@synthesize hasAlpha = _hasAlpha;
@synthesize animated = _animated;
@synthesize progressive = _progressive;

- (NSUInteger)byteCount TIP_THREAD_SANITIZER_DISABLED
{
    return _byteCount;
}

- (CGSize)dimensions TIP_THREAD_SANITIZER_DISABLED
{
    return _dimensions;
}

- (NSUInteger)frameCount TIP_THREAD_SANITIZER_DISABLED
{
    return _frameCount;
}

- (BOOL)hasAlpha TIP_THREAD_SANITIZER_DISABLED
{
    return _hasAlpha;
}

- (BOOL)isAnimated TIP_THREAD_SANITIZER_DISABLED
{
    return _animated;
}

- (BOOL)isProgressive TIP_THREAD_SANITIZER_DISABLED
{
    return _progressive;
}

- (NSData *)data
{
    __block NSData *data = nil;
    dispatch_sync(_renderQueue, ^{
        data = self->_decoderContext.tip_data;
    });
    return data;
}

- (instancetype)initWithExpectedContentLength:(NSUInteger)contentLength
{
    if (self = [super init]) {
        _expectedContentLength = contentLength;
        _renderQueue = dispatch_queue_create("com.twitter.tip.partial.image.render.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (float)progress
{
    if (!_expectedContentLength) {
        return 0.0f;
    }

    const float progress = MIN(kUnfinishedImageProgressCap, (float)((double)self.byteCount / (double)_expectedContentLength));
    return progress;
}

- (TIPImageDecoderAppendResult)appendData:(NSData *)data final:(BOOL)final
{
    __block TIPImageDecoderAppendResult result = TIPImageDecoderAppendResultDidProgress;

    dispatch_sync(_renderQueue, ^{
        result = [self _tip_appendData:data final:final];
    });

    return result;
}

- (BOOL)_tip_detectCodec:(NSData *)data final:(BOOL)final
{
    if (!_codec) {
        if (!_codecDetector) {
            _codecDetector = [[TIPPartialImageCodecDetector alloc] initWithExpectedDataLength:_expectedContentLength];
        }

        if ([_codecDetector appendData:data final:final]) {
            _type = _codecDetector.detectedImageType;
            _codec = _codecDetector.detectedCodec;
            _decoder = _codec.tip_decoder;
            NSMutableData *buffer = _codecDetector.codecDetectionBuffer;
            if (buffer.length == 0) {
                buffer = [NSMutableData dataWithCapacity:_expectedContentLength];
                [buffer appendData:data];
            }
            _decoderContext = [_decoder tip_initiateDecodingWithExpectedDataLength:_expectedContentLength buffer:buffer];
            _codecDetector = nil;
            return YES;
        }
    }

    return NO;
}

- (TIPImageDecoderAppendResult)_tip_appendData:(NSData *)data final:(BOOL)final
{
    if (TIPPartialImageStateComplete == _state) {
        return TIPImageDecoderAppendResultDidCompleteLoading;
    }

    TIPImageDecoderAppendResult result = TIPImageDecoderAppendResultDidProgress;
    if (!_codec) {
        if ([self _tip_detectCodec:data final:final]) {
            // We want our append to be unified below
            // but at this point we'll have prepopulated the buffer.
            // Change "data" to be 0 bytes so that we can keep our logic
            // without doubling the data that's being appended :)
            data = [NSData data];
        }
    }

    if (_decoder) {
        result = [_decoder tip_append:_decoderContext data:data];
        if (final) {
            if ([_decoder tip_finalizeDecoding:_decoderContext] == TIPImageDecoderAppendResultDidCompleteLoading) {
                result = TIPImageDecoderAppendResultDidCompleteLoading;
            }
        }
        [self _tip_extractState];
    }

    [self _tip_updateStateWithLatestResult:result];
    return result;
}

- (void)_tip_updateStateWithLatestResult:(TIPImageDecoderAppendResult)result
{
    switch (result) {
        case TIPImageDecoderAppendResultDidLoadHeaders:
        case TIPImageDecoderAppendResultDidLoadFrame:
            if (_state <= TIPPartialImageStateLoadingImage) {
                _state = TIPPartialImageStateLoadingImage;
            }
            break;
        case TIPImageDecoderAppendResultDidCompleteLoading:
            if (_state <= TIPPartialImageStateComplete) {
                _state = TIPPartialImageStateComplete;
            }
            break;
        case TIPImageDecoderAppendResultDidProgress:
        default:
            if (_state <= TIPPartialImageStateLoadingHeaders) {
                _state = TIPPartialImageStateLoadingHeaders;
            }
            break;
    }
}

- (void)_tip_extractState
{
    if (_decoderContext) {
        _byteCount = _decoderContext.tip_data.length;
        _frameCount = _decoderContext.tip_frameCount;
        _dimensions = _decoderContext.tip_dimensions;
        if ([_decoderContext respondsToSelector:@selector(tip_isProgressive)]) {
            _progressive = _decoderContext.tip_isProgressive;
        }
        if ([_decoderContext respondsToSelector:@selector(tip_isAnimated)]) {
            _animated = _decoderContext.tip_isAnimated;
        }
        if ([_decoderContext respondsToSelector:@selector(tip_hasAlpha)]) {
            _hasAlpha = _decoderContext.tip_hasAlpha;
        }
        if ([_decoderContext respondsToSelector:@selector(tip_hasGPSInfo)]) {
            _hasGPSInfo = _decoderContext.tip_hasGPSInfo;
        }
    }
}

- (TIPImageContainer *)renderImageWithMode:(TIPImageDecoderRenderMode)mode decoded:(BOOL)decode
{
    __block TIPImageContainer *image = nil;

    dispatch_sync(_renderQueue, ^{
        image = [self->_decoder tip_renderImage:self->_decoderContext mode:mode];
        if (image && decode) {
            [image decode];
        }
    });

    return image;
}

@end

@implementation TIPPartialImageCodecDetector
{
    NSUInteger _expectedDataLength;
    CGImageSourceRef _codecDetectionImageSource;
    NSMutableDictionary<NSString *, id<TIPImageCodec>> *_potentialCodecs;
}

- (instancetype)initWithExpectedDataLength:(NSUInteger)expectedDataLength
{
    if (self = [super init]) {
        _expectedDataLength = expectedDataLength;
    }
    return self;
}

- (BOOL)appendData:(NSData *)data final:(BOOL)final
{
    if (!_codecDetectionImageSource) {
        TIPAssert(!_codecDetectionBuffer);

        if ([self _tip_quickDetectCodec:data]) {
            TIPAssert(_detectedCodec != nil);
            return YES;
        }

        _codecDetectionBuffer = [[NSMutableData alloc] initWithCapacity:_expectedDataLength];

        NSDictionary *options = @{ (NSString *)kCGImageSourceShouldCache : @NO };
        _codecDetectionImageSource = CGImageSourceCreateIncremental((CFDictionaryRef)options);

        _potentialCodecs = [[TIPImageCodecCatalogue sharedInstance].allCodecs mutableCopy];
    }

    if (data) {
        [_codecDetectionBuffer appendData:data];
    }
    CGImageSourceUpdateData(_codecDetectionImageSource, (CFDataRef)_codecDetectionBuffer, final);

    [self _tip_detectCodec];
    return _detectedCodec != nil;
}

- (void)dealloc
{
    if (_codecDetectionImageSource) {
        CFRelease(_codecDetectionImageSource);
    }
}

- (BOOL)_tip_quickDetectCodec:(NSData *)data
{
    NSString *quickDetectType = TIPDetectImageTypeViaMagicNumbers(data);
    if (quickDetectType) {
        id<TIPImageCodec> quickCodec = [TIPImageCodecCatalogue sharedInstance][quickDetectType];
        if (quickCodec) {
            TIPImageDecoderDetectionResult result = [quickCodec.tip_decoder tip_detectDecodableData:data earlyGuessImageType:quickDetectType];
            if (TIPImageDecoderDetectionResultMatch == result) {
                _detectedCodec = quickCodec;
                _detectedImageType = [quickDetectType copy];
                return YES;
            }
        }
    }
    return NO;
}

- (void)_tip_detectCodec
{
    TIPAssert(_codecDetectionImageSource != nil);
    if (_detectedCodec || _potentialCodecs.count == 0) {
        return;
    }

    NSString *detectedImageType = nil;
    NSString *detectedUTType = (NSString *)CGImageSourceGetType(_codecDetectionImageSource);
    if (detectedUTType) {
        detectedImageType = TIPImageTypeFromUTType(detectedUTType);
    }

    id<TIPImageCodec> matchingImageTypeCodec = (detectedImageType) ? _potentialCodecs[detectedImageType] : nil;
    if (matchingImageTypeCodec) {
        TIPImageDecoderDetectionResult result = [matchingImageTypeCodec.tip_decoder tip_detectDecodableData:_codecDetectionBuffer earlyGuessImageType:detectedImageType];
        if (TIPImageDecoderDetectionResultMatch == result) {
            _detectedCodec = matchingImageTypeCodec;
            _detectedImageType = detectedImageType;
            return;
        } else if (TIPImageDecoderDetectionResultNoMatch == result) {
            [_potentialCodecs removeObjectForKey:detectedImageType];
            if (0 == _potentialCodecs.count) {
                return;
            }
        }
    }

    NSMutableArray<NSString *> *excludedCodecImageTypes = [[NSMutableArray alloc] initWithCapacity:_potentialCodecs.count];
    [_potentialCodecs enumerateKeysAndObjectsUsingBlock:^(NSString *imageType, id<TIPImageCodec> codec, BOOL *stop) {
        TIPImageDecoderDetectionResult result = [codec.tip_decoder tip_detectDecodableData:self->_codecDetectionBuffer earlyGuessImageType:detectedImageType];
        if (TIPImageDecoderDetectionResultMatch == result) {
            self->_detectedCodec = codec;
            self->_detectedImageType = imageType;
            *stop = YES;
        } else if (TIPImageDecoderDetectionResultNoMatch == result) {
            [excludedCodecImageTypes addObject:imageType];
        }
    }];

    if (!_detectedCodec) {
        [_potentialCodecs removeObjectsForKeys:excludedCodecImageTypes];
    }
}

@end
