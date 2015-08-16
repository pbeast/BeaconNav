//
//  AppDelegate.m
//  BeaconNav
//
//  Created by Pavel Yankelevich on 3/16/15.
//  Copyright (c) 2015 PavelY. All rights reserved.
//

#import "AppDelegate.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "Parse/Parse.h"
#import "ParseUI/ParseUI.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


+(NSDictionary*) appSettings
{
    static NSDictionary* settingsDictionary = nil;
    
    if (settingsDictionary == nil)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource: @"appSettings" ofType: @"plist"];
        settingsDictionary = [NSDictionary dictionaryWithContentsOfFile: path];
    }
    
    return settingsDictionary;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [Fabric with:@[CrashlyticsKit]];
    
    [AppDelegate appSettings];
    
    
    PFACL *defaultACL = [PFACL ACL];
    // If you would like all objects to be private by default, remove this line.
    [defaultACL setPublicReadAccess:YES];
    
    [PFACL setDefaultACL:defaultACL withAccessForCurrentUser:YES];
    
    [Parse enableLocalDatastore];
    
    //Prod
    [Parse setApplicationId:@"3WysGgk1tvtwVQC4SDljVNjqE9kmqw2ta9NQSdPh" clientKey:@"4dSy1lmDieqSjteWlh7nBBBcOwpz45XEFIOwj5hG"];

    [PFImageView class];

    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.


    [application setIdleTimerDisabled:NO];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    [application setIdleTimerDisabled:YES];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
