//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

#import "SRGPlaylistsRequest.h"

@interface PlaylistsSynchronizationTestCase : UserDataBaseTestCase

@end

@implementation PlaylistsSynchronizationTestCase

#pragma mark Overrides

- (NSString *)sessionToken
{
    // For playsrgtests+userdata2@gmail.com
    return @"s:zqlZDM1QTjSgCImtircirQr8KOgybQTj.nCgIw2PSk6mhO3ofFhbPErFBD+IGQ0dBcwsJ1lQn5fA";
}

#pragma mark Setup and teardown

- (void)setUp
{
    [super setUp];
    
    [self eraseRemoteDataAndWait];
    [self logout];
}

#pragma mark Tests

- (void)testSystemPlaylistAvailability
{
    // FIXME:
#if 0
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        return [notification.userInfo[SRGPlaylistsUidsKey] containsObject:SRGPlaylistUidWatchLater];
    }];
    
    [self setupForOfflineOnly];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
    
    NSArray<SRGPlaylist *> *playlists = [self.userData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
    XCTAssertEqual(playlists.count, 1);
    
    SRGPlaylist *playlist = playlists.firstObject;
    XCTAssertEqual(playlist.type, SRGPlaylistTypeWatchLater);
    XCTAssertEqualObjects(playlist.uid, SRGPlaylistUidWatchLater);
#endif
}

- (void)testSystemPlaylistAvailabilityAfterLogout
{
    XCTFail(@"Implement");
}

- (void)testInitialSynchronizationWithoutRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
}

- (void)testInitialSynchronizationWithExistingRemotePlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithoutPlaylistChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[]];
}

- (void)testSynchronizationWithAddedRemotePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    
    [self assertLocalPlaylistUids:@[]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b" ]];
}

- (void)testSynchronizationWithAddedRemoteAndLocalPlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistWithUid:@"a"];
    [self insertLocalPlaylistWithUid:@"b"];
    
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"c" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c" ]];
}

- (void)testSynchronizationWithDiscardedLocalPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardLocalPlaylistsWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemotePlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    
    [self discardRemotePlaylistsWithUids:@[ @"a", @"c" ]];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testSynchronizationWithDiscardedRemoteAndLocalPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    [self insertRemotePlaylistWithUid:@"e"];
    [self insertRemotePlaylistWithUid:@"f"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalPlaylistUids:@[ @"a", @"b", @"c", @"d", @"e", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"c", @"d", @"e", @"f" ]];
    
    [self discardLocalPlaylistsWithUids:@[ @"b", @"c" ]];
    [self discardRemotePlaylistsWithUids:@[ @"c", @"d", @"e" ]];
    
    [self assertLocalPlaylistUids:@[ @"a", @"d", @"e", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"b", @"f" ]];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:@[ @"a", @"f" ]];
    [self assertRemotePlaylistUids:@[ @"a", @"f" ]];
}

- (void)testPlaylistSynchronizationWithoutEntryChanges
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedRemoteEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithAddedRemoteAndLocalEntries
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self insertLocalPlaylistEntriesWithUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self insertRemotePlaylistEntriesWithUids:@[ @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedRemoteEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];

    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
        
    [self assertLocalEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardRemoteEntriesWithUids:@[ @"a", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedLocalEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardLocalEntriesWithUids:@[ @"a", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"b", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

- (void)testPlaylistSynchronizationWithDiscardedRemoteAndLocalEntries
{
    [self insertRemotePlaylistEntriesWithUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self assertLocalEntryUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"c", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self discardLocalEntriesWithUids:@[ @"b", @"c" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self discardRemoteEntriesWithUids:@[ @"c", @"d" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self assertLocalEntryUids:@[ @"a", @"d", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"b", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    
    [self synchronizeAndWait];
    
    [self assertLocalEntryUids:@[ @"a", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
    [self assertRemoteEntryUids:@[ @"a", @"e" ] forPlaylistWithUid:SRGPlaylistUidWatchLater];
}

#if 0
- (void)testLargePlaylists
{
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    NSArray<NSString *> *(^uidsBuilder)(NSUInteger, NSUInteger) = ^(NSUInteger start, NSUInteger end) {
        NSMutableArray<NSString *> *uids = [NSMutableArray array];
        for (NSUInteger i = start; i < end; i++) {
            [uids addObject:@(i).stringValue];
        }
        return [uids copy];
    };
    
    for (NSUInteger i = 0; i < 100; ++i) {
        [self insertLocalPlaylistWithUid:@(i).stringValue];
    }
    
    for (NSUInteger i = 50; i < 150; ++i) {
        [self insertRemotePlaylistWithUid:@(i).stringValue];
    }
    
    [self assertLocalPlaylistUids:uidsBuilder(0, 100)];
    [self assertRemotePlaylistUids:uidsBuilder(50, 150)];
    
    [self synchronizeAndWait];
    
    [self assertLocalPlaylistUids:uidsBuilder(0, 150)];
    [self assertRemotePlaylistUids:uidsBuilder(0, 150)];
}
#endif

- (void)testAfterLogout
{
    XCTFail(@"Implement");
}

- (void)testSynchronizationAfterLogoutDuringSynchronization
{
    XCTFail(@"Implement");
}

- (void)testSynchronizationWithoutLoggedInUser
{
    // FIXME:
#if 0
    [self setupForAvailableService];
    
    id startObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidStartSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No start notification is expected");
    }];
    id finishObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGUserDataDidFinishSynchronizationNotification object:self.userData queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        XCTFail(@"No finish notification is expected");
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 1);
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:startObserver];
        [NSNotificationCenter.defaultCenter removeObserver:finishObserver];
    }];
#endif
}

- (void)testSynchronizationWithUnavailableService
{
    // FIXME:
#if 0
    [self setupForUnavailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self expectationForSingleNotification:SRGUserDataDidStartSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    [self expectationForSingleNotification:SRGUserDataDidFinishSynchronizationNotification object:self.userData handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqual([notification.userInfo[SRGPlaylistsUidsKey] count], 1);
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:10. handler:nil];
#endif
}

- (void)testChangeNotificationsWithDiscardedLocalEmptyPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    // Changes are notified when playlists are marked as being discarded
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"c", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discard"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"a", @"c" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    // No more changes must be received for the discarded playlists when deleted during synchronization
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"b", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testChangeNotificationsWithDiscardedLocalPlaylistsWithEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", nil]));
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Playlist discarded"];
    
    [self.userData.playlists discardPlaylistsWithUids:@[ @"a" ] completionBlock:^(NSError * _Nullable error) {
        XCTAssertFalse(NSThread.isMainThread);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
}

- (void)testChangeNotificationsWithDiscardedRemoteEmptyPlaylists
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePlaylistsWithUids:@[ @"a", @"c" ]];
    
    // Changes are notified when synchronization occurs with the remote changes
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"d" ]];
}

- (void)testChangeNotificationsWithDiscardedRemotePlaylistsWithEntries
{
    [self insertRemotePlaylistWithUid:@"a"];
    [self insertRemotePlaylistWithUid:@"b"];
    [self insertRemotePlaylistWithUid:@"c"];
    [self insertRemotePlaylistWithUid:@"d"];
    
    [self insertRemotePlaylistEntriesWithUids:@[ @"1", @"2", @"3", @"4", @"5" ] forPlaylistWithUid:@"a"];
    
    [self setupForAvailableService];
    [self loginAndWaitForInitialSynchronization];
    
    [self discardRemotePlaylistsWithUids:@[ @"a" ]];
    
    [self expectationForSingleNotification:SRGPlaylistsDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistsUidsKey], ([NSSet setWithObjects:@"a", @"b", @"c", @"d", nil]));
        return YES;
    }];
    
    [self expectationForSingleNotification:SRGPlaylistEntriesDidChangeNotification object:self.userData.playlists handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue(NSThread.isMainThread);
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistUidKey], @"a");
        XCTAssertEqualObjects(notification.userInfo[SRGPlaylistEntriesUidsKey], ([NSSet setWithObjects:@"1", @"2", @"3", @"4", @"5", nil]));
        return YES;
    }];
    
    [self synchronize];
    
    [self waitForExpectationsWithTimeout:30. handler:nil];
    
    [self assertLocalPlaylistUids:@[ @"b", @"c", @"d" ]];
    [self assertRemotePlaylistUids:@[ @"b", @"c", @"d" ]];
}

// TODO: Check notifications with discarded playlist entries only (not playlists themselves)

@end
