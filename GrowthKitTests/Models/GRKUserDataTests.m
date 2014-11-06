//
//  GRKUserDataTests.m
//  GrowthKit
//
//  Created by Danny Cosson on 11/6/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "GRKUserData.h"

@interface GRKUserDataTests : XCTestCase

@end

@implementation GRKUserDataTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitWithUserData {
    GRKUserData *ud = [[GRKUserData alloc] initWithUserID:@"id1" firstName:@"fi" lastName:@"la" email:@"em" phone:@"ph"];
    XCTAssertEqualObjects(ud.userID, @"id1");
    XCTAssertEqualObjects(ud.firstName, @"fi");
    XCTAssertEqualObjects(ud.lastName, @"la");
    XCTAssertEqualObjects(ud.email, @"em");
    XCTAssertEqualObjects(ud.phone, @"ph");

}

@end
