#import "UIColor_Utils.h"

@implementation UIColor (Utils)

// Create a color using a string with a webcolor
// ex. [UIColor colorWithHexString:@"#03047F"]
+ (UIColor *) colorWithHexString:(NSString *)hexstr {
    NSScanner *scanner;
    unsigned int rgbval;
    
    scanner = [NSScanner scannerWithString: hexstr];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    [scanner scanHexInt: &rgbval];
    
    return [UIColor colorWithHexValue: rgbval];
}

// Create a color using a hex RGB value
// ex. [UIColor colorWithHexValue: 0x03047F]
+ (UIColor *) colorWithHexValue: (NSInteger) rgbValue {
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0
                           green:((float)((rgbValue & 0xFF00) >> 8))/255.0
                            blue:((float)(rgbValue & 0xFF))/255.0
                           alpha:1.0];
    
}

+ (UIColor *) colorWithRGB: (NSString*) rgb
{
    NSArray* parts = [rgb componentsSeparatedByString:@","];
    
    return RGB(
                    [[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] integerValue],
                    [[parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] integerValue],
                    [[parts[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] integerValue]);
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


@end