//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <XCTest/XCTest.h>

#import <libextobjc/libextobjc.h>
#import <SRGUserData/SRGUserData.h>

@interface DataStoreTestCase : XCTestCase

@end

@implementation DataStoreTestCase

- (void)testMigrationFromV1
{
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *name = @"UserData-test";
    
    for (NSString *extension in @[ @"sqlite", @"sqlite-shm", @"sqlite-wal"]) {
        NSString *sqliteFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:extension inDirectory:@"Play_DB_v1"];
        NSURL *sqliteFileURL = [NSURL fileURLWithPath:sqliteFilePath];
        NSURL *sqliteDestinationFileURL = [[[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:name] URLByAppendingPathExtension:extension];
        [[NSFileManager defaultManager] removeItemAtURL:sqliteDestinationFileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:sqliteFileURL toURL:sqliteDestinationFileURL error:nil];
    }
    
    SRGUserData.currentUserData = [[SRGUserData alloc] initWithHistoryServiceURL:[NSURL URLWithString:@"https://history.rts.ch"]
                                                                 identityService:SRGIdentityService.currentIdentityService
                                                                            name:name
                                                                       directory:libraryDirectory];
    
    NSArray<NSString *> *itemUids1 = [SRGUserData.currentUserData performMainThreadReadTask:^id _Nonnull(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry historyEntriesMatchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] inManagedObjectContext:managedObjectContext];
        return [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, itemUid)];
    }];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSArray<NSString *> *itemUids2 = [SRGUserData.currentUserData performMainThreadReadTask:^id _Nonnull(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry historyEntriesMatchingPredicate:predicate sortedWithDescriptors:@[sortDescriptor] inManagedObjectContext:managedObjectContext];
        return [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, itemUid)];
    }];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *URN = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData performMainThreadReadTask:^id _Nonnull(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGHistoryEntry historyEntryWithURN:URN inManagedObjectContext:managedObjectContext];
    }];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertTrue(CMTimeCompare(historyEntry.lastPlaybackTime, kCMTimeZero) != 0);
    XCTAssertNotNil([historyEntry valueForKey:@"discarded"]);
    XCTAssertNotNil([historyEntry valueForKey:@"deviceUid"]);
    
    SRGUser *user = [SRGUserData.currentUserData performMainThreadReadTask:^id _Nonnull(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser mainUserInManagedObjectContext:managedObjectContext];
    }];
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@"historyLocalSynchronizationDate"]);
    XCTAssertNotNil([user valueForKey:@"historyServerSynchronizationDate"]);
    XCTAssertNil([user valueForKey:@"accountUid"]);
}

@end
