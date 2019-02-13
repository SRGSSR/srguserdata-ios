//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <XCTest/XCTest.h>

#import <libextobjc/libextobjc.h>
#import <SRGUserData/SRGUserData.h>

@interface SRGHistoryTestCase : XCTestCase

@property (nonatomic) SRGUserData *userData;

@end

@implementation SRGHistoryTestCase

#pragma mark Setup and tear down

- (void)setUp
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    self.userData = [[SRGUserData alloc] initWithIdentityService:nil historyServiceURL:nil storeFileURL:fileURL];
}

- (void)tearDown
{
    self.userData = nil;
}

#pragma mark Tests

- (void)testEmptyHistoryInitialization
{
    XCTAssertNotNil(self.userData.history);
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries.count, 0);
}

- (void)testHistorySaveHistoryEntry
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        return [uids containsObject:uid];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
        
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistorySaveHistoryEntries
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *deviceUid = @"Test device";
    
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        CMTime time = CMTimeMakeWithSeconds(uid.integerValue, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
            
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistorySaveSameHistoryEntry
{
    NSString *uid = @"1234";
    NSString *deviceUid = @"Test device";
    
    NSUInteger saveInterations = 5;
    __block NSUInteger expectedSavedNotifications = saveInterations;
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        expectedSavedNotifications -= uids.count;
        return (expectedSavedNotifications == 0);
    }];
    
    for (NSUInteger i = 0; i < saveInterations; i++) {
        CMTime time = CMTimeMakeWithSeconds(i, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
            
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntryWithUid
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    SRGHistoryEntry *historyEntry = [self.userData.history historyEntryWithUid:uid];
    
    XCTAssertEqualObjects(historyEntry.uid, uid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
    XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
    XCTAssertEqual(historyEntry.discarded, NO);
}

- (void)testHistoryEntryWithUidAsynchronously
{
    NSString *uid = @"1234";
    CMTime time = CMTimeMakeWithSeconds(10, NSEC_PER_SEC);
    ;
    NSString *deviceUid = @"Test device";
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"History entry saved"];
    
    [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"History entry fetched"];
    
    [self.userData.history historyEntryWithUid:uid completionBlock:^(SRGHistoryEntry * _Nullable historyEntry) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertEqualObjects(historyEntry.uid, uid);
        XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, time));
        XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
        XCTAssertEqual(historyEntry.discarded, NO);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testHistoryEntriesMatchingEmptyPredicateEmptySortedhDescriptor
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *deviceUid = @"Test device";
    
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        CMTime time = CMTimeMakeWithSeconds(uid.integerValue, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
            
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSArray<SRGHistoryEntry *> *historyEntries = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries.count, uids.count);
    
    NSArray<NSString *> *queryUids = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids, [[uids reverseObjectEnumerator] allObjects]);
}

- (void)testHistoryEntriesMatchingPredicatesOrSortedDescriptors
{
    NSArray<NSString *> *uids = @[@"12", @"34", @"56", @"78", @"90"];
    NSString *deviceUid = @"Test device";
    
    NSMutableArray<NSString *> *expectedSavedNotifications = uids.mutableCopy;
    
    [self expectationForNotification:SRGHistoryDidChangeNotification object:self.userData.history handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        NSArray<NSString *> *uids = notification.userInfo[SRGHistoryUidsKey];
        [expectedSavedNotifications removeObjectsInArray:uids];
        return (expectedSavedNotifications.count == 0);
    }];
    
    for (NSString *uid in uids) {
        CMTime time = CMTimeMakeWithSeconds(uid.integerValue, NSEC_PER_SEC);
        XCTestExpectation *expectation = [self expectationWithDescription:@"History entry saved"];
        
        [self.userData.history saveHistoryEntryForUid:uid withLastPlaybackTime:time deviceUid:deviceUid completionBlock:^(NSError * _Nonnull error) {
            XCTAssertNil(error);
            [expectation fulfill];
            
        }];
    }
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries1 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor1]];
    
    XCTAssertEqual(historyEntries1.count, uids.count);
    NSArray<NSString *> *queryUids1 = [historyEntries1 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids1, uids);
    
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, uid) ascending:YES];
    NSArray<SRGHistoryEntry *> *historyEntries2 = [self.userData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor2]];
    
    XCTAssertEqual(historyEntries2.count, uids.count);
    NSArray<NSString *> *queryUids2 = [historyEntries2 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids2, uids);
    
    NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    NSArray<SRGHistoryEntry *> *historyEntries3 = [self.userData.history historyEntriesMatchingPredicate:predicate3 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries3.count, uids.count);
    NSArray<NSString *> *queryUids3 = [historyEntries3 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids3, [[uids reverseObjectEnumerator] allObjects]);
    
    NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, deviceUid), deviceUid];
    NSArray<SRGHistoryEntry *> *historyEntries4 = [self.userData.history historyEntriesMatchingPredicate:predicate4 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries4.count, uids.count);
    NSArray<NSString *> *queryUids4 = [historyEntries4 valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
    XCTAssertEqualObjects(queryUids4, [[uids reverseObjectEnumerator] allObjects]);
    
    NSString *queryUid = @"34";
    NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, uid), queryUid];
    NSArray<SRGHistoryEntry *> *historyEntries5 = [self.userData.history historyEntriesMatchingPredicate:predicate5 sortedWithDescriptors:nil];
    
    XCTAssertEqual(historyEntries5.count, 1);
    SRGHistoryEntry *historyEntry = historyEntries5.firstObject;
    XCTAssertEqualObjects(historyEntry.uid, queryUid);
    XCTAssertTrue(CMTIME_COMPARE_INLINE(historyEntry.lastPlaybackTime, ==, CMTimeMakeWithSeconds(queryUid.integerValue, NSEC_PER_SEC)));
    XCTAssertEqualObjects(historyEntry.deviceUid, deviceUid);
    XCTAssertEqual(historyEntry.discarded, NO);
}

@end
