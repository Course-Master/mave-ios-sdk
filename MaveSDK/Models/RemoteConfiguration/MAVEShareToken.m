//
//  MAVEShareToken.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/7/15.
//
//

#import "MAVEShareToken.h"
#import "MaveSDK.h"

NSString * const MAVEUserDefaultsKeyShareToken = @"MAVEUserDefaultsKeyShareToken";
NSString *const MAVEShareTokenKeyShareToken = @"share_token";

@implementation MAVEShareToken

- (instancetype)initWithDictionary:(NSDictionary *)data {
    if (self = [super init]) {
        self.shareToken = [data objectForKey:@"share_token"];
    }
    return self;
}

+ (MAVERemoteObjectBuilder *)remoteBuilder {
    return [[MAVERemoteObjectBuilder alloc] initWithClassToCreate:[self class]
            preFetchBlock:^(MAVEPromise *promise) {
                [[MaveSDK sharedInstance].APIInterface
                getRemoteConfigurationWithCompletionBlock:^(NSError *error, NSDictionary *responseData) {
                    if (error) {
                        [promise rejectPromise];
                    } else {
                        [promise fulfillPromise:(NSValue *)responseData];
                    }
                }];
            } defaultData:[self defaultJSONData]
            saveIfSuccessfulToUserDefaultsKey:MAVEUserDefaultsKeyShareToken
                                           preferLocallySavedData:YES];
}

+ (NSDictionary *)defaultJSONData {
    return @{};
}

@end