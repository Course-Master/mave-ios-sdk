//
//  InvitePage.m
//  GrowthKitDevApp
//
//  Created by dannycosson on 9/25/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import "GrowthKit.h"
#import "GRKConstants.h"
#import "GRKInvitePageViewController.h"
#import "GRKDisplayOptions.h"
#import "GRKHTTPManager.h"

@implementation GrowthKit {
    // Controller
    UINavigationController *invitePageNavController;
}

//
// Init and handling shared instance & needed data
//
- (instancetype)initWithAppId:(NSString *)appId {
    if (self = [self init]) {
        _appId = appId;
        _displayOptions = [[GRKDisplayOptions alloc] initWithDefaults];
        _HTTPManager = [[GRKHTTPManager alloc] initWithApplicationId:appId];
    }
    return self;
}

static GrowthKit *sharedInstance = nil;
static dispatch_once_t sharedInstanceonceToken;

+ (void)setupSharedInstanceWithApplicationID:(NSString *)applicationID {
    dispatch_once(&sharedInstanceonceToken, ^{
        sharedInstance = [[self alloc] initWithAppId:applicationID];
    });
}

# if DEBUG
+ (void)resetSharedInstanceForTesting {
    sharedInstanceonceToken = 0;
}
#endif

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        NSLog(@"Error: didn't setup shared instance with app id");
    }
    return sharedInstance;
}

- (void)setUserData:(NSString *)userId firstName:(NSString *)firstName lastName:(NSString *)lastName {
    _currentUserId = userId;
    _currentUserFirstName = firstName;
    _currentUserLastName = lastName;
}

- (NSError *)validateSetup {
    NSInteger errCode = 0;
    if (self.appId == nil) {
        DebugLog(@"Error with GrowthKit shared instance setup - Application ID not set");
        errCode = GRKValidationErrorApplicationIDNotSetCode;
    } else if (self.currentUserId == nil) {
        DebugLog(@"Error with GrowthKit shared instance setup - UserID not set");
        errCode = GRKValidationErrorUserIDNotSetCode;
    } else if (self.currentUserFirstName == nil) {
        DebugLog(@"Error with GrowthKit shared instance setup - user firstName not set");
        errCode = GRKValidationErrorUserNameNotSetCode;
    } else {
        return nil;
    }

    return [[NSError alloc] initWithDomain:GRK_VALIDATION_ERROR_DOMAIN code:errCode userInfo:@{}];
}

//
// Funnel events that need to be called explicitly by consumer
//
- (void)registerAppOpen {
    [self.HTTPManager sendApplicationLaunchNotification];
}

- (void)registerNewUserSignup:(NSString *)userId
                    firstName:(NSString *)firstName
                     lastName:(NSString *)lastName
                        email:(NSString *)email
                        phone:(NSString *)phone {
    self.currentUserId = userId;
    self.currentUserFirstName = firstName;
    self.currentUserLastName = lastName;
    [self.HTTPManager sendUserSignupNotificationWithUserID:userId
                                                 firstName:firstName
                                                  lastName:lastName
                                                     email:email
                                                     phone:phone];
}

//
// Methods for consumer to present/manage the invite page
//
- (UIViewController *)invitePageViewControllerWithDelegate:(id<GRKInvitePageDelegate>)delegate
                                           validationError:(NSError **)error{
    UIViewController *returnVC = nil;
    *error = [self validateSetup];
    if (!*error) {
        GRKInvitePageViewController *inviteController = [[GRKInvitePageViewController alloc] initWithDelegate:delegate];
        returnVC = [[UINavigationController alloc] initWithRootViewController:inviteController];
    }
    return returnVC;
}

@end