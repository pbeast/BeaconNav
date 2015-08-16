//
//  AppDelegate.h
//  BeaconNav
//
//  Created by Pavel Yankelevich on 3/16/15.
//  Copyright (c) 2015 PavelY. All rights reserved.
//

#import <UIKit/UIKit.h>

#define AppSettings(settingName) [AppDelegate appSettings][settingName]

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+(NSDictionary*) appSettings;

@end

