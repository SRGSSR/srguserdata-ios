//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistsRequest.h"

@import libextobjc;

@implementation SRGPlaylistsRequest

+ (SRGRequest *)playlistsFromServiceURL:(NSURL *)serviceURL
                        forSessionToken:(NSString *)sessionToken
                            withSession:(NSURLSession *)session
                        completionBlock:(SRGPlaylistsCompletionBlock)completionBlock
{
    NSURL *URL = [serviceURL URLByAppendingPathComponent:@"v3"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary[@"playlists"], HTTPResponse, error);
    }];
}

+ (SRGRequest *)postPlaylistDictionary:(NSDictionary *)dictionary
                          toServiceURL:(NSURL *)serviceURL
                       forSessionToken:(NSString *)sessionToken
                           withSession:(NSURLSession *)session
                       completionBlock:(SRGPlaylistPostCompletionBlock)completionBlock
{
    NSString *businessUid = dictionary[@"businessId"];
    NSAssert(businessUid != nil, @"A business identifier is required");
    
    NSURL *URL = [[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:businessUid];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"POST";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSAssert([NSJSONSerialization isValidJSONObject:dictionary], @"The data must be serializable to JSON");
    URLRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary, HTTPResponse, error);
    }];
}

+ (SRGRequest *)deletePlaylistWithUid:(NSString *)uid
                       fromServiceURL:(NSURL *)serviceURL
                      forSessionToken:(NSString *)sessionToken
                          withSession:(NSURLSession *)session
                      completionBlock:(SRGPlaylistDeleteCompletionBlock)completionBlock
{
    NSURL *URL = [[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:uid];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:session completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

+ (SRGRequest *)entriesForPlaylistWithUid:(NSString *)playlistUid
                           fromServiceURL:(NSURL *)serviceURL
                          forSessionToken:(NSString *)sessionToken
                              withSession:(NSURLSession *)session
                          completionBlock:(SRGPlaylistEntriesCompletionBlock)completionBlock
{
    NSURL *URL = [[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:playlistUid];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONDictionary[@"bookmarks"], HTTPResponse, error);
    }];
}

+ (SRGRequest *)putPlaylistEntryDictionaries:(NSArray<NSDictionary *> *)dictionaries
                          forPlaylistWithUid:(NSString *)playlistUid
                                toServiceURL:(NSURL *)serviceURL
                             forSessionToken:(NSString *)sessionToken
                                 withSession:(NSURLSession *)session
                             completionBlock:(SRGPlaylistEntriesCompletionBlock)completionBlock
{
    NSURL *URL = [[[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:playlistUid] URLByAppendingPathComponent:@"bookmarks"];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"PUT";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSAssert([NSJSONSerialization isValidJSONObject:dictionaries], @"The data must be serializable to JSON");
    URLRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:dictionaries options:0 error:NULL];
    
    return [SRGRequest JSONArrayRequestWithURLRequest:URLRequest session:session completionBlock:^(NSArray * _Nullable JSONArray, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(JSONArray, HTTPResponse, error);
    }];
}

+ (SRGRequest *)deletePlaylistEntriesWithUids:(NSArray<NSString *> *)uids
                           forPlaylistWithUid:(NSString *)playlistUid
                               fromServiceURL:(NSURL *)serviceURL
                              forSessionToken:(NSString *)sessionToken
                                  withSession:(NSURLSession *)session
                              completionBlock:(SRGPlaylistDeleteCompletionBlock)completionBlock
{
    NSURL *URL = [[[serviceURL URLByAppendingPathComponent:@"v3"] URLByAppendingPathComponent:playlistUid] URLByAppendingPathComponent:@"bookmarks"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
    if (uids) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"mediaIds" value:[uids componentsJoinedByString:@","]]];
    }
    URLComponents.queryItems = queryItems.copy;
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    URLRequest.HTTPMethod = @"DELETE";
    [URLRequest setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return [SRGRequest dataRequestWithURLRequest:URLRequest session:session completionBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

@end
