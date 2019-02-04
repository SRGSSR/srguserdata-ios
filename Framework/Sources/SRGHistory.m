//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistory.h"

#import "NSTimer+SRGUserData.h"
#import "SRGHistoryEntry.h"
#import "SRGUser.h"

#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGNetwork/SRGNetwork.h>

typedef void (^SRGHistoryUpdatesCompletionBlock)(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGHistoryPullCompletionBlock)(NSDate * _Nullable serverDate, NSError * _Nullable error);

NSString * const SRGHistoryDidChangeNotification = @"SRGHistoryDidChangeNotification";
NSString * const SRGHistoryURNsKey = @"SRGHistoryURNsKey";

NSString * const SRGHistoryDidStartSynchronizationNotification = @"SRGHistoryDidStartSynchronizationNotification";
NSString * const SRGHistoryDidFinishSynchronizationNotification = @"SRGHistoryDidFinishSynchronizationNotification";
NSString * const SRGHistoryDidClearNotification = @"SRGHistoryDidClearNotification";

static SRGHistory *s_history;

static BOOL SRGHistoryIsUnauthorizationError(NSError *error)
{
    if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorMultiple) {
        NSArray<NSError *> *errors = error.userInfo[SRGNetworkErrorsKey];
        for (NSError *error in errors) {
            if (SRGHistoryIsUnauthorizationError(error)) {
                return YES;
            }
        }
        return NO;
    }
    else {
        return [error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorHTTP && [error.userInfo[SRGNetworkHTTPStatusCodeKey] integerValue] == 401;
    }
}

@interface SRGHistory ()

@property (nonatomic) NSURL *serviceURL;
@property (nonatomic) SRGIdentityService *identityService;
@property (nonatomic) SRGDataStore *dataStore;

@property (nonatomic) NSTimer *synchronizationTimer;
@property (atomic /* custom */, getter=isSynchronizing) BOOL synchronizing;

@property (nonatomic, weak) SRGPageRequest *pullRequest;
@property (nonatomic) SRGRequestQueue *pushRequestQueue;

@property (nonatomic) dispatch_queue_t concurrentQueue;

@property (nonatomic) NSURLSession *session;

@end;

@implementation SRGHistory

@synthesize synchronizing = _synchronizing;

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL identityService:(SRGIdentityService *)identityService dataStore:(SRGDataStore *)dataStore
{
    if (self = [super init]) {
        self.serviceURL = serviceURL;
        self.identityService = identityService;
        self.dataStore = dataStore;
        
        self.concurrentQueue = dispatch_queue_create("ch.srgssr.playsrg.datastore.concurrent", DISPATCH_QUEUE_CONCURRENT);
        self.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        
        // TODO: Make sync interval a history configuration parameter
        @weakify(self)
        self.synchronizationTimer = [NSTimer srguserdata_timerWithTimeInterval:60. repeats:YES block:^(NSTimer * _Nonnull timer) {
            @strongify(self)
            [self synchronize];
        }];
        [self synchronize];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillEnterForeground:)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogin:)
                                                   name:SRGIdentityServiceUserDidLoginNotification
                                                 object:identityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogout:)
                                                   name:SRGIdentityServiceUserDidLogoutNotification
                                                 object:identityService];
    }
    return self;
}

#pragma clang diagnostic pop

- (void)dealloc
{
    self.synchronizationTimer = nil;
}

#pragma mark Getters and setters

- (void)setSynchronizationTimer:(NSTimer *)synchronizationTimer
{
    [_synchronizationTimer invalidate];
    _synchronizationTimer = synchronizationTimer;
}

- (BOOL)isSynchronizing
{
    __block BOOL synchronizing = NO;
    dispatch_sync(self.concurrentQueue, ^{
        synchronizing = self->_synchronizing;
    });
    return synchronizing;
}

- (void)setSynchronizing:(BOOL)synchronizing
{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_synchronizing = synchronizing;
    });
}

#pragma mark Requests

