//
//  MAVEReferralData.h
//  MaveSDK
//
//  Created by Danny Cosson on 2/26/15.
//
//

#import <Foundation/Foundation.h>
#import "MAVERemoteObjectBuilder.h"
#import "MAVEUserData.h"

@interface MAVEReferringData : NSObject<MAVEDictionaryInitializable>

@property (nonatomic, strong) MAVEUserData *referringUser;
@property (nonatomic, strong) MAVEUserData *currentUser;

+ (MAVERemoteObjectBuilder *)remoteBuilder;
+ (NSDictionary *)defaultData;

@end
