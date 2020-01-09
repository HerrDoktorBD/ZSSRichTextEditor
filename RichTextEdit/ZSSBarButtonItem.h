//
//  ZSSBarButtonItem.h
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 12/3/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#pragma once

@import UIKit;

typedef NS_ENUM(NSInteger, ZSSBarButtonItemType) {
    
    ZSSBarButtonItemTypeCustom = 0,

    ZSSBarButtonItemTypeBold,
    ZSSBarButtonItemTypeItalic,
    ZSSBarButtonItemTypeSubscript,
    ZSSBarButtonItemTypeSuperscript,
    ZSSBarButtonItemTypeStrikeThrough,
    ZSSBarButtonItemTypeUnderline,
    ZSSBarButtonItemTypeRemoveFormat,
    ZSSBarButtonItemTypeFonts,
    ZSSBarButtonItemTypeUndo,
    ZSSBarButtonItemTypeRedo,
    ZSSBarButtonItemTypeJustifyLeft,
    ZSSBarButtonItemTypeJustifyCenter,
    ZSSBarButtonItemTypeJustifyRight,
    ZSSBarButtonItemTypeJustifyFull,
    ZSSBarButtonItemTypeParagraph,
    ZSSBarButtonItemTypeH1,
    ZSSBarButtonItemTypeH2,
    ZSSBarButtonItemTypeH3,
    ZSSBarButtonItemTypeH4,
    ZSSBarButtonItemTypeH5,
    ZSSBarButtonItemTypeH6,
    ZSSBarButtonItemTypeTextColor,
    ZSSBarButtonItemTypeBgColor,
    ZSSBarButtonItemTypeUnorderedList,
    ZSSBarButtonItemTypeOrderedList,
    ZSSBarButtonItemTypeHorizontalRule,
    ZSSBarButtonItemTypeIndent,
    ZSSBarButtonItemTypeOutdent,
    ZSSBarButtonItemTypeImage,
    ZSSBarButtonItemTypeImageFromDevice,
    ZSSBarButtonItemTypeInsertLink,
    ZSSBarButtonItemTypeRemoveLink,
    ZSSBarButtonItemTypeQuickLink,

    ZSSBarButtonItemTypeShowSource,
    ZSSBarButtonItemTypeKeyboard,
};

NS_ASSUME_NONNULL_BEGIN

@interface ZSSBarButtonItem: UIBarButtonItem

    /**
     A label of the bar button item. Useful for identifying the bar button item and user actions.
     */
    @property (nonatomic, readonly, nullable) NSString* label;

    /**
     An item type of the bar button item.
     */
    @property (nonatomic) ZSSBarButtonItemType itemType;

    + (NSString*) labelForItemType: (ZSSBarButtonItemType) itemType;
    + (UIImage*) imageForItemType: (ZSSBarButtonItemType) itemType;

    /**
     Returns new bar button item.
     */
    + (ZSSBarButtonItem*) barButtonItemForItemType: (ZSSBarButtonItemType) itemType
                                            target: (id) t
                                            action: (SEL) sel;
@end

NS_ASSUME_NONNULL_END
