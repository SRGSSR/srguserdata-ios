//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGHistoryRequest.h"

#import <libextobjc/libextobjc.h>

@implementation SRGHistoryRequest

+ (SRGFirstPageRequest *)historyUpdatesFromServiceURL:(NSURL *)serviceURL
                                      forSessionToken:(NSString *)sessionToken
                                            afterDate:(NSDate *)date
                                          withSession:(NSURLSession *)session
                                      completionBlock:(SRGHistoryUpdatesCompletionBlock)completionBlock
{
    NSURL *URL = [serviceURL URLByAppendingPathComponent:@"v2"];
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
    
    return [SRGFirstPageRequest JSONDictionaryRequestWithURLRequest:URLRequest session:session sizer:^NSURLRequest *(NSURLRequest * _Nonnull URLRequest, NSUInteger size) {
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
        }
        else {
            return nil;
        };
    } completionBlock:^(NSDictionary * _Nullable JSONDictionary, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSNumber *serverTimestamp = JSONDictionary[@"last_update"];
        NSDate *serverDate = serverTimestamp ? [NSDate dateWithTimeIntervalSince1970:serverTimestamp.doubleValue / 1000.] : nil;
        completionBlock(JSONDictionary[@"data"], serverDate, page, nextPage, HTTPResponse, error);
    }];
}

+ (SRGRequest *)postHistoryEntryDictionary:(NSDictionary *)dictionary
                              toServiceURL:(NSURL *)serviceURL
                           forSessionToken:(NSString *)sessionToken
                               withSession:(NSURLSession *)session
                           completionBlock:(SRGHistoryPostCompletionBlock)completionBlock
{
    NSURL *URL = [serviceURL URLByAppendingPathComponent:@"v2"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    
    return [SRGRequest JSONDictionaryRequestWithURLRequest:request session:session completionBlock:^(NSDictionary * _Nullable JSONDictionary, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        completionBlock(HTTPResponse, error);
    }];
}

@end
