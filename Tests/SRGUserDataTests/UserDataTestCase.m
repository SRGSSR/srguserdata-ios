//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UserDataBaseTestCase.h"

@interface UserDataTestCase : UserDataBaseTestCase

@end

@implementation UserDataTestCase

#pragma mark Tests

- (void)testInstantiation
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testInstantiationWithHistoryServiceURL
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    NSURL *serviceURL = [NSURL URLWithString:@"https://userdata.service"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:serviceURL identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testInstantiationWithIdentityService
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    SRGIdentityService *identityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://identity.webservice"] websiteURL:[NSURL URLWithString:@"https://identity.website"]];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:nil identityService:identityService];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

- (void)testInstantiationWithHistoryServiceURLAndIdentityService
{
    NSURL *fileURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString] URLByAppendingPathExtension:@"sqlite"];
    NSURL *serviceURL = [NSURL URLWithString:@"https://userdata.service"];
    SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL serviceURL:serviceURL identityService:nil];
    XCTAssertNotNil(userData);
    XCTAssertNotNil(userData.user);
    XCTAssertNotNil(userData.history);
}

@end
