//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

// Private headers
#import "SRGUser+Private.h"
#import "SRGUserObject+Private.h"

#import <libextobjc/libextobjc.h>

@interface MigrationTestCase : UserDataBaseTestCase

@end

@implementation MigrationTestCase

#pragma mark Tests

- (void)testFailingMigration
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_invalid"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    XCTAssertNil(userData);
}

// Version v1 was in Play 2.8.4 (prod 278), Play 2.8.5 (prod 280), Play 2.8.6 (prod 283), Play 2.8.7 (prod 284)
- (void)testMigrationFromV1
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v1"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, dirty)];
    NSSortDescriptor *sortDescriptor3 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate3
                                                                  sortedWithDescriptors:@[sortDescriptor3]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historyLocalSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historyServerSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryChangedUidsKey];
        return [uids containsObject:uid2];
    }];
    
    [userData.history saveHistoryEntryForUid:uid2 withLastPlaybackTime:kCMTimeZero deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids4 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids4.count, 104);
}

// Version v2 was in Play 2.8.8 (beta 285)
- (void)testMigrationFromV2
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v2"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historyLocalSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, historyServerSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryChangedUidsKey];
        return [uids containsObject:uid2];
    }];
    
    [userData.history saveHistoryEntryForUid:uid2 withLastPlaybackTime:kCMTimeZero deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v3 was in Play 2.8.8 (prod 289), Play 2.8.9 (prod 292)
- (void)testMigrationFromV3
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v3"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyLocalSynchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyServerSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryChangedUidsKey];
        return [uids containsObject:uid2];
    }];
    
    [userData.history saveHistoryEntryForUid:uid2 withLastPlaybackTime:kCMTimeZero deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v4 was in Play 2.8.9 (beta 290), Play 2.8.9 (beta 291)
- (void)testMigrationFromV4
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v4"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyLocalSynchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyServerSynchronizationDate)]);
    XCTAssertNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryChangedUidsKey];
        return [uids containsObject:uid2];
    }];
    
    [userData.history saveHistoryEntryForUid:uid2 withLastPlaybackTime:kCMTimeZero deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

// Version v5 was in Play 2.8.10 (beta 293)
- (void)testMigrationFromV5
{
    NSURL *fileURL = [self URLForStoreFromPackage:@"UserData_DB_v5"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL historyServiceURL:nil playlistServiceURL:nil identityService:nil];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids1 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids1.count, 103);
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"%K == nil", @keypath(SRGHistoryEntry.new, discarded)];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    NSArray<NSString *> *itemUids2 = [[userData.history historyEntriesMatchingPredicate:predicate2
                                                                  sortedWithDescriptors:@[sortDescriptor2]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids2.count, 0);
    
    NSString *uid1 = @"urn:rts:video:10085364";
    SRGHistoryEntry *historyEntry = [userData.history historyEntryWithUid:uid1];
    
    XCTAssertNotNil(historyEntry);
    XCTAssertEqualObjects(historyEntry.uid, uid1);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, !=, kCMTimeZero));
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, discarded)]);
    XCTAssertNotNil([historyEntry valueForKey:@keypath(SRGHistoryEntry.new, deviceUid)]);
    
    SRGUser *user = userData.user;
    
    XCTAssertNotNil(user);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyLocalSynchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, historyServerSynchronizationDate)]);
    XCTAssertNotNil([user valueForKey:@keypath(SRGUser.new, accountUid)]);
    
    // Database is writable.
    NSString *uid2 = @"urn:rts:video:1234567890";
    [self expectationForSingleNotification:SRGHistoryDidChangeNotification object:userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryChangedUidsKey];
        return [uids containsObject:uid2];
    }];
    
    [userData.history saveHistoryEntryForUid:uid2 withLastPlaybackTime:kCMTimeZero deviceUid:@"Test device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<NSString *> *itemUids3 = [[userData.history historyEntriesMatchingPredicate:predicate1
                                                                  sortedWithDescriptors:@[sortDescriptor1]] valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    
    XCTAssertEqual(itemUids3.count, 104);
}

@end
