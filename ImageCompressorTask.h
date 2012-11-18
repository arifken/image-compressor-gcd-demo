/*!
 * \file    TaskGroup
 * \project 
 * \author  Andy Rifken 
 * \date    11/17/12.
 *
 */



#import <Foundation/Foundation.h>


@interface ImageCompressorTask : NSObject {
    NSArray *mImageUrls;
    void(^mOnComplete)(NSArray *imageCompressionResults);
}
@property(strong) NSArray *imageUrls;
@property(copy) void (^onComplete)(NSArray *);

- (void) start;

@end


@interface ImageCompressionResult : NSObject {
    NSURL *mUrl;
    NSString *mLocalPath;
    NSError *mError;
}
@property(strong) NSURL *url;
@property(copy) NSString *localPath;
@property(strong) NSError *error;


@end