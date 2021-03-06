//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import CoreData;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Abstract base class for objects supporting synchronization with a remote server.
 *
 *  @discussion Instances must not be shared among threads.
 */
@interface SRGUserObject : NSManagedObject

/**
 *  The item unique identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *uid;

/**
 *  The date at which the entry was updated for the last time.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

@end

NS_ASSUME_NONNULL_END
