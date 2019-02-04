//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Entry in the media playback history.
 */
@interface SRGHistoryEntry : NSManagedObject

/**
 *  Return history entries, optionally matching a specific predicate and / or sorted with descriptors.
 *
 *  @discussion Entries are returned in a stable order.
 */
+ (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                          sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                         inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Return an entry matching the specified URN, `nil` if none is found.
 */
+ (nullable SRGHistoryEntry *)historyEntryWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  The item unique identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *itemUid;

/**
 *  The playback position which the item was played at.
 */
@property (nonatomic, readonly) CMTime lastPlaybackTime;

/**
 *  The date at which the entry was updated.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *date;

/**
 *  An identifier for the device which updated the entry.
 */
@property (nonatomic, readonly, copy, nullable) NSString *deviceUid;

/**
 *  `YES` iff the entry has been marked as discarded.
 */
@property (nonatomic, readonly) BOOL discarded;

@end

NS_ASSUME_NONNULL_END
