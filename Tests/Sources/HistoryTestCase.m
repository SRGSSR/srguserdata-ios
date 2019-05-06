//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import <libextobjc/libextobjc.h>

@interface HistoryTestCase : UserDataBaseTestCase

@end

@implementation HistoryTestCase

#pragma mark Setup and tear down

- (void)setUp
{
    [super setUp];
    
    [self setupForOfflineOnly];
}

#pragma mark Tests

- (void)testEmptyInitialization
{
    XCTAssertNotNil(self.userData.history);
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqualObjects(historyEntries, @[]);
}

- (void)testSaveHistoryEntry
{
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], [NSSet setWithObject:@"a"]);
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryWithUid:@"a" lastPlaybackTime:CMTimeMakeWithSeconds(10., NSEC_PER_SEC) deviceUid:@"device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntryWithUid
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryWithUid:@"a" lastPlaybackTime:CMTimeMakeWithSeconds(10., NSEC_PER_SEC) deviceUid:@"device" completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // Synchronous
    SRGHistoryEntry *historyEntry1 = [self.userData.history historyEntryWithUid:@"a"];
    
    XCTAssertEqualObjects(historyEntry1.uid, @"a");
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry1.lastPlaybackTime, ==, CMTimeMakeWithSeconds(10., NSEC_PER_SEC)));
    XCTAssertEqualObjects(historyEntry1.deviceUid, @"device");
    XCTAssertFalse(historyEntry1.discarded);
    
    SRGHistoryEntry *historyEntry2 = [self.userData.history historyEntryWithUid:@"b"];
    XCTAssertNil(historyEntry2);
    
    // Asynchronous
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"a" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(historyEntry.uid, @"a");
        XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, CMTimeMakeWithSeconds(10., NSEC_PER_SEC)));
        XCTAssertEqualObjects(historyEntry.deviceUid, @"device");
        XCTAssertFalse(historyEntry.discarded);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:@"b" completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        XCTAssertNil(historyEntry);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntries
{
    [self insertLocalHistoryEntriesWithUids:@[ @"a", @"b", @"c", @"d", @"e" ]];
    
    // Synchronous
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"e", @"d", @"c", @"b", @"a" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entries fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        
        NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"e", @"d", @"c", @"b", @"a" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingPredicate
{
    [self insertLocalHistoryEntriesWithUids:@[@"a", @"b", @"c", @"d", @"e"]];
    
    // Synchronous
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @keypath(SRGHistoryEntry.new, uid), @[ @"c", @"d" ]];
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"d", @"c" ]));
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entries fetched"];
    
    // Asynchronous
    [self.userData.history historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        
        NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"d", @"c" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingSortDescriptor
{
    [self insertLocalHistoryEntriesWithUids:@[@"a", @"b", @"c", @"d", @"e"]];
    
    // Synchronous
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, uid) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor]];
    NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"a", @"b", @"c", @"d", @"e" ]));
    
    // Asynchronous
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entries fetched"];
    
    [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nonnull historyEntries, NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        
        NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        XCTAssertEqualObjects(uids, (@[ @"a", @"b", @"c", @"d", @"e" ]));
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testDiscardHistoryEntries
{
    [self insertLocalHistoryEntriesWithUids:@[@"a", @"b", @"c", @"d", @"e"]];
    
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], ([NSSet setWithObjects:@"b", @"c", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History discarded"];
    
    [self.userData.history discardHistoryEntriesWithUids:@[ @"b", @"c" ] completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(uids, (@[ @"e", @"d", @"a" ]));
}

- (void)testDiscardAllHistoryEntries
{
    [self insertLocalHistoryEntriesWithUids:@[@"a", @"b", @"c", @"d", @"e"]];
    
    [self expectationForSingleNotification:SRGHistoryEntriesDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGHistoryChangedUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", @"e", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History discarded"];
    
    [self.userData.history discardHistoryEntriesWithUids:nil completionBlock:^(NSError * _Nonnull error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    NSArray<NSString *> *uids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(uids, @[]);
}

@end
