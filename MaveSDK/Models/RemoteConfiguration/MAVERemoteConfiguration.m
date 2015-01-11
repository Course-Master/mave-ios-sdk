//
//  MAVERemoteConfiguration.m
//  MaveSDK
//
//  Created by Danny Cosson on 12/18/14.
//
//

#import <Foundation/Foundation.h>
#import "MaveSDK.h"
#import "MAVEConstants.h"
#import "MAVERemoteConfiguration.h"
#import "MAVERemoteObjectBuilder.h"
#import "MAVERemoteConfigurationContactsPrePrompt.h"

NSString * const MAVEUserDefaultsKeyRemoteConfiguration = @"MAVEUserDefaultsKeyRemoteConfiguration";

const NSString *MAVERemoteConfigKeyContactsPrePrompt = @"contacts_pre_permission_prompt";
const NSString *MAVERemoteConfigKeyContactsInvitePage =
    @"contacts_invite_page";
NSString * const MAVERemoteConfigKeyClientSMS = @"client_sms";


@implementation MAVERemoteConfiguration

- (instancetype)initWithDictionary:(NSDictionary *)data {
    if (self = [super init]) {
        self.contactsPrePrompt = [[MAVERemoteConfigurationContactsPrePrompt alloc] initWithDictionary:[data objectForKey:MAVERemoteConfigKeyContactsPrePrompt]];
        self.contactsInvitePage = [[MAVERemoteConfigurationContactsInvitePage alloc] initWithDictionary:[data objectForKey:MAVERemoteConfigKeyContactsInvitePage]];
        self.clientSMS = [[MAVERemoteConfigurationClientSMS alloc] initWithDictionary:[data objectForKey:MAVERemoteConfigKeyClientSMS]];

        if (!self.contactsPrePrompt
            || !self.contactsInvitePage
            || !self.clientSMS) {
            return nil;
        }
    }
    return self;
}

+ (MAVERemoteObjectBuilder *)remoteBuilder {
    return [[MAVERemoteObjectBuilder alloc] initWithClassToCreate:[self class] preFetchBlock:^(MAVEPromise *promise) {
            [[MaveSDK sharedInstance].APIInterface getRemoteConfigurationWithCompletionBlock:^(NSError *error, NSDictionary *responseData) {
                DebugLog(@"RemoteConfiguration data was: %@", responseData);
                 if (error) {
                     [promise rejectPromise];
                 } else {
                     [promise fulfillPromise:(NSValue *)responseData];
                 }
             }];
            } defaultData:[self defaultJSONData]
            saveIfSuccessfulToUserDefaultsKey:MAVEUserDefaultsKeyRemoteConfiguration
            preferLocallySavedData:NO];
}

+ (NSDictionary *)defaultJSONData {
    return @{
             MAVERemoteConfigKeyContactsPrePrompt: [MAVERemoteConfigurationContactsPrePrompt defaultJSONData],
             MAVERemoteConfigKeyContactsInvitePage:[MAVERemoteConfigurationContactsInvitePage defaultJSONData],
             MAVERemoteConfigKeyClientSMS: [MAVERemoteConfigurationClientSMS defaultJSONData],
             };
}

@end
