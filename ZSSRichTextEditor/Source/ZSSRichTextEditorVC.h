//
//  ZSSRichTextEditorVC.h
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 11/30/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import <UIKit/UIKit.h>

#pragma once

@class ZSSRichTextEditorVC;
@class ZSSBarButtonItem;

NS_ASSUME_NONNULL_BEGIN

@protocol ZSSRichTextEditorDelegate <NSObject>

    @optional

    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor
              didChangeText: (nullable NSString*) text
                       html: (nullable NSString*) html;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didScrollToPosition: (NSInteger) position;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didRecognizeHashtag: (nullable NSString*) hashtag;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didRecognizeMention: (nullable NSString*) mention;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didReceiveUnrecognizedActionLabel: (nullable NSString*) label;
    - (BOOL) richTextEditor: (ZSSRichTextEditorVC*) editor shouldInteractWithURL: (nullable NSURL*) url;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didChangeContentHeight: (CGFloat)height;
    - (void) richTextEditorDidFinishLoad: (ZSSRichTextEditorVC*) editor;
    - (void) richTextEditor: (ZSSRichTextEditorVC*) editor didChangeCaretYPosition: (CGFloat) caretYPosition
                 lineHeight: (CGFloat) lineHeight;
@end

/**
 *  The viewController used with ZSSRichTextEditor
 */
@interface ZSSRichTextEditorVC: UIViewController

    /**
     *  The base URL to use for the webView
     */
    @property (nonatomic, strong) NSURL* baseURL;

    /**
     *  If the HTML should be formatted to be pretty
     */
    @property (nonatomic) BOOL formatHTML;

    /**
     *  If the keyboard should be shown when the editor loads
     */
    @property (nonatomic) BOOL shouldShowKeyboard;

    /**
     * If the sub class receives text did change events or not
     */
    @property (nonatomic) BOOL receiveEditorDidChangeEvents;

    /**
     *  The placeholder text to use if there is no editor content
     */
    @property (nonatomic, strong) NSString* placeholder;

    /**
     *  Color to tint the toolbar items
     */
    @property (nonatomic, strong) UIColor* toolbarItemTintColor;

    /**
     *  Color to tint selected items
     */
    @property (nonatomic, strong) UIColor* toolbarItemSelectedTintColor;

    /**
     A delegate of the text editor.
     */
    @property (nonatomic, weak, nullable) id<ZSSRichTextEditorDelegate> delegate;

    /**
     *  Sets the HTML for the entire editor
     *
     *  @param html  HTML string to set for the editor
     *
     */
    - (void) setHTML: (NSString*) html;

    /**
     *  Returns the HTML from the Rich Text Editor
     *
     */
    - (void) getHTML: (void (^)(id, NSError* error)) completionHandler;

    /**
     *  Returns the plain text from the Rich Text Editor
     *
     */
    - (void) getText: (void (^)(id, NSError* error)) completionHandler;

    /**
     *  Inserts HTML at the caret position
     *
     *  @param html  HTML string to insert
     *
     */
    - (void) insertHTML: (NSString*) html;

    /**
     *  Manually focuses on the text editor
     */
    - (void) focusTextEditor;

    /**
     *  Manually dismisses on the text editor
     */
    - (void) blurTextEditor;

    /**
     *  Shows the insert image dialog with optinal inputs
     *
     *  @param url The URL for the image
     *  @param alt The alt for the image
     */
    - (void) showInsertImageDialogWithLink: (NSString*) url
                                       alt: (nullable NSString*) alt;

    /**
     *  Inserts an image
     *
     *  @param url The URL for the image
     *  @param alt The alt attribute for the image
     */
    - (void) insertImage:(NSString*) url
                     alt: (nullable NSString*) alt;

    /**
     *  Shows the insert link dialog with optional inputs
     *
     *  @param url   The URL for the link
     *  @param title The tile for the link
     */
    - (void) showInsertLinkDialogWithLink: (NSString*) url
                                    title: (nullable NSString*) title;

    /**
     *  Inserts a link
     *
     *  @param url The URL for the link
     *  @param title The title for the link
     */
    - (void) insertLink: (NSString*) url
                  title: (NSString*) title;

    /**
     *  Set custom css
     */
    - (void) setCSS: (NSString*) css;

@end

NS_ASSUME_NONNULL_END
