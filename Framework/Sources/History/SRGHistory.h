//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"
#import "SRGUserDataService.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when the history changes. Use the `SRGHistoryURNsKey` to retrieve the updated URNs from the
 *  notification `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const SRGHistoryDidChangeNotification;                    // Notification name.
OBJC_EXPORT NSString * const SRGHistoryURNsKey;                                  // Key to access the updated URNs as an `NSArray` of `NSString` objects.

/**
 *  Notification sent when history synchronization has started.
 */
OBJC_EXPORT NSString * const SRGHistoryDidStartSynchronizationNotification;

/**
 *  Notification sent when history synchronization has finished.
 */
OBJC_EXPORT NSString * const SRGHistoryDidFinishSynchronizationNotification;

/**
 *  Notification sent when the history has been cleared.
 */
OBJC_EXPORT NSString * const SRGHistoryDidClearNotification;

/**
 *  Service for history and playback resume.
 *
 *  @discussion Though similar methods exist on `SRGHistoryEntry`, use `SRGHistory` as the main entry point for local history
 *              updates.
 */
@interface SRGHistory : SRGUserDataService

- (NSArray<__kindof SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                                                   sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors;

- (void)historyEntriesMatchingPredicate:(nullable NSPredicate *)predicate
                  sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                        completionBlock:(void (^)(NSArray<SRGHistoryEntry *> *historyEntries))completionBlock;

- (void)saveHistoryEntryForURN:(NSString *)URN
          withLastPlaybackTime:(CMTime)lastPlaybackTime
                    deviceName:(nullable NSString *)deviceName
               completionBlock:(nullable void (^)(NSError *error))completionBlock;

// Use `nil` to discard all
- (void)discardHistoryEntriesWithURNs:(nullable NSArray<NSString *> *)URNs
                      completionBlock:(nullable void (^)(NSError *error))completionBlock;

@end

NS_ASSUME_NONNULL_END
