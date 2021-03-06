//
//  ZSSAppDelegate.h
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 11/28/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZSSDemoList.h"

@interface ZSSAppDelegate: UIResponder <UIApplicationDelegate>

    @property (strong, nonatomic) UIWindow* window;
    @property (nonatomic, strong) ZSSDemoList* mainViewController;

@end
