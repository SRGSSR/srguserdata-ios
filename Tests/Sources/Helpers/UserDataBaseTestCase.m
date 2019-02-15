//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

@implementation UserDataBaseTestCase

- (NSURL *)URLForStoreFromPackage:(NSString *)package
{
    static NSString * const kStoreName = @"Data";
    
    if (package) {
        for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
            NSString *sqliteFilePath = [[NSBundle bundleForClass:self.class] pathForResource:kStoreName ofType:extension inDirectory:package];
            if (! [NSFileManager.defaultManager fileExistsAtPath:sqliteFilePath]) {
                continue;
            }
            
            NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
            NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:extension];
            XCTAssertTrue([NSFileManager.defaultManager replaceItemAtURL:sqliteDestinationFileURL
                                                           withItemAtURL:sqliteFileURL
                                                          backupItemName:nil
                                                                 options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                                        resultingItemURL:NULL
                                                                   error:NULL]);
        }
        
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:package] URLByAppendingPathExtension:@"sqlite"];
    }
    else {
        return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    }
}

- (XCTestExpectation *)expectationForElapsedTimeInterval:(NSTimeInterval)timeInterval withHandler:(void (^)(void))handler
{
    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for %@ seconds", @(timeInterval)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
        handler ? handler() : nil;
    });
    return expectation;
}

@end