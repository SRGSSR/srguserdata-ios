//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistory.h"

#import "NSArray+SRGUserData.h"
#import "NSBundle+SRGUserData.h"
#import "NSSet+SRGUserData.h"
#import "SRGDataStore.h"
#import "SRGHistoryEntry+Private.h"
#import "SRGHistoryRequest.h"
#import "SRGUser+Private.h"
#import "SRGUserData+Private.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"
#import "SRGUserObject+Private.h"
#import "SRGUserObject+Subclassing.h"

@import libextobjc;
@import MAKVONotificationCenter;
@import SRGIdentity;
@import SRGNetwork;

NSString * const SRGHistoryEntriesDidChangeNotification = @"SRGHistoryEntriesDidChangeNotification";
NSString * const SRGHistoryEntriesUidsKey = @"SRGHistoryEntriesUids";

@interface SRGHistory ()

@property (nonatomic, weak) SRGPageRequest *pullRequest;
@property (nonatomic, weak) SRGRequest *pushRequest;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGHistory

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL userData:(SRGUserData *)userData
{
    if (self = [super initWithServiceURL:serviceURL userData:userData]) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    }
    return self;
}

#pragma mark Data

- (void)saveHistoryEntryDictionaries:(NSArray<NSDictionary *> *)historyEntryDictionaries withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    if (historyEntryDictionaries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableSet<NSString *> *changedUids = [NSMutableSet set];
    
    [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        for (NSDictionary *historyEntryDictionary in historyEntryDictionaries) {
            SRGHistoryEntry *historyEntry = [SRGHistoryEntry synchronizeWithDictionary:historyEntryDictionary matchingPredicate:nil inManagedObjectContext:managedObjectContext];
            if (historyEntry) {
                [changedUids addObject:historyEntry.uid];
            }
        }
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryEntriesUidsKey : changedUids.copy }];
            });
        }
        completionBlock(error);
    }];
}

#pragma mark Requests

- (void)pullHistoryEntriesForSessionToken:(NSString *)sessionToken
                                afterDate:(NSDate *)date
                      withCompletionBlock:(void (^)(NSDate *serverDate, NSError *error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    __block SRGFirstPageRequest *firstRequest = nil;
    
    @weakify(self)
    firstRequest = [[[SRGHistoryRequest historyUpdatesFromServiceURL:self.serviceURL forSessionToken:sessionToken afterDate:date withDeletedEntries:YES session:self.session completionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        @strongify(self)
        
        void (^pullCompletionBlock)(NSDate *, NSError *) = ^(NSDate *serverDate, NSError *error) {
            completionBlock(serverDate, error);
            firstRequest = nil;
        };
        
        if (error) {
            pullCompletionBlock(nil, error);
            return;
        }
        
        [self saveHistoryEntryDictionaries:historyEntryDictionaries withCompletionBlock:^(NSError *error) {
            if (error) {
                pullCompletionBlock(nil, error);
                return;
            }
            
            if (nextPage) {
                SRGPageRequest *nextRequest = [firstRequest requestWithPage:nextPage];
                [nextRequest resume];
                self.pullRequest = nextRequest;
            }
            else {
                pullCompletionBlock(serverDate, nil);
            }
        }];
    }] requestWithPageSize:500] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [firstRequest resume];
    self.pullRequest = firstRequest;
}

- (void)pushHistoryEntries:(NSArray<SRGHistoryEntry *> *)historyEntries
           forSessionToken:(NSString *)sessionToken
       withCompletionBlock:(void (^)(NSError *error))completionBlock
{
    NSParameterAssert(historyEntries);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    if (historyEntries.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableDictionary<NSManagedObjectID *, NSDictionary *> *historyEntriesMap = [NSMutableDictionary dictionary];
    for (SRGHistoryEntry *historyEntry in historyEntries) {
        historyEntriesMap[historyEntry.objectID] = historyEntry.dictionary;
    }
    
    SRGRequest *pushRequest = [[SRGHistoryRequest postBatchOfHistoryEntryDictionaries:historyEntriesMap.allValues toServiceURL:self.serviceURL forSessionToken:sessionToken withSession:self.session completionBlock:^(NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
            for (NSManagedObjectID *historyEntryID in historyEntriesMap) {
                SRGHistoryEntry *historyEntry = [managedObjectContext existingObjectWithID:historyEntryID error:NULL];
                if (historyEntry.discarded) {
                    [managedObjectContext deleteObject:historyEntry];
                }
                else {
                    [historyEntry updateWithDictionary:historyEntriesMap[historyEntryID]];
                    historyEntry.dirty = NO;
                }
            }
        } withPriority:NSOperationQueuePriorityLow completionBlock:completionBlock];
    }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [pushRequest resume];
    self.pushRequest = pushRequest;
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    NSString *sessionToken = self.userData.identityService.sessionToken;
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGHistoryEntry.new, dirty)];
        return [SRGHistoryEntry objectsMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        if (error) {
            completionBlock(error);
            return;
        }
        
        [self pushHistoryEntries:historyEntries forSessionToken:sessionToken withCompletionBlock:^(NSError *error) {
            if (error) {
                completionBlock(error);
                return;
            }
            
            [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                return [SRGUser userInManagedObjectContext:managedObjectContext];
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
                if (error) {
                    completionBlock(error);
                    return;
                }
                
                NSManagedObjectID *userID = user.objectID;
                [self pullHistoryEntriesForSessionToken:sessionToken afterDate:user.historySynchronizationDate withCompletionBlock:^(NSDate * _Nullable serverDate, NSError * _Nullable error) {
                    if (error) {
                        completionBlock(error);
                        return;
                    }
                    
                    [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
                        SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                        user.historySynchronizationDate = serverDate;
                    } withPriority:NSOperationQueuePriorityLow completionBlock:completionBlock];
                }];
            }];
        }];
    }];
}

- (void)cancelSynchronization
{
    [self.pullRequest cancel];
    [self.pushRequest cancel];
}

- (NSArray<SRGUserObject *> *)userObjectsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
}

- (void)clearData
{
    __block NSSet<NSString *> *previousUids = nil;
    
    [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry objectsMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGHistoryEntry.new, uid)];
        previousUids = [NSSet setWithArray:[historyEntries valueForKeyPath:keyPath]];
        [SRGHistoryEntry deleteAllObjectsMatchingPredicate:nil inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (previousUids.count > 0) {
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryEntriesUidsKey : previousUids }];
            }
        });
    }];
}

#pragma mark Reads and writes

- (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *historyEntriesPredicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    if (predicate) {
        historyEntriesPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[historyEntriesPredicate, predicate]];
    }
    return [SRGHistoryEntry objectsMatchingPredicate:historyEntriesPredicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
}

- (SRGHistoryEntry *)historyEntryWithUid:(NSString *)uid inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGHistoryEntry.new, discarded)];
    return [SRGHistoryEntry objectWithUid:uid matchingPredicate:predicate inManagedObjectContext:managedObjectContext];
}

- (NSArray<SRGHistoryEntry *> *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return [self.userData.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self historyEntriesMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)historyEntriesMatchingPredicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors completionBlock:(void (^)(NSArray<SRGHistoryEntry *> * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self historyEntriesMatchingPredicate:predicate sortedWithDescriptors:sortDescriptors inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (SRGHistoryEntry *)historyEntryWithUid:(NSString *)uid
{
    return [self.userData.dataStore performMainThreadReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self historyEntryWithUid:uid inManagedObjectContext:managedObjectContext];
    }];
}

- (NSString *)historyEntryWithUid:(NSString *)uid completionBlock:(void (^)(SRGHistoryEntry * _Nullable, NSError * _Nullable))completionBlock
{
    return [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [self historyEntryWithUid:uid inManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (NSString *)saveHistoryEntryWithUid:(NSString *)uid lastPlaybackTime:(CMTime)lastPlaybackTime deviceUid:(NSString *)deviceUid completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    return [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        SRGHistoryEntry *historyEntry = [SRGHistoryEntry upsertWithUid:uid matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        historyEntry.lastPlaybackTime = lastPlaybackTime;
        historyEntry.deviceUid = deviceUid;
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryEntriesUidsKey : [NSSet setWithObject:uid] }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (NSString *)discardHistoryEntriesWithUids:(NSArray<NSString *> *)uids completionBlock:(void (^)(NSError * _Nonnull))completionBlock
{
    __block NSSet<NSString *> *changedUids = nil;
    
    return [self.userData.dataStore performBackgroundWriteTask:^(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<NSString *> *discardedUids = [SRGHistoryEntry discardObjectsWithUids:uids matchingPredicate:nil inManagedObjectContext:managedObjectContext];
        changedUids = [NSSet setWithArray:discardedUids];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(NSError * _Nullable error) {
        if (! error && changedUids.count > 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryEntriesDidChangeNotification
                                                                  object:self
                                                                userInfo:@{ SRGHistoryEntriesUidsKey : changedUids }];
            });
        }
        completionBlock ? completionBlock(error) : nil;
    }];
}

- (void)cancelTaskWithHandle:(NSString *)handle
{
    [self.userData.dataStore cancelBackgroundTaskWithHandle:handle];
}

@end
