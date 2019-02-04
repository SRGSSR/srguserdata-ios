//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryEntry.h"

#import "SRGUser.h"

#import <libextobjc/libextobjc.h>

@interface SRGHistoryEntry ()

@property (nonatomic, copy) NSString *itemUid;
@property (nonatomic) double lastPlaybackPosition;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSString *deviceUid;
@property (nonatomic) BOOL discarded;
@property (nonatomic) BOOL dirty;

@end

@implementation SRGHistoryEntry

@dynamic itemUid;
@dynamic lastPlaybackPosition;
@dynamic date;
@dynamic deviceUid;
@dynamic discarded;
@dynamic dirty;

#pragma mark Class methods

+ (NSString *)synchronizeWithDictionary:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *URN = dictionary[@"item_id"];
    if (! URN) {
        return nil;
    }
    
    SRGHistoryEntry *historyEntry = [self historyEntryWithURN:URN inManagedObjectContext:managedObjectContext];
    
    // If the local entry is dirty and more recent than server version, keep the local version as is.
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    if (historyEntry.dirty && [historyEntry.date compare:date] == NSOrderedDescending) {
        return URN;
    }
    
    BOOL isDeleted = [dictionary[@"deleted"] boolValue];
    if (isDeleted) {
        if (historyEntry) {
            [managedObjectContext deleteObject:historyEntry];
        }
        return URN;
    }
    
    if (! historyEntry) {
        historyEntry = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
    }
    
    [historyEntry updateWithDictionary:dictionary];
    historyEntry.dirty = NO;
    return URN;
}

+ (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(NSPredicate *)predicate
                                       sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
                                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    fetchRequest.predicate = predicate;
    
    // Ensure stable sorting using the URN as fallback (same criterium applied by the history service)
    NSMutableArray<NSSortDescriptor *> *allSortDescriptors = [NSMutableArray array];
    if (sortDescriptors) {
        [allSortDescriptors addObjectsFromArray:sortDescriptors];
    }
    [allSortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, itemUid) ascending:NO]];
    fetchRequest.sortDescriptors = [allSortDescriptors copy];
    
    fetchRequest.fetchBatchSize = 100;
    return [managedObjectContext executeFetchRequest:fetchRequest error:NULL];
}

+ (SRGHistoryEntry *)historyEntryWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGHistoryEntry.new, itemUid), URN];
    return [self historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext].firstObject;
}

+ (SRGHistoryEntry *)upsertWithURN:(NSString *)URN inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    SRGHistoryEntry *historyEntry = [self historyEntryWithURN:URN inManagedObjectContext:managedObjectContext];
    if (! historyEntry) {
        historyEntry = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:managedObjectContext];
        historyEntry.itemUid = URN;
    }
    historyEntry.dirty = YES;
    historyEntry.discarded = NO;
    historyEntry.date = NSDate.date;
    return historyEntry;
}

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    NSBatchDeleteRequest *batchDeleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
    [managedObjectContext executeRequest:batchDeleteRequest error:NULL];
}

#pragma mark Getters and Setters

- (CMTime)lastPlaybackTime
{
    return CMTimeMakeWithSeconds(self.lastPlaybackPosition, NSEC_PER_SEC);
}

- (void)setLastPlaybackTime:(CMTime)resumeTime
{
    self.lastPlaybackPosition = CMTimeGetSeconds(resumeTime);
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    JSONDictionary[@"item_id"] = self.itemUid;
    JSONDictionary[@"device_id"] = self.deviceUid;
    JSONDictionary[@"last_playback_position"] = @(self.lastPlaybackPosition);
    JSONDictionary[@"date"] = @(round(self.date.timeIntervalSince1970 * 1000.));
    JSONDictionary[@"deleted"] = @(self.discarded);
    return [JSONDictionary copy];
}

#pragma mark Updates

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    self.itemUid = dictionary[@"item_id"];
    self.deviceUid = dictionary[@"device_id"];
    self.lastPlaybackPosition = [dictionary[@"last_playback_position"] doubleValue];
    self.date = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"date"] doubleValue] / 1000.];
    self.discarded = [dictionary[@"deleted"] boolValue];
}

- (void)discard
{
    if (! [SRGUser mainUserInManagedObjectContext:self.managedObjectContext].accountUid) {
        [self.managedObjectContext deleteObject:self];
    }
    else {
        self.discarded = YES;
        self.dirty = YES;
        self.date = NSDate.date;
    }
}

@end
