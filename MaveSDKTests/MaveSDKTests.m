//
//  MaveSDKTests.m
//  MaveSDKDevApp
//
//  Created by dannycosson on 10/2/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <objc/runtime.h>
#import "MaveSDK.h"
#import "MaveSDK_Internal.h"
#import "MAVEUserData.h"
#import "MAVEConstants.h"
#import "MAVEAPIInterface.h"

@interface MaveSDK(Testing)
+ (void)resetSharedInstanceForTesting;
@end

@interface MaveSDKTests : XCTestCase

@end

@implementation MaveSDKTests {
    BOOL _fakeAppLaunchWasTriggered;
}

- (void)setUp {
    [super setUp];
    [MaveSDK resetSharedInstanceForTesting];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSetupSharedInstance {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *mave = [MaveSDK sharedInstance];
    XCTAssertEqualObjects(mave.appId, @"foo123");
    XCTAssertNotNil(mave.displayOptions);
    XCTAssertEqualObjects(mave.defaultSMSMessageText, mave.remoteConfiguration.contactsInvitePage.smsCopy);
    XCTAssertNotNil(mave.appDeviceID);
    XCTAssertNotNil(mave.remoteConfigurationBuilder);
    XCTAssertNotNil(mave.shareTokenBuilder);
    XCTAssertNotNil(mave.invitePageChooser);
}


- (void)testSharedInstanceIsShared {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *gk1 = [MaveSDK sharedInstance];
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *gk2 = [MaveSDK sharedInstance];
    
    // Test pointer to same object
    XCTAssertTrue(gk1 == gk2);
}

- (void)testResetSharedInstanceResetsUserDataButNotAppDeviceID {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    NSString *appDeviceID1 = [MaveSDK sharedInstance].appDeviceID;
    [MaveSDK sharedInstance].userData = [[MAVEUserData alloc] init];
    [MaveSDK sharedInstance].userData.userID = @"blah";

    [MaveSDK resetSharedInstanceForTesting];
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    XCTAssertNil([MaveSDK sharedInstance].userData.userID);
    XCTAssertEqualObjects(appDeviceID1, [MaveSDK sharedInstance].appDeviceID);
}

- (void)testSetupSharedInstanceTriggersAppOpenEvent {
    id mock = OCMClassMock([MaveSDK class]);
    OCMStub([mock alloc]).andReturn(mock);
    OCMStub([mock initWithAppId:[OCMArg any]]).andReturn(mock);
    
    OCMExpect([mock trackAppOpen]);
    
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    
    OCMVerifyAll(mock);
    // explicitly stop mocking b/c it's a singleton and won't get cleaned up
    [mock stopMocking];
}

// Test getting properties on the mave object
- (void) testRemoteConfiguration {
    MAVERemoteObjectBuilder *builder = [[MAVERemoteObjectBuilder alloc] init];
    [MaveSDK sharedInstance].remoteConfigurationBuilder = builder;
    id remoteConfig = [[MAVERemoteConfiguration alloc] init];

    id builderMock = OCMPartialMock(builder);
    OCMStub([builderMock createObjectSynchronousWithTimeout:0]).andReturn(remoteConfig);

    XCTAssertEqualObjects([[MaveSDK sharedInstance] remoteConfiguration],
                          remoteConfig);
}
- (void) testDefaultSMSText {
    MaveSDK *mave = [MaveSDK sharedInstance];

    // can be set in remote config
    MAVERemoteConfiguration *remoteConfig = [[MAVERemoteConfiguration alloc] init];
    remoteConfig.contactsInvitePage = [[MAVERemoteConfigurationContactsInvitePage alloc] init];
    remoteConfig.contactsInvitePage.smsCopy = @"foo";
    id maveMock = OCMPartialMock(mave);
    OCMStub([maveMock remoteConfiguration]).andReturn(remoteConfig);

    // if set explicitly, return that as explanation text
    mave.defaultSMSMessageText = @"bar";
    XCTAssertEqualObjects(mave.defaultSMSMessageText, @"bar");

    // if not set, return the value from remote config
    mave.defaultSMSMessageText = nil;
    XCTAssertEqualObjects(mave.defaultSMSMessageText, @"foo");
}

- (void)testInviteExplanationCopy {
    MaveSDK *mave = [MaveSDK sharedInstance];
    mave.displayOptions = [[MAVEDisplayOptions alloc] init];

    // can be set in remote config
    MAVERemoteConfiguration *remoteConfig = [[MAVERemoteConfiguration alloc] init];
    remoteConfig.contactsInvitePage = [[MAVERemoteConfigurationContactsInvitePage alloc] init];
    remoteConfig.contactsInvitePage.explanationCopy = @"foo";
    id maveMock = OCMPartialMock(mave);
    OCMStub([maveMock remoteConfiguration]).andReturn(remoteConfig);

    // if set explicitly in display options, return that as explanation text
    mave.displayOptions.inviteExplanationCopy = @"bar";
    XCTAssertEqualObjects(mave.inviteExplanationCopy, @"bar");

    // if not set, return the value from remote config
    mave.displayOptions.inviteExplanationCopy = nil;
    XCTAssertEqualObjects(mave.inviteExplanationCopy, @"foo");
}

- (void)testGetReferringUser {
    // Just ensure that the method on mock manager gets called with our block
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *mave = [MaveSDK sharedInstance];
    id mockAPIInterface = OCMPartialMock(mave.APIInterface);
    void (^emptyReferringUserBlock)(MAVEUserData *userData) = ^void(MAVEUserData *userData) {};
    OCMExpect([mockAPIInterface getReferringUser:emptyReferringUserBlock]);
    
    [mave getReferringUser:emptyReferringUserBlock];
    
    OCMVerifyAll(mockAPIInterface);
}

- (void)testIdentifyUser {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MAVEUserData *userData = [[MAVEUserData alloc] initWithUserID:@"100" firstName:@"Dan" lastName:@"Foo" email:@"dan@example.com" phone:@"18085551234"];
    MaveSDK *gk = [MaveSDK sharedInstance];
    gk.invitePageDismissalBlock = ^void(UIViewController *vc,
                                        NSUInteger numInvitesSent) {};
    id mockAPIInterface = [OCMockObject mockForClass:[MAVEAPIInterface class]];
    gk.APIInterface = mockAPIInterface;
    OCMExpect([mockAPIInterface identifyUser]);

    [gk identifyUser:userData];

    OCMVerifyAll(mockAPIInterface);
    XCTAssertEqualObjects(gk.userData, userData);
}

- (void)testIdentifyUserInvalidDoesntMakeNetworkRequest {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MAVEUserData *userData = [[MAVEUserData alloc] init];
    userData.userID = @"1";  // no first name
    id mockAPIInterface = OCMClassMock([MAVEAPIInterface class]);
    MaveSDK *mave = [MaveSDK sharedInstance];
    mave.APIInterface = mockAPIInterface;
    [[mockAPIInterface reject] identifyUser];
    
    [mave identifyUser:userData];
    
    OCMVerifyAll(mockAPIInterface);
    XCTAssertEqualObjects(mave.userData, userData);
}

- (void)testIdentifyAnonymousUser {
    id userDataMock = OCMClassMock([MAVEUserData class]);
    OCMExpect([userDataMock alloc]).andReturn(userDataMock);
    OCMExpect([userDataMock initAutomaticallyFromDeviceName]).andReturn(userDataMock);

    id maveMock = OCMPartialMock([MaveSDK sharedInstance]);
    OCMExpect([maveMock identifyUser:userDataMock]);

    [[MaveSDK sharedInstance] identifyAnonymousUser];

    OCMVerifyAll(userDataMock);
    OCMVerifyAll(maveMock);
}

- (void)testIsSetupOKFailsWithNoApplicationID {
    [MaveSDK setupSharedInstanceWithApplicationID:nil];
    MaveSDK *mave = [MaveSDK sharedInstance];
    [mave identifyAnonymousUser];
    mave.invitePageDismissalBlock = ^void(UIViewController *vc,
                                        NSUInteger numInvitesSent) {};
    XCTAssertFalse([mave isSetupOK]);
}

- (void)testIsSetupOkFailsWithNoDismissalBlock {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *mave = [MaveSDK sharedInstance];
    [mave identifyAnonymousUser];

    // never set dismissal block so it's nil
    XCTAssertFalse([mave isSetupOK]);
}

- (void)testIsSetupOkSucceedsWithMinimumRequiredFields {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *mave = [MaveSDK sharedInstance];
    // didn't identify user, but it's ok
    mave.invitePageDismissalBlock = ^void(UIViewController *vc,
                                        NSUInteger numInvitesSent) {};
    XCTAssertTrue([mave isSetupOK]);
}

# pragma mark - Displaying the invite page
- (void)testPresentInvitePageModally {
    MaveSDK *mave = [MaveSDK sharedInstance];

    id maveMock = OCMPartialMock(mave);
    OCMExpect([maveMock isSetupOK]).andReturn(YES);

    MAVEInvitePageDismissBlock dismissalBlock = ^(UIViewController *viewController, NSUInteger numberOfInvitesSent) {};

    __block UIViewController *returnedController;
    __block BOOL called;
    [mave presentInvitePageModallyWithBlock:^(UIViewController *inviteViewController) {
        returnedController = inviteViewController;
        called = YES;
    } dismissBlock:dismissalBlock inviteContext:@"foocontext"];

    // Returns a navigation controller since this is the present modally variation,
    // and set the necessary properties
    OCMVerifyAll(maveMock);
    XCTAssertEqualObjects(mave.invitePageDismissalBlock, dismissalBlock);
    XCTAssertEqualObjects(mave.inviteContext, @"foocontext");
    XCTAssertTrue(called);
    XCTAssertNotNil(returnedController);
    XCTAssertTrue([returnedController isKindOfClass:[UINavigationController class]]);
}

- (void)testPresentInvitePageModallyWithError {
    MaveSDK *mave = [MaveSDK sharedInstance];

    id maveMock = OCMPartialMock(mave);
    OCMExpect([maveMock isSetupOK]).andReturn(NO);

    __block BOOL called;
    // dismissal block nil triggers error
    [mave presentInvitePageModallyWithBlock:^(UIViewController *inviteViewController) {
        called = YES;
    } dismissBlock:nil inviteContext:@"foocontext"];

    // Returns a navigation controller since this is the present modally variation,
    // and set the necessary properties
    OCMVerifyAll(maveMock);
    XCTAssertFalse(called);
}

- (void)testInvitePageViewControllerNoErrorIfUserDataSet {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *gk = [MaveSDK sharedInstance];
    gk.userData = [[MAVEUserData alloc] init];
    gk.userData.userID = @"123";
    gk.userData.firstName = @"Dan";

    NSError *error;
    __block BOOL blockCalled = NO;
    UIViewController *vc =
        [gk invitePageWithDefaultMessage:@"tmp"
                              setupError:&error
                          dismissalBlock:^(UIViewController *viewController,
                                           NSUInteger numberOfInvitesSent) {
                             blockCalled = YES;
    }];
    XCTAssertNotNil(vc);
    XCTAssertNil(error);
    XCTAssertEqualObjects(gk.defaultSMSMessageText, @"tmp");
    // Assert dismissal block set
    gk.invitePageDismissalBlock(vc, 10);
    XCTAssertTrue(blockCalled);
}

- (void)testInvitePageViewControllerErrorIfValidationError {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *gk = [MaveSDK sharedInstance];

    ErrorLog(@"foo");
    NSError *error;
    // dismissal block nil triggers an error
    UIViewController *vc =
        [gk invitePageWithDefaultMessage:@"tmp"
                              setupError:&error
                          dismissalBlock:nil];
    XCTAssertNil(vc);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(gk.defaultSMSMessageText, gk.remoteConfiguration.contactsInvitePage.smsCopy);
    XCTAssertEqualObjects(error.domain, MAVE_VALIDATION_ERROR_DOMAIN);
    XCTAssertEqual(error.code, 5);
}

- (void)testTrackAppOpen {
    [MaveSDK setupSharedInstanceWithApplicationID:@"foo123"];
    MaveSDK *mave = [MaveSDK sharedInstance];
    id mockAPIInterface = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([mockAPIInterface trackAppOpen]);
    [mave trackAppOpen];
    OCMVerifyAll(mockAPIInterface);
}

- (void)testTrackSignup {
    MAVEUserData *userData = [[MAVEUserData alloc] init];
    // Verify the API request is sent
    id mockAPIInterface = [OCMockObject mockForClass:[MAVEAPIInterface class]];
    MaveSDK *mave = [MaveSDK sharedInstance];
    mave.APIInterface = mockAPIInterface;
    mave.userData = userData;
    OCMExpect([mockAPIInterface trackSignup]);
    
    [mave trackSignup];

    OCMVerifyAll(mockAPIInterface);
}

@end