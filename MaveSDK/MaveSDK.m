//
//  InvitePage.m
//  MaveSDKDevApp
//
//  Created by dannycosson on 9/25/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import "MaveSDK.h"
#import "MaveSDK_Internal.h"
#import "MAVEInvitePageViewController.h"
#import "MAVEConstants.h"
#import "MAVEIDUtils.h"
#import "MAVEDisplayOptions.h"
#import "MAVERemoteConfiguration.h"
#import "MAVEShareToken.h"
#import "MAVECustomSharePageViewController.h"

@implementation MaveSDK {
    // Controller
    UINavigationController *invitePageNavController;
}

//
// Init and handling shared instance & needed data
//
- (instancetype)initWithAppId:(NSString *)appId {
    if (self = [self init]) {
        _appId = appId;
        _appDeviceID = [MAVEIDUtils loadOrCreateNewAppDeviceID];
        _displayOptions = [[MAVEDisplayOptions alloc] initWithDefaults];
        _APIInterface = [[MAVEAPIInterface alloc] init];
    }
    return self;
}

static MaveSDK *sharedInstance = nil;
static dispatch_once_t sharedInstanceonceToken;

+ (void)setupSharedInstanceWithApplicationID:(NSString *)applicationID {
    dispatch_once(&sharedInstanceonceToken, ^{
        sharedInstance = [[self alloc] initWithAppId:applicationID];
        [sharedInstance trackAppOpen];

        sharedInstance.remoteConfigurationBuilder = [MAVERemoteConfiguration remoteBuilder];
        sharedInstance.shareTokenBuilder = [MAVEShareToken remoteBuilder];
    });
}

// ability to reset singleton during tests
# if DEBUG
+ (void)resetSharedInstanceForTesting {
    sharedInstanceonceToken = 0;
}
#endif

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        MAVEErrorLog(@"You did not set up shared instance with app id");
    }
    return sharedInstance;
}

- (NSError *)validateUserSetup {
    NSInteger errCode = 0;
    NSString *humanError = @"";
    if (self.appId == nil) {
        humanError = @"applicationID is nil";
        errCode = MAVEValidationErrorApplicationIDNotSetCode;
    } else if (self.userData == nil) {
        humanError = @"identifyUser not called";
        errCode = MAVEValidationErrorUserIdentifyNeverCalledCode;
    } else if (self.userData.userID == nil) {
        humanError = @"userID set to nil";
        errCode = MAVEValidationErrorUserIDNotSetCode;
    } else if (self.userData.firstName == nil) {
        humanError = @"user firstName set to nil";
        errCode = MAVEValidationErrorUserNameNotSetCode;
    } else {
        return nil;
    }
    MAVEDebugLog(@"Error with MaveSDK sharedInstance user info setup - %@", humanError);
    return [[NSError alloc] initWithDomain:MAVE_VALIDATION_ERROR_DOMAIN
                                      code:errCode
                                  userInfo:@{@"message": humanError}];
}

- (BOOL)isSetupOK {
    NSString *errorFormat = @"Issue with MaveSDK setup - %@.";
    BOOL ok = YES;
    if (!self.appId) {
        MAVEErrorLog(errorFormat, @"applicationID is nil");
        ok = NO;
    }
    return ok;
}

- (MAVERemoteConfiguration *)remoteConfiguration {
    id obj = [self.remoteConfigurationBuilder createObjectSynchronousWithTimeout:0];
    return (MAVERemoteConfiguration *)obj;
}

- (NSString *)defaultSMSMessageText {
    if (_defaultSMSMessageText) {
        return _defaultSMSMessageText;
    } else {
        return self.remoteConfiguration.serverSMS.text;
    }
}

- (NSString *)inviteExplanationCopy {
    if (self.displayOptions.inviteExplanationCopy) {
        return self.displayOptions.inviteExplanationCopy;
    } else {
        return self.remoteConfiguration.contactsInvitePage.explanationCopy;
    }
}

//
// Methods to get data from our sdk
//
- (void)getReferringUser:(void (^)(MAVEUserData *))referringUserHandler {
    [self.APIInterface getReferringUser:referringUserHandler];
}

//
// Funnel events that need to be called explicitly by consumer
//
- (void)trackAppOpen {
    [self.APIInterface trackAppOpen];
}

- (void)identifyUser:(MAVEUserData *)userData {
    self.userData = userData;
    NSError *validationError = [self validateUserSetup];
    if (validationError == nil) {
        [self.APIInterface identifyUser];
    }
}

- (void)identifyAnonymousUser {
    MAVEUserData *user = [[MAVEUserData alloc] initAutomaticallyFromDeviceName];
    if (user) {
        [self identifyUser:user];
    }
}

- (void)trackSignup {
    [self.APIInterface trackSignup];
}

//
// Methods for consumer to present/manage the invite page
//

- (void)presentInvitePageModallyWithBlock:(MAVEInvitePagePresentBlock)presentBlock
                             dismissBlock:(MAVEInvitePageDismissBlock)dismissBlock
                            inviteContext:(NSString *)inviteContext {
    if (![self isSetupOK]) {
        MAVEErrorLog(@"Not displaying Mave invite page because parameters not all set, see other log errors");
        return;
    }
    self.invitePageChooser = [[MAVEInvitePageChooser alloc]
                              initForModalPresentWithCancelBlock:dismissBlock];
    [self.invitePageChooser chooseAndCreateInvitePageViewController];
    [self.invitePageChooser setupNavigationBarForActiveViewController];
    self.inviteContext = inviteContext;
    presentBlock(self.invitePageChooser.activeViewController.navigationController);
}

- (void)presentInvitePagePushWithBlock:(MAVEInvitePagePresentBlock)presentBlock
                          forwardBlock:(MAVEInvitePageDismissBlock)forwardBlock
                            backBlock:(MAVEInvitePageDismissBlock)backBlock
                         inviteContext:(NSString *)inviteContext {
    if (![self isSetupOK]) {
        MAVEErrorLog(@"Not displaying Mave invite page because parameters not all set, see other log errors");
        return;
    }
    self.invitePageChooser = [[MAVEInvitePageChooser alloc]
                              initForPushPresentWithForwardBlock:forwardBlock
                              backBlock:backBlock];
    [self.invitePageChooser chooseAndCreateInvitePageViewController];
    [self.invitePageChooser setupNavigationBarForActiveViewController];
    self.inviteContext = inviteContext;
    presentBlock(self.invitePageChooser.activeViewController);
}

@end