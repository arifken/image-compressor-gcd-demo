/*!
 * \file    TaskGroup
 * \project 
 * \author  Andy Rifken 
 * \date    11/17/12.
 *
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
                    NSError *error = nil;
                    // download the image data
                    NSData *imageData = [[NSData alloc] initWithContentsOfURL:url options:0 error:&error];
                    if (!error) {
                        // create a UIImage
                        UIImage *fullImage = [[UIImage alloc] initWithData:imageData];

                        // compress the image
                        NSData *compressedImageData = UIImageJPEGRepresentation(fullImage, 0.1);

                        // write to local file system
                        NSString *filename = [ImageCompressorTask md5OfURL:url];
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


+ (NSString *)md5OfURL:(NSURL *)url {
    unsigned char hashedChars[CC_SHA1_DIGEST_LENGTH];
    NSString *urlPath = [[[url standardizedURL] absoluteString] lowercaseString];
    CC_SHA1([urlPath UTF8String], (unsigned int) [urlPath lengthOfBytesUsingEncoding:NSUTF8StringEncoding], hashedChars);

    NSMutableString *vdigest = [NSMutableString string];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        NSString *hexInt = [NSString stringWithFormat:@"%02x", hashedChars[i]];
        [vdigest appendString:hexInt];
    }
    return vdigest;
}


@end

@implementation ImageCompressionResult
@synthesize url = mUrl;
@synthesize localPath = mLocalPath;
@synthesize error = mError;


@end
