//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPreferences.h"

#import "SRGPreferenceChangelog.h"
#import "SRGUser+Private.h"
#import "SRGUserData+Private.h"
#import "SRGUserDataLogger.h"
#import "SRGUserDataService+Private.h"
#import "SRGUserDataService+Subclassing.h"

// TODO: - Thread-safety considerations
//       - Delete each log entry consumed during sync
//       - Should coalesce operations by path / domain (only the last one in the changelog must be kept)
//       - UT: Spaces / slashes / dots in keys + encoding if needed

NSString * const SRGPreferencesDidChangeNotification = @"SRGPreferencesDidChangeNotification";

static NSDictionary *SRGDictionaryMakeImmutable(NSDictionary *dictionary)
{
    if (! dictionary) {
        return nil;
    }
    
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull object, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:NSMutableDictionary.class]) {
            mutableDictionary[key] = [object copy];
        }
        else {
            mutableDictionary[key] = object;
        }
    }];
    return [mutableDictionary copy];
}

@interface SRGPreferences ()

@property (nonatomic) NSURL *fileURL;
@property (nonatomic) NSMutableDictionary *dictionary;

@property (nonatomic) SRGPreferenceChangelog *changelog;

@end

@implementation SRGPreferences

#pragma mark Class methods

+ (NSArray<NSString *> *)pathComponentsForPath:(NSString *)path inDomain:(NSString *)domain
{
    NSParameterAssert(domain);
    
    NSArray<NSString *> *pathComponents = path.pathComponents;
    if (pathComponents) {
        return [@[domain] arrayByAddingObjectsFromArray:pathComponents];
    }
    else {
        return @[domain];
    }
}

+ (void)savePreferenceDictionary:(NSDictionary *)dictionary toFileURL:(NSURL *)fileURL
{
    NSError *JSONError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not save preferences. Reason %@", JSONError);
        return;
    }
    
    NSError *writeError = nil;
    if (! [data writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) {
        SRGUserDataLogError(@"preferences", @"Could not save preferences. Reason %@", writeError);
        return;
    }
    
    SRGUserDataLogInfo(@"preferences", @"Preferences successfully saved");
}

+ (NSMutableDictionary *)savedPreferenceDictionaryFromFileURL:(NSURL *)fileURL
{
    if (! [NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    
    NSError *JSONError = nil;
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&JSONError];
    if (JSONError) {
        SRGUserDataLogError(@"preferences", @"Could not read preferences. Reason %@", JSONError);
        return nil;
    }
    
    if (! [JSONObject isKindOfClass:NSDictionary.class]) {
        SRGUserDataLogError(@"preferences", @"Could not read preferences. The format is invalid");
        return nil;
    }
    
    return JSONObject;
}

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL userData:(SRGUserData *)userData
{
    if (self = [super initWithServiceURL:serviceURL userData:userData]) {
        self.fileURL = [[userData.storeFileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"prefs"];
        self.dictionary = [SRGPreferences savedPreferenceDictionaryFromFileURL:self.fileURL] ?: [NSMutableDictionary dictionary];
        self.changelog = [[SRGPreferenceChangelog alloc] initForPreferencesFileWithURL:self.fileURL];
    }
    return self;
}

#pragma mark Preference management

- (BOOL)hasObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        id value = dictionary[pathComponent];
        
        if (pathComponent == pathComponents.lastObject) {
            return value != nil;
        }
        else {
            if (! [value isKindOfClass:NSDictionary.class]) {
                break;
            }
            dictionary = value;
        }
    }
    return NO;
}

- (void)setObject:(id)object atPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        if (pathComponent == pathComponents.lastObject) {
            dictionary[pathComponent] = object;
        }
        else {
            id value = dictionary[pathComponent];
            if (! value) {
                dictionary[pathComponent] = [NSMutableDictionary dictionary];
            }
            else if (! [value isKindOfClass:NSDictionary.class]) {
                return;
            }
            dictionary = dictionary[pathComponent];
        }
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangelogEntry *entry = [SRGPreferenceChangelogEntry changelogEntryForUpsertAtPath:path inDomain:domain withObject:object];
            [self.changelog addEntry:entry];
        }
    }];
}

- (id)objectAtPath:(NSString *)path inDomain:(NSString *)domain withClass:(Class)cls
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        id value = dictionary[pathComponent];
        
        if (pathComponent == pathComponents.lastObject) {
            return [value isKindOfClass:cls] ? value : nil;
        }
        else {
            if (! [value isKindOfClass:NSDictionary.class]) {
                break;
            }
            dictionary = value;
        }
    }
    return nil;
}

- (void)removeObjectAtPath:(NSString *)path inDomain:(NSString *)domain
{
    NSArray<NSString *> *pathComponents = [SRGPreferences pathComponentsForPath:path inDomain:domain];
    
    NSMutableDictionary *dictionary = self.dictionary;
    for (NSString *pathComponent in pathComponents) {
        if (pathComponent == pathComponents.lastObject) {
            [dictionary removeObjectForKey:pathComponent];
        }
        else {
            id value = dictionary[pathComponent];
            if (! [value isKindOfClass:NSDictionary.class]) {
                return;
            }
        }
        dictionary = dictionary[pathComponent];
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
    
    [SRGPreferences savePreferenceDictionary:self.dictionary toFileURL:self.fileURL];
    
    [self.userData.dataStore performBackgroundReadTask:^id _Nullable(NSManagedObjectContext * _Nonnull managedObjectContext) {
        return [SRGUser userInManagedObjectContext:managedObjectContext];
    } withPriority:NSOperationQueuePriorityNormal completionBlock:^(SRGUser * _Nullable user, NSError * _Nullable error) {
        if (user.accountUid) {
            SRGPreferenceChangelogEntry *entry = [SRGPreferenceChangelogEntry changelogEntryForDeleteAtPath:path inDomain:domain];
            [self.changelog addEntry:entry];
        }
    }];
}

- (void)setString:(NSString *)string atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:string atPath:path inDomain:domain];
}

- (void)setNumber:(NSNumber *)number atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:number atPath:path inDomain:domain];
}

- (void)setArray:(NSArray *)array atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:array atPath:path inDomain:domain];
}

- (void)setDictionary:(NSDictionary *)dictionary atPath:(NSString *)path inDomain:(NSString *)domain
{
    [self setObject:[dictionary mutableCopy] atPath:path inDomain:domain];
}

- (NSString *)stringAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSString.class];
}

- (NSNumber *)numberAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSNumber.class];
}

- (NSArray *)arrayAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return [self objectAtPath:path inDomain:domain withClass:NSArray.class];
}

- (NSDictionary *)dictionaryAtPath:(NSString *)path inDomain:(NSString *)domain
{
    return SRGDictionaryMakeImmutable([self objectAtPath:path inDomain:domain withClass:NSDictionary.class]);
}

#pragma mark Subclassing hooks

- (void)synchronizeWithCompletionBlock:(void (^)(NSError * _Nullable))completionBlock
{
    
    
    
    completionBlock(nil);
}

- (void)cancelSynchronization
{
    
}

- (void)clearData
{
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:NULL];
    [self.dictionary removeAllObjects];
    
    [self.changelog clearData];
    
    [NSNotificationCenter.defaultCenter postNotificationName:SRGPreferencesDidChangeNotification object:self];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; dictionary = %@>",
            [self class],
            self,
            self.dictionary];
}

@end
