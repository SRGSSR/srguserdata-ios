//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <SRGIdentity/SRGIdentity.h>

// Public headers.
#import "SRGHistory.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"
#import "SRGUserDataService.h"
#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

// Official version number.
FOUNDATION_EXPORT NSString *SRGUserDataMarketingVersion(void);

/**
 *  Manages data associated with a user, either offline or logged in using SRG Identity. For logged in users,
 *  data is transparently kept synchronized with the corresponding remote service.
 *
 *  Several instances of `SRGUserData` can coexist in an application, though in general one should suffice. This
 *  global instance can be accessed easily from anywhere by assigning it to the `currentUserData` class property
 *  first.
 */
@interface SRGUserData : NSObject

/**
 *  The instance currently set as shared instance, if any.
 */
@property (class, nonatomic, nullable) SRGUserData *currentUserData;

// TODO: URL conxfiguration object
/**
 *  Create a user data repository, which optionally can be synced with the specified identity service.
 *
 *  @param name      The name of the file to store the data into (without extension).
 *  @param directory The directory in which the file will be saved.
 */
- (instancetype)initWithIdentityService:(nullable SRGIdentityService *)identityService
                      historyServiceURL:(nullable NSURL *)historyServiceURL
                                   name:(NSString *)name
                              directory:(NSString *)directory;

/**
 *  The user to which the data belongs. Might be offline or bound to a remote account.
 */
@property (nonatomic, readonly) SRGUser *user;

/**
 *  Acess to playback history for the user.
 */
@property (nonatomic, readonly, nullable) SRGHistory *history;

// Completion blocks called on background threads

/**
 *  Dissociate the current identity (if any) from the local user, calling an optional block on completion. Local data
 *  is kept and can be synchronized with another account after logging in again.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (void)dissociateIdentityWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;

/**
 *  Erase all local data and the identity associated with it (if any), calling an optional block on completion. The
 *  account itself is not deleted and the user can login to retrieve her data again.
 *
 *  @discussion The completion block is called on a background thread.
 */
- (void)eraseWithCompletionBlock:(void (^ _Nullable)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END
