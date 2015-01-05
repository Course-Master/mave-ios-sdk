//
//  MAVEHTTPInterface.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/2/15.
//
//

#import "MAVEHTTPInterface.h"
#import "MaveSDK.h"
#import "MAVEUserData.h"
#import "MAVEConstants.h"
#import "MAVEClientPropertyUtils.h"


NSString * const MAVERouteTrackSignup = @"/signup";
NSString * const MAVERouteTrackAppLaunch = @"/launch";
NSString * const MAVERouteTrackInvitePageOpen = @"/invite_page";

NSString * const MAVERouteTrackContactsPrePermissionPromptView = @"/events/contacts_pre_permission_prompt_view";
NSString * const MAVERouteTrackContactsPrePermissionGranted = @"/events/contacts_pre_permission_granted";
NSString * const MAVERouteTrackContactsPrePermissionDenied = @"/events/contacts_pre_permission_denied";
NSString * const MAVERouteTrackContactsPermissionPromptView = @"/events/contacts_permission_prompt_view";
NSString * const MAVERouteTrackContactsPermissionGranted = @"/events/contacts_permission_granted";
NSString * const MAVERouteTrackContactsPermissionDenied = @"/events/contacts_permission_denied";

NSString * const MAVEParamKeyPrePromptTemplateID = @"contacts_pre_permission_prompt_template_id";
NSString * const MAVEParamKeyInvitePageType = @"invite_page_type";


@implementation MAVEHTTPInterface

- (instancetype)init {
    if (self = [super init]) {
        NSString *baseURL = [MAVEAPIBaseURL stringByAppendingString:MAVEAPIVersion];
        self.httpStack = [[MAVEHTTPStack alloc] initWithAPIBaseURL:baseURL];
    }
    return self;
}

- (NSString *)applicationID {
    return [MaveSDK sharedInstance].appId;
}

- (NSString *)applicationDeviceID {
    return [MaveSDK sharedInstance].appDeviceID;
}

- (MAVEUserData *)userData {
    return [MaveSDK sharedInstance].userData;
}

///
/// Specific Tracking Events
///
- (void)trackAppOpen {
    [self trackGenericUserEventWithRoute:MAVERouteTrackAppLaunch
                        additionalParams:nil];
}

- (void)trackSignup {
    [self trackGenericUserEventWithRoute:MAVERouteTrackSignup additionalParams:nil];
}

- (void)trackInvitePageOpenForPageType:(NSString *)invitePageType {
    if ([invitePageType length] == 0) {
        invitePageType = @"unknown";
    }
    [self trackGenericUserEventWithRoute:MAVERouteTrackInvitePageOpen
                        additionalParams:@{MAVEParamKeyInvitePageType: invitePageType}];
}

///
/// Other remote calls
///
- (void)sendInvitesWithPersons:(NSArray *)persons
                       message:(NSString *)messageText
                        userId:(NSString *)userId
      inviteLinkDestinationURL:(NSString *)inviteLinkDestinationURL
               completionBlock:(MAVEHTTPCompletionBlock)completionBlock {
    NSString *invitesRoute = @"/invites/sms";
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setObject:persons forKey:@"recipients"];
    [params setObject:messageText forKey:@"sms_copy"];
    [params setObject:userId forKey:@"sender_user_id"];
    if ([inviteLinkDestinationURL length] > 0) {
        [params setObject:inviteLinkDestinationURL forKey:@"link_destination"];
    }
    
    [self sendIdentifiedJSONRequestWithRoute:invitesRoute
                                  methodName:@"POST"
                                      params:params
                             completionBlock:completionBlock];
}

- (void)identifyUser {
    NSString *launchRoute = @"/users";
    NSDictionary *params = [self.userData toDictionary];
    [self sendIdentifiedJSONRequestWithRoute:launchRoute
                                  methodName:@"PUT"
                                      params:params
                             completionBlock:nil];
}



//
// GET Requests
// We generally want to pre-fetch them so that when we actually want to access
// the data it's already here and there's no latency.
- (void)getReferringUser:(void (^)(MAVEUserData *userData))referringUserBlock {
    NSString *launchRoute = @"/referring_user";
    
    [self sendIdentifiedJSONRequestWithRoute:launchRoute
                                  methodName:@"GET"
                                      params:nil
                             completionBlock:^(NSError *error, NSDictionary *responseData) {
                                 MAVEUserData *userData;
                                 if (error || [responseData count] == 0) {
                                     userData = nil;
                                 } else {
                                     userData = [[MAVEUserData alloc] initWithDictionary:responseData];
                                 }
                                 referringUserBlock(userData);
                             }];
}

- (MAVEPendingResponseData *)preFetchRemoteConfiguration:(NSDictionary *)defaultData {
    NSString *route = @"/remote_configuration/ios";
    NSError *err;
    NSMutableURLRequest *request = [self.httpStack prepareJSONRequestWithRoute:route
                                                                    methodName:@"GET"
                                                                        params:nil
                                                              preparationError:&err];
    return [self.httpStack preFetchPreparedRequest:request defaultData:defaultData];
}



///
/// Request Sending Helpers
///
- (void)addCustomUserHeadersToRequest:(NSMutableURLRequest *)request {
    [request setValue:self.applicationID forHTTPHeaderField:@"X-Application-Id"];
    [request setValue:self.applicationDeviceID forHTTPHeaderField:@"X-App-Device-Id"];
    NSString *userAgent = [MAVEClientPropertyUtils userAgentDeviceString];
    NSString *screenSize = [MAVEClientPropertyUtils formattedScreenSize];
    NSString *clientProperties = [MAVEClientPropertyUtils encodedAutomaticClientProperties];
    
    [request setValue:screenSize forHTTPHeaderField:@"X-Device-Screen-Dimensions"];
    [request setValue:clientProperties forHTTPHeaderField:@"X-Client-Properties"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
}

- (void)sendIdentifiedJSONRequestWithRoute:(NSString *)relativeURL
                                methodName:(NSString *)methodName
                                    params:(NSDictionary *)params
                           completionBlock:(MAVEHTTPCompletionBlock)completionBlock {
    NSError *requestCreationError;
    NSMutableURLRequest *request = [self.httpStack prepareJSONRequestWithRoute:relativeURL
                                                                    methodName:methodName
                                                                        params:params
                                                              preparationError:&requestCreationError];
    if (requestCreationError) {
        completionBlock(requestCreationError, nil);
    }
    
    [self addCustomUserHeadersToRequest:request];
    
    [self.httpStack sendPreparedRequest:request completionBlock:completionBlock];
}

- (void)trackGenericUserEventWithRoute:(NSString *)relativeRoute
                      additionalParams:(NSDictionary *)params {
    NSMutableDictionary *fullParams = [[NSMutableDictionary alloc] init];
    MAVEUserData *userData = [MaveSDK sharedInstance].userData;
    if (userData.userID) {
        [fullParams setObject:userData.userID forKey:MAVEUserDataKeyUserID];
    }
    for (NSString *key in params) {
        [fullParams setObject:[params objectForKey:key] forKey:key];
    }
    
    [self sendIdentifiedJSONRequestWithRoute:relativeRoute
                                  methodName:@"POST"
                                      params:fullParams
                             completionBlock:nil];
}

@end
