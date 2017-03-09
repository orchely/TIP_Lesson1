//
//  TIPURLStringCoding.m
//  TwitterImagePipeline
//
//  Created on 8/12/16.
//  Copyright (c) 2016 Twitter. All rights reserved.
//

#import "TIP_Project.h"
#import "TIPURLStringCoding.h"

static const char kHexDigits[] = "0123456789ABCDEF";

NSString *TIPURLEncodeString(NSString *string)
{
    if (0 == string.length) {
        return @"";
    }

    const char *stringAsUTF8 = [string UTF8String];
    if (stringAsUTF8 == NULL) {
        NSMutableString *byteString = [[NSMutableString alloc] init];
        for (NSUInteger i = 0; i < string.length; i++) {
            unichar uchar = [string characterAtIndex:i];
            [byteString appendFormat:@"%02X ", uchar];
        }
        TIPLogError(@"No UTF8String for NSString:\n%@", byteString);
        return nil;
    }

    NSUInteger encodedLength = 0;
    BOOL needsEncoding = NO;
    for (const char *c = stringAsUTF8; *c; c++) {
        switch (*c) {
            case '0' ... '9':
            case 'A' ... 'Z':
            case 'a' ... 'z':
            case '-':
            case '.':
            case '_':
            case '~':
                encodedLength++;
                break;
            default:
                encodedLength += 3;
                needsEncoding = YES;
                break;
        }
    }
    if (!needsEncoding) {
        return string;
    }

    char *encodedBytes = malloc(encodedLength);
    if (NULL == encodedBytes) {
        TIPLogError(@"Out of memory");
        return nil;
    }

    char *outPtr = encodedBytes;
    for (const unsigned char *c = (const unsigned char *)stringAsUTF8; *c; c++) {
        switch (*c) {
            case '0' ... '9':
            case 'A' ... 'Z':
            case 'a' ... 'z':
            case '-':
            case '.':
            case '_':
            case '~':
                *outPtr++ = (char)*c;
                break;
            default:
                *outPtr++ = '%';
                *outPtr++ = kHexDigits[(*c>>4)&0xf];
                *outPtr++ = kHexDigits[*c&0xf];
                break;
        }
    }

    NSString *encodedString = [[NSString alloc] initWithBytesNoCopy:encodedBytes length:encodedLength encoding:NSASCIIStringEncoding freeWhenDone:YES];
    if (encodedString == nil) {
        TIPLogError(@"Can't create encodedString from '%@'", string);
        free(encodedBytes);
    }
    return encodedString;
}

NSString *TIPURLDecodeString(NSString *string, BOOL replacePlussesWithSpaces)
{
    NSString *s = string;
    // replace the '+' first since if the '+' is encoded we want to preserve its value
    if (replacePlussesWithSpaces) {
        s = [s stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    }

    // the deprecated [s stringByReplacingPercentExcapesUsingEncoding:NSUTF8StringEncoding]
    // used to return @"" for @"" .  the replacement method returns nil.
    //
    // by checking length, we preserve the old behavior for this caller in case anything depended upon it.
    return s.length ? [s stringByRemovingPercentEncoding] : s;
}
