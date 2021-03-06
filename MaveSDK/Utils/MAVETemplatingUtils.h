//
//  MAVETemplatingUtils.h
//  MaveSDK
//
//  Created by Danny Cosson on 3/24/15.
//
//

#import <Foundation/Foundation.h>
#import "MAVEUserData.h"

@interface MAVETemplatingUtils : NSObject

// Convert any id to a string value if possible, or return nil if not possible.
// Will convert NSNumber and NSNull successfully, not arbitrary objects.
+ (NSString *)convertValueToString:(id)value;

// Helper method to interpolate the template string using the current context.
// Available fields in template are user.* and customData.*, but the way we
// pass the values in customData is a property of MAVEUserData.
+ (NSString *)interpolateTemplateString:(NSString *)templateString
                               withUser:(MAVEUserData *)user
                                   link:(NSString *)link;

+ (NSString *)appendLinkVariableToTemplateStringIfNeeded:(NSString *)templateString;

+ (NSString *)interpolateWithSingletonDataTemplateString:(NSString *)templateString;

@end
