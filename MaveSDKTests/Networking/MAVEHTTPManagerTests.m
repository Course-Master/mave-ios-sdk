//
//  MAVEHTTPManagerTests.m
//  MaveSDK
//
//  Created by dannycosson on 10/13/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "MAVEConstants.h"
#import "MAVEHTTPManager.h"
#import "MAVEHTTPManager_Internal.h"

#import <OCMock/OCMock.h>

@interface MAVEHTTPManagerTests : XCTestCase

@property (nonatomic, strong) MAVEHTTPManager *httpManager;

@end

@implementation MAVEHTTPManagerTests

- (void)setUp {
    [super setUp];
    
    // Set up http manager to use
    self.httpManager = [[MAVEHTTPManager alloc] initWithApplicationId:@"foo123"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInitSetsCorrectVaues {
    XCTAssertEqualObjects(self.httpManager.applicationId, @"foo123");
    XCTAssertEqualObjects(self.httpManager.baseURL, @"http://devapi.mave.io/v1.0");
    XCTAssertNotNil(self.httpManager.session);
    XCTAssertEqualObjects(self.httpManager.session.configuration.HTTPAdditionalHeaders, nil);
}

- (void)testUserAgent {
    NSString *expectedUA =  @"(iPhone; CPU iPhone OS 8_1 like Mac OS X)";
    NSString *ua = [MAVEHTTPManager userAgentWithUIDevice:[UIDevice currentDevice]];
    XCTAssertEqualObjects(ua, expectedUA);

}

- (void)testFormattedScreenSize {
    // Should convert the screen size to a string of the format "AxB" that does
    // not differ if we are in landscape mode
    NSString *s1 = [MAVEHTTPManager formattedScreenSize:CGSizeMake(10, 20)];
    NSString *s2 = [MAVEHTTPManager formattedScreenSize:CGSizeMake(10, 10)];
    NSString *s3 = [MAVEHTTPManager formattedScreenSize:CGSizeMake(20, 10)];
    // No need for decimal screen sizes
    NSString *s4 = [MAVEHTTPManager formattedScreenSize:CGSizeMake(10.5001, 10.4999)];
    XCTAssertEqualObjects(s1, @"10x20");
    XCTAssertEqualObjects(s2, @"10x10");
    XCTAssertEqualObjects(s3, @"10x20");
    XCTAssertEqualObjects(s4, @"10x11");
}

//
// Individual API Requests
//
- (void)testTrackAppOpenRequest {
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/launch"
                                             methodType:@"POST"
                                                 params:@{}
                                        completionBlock:nil];
    [httpManager trackAppOpenRequest];
    [mocked verify];
}

- (void)testIdentifyUserRequest {
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    MAVEUserData *userData = [[MAVEUserData alloc] initWithUserID:@"1" firstName:@"Dan" lastName:@"Foo" email:@"foo@bar.com" phone:@"18085551234"];
    NSDictionary *expectedParams = @{@"user_id": userData.userID,
                                     @"first_name": userData.firstName,
                                     @"last_name": userData.lastName,
                                     @"email": userData.email,
                                     @"phone": userData.phone};
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/users"
                                             methodType:@"PUT"
                                                 params:expectedParams
                                        completionBlock:nil];
    [httpManager identifyUserRequest:userData];
    [mocked verify];
}

- (void)testIdentifyUserRequestWithMinimalParams {
    // user id is the only property of the user data required to be non-nil to make the identify user request
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    MAVEUserData *userData = [[MAVEUserData alloc] init];
    // user id is missing so request will fail but it will still get attempted
    NSDictionary *expectedParams = @{};
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/users"
                                             methodType:@"PUT"
                                                 params:expectedParams
                                        completionBlock:nil];
    [httpManager identifyUserRequest:userData];
    [mocked verify];
}

- (void)testTrackSignupRequest {
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    MAVEUserData *userData = [[MAVEUserData alloc] initWithUserID:@"1" firstName:@"Blah" lastName:nil email:nil phone:nil];
    NSDictionary *expectedParams = @{@"user_id": userData.userID};
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/users/signup"
                                             methodType:@"POST"
                                                 params:expectedParams
                                        completionBlock:nil];
    [httpManager trackSignupRequest:userData];
    [mocked verify];
}

- (void)testSendInvitePageOpenEvent {
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    MAVEUserData *userData = [[MAVEUserData alloc] init];
    userData.userID = @"1"; userData.firstName = @"Dan";
    NSDictionary *expectedParams = @{@"user_id": userData.userID};
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/invite_page_open"
                                             methodType:@"POST"
                                                 params:expectedParams
                                        completionBlock:nil];
    [httpManager trackInvitePageOpenRequest:userData];
    [mocked verify];
}

- (void)testSendInvitesEvent {
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] init];
    id mocked = [OCMockObject partialMockForObject:httpManager];
    NSArray *recipients = @[@"18085551234", @"18085555678"];
    NSString *smsCopy = @"This is as test";
    NSString *userId = @"some-user-id";
    NSDictionary *expectedParams = @{@"recipients": recipients,
                                     @"sms_copy": smsCopy,
                                     @"sender_user_id": userId
                                   };
    [[mocked expect] sendIdentifiedJSONRequestWithRoute:@"/invites/sms"
                                             methodType:@"POST"
                                                 params:expectedParams
                                        completionBlock:nil];
    [httpManager sendInvitesWithPersons:recipients message:smsCopy userId:userId completionBlock:nil];
    [mocked verify];
}


//
// Underlying request sending infrastructure
//

