//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRGPreferenceChangeLogEntryType) {
    SRGPreferenceChangeLogEntryTypeUpsert,
    SRGPreferenceChangeLogEntryTypeDelete,
    SRGPreferenceChangeLogEntryTypeNode
};

@interface SRGPreferenceChangeLogEntry : NSObject

+ (SRGPreferenceChangeLogEntry *)changeLogEntryForUpsertAtKeyPath:(NSString *)keyPath inDomain:(NSString *)domain withObject:(id)object;
+ (SRGPreferenceChangeLogEntry *)changeLogEntryForDeleteAtKeyPath:(NSString *)keyPath inDomain:(NSString *)domain;

+ (NSArray<SRGPreferenceChangeLogEntry *> *)changeLogEntriesForDictionary:(NSDictionary *)dictionary inDomain:(NSString *)domain;

@end

NS_ASSUME_NONNULL_END
