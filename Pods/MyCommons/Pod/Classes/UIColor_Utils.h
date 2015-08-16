//
//  UIColor_Utils.h
//  Rashim
//
//  Created by Pavel Yankelevich on 6/16/14.
//  Copyright (c) 2014 Pavel Yankelevich. All rights reserved.
//

#import <UIKit/UIKit.h>

#define RGB(r, g, b) \
    [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBA(r, g, b, a) \
    [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

@interface UIColor (Utils)
+ (UIColor *) colorWithHexString:(NSString *)hex;
+ (UIColor *) colorWithHexValue: (NSInteger) hex;
+ (UIColor *) colorWithRGB: (NSString*) rgb;

+ (UIImage *)imageWithColor:(UIColor *)color;

@end