- (void)testSendIdentifiedJSONRequestSuccess {
    // Setup mock and block to get data out of the request
    MAVEHTTPManager *httpManager = [[MAVEHTTPManager alloc] initWithApplicationId:@"appid12"];
    id mockSession = [OCMockObject mockForClass:[NSURLSession class]];
    id mockTask = [OCMockObject mockForClass:[NSURLSessionTask class]];
    httpManager.session = mockSession;
    __block NSString *urlString;
    __block NSString *requestMethod;
    __block NSString *requestBodyParams;
    __block NSDictionary *requestHeaders;
    NSString *requestPath = @"/foo";
    NSDictionary *requestDict = @{@"foo": @2, @"bar": @YES};
    OCMStub([mockSession dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *request = (NSURLRequest *)obj;
        urlString = [request.URL absoluteString];
        requestMethod = request.HTTPMethod;
        requestBodyParams = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:kNilOptions error:nil];
        requestHeaders = request.allHTTPHeaderFields;
        return YES;
    }] completionHandler:[OCMArg any]]).andReturn(mockTask);
    OCMExpect([mockTask resume]);

    // Call the send method
    [httpManager sendIdentifiedJSONRequestWithRoute:requestPath methodType:@"POST" params:requestDict completionBlock:nil];

    // Verify
    OCMVerify([mockTask resume]);
    XCTAssertEqualObjects(urlString, @"http://devapi.mave.io/v1.0/foo");
    XCTAssertEqualObjects(requestMethod, @"POST");
    XCTAssertEqualObjects(requestBodyParams, requestDict);
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    NSString *expectedDimensions = [NSString stringWithFormat:@"%ldx%ld",
                                    (long)screenSize.width, (long)screenSize.height];
    NSString *expectedUserAgent = [MAVEHTTPManager userAgentWithUIDevice:[UIDevice currentDevice]];
    NSDictionary *expectedHeaders = @{@"Content-Type": @"application/json; charset=utf-8",
                                      @"Accept": @"application/json",
                                      @"X-Application-ID": @"appid12",
                                      @"User-Agent": expectedUserAgent,
                                      @"X-Device-Screen-Dimensions": expectedDimensions,
                                      };
    XCTAssertEqualObjects(requestHeaders, expectedHeaders);
}

- (void)testGetHTTPStatusCodeLevel {
    NSInteger code = 200;
    NSInteger codeLevel = code / 100;
    XCTAssertEqual(codeLevel, 2);
    code = 201;
    codeLevel = code / 100;
    XCTAssertEqual(codeLevel, 2);
    code = 299;
    codeLevel = code / 100;
    XCTAssertEqual(codeLevel, 2);
}

//
// Tests for errors in building Request
//
- (void)testSendIdentifiedJSONRequestWithBadJSONfails {
    // Object is invalid for JSON
    __block NSError *returnedError;
    __block NSDictionary *returnedDict;
    [self.httpManager sendIdentifiedJSONRequestWithRoute:@"/foo" methodType:@"POST" params:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedDict = responseData;
    }];
    XCTAssertEqual([returnedDict count], 0);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorRequestJSONCode);
}

- (NSData *)failingDataWithJSONObject:(id)params options:(NSJSONWritingOptions)options error:(NSError **)error {
    *error = [[NSError alloc] init];
    return nil;
}

- (void)testSendIdentifiedJSONRequestWithInternalJSONFailure {
    // Internal error when encoding JSON
    // Swizzle the methods to force the error
    Method ogMethod = class_getClassMethod([NSJSONSerialization class], @selector(dataWithJSONObject:options:error:));
    Method mockMethod = class_getInstanceMethod([self class], @selector(failingDataWithJSONObject:options:error:));
    method_exchangeImplementations(ogMethod, mockMethod);

    // Make call to run test
    __block NSError *returnedError = nil;
    __block NSDictionary *returnedDict = nil;
    [self.httpManager sendIdentifiedJSONRequestWithRoute:@"/foo" methodType:@"POST" params:@{} completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedDict = responseData;
    }];
    XCTAssertEqual([returnedDict count], 0);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorRequestJSONCode);
    method_exchangeImplementations(mockMethod, ogMethod);
}

//
// Tests for response handler
//
- (void)testHandleSuccessJSONResponseWithData {
    NSDictionary *dataDict = @{@"foo": @2, @"bar": @"yes", @"baz": @YES};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:kNilOptions error:nil];
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];

    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, dataDict);
    XCTAssertEqualObjects(returnedError, nil);
}

- (void) testHandleEmptyStringResponseBody {
    // Empty string
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];

    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);
    
    // Literal double quotes in string
    data = [@"\"\"\n" dataUsingEncoding:NSUTF8StringEncoding];
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);

    // data nil
    data = nil;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);
}

- (void)testHandleInvalidJSONResponse {
    NSData *data = [@"{\"this is not json" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];

    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseJSONCode);
}

- (void)testHandleNonJSONResponse {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{} options:kNilOptions error:nil];
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"text/html"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseIsNotJSONCode);
}

- (void)testHandle400LevelResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:401 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponse400LevelCode);
}

- (void)testHandle500LevelResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:504 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponse500LevelCode);
}

- (void)testHandleNilResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = nil;
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [MAVEHTTPManager handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseNilCode);
}

- (void)testHandleResponseWithNilCompletionBlockDoesNothing {
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:504 HTTPVersion:@"1.1" headerFields:headers];

    // Shouldn't throw an error
    [MAVEHTTPManager handleJSONResponseWithData:data
                                      response:response
                                         error:nil
                               completionBlock:nil];
}


@end