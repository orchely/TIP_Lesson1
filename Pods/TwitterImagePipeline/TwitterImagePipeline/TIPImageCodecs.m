//
//  TIPImageCodecs.m
//  TwitterImagePipeline
//
//  Created on 11/7/16.
//  Copyright © 2016 Twitter. All rights reserved.
//

#import "TIP_Project.h"
#import "TIPError.h"
#import "TIPImageCodecs.h"

TIPImageContainer *TIPDecodeImageFromData(id<TIPImageCodec> codec, NSData *imageData) __attribute__((overloadable))
{
    return TIPDecodeImageFromData(codec, imageData, nil);
}

TIPImageContainer *TIPDecodeImageFromData(id<TIPImageCodec> codec, NSData *imageData, NSString *earlyGuessImageType) __attribute__((overloadable))
{
    TIPImageContainer *container = nil;
    id<TIPImageDecoder> decoder = codec.tip_decoder;
    if ([decoder respondsToSelector:@selector(tip_decodeImageWithData:)]) {
        container = [decoder tip_decodeImageWithData:imageData];
    } else {
        if (TIPImageDecoderDetectionResultMatch == [decoder tip_detectDecodableData:imageData earlyGuessImageType:earlyGuessImageType]) {
            id<TIPImageDecoderContext> context = [decoder tip_initiateDecodingWithExpectedDataLength:imageData.length buffer:nil];
            [decoder tip_append:context data:imageData];
            if (TIPImageDecoderAppendResultDidCompleteLoading == [decoder tip_finalizeDecoding:context]) {
                container = [decoder tip_renderImage:context mode:TIPImageDecoderRenderModeCompleteImage];
            }
        }
    }
    return container;
}

BOOL TIPEncodeImageToFile(id<TIPImageCodec> codec, TIPImageContainer *imageContainer, NSString *filePath, TIPImageEncodingOptions options, float quality, BOOL atomic, NSError **error)
{
    BOOL success = NO;
    id<TIPImageEncoder> encoder = codec.tip_encoder;
    if (!encoder) {
        if (error) {
            *error = [NSError errorWithDomain:TIPErrorDomain code:TIPErrorCodeEncodingUnsupported userInfo:@{ @"codec" : codec }];
        }
    } else {
        if ([encoder respondsToSelector:@selector(tip_writeToFile:withImage:encodingOptions:suggestedQuality:atomically:error:)]) {
            success = [encoder tip_writeToFile:filePath withImage:imageContainer encodingOptions:options suggestedQuality:quality atomically:atomic error:error];
        } else {
            NSData *data = [encoder tip_writeDataWithImage:imageContainer encodingOptions:options suggestedQuality:quality error:error];
            if (data) {
                success = [data writeToFile:filePath options:(atomic) ? NSDataWritingAtomic : 0 error:error];
            }
        }
    }

    if (!success && error) {
        TIPAssert(*error != nil);
        if (!*error) {
            *error = [NSError errorWithDomain:TIPErrorDomain code:TIPErrorCodeUnknown userInfo:nil];
        }
    }

    return success;
}
