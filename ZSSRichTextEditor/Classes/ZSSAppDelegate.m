//
//  ZSSAppDelegate.m
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 11/28/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import "ZSSAppDelegate.h"

@implementation ZSSAppDelegate

- (BOOL) application: (UIApplication*) application didFinishLaunchingWithOptions: (NSDictionary*) launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame: [[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.

    self.mainViewController = [ZSSDemoList new];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController: self.mainViewController];
    nav.navigationBar.translucent = NO;

    self.window.rootViewController = nav;
    self.window.backgroundColor = [UIColor systemBackgroundColor];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