- (SRGFirstPageRequest *)historyUpdatesForSessionToken:(NSString *)sessionToken
                                             afterDate:(NSDate *)date
                                   withCompletionBlock:(SRGHistoryUpdatesCompletionBlock)completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    NSURL *URL = [self.serviceURL URLByAppendingPathComponent:@"historyapi/v2"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"with_deleted" value:@"true"]];
    if (date) {
        NSTimeInterval timestamp = round(date.timeIntervalSince1970 * 1000.);
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"after" value:@(timestamp).stringValue]];
    }
    URLComponents.queryItems = [queryItems copy];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGFirstPageRequest JSONDictionaryRequestWithURLRequest:URLRequest session:self.session sizer:^NSURLRequest *(NSURLRequest * _Nonnull URLRequest, NSUInteger size) {
        NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URLRequest.URL resolvingAgainstBaseURL:NO];
        NSMutableArray<NSURLQueryItem *> *queryItems = URLComponents.queryItems ? [NSMutableArray arrayWithArray:URLComponents.queryItems]: [NSMutableArray array];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K != %@", @keypath(NSURLQueryItem.new, name), @"limit"];
        [queryItems filterUsingPredicate:predicate];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"limit" value:@(size).stringValue]];
        URLComponents.queryItems = [queryItems copy];
        
        NSMutableURLRequest *request = [URLRequest mutableCopy];
        request.URL = URLComponents.URL;
        return [request copy];
    } paginator:^NSURLRequest * _Nullable(NSURLRequest * _Nonnull URLRequest, NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSUInteger size, NSUInteger number) {
        NSString *nextURLComponent = JSONDictionary[@"next"];
        NSString *nextURLString = nextURLComponent ? [URL.absoluteString stringByAppendingString:nextURLComponent] : nil;
        NSURL *nextURL = nextURLString ? [NSURL URLWithString:nextURLString] : nil;
        if (nextURL) {
            NSMutableURLRequest *request = [URLRequest mutableCopy];
            request.URL = nextURL;
            return [request copy];
        } else {
            return nil;
        };
    } completionBlock:^(NSDictionary * _Nullable JSONDictionary, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSNumber *serverTimestamp = JSONDictionary[@"last_update"];
        NSDate *serverDate = serverTimestamp ? [NSDate dateWithTimeIntervalSince1970:serverTimestamp.doubleValue / 1000.] : nil;
        completionBlock(JSONDictionary[@"data"], serverDate, page, nextPage, HTTPResponse, error);
    }];
}

- (void)pullHistoryEntriesForSessionToken:(NSString *)sessionToken
                                afterDate:(NSDate *)date
                          completionBlock:(SRGHistoryPullCompletionBlock)completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    __block SRGFirstPageRequest *firstRequest = [[[self historyUpdatesForSessionToken:sessionToken afterDate:date withCompletionBlock:^(NSArray<NSDictionary *> * _Nullable historyEntryDictionaries, NSDate * _Nullable serverDate, SRGPage * _Nullable page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            completionBlock(nil, error);
            return;
        }
        
        if (historyEntryDictionaries.count != 0) {
            NSMutableArray<NSString *> *URNs = [NSMutableArray array];
            [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                for (NSDictionary *historyEntryDictionary in historyEntryDictionaries) {
                    NSString *URN = [SRGHistoryEntry synchronizeWithDictionary:historyEntryDictionary inManagedObjectContext:managedObjectContext];
                    if (URN) {
                        [URNs addObject:URN];
                    }
                }
                return YES;
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        return;
                    }
                    
                    if (page.number == 0) {
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification
                                                                          object:self];
                    }
                    
                    if (URNs.count > 0) {
                        [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidChangeNotification
                                                                          object:self
                                                                        userInfo:@{ SRGHistoryURNsKey : [URNs copy] }];
                    }
                });
            }];
        }
        else if (page.number == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidStartSynchronizationNotification
                                                                  object:self];
            });
        }
        
        if (nextPage) {
            SRGPageRequest *nextRequest = [firstRequest requestWithPage:nextPage];
            [nextRequest resume];
            self.pullRequest = nextRequest;
        }
        else {
            completionBlock(serverDate, nil);
        }
    }] requestWithPageSize:100] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
    [firstRequest resume];
    self.pullRequest = firstRequest;
}

- (SRGRequest *)pushHistoryEntry:(SRGHistoryEntry *)historyEntry
                 forSessionToken:(NSString *)sessionToken
             withCompletionBlock:(void (^)(NSHTTPURLResponse * _Nonnull HTTPResponse, NSError * _Nullable error))completionBlock
{
    NSParameterAssert(historyEntry);
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    NSURL *URL = [self.serviceURL URLByAppendingPathComponent:@"historyapi/v2"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:historyEntry.dictionary options:0 error:NULL];
    
    NSManagedObjectID *historyEntryID = historyEntry.objectID;
    return [SRGRequest JSONDictionaryRequestWithURLRequest:request session:self.session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (! error) {
            [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull mangedObjectContext) {
                SRGHistoryEntry *historyEntry = [mangedObjectContext existingObjectWithID:historyEntryID error:NULL];
                if (JSONDictionary) {
                    [historyEntry updateWithDictionary:JSONDictionary];
                }
                historyEntry.dirty = NO;
                return YES;
            } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
        }
        completionBlock(HTTPResponse, error);
    }];
}

- (void)pushHistoryEntries:(NSArray<SRGHistoryEntry *> *)historyEntries
           forSessionToken:(NSString *)sessionToken
       withCompletionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    NSParameterAssert(sessionToken);
    NSParameterAssert(completionBlock);
    
    if (historyEntries.count == 0) {
        completionBlock(nil);
    }
    
    self.pushRequestQueue = [[[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        if (finished) {
            completionBlock(error);
        }
    }] requestQueueWithOptions:SRGRequestQueueOptionAutomaticCancellationOnErrorEnabled];
    
    for (SRGHistoryEntry *historyEntry in historyEntries) {
        SRGRequest *request = [[self pushHistoryEntry:historyEntry forSessionToken:sessionToken withCompletionBlock:^(NSHTTPURLResponse * _Nonnull HTTPResponse, NSError * _Nullable error) {
            [self.pushRequestQueue reportError:error];
        }] requestWithOptions:SRGNetworkRequestBackgroundThreadCompletionEnabled | SRGRequestOptionCancellationErrorsEnabled];
        [self.pushRequestQueue addRequest:request resume:NO /* see below */];
    }
    
    // TODO: Temporary workaround to SRG Network not being thread safe. Attempting to add & start requests leads
    //       to an concurrent resource in SRG Network, which we can avoided by starting all requests at once.
    [self.pushRequestQueue resume];
}

#pragma mark Synchronization

- (void)synchronize
{
    if (! self.serviceURL || self.synchronizing) {
        return;
    }
    
    if (! self.identityService.isLoggedIn) {
        return;
    }
    
    self.synchronizing = YES;
    
    // There is currently at most one logged in user with SRG Identity
    NSString *sessionToken = self.identityService.sessionToken;
    NSAssert(sessionToken != nil, @"A logged in User must have a token by construction");
    
    [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser mainUserInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user) {
        [self pullHistoryEntriesForSessionToken:sessionToken afterDate:user.historyServerSynchronizationDate completionBlock:^(NSDate * _Nullable serverDate, NSError * _Nullable pullError) {
            if (! pullError) {
                NSManagedObjectID *userID = user.objectID;
                [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                    SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                    user.historyServerSynchronizationDate = serverDate;
                    return YES;
                } withPriority:NSOperationQueuePriorityLow completionBlock:nil];
            }
            else if (SRGHistoryIsUnauthorizationError(pullError)) {
                [self.identityService reportUnauthorization];
                self.synchronizing = NO;
                return;
            }
            
            [self.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == YES", @keypath(SRGHistoryEntry.new, dirty)];
                return [SRGHistoryEntry historyEntriesMatchingPredicate:predicate sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
            } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries) {
                [self pushHistoryEntries:historyEntries forSessionToken:sessionToken withCompletionBlock:^(NSError * _Nullable pushError) {
                    self.synchronizing = NO;
                    
                    if (SRGHistoryIsUnauthorizationError(pushError)) {
                        [self.identityService reportUnauthorization];
                    }
                    else if (! pushError && ! pullError) {
                        NSManagedObjectID *userID = user.objectID;
                        [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
                            SRGUser *user = [managedObjectContext existingObjectWithID:userID error:NULL];
                            user.historyLocalSynchronizationDate = NSDate.date;
                            return YES;
                        } withPriority:NSOperationQueuePriorityLow completionBlock:^(NSError * _Nullable error) {
                            if (! error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [NSNotificationCenter.defaultCenter postNotificationName:SRGHistoryDidFinishSynchronizationNotification object:self];
                                });
                            }
                        }];
                    }
                }];
            }];
        }];
    }];
}

#pragma mark Notifications

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self synchronize];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self synchronize];
}

- (void)userDidLogin:(NSNotification *)notification
{
    [self.dataStore performBackgroundWriteTask:^BOOL(NSManagedObjectContext * _Nonnull managedObjectContext) {
        NSArray<SRGHistoryEntry *> *historyEntries = [SRGHistoryEntry historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil inManagedObjectContext:managedObjectContext];
        for (SRGHistoryEntry *historyEntry in historyEntries) {
            historyEntry.dirty = YES;
        }
        return YES;
    } withPriority:NSOperationQueuePriorityVeryHigh completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self synchronize];
        });
    }];
}

- (void)userDidLogout:(NSNotification *)notification
{
    dispatch_sync(self.concurrentQueue, ^{
        [self.pullRequest cancel];
        [self.pushRequestQueue cancel];
    });
    [self.dataStore cancelAllTasks];
}

@end
