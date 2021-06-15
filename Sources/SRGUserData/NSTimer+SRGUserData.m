//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSTimer+SRGUserData.h"

@implementation NSTimer (SRGUserData)

#pragma mark Class methods

+ (NSTimer *)srguserdata_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer * _Nonnull timer))block
{
    NSTimer *timer = [self timerWithTimeInterval:interval repeats:repeats block:block];
    
    // Use the recommended 10% tolerance as default, see `tolerance` documentation
    timer.tolerance = interval / 10.;
    
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    return timer;
}

@end
