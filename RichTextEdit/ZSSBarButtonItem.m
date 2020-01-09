//
//  ZSSBarButtonItem.m
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 12/3/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import "ZSSBarButtonItem.h"

@interface ZSSBarButtonItem()

    @property (nonatomic) NSString* label;

@end

@implementation ZSSBarButtonItem

+ (NSBundle*) bundle {

    static NSBundle* _bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bundle = [NSBundle bundleForClass: [ZSSBarButtonItem class]];
    });
    return _bundle;
}

+ (ZSSBarButtonItem*) barButtonItemForItemType: (ZSSBarButtonItemType) itemType
                                        target: (id) target
                                        action: (SEL) action {

    NSString* itemName = [self labelForItemType: itemType];

    if (itemType == ZSSBarButtonItemTypeKeyboard || itemType == ZSSBarButtonItemTypeShowSource) {

        UIButton* btn = [UIButton buttonWithType: UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 44, 44);

        UIImage* image = [[UIImage imageNamed: itemName
                                     inBundle: [self bundle]
                compatibleWithTraitCollection: nil]
                          imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
        [btn setImage: image
             forState: UIControlStateNormal];
        btn.imageView.tintColor = [UIColor colorNamed: @"tintColor"];
        [btn addTarget: target
                action: action
      forControlEvents: UIControlEventTouchUpInside];

        ZSSBarButtonItem* item = [[ZSSBarButtonItem alloc] initWithCustomView: btn];

        item.label = itemName;
        item.itemType = itemType;

        return item;
    }

    UIImage* image = [[UIImage imageNamed: itemName
                                 inBundle: [self bundle]
            compatibleWithTraitCollection: nil]
                      imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];

    ZSSBarButtonItem* item = [[ZSSBarButtonItem alloc] initWithImage: image
                                                               style: UIBarButtonItemStylePlain
                                                              target: target
                                                              action: action];
    item.label = itemName;
    item.itemType = itemType;

    return item;
}

+ (UIImage*) imageForItemType: (ZSSBarButtonItemType) itemType {

    NSString* imageName = [self labelForItemType: itemType];

    UIImage* image = [[UIImage imageNamed: imageName
                                 inBundle: [self bundle]
            compatibleWithTraitCollection: nil]
                      imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
    return image;
}

+ (NSString*) labelForItemType: (ZSSBarButtonItemType) itemType {

    NSArray* labels = @[
        @"", // custom

        @"bold",
        @"italic",
        @"subscript",
        @"superscript",
        @"strikethrough",
        @"underline",
        @"removeFormat",
        @"fonts",
        @"undo",
        @"redo",
        @"justifyLeft",
        @"justifyCenter",
        @"justifyRight",
        @"justifyFull",
        @"h1",
        @"h2",
        @"h3",
        @"h4",
        @"h5",
        @"h6",
        @"paragraph",
        @"textcolor",
        @"bgcolor",
        @"unorderedList",
        @"orderedList",
        @"horizontalRule",
        @"indent",
        @"outdent",
        @"image",
        @"imageFromDevice",
        @"link",
        @"removeLink",
        @"quickLink",
        @"viewSource",
        @"keyboard"
    ];

    NSUInteger index = (NSUInteger)itemType;
    NSString* label = [labels objectAtIndex: index];

    return label;
}

@end
