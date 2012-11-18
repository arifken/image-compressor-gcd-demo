/*
 Copyright (C) 2012 Andy Rifken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name of the author nor the names of its contributors may be used
   to endorse or promote products derived from this software without specific
   prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ImageCompressorTask.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation ImageCompressorTask
@synthesize imageUrls = mImageUrls;
@synthesize onComplete = mOnComplete;

+ (void) runExample {
    ImageCompressorTask *task = [[ImageCompressorTask alloc] init];
    task.imageUrls = @[
    [NSURL URLWithString:@"http://placekitten.com/1024/1024"],
    [NSURL URLWithString:@"http://placekitten.com/512/512"],
    [NSURL URLWithString:@"http://placekitten.com/1024/512"]
    ];
    [task setOnComplete:^(NSArray *array) {
        for (ImageCompressionResult *result in array) {
            NSLog(@"Completed %@ ==> %@. error = %@", result.url, result.localPath, result.error);
        }
    }];
    [task start];
}

- (void)start {
    NSArray *imageUrls = mImageUrls;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            NSUInteger numberOfUrls = [imageUrls count];
            NSMutableArray *results = [[NSMutableArray alloc] init];

            // this will allow us to block this group thread all the other threads are complete
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);

            for (NSURL *url in imageUrls) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    @autoreleasepool {
                        NSError *error = nil;
                        // download the image data
                        NSData *imageData = [[NSData alloc] initWithContentsOfURL:url options:0 error:&error];
                        if (!error) {
                            // create a UIImage
                            UIImage *fullImage = [[UIImage alloc] initWithData:imageData];

                            // compress the image
                            NSData *compressedImageData = UIImageJPEGRepresentation(fullImage, 0.1);

                            // write to local file system
                            NSString *filename = [ImageCompressorTask sha1OfUrl:url];
                            NSString *outPath = [NSString stringWithFormat:@"%@/%@.jpg",
                                                                           [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0],
                                                                           filename];

                            [compressedImageData writeToFile:outPath options:0 error:&error];

                            // prepare result
                            ImageCompressionResult *result = [[ImageCompressionResult alloc] init];
                            result.url = url;
                            result.localPath = outPath;
                            result.error = error;

                            @synchronized (results) {
                                [results addObject:result];
                            }

                            // tell the group thread we completed one of the tasks:
                            dispatch_semaphore_signal(sema);
                        }
                    }
                });
            }

            // wait here until we get a 'completed' signal from each of the worker threads
            for (int j = 0; j < numberOfUrls; j++) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            }

            // if we got here, it means that all the worker threads completed, so send the onComplete callback to the
            // main thread
            if (mOnComplete) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    mOnComplete(results);
                });
            }
        }
    });
}


+ (NSString *)sha1OfUrl:(NSURL *)url {
    NSString *urlPath = [[[url standardizedURL] absoluteString] lowercaseString];

    unsigned char digestChars[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([urlPath UTF8String], (unsigned int) [urlPath lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digestChars);

    NSMutableString *digestString = [[NSMutableString alloc] init];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        NSString *hexInt = [NSString stringWithFormat:@"%02x", digestChars[i]];
        [digestString appendString:hexInt];
    }

    return digestString;
}


@end

@implementation ImageCompressionResult
@synthesize url = mUrl;
@synthesize localPath = mLocalPath;
@synthesize error = mError;


@end
