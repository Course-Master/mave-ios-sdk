//
//  GRKInviteMessageViewTests.m
//  GrowthKit
//
//  Created by dannycosson on 10/19/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "GrowthKit.h"
#import "GRKDisplayOptions.h"
#import "GRKDisplayOptionsFactory.h"
#import "GRKInviteMessageView.h"
#import "GRKInviteSendingProgressView.h"

@interface GRKInviteMessageViewTests : XCTestCase

@end

@implementation GRKInviteMessageViewTests

- (void)setUp {
    [super setUp];
    [GrowthKit setupSharedInstanceWithApplicationID:@"foo123"];
    [GrowthKit sharedInstance].displayOptions = [GRKDisplayOptionsFactory generateDisplayOptions];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMessageViewStyleOnInit {
    // Setup and get opts to compare it to
    CGRect fakeFrame = CGRectMake(0, 0, 0, 0);
    GRKInviteMessageView *view = [[GRKInviteMessageView alloc] initWithFrame:fakeFrame];
    GRKDisplayOptions *opts = [GrowthKit sharedInstance].displayOptions;

    // Test Message field style
    XCTAssertEqualObjects(view.backgroundColor, opts.bottomViewBackgroundColor);
    UIColor *tfbgColor = [[UIColor alloc]
                          initWithCGColor:view.textField.layer.backgroundColor];
    XCTAssertEqualObjects(tfbgColor, [GRKDisplayOptions colorWhite]);
    UIColor *tfBorderColor = [[UIColor alloc]
                              initWithCGColor:view.textField.layer.borderColor];
    XCTAssertEqualObjects(tfBorderColor, [GRKDisplayOptions colorAlmostBlack]);

    // Test Button Style
    XCTAssertEqualObjects([view.sendButton titleColorForState:UIControlStateNormal], opts.tintColor);
}

- (void)testSendingProgressViewStyleOnInit {
    CGRect fakeFrame = CGRectMake(0, 0, 0, 0);
    GRKInviteSendingProgressView *view = [[GRKInviteSendingProgressView alloc] initWithFrame:fakeFrame];
    GRKDisplayOptions *opts = [GrowthKit sharedInstance].displayOptions;

    XCTAssertEqualObjects(view.backgroundColor, opts.bottomViewBackgroundColor);
    XCTAssertEqualObjects(view.progressView.tintColor, opts.tintColor);
    XCTAssertEqualObjects(view.mainLabel.textColor, opts.tintColor);
}
    
@end