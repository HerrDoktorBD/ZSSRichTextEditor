//
//  ZSSRichTextEditorVC.h
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 11/30/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#import "HRColorPickerViewController.h"
#import "ZSSFontsViewController.h"

/**
 *  The types of toolbar items that can be added
 */
static NSString * _Nonnull const ZSSRichTextEditorToolbarBold = @"com.zedsaid.toolbaritem.bold";
static NSString * _Nonnull const ZSSRichTextEditorToolbarItalic = @"com.zedsaid.toolbaritem.italic";
static NSString * _Nonnull const ZSSRichTextEditorToolbarSubscript = @"com.zedsaid.toolbaritem.subscript";
static NSString * _Nonnull const ZSSRichTextEditorToolbarSuperscript = @"com.zedsaid.toolbaritem.superscript";
static NSString * _Nonnull const ZSSRichTextEditorToolbarStrikeThrough = @"com.zedsaid.toolbaritem.strikeThrough";
static NSString * _Nonnull const ZSSRichTextEditorToolbarUnderline = @"com.zedsaid.toolbaritem.underline";
static NSString * _Nonnull const ZSSRichTextEditorToolbarRemoveFormat = @"com.zedsaid.toolbaritem.removeFormat";
static NSString * _Nonnull const ZSSRichTextEditorToolbarJustifyLeft = @"com.zedsaid.toolbaritem.justifyLeft";
static NSString * _Nonnull const ZSSRichTextEditorToolbarJustifyCenter = @"com.zedsaid.toolbaritem.justifyCenter";
static NSString * _Nonnull const ZSSRichTextEditorToolbarJustifyRight = @"com.zedsaid.toolbaritem.justifyRight";
static NSString * _Nonnull const ZSSRichTextEditorToolbarJustifyFull = @"com.zedsaid.toolbaritem.justifyFull";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH1 = @"com.zedsaid.toolbaritem.h1";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH2 = @"com.zedsaid.toolbaritem.h2";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH3 = @"com.zedsaid.toolbaritem.h3";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH4 = @"com.zedsaid.toolbaritem.h4";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH5 = @"com.zedsaid.toolbaritem.h5";
static NSString * _Nonnull const ZSSRichTextEditorToolbarH6 = @"com.zedsaid.toolbaritem.h6";
static NSString * _Nonnull const ZSSRichTextEditorToolbarTextColor = @"com.zedsaid.toolbaritem.textColor";
static NSString * _Nonnull const ZSSRichTextEditorToolbarBackgroundColor = @"com.zedsaid.toolbaritem.backgroundColor";
static NSString * _Nonnull const ZSSRichTextEditorToolbarUnorderedList = @"com.zedsaid.toolbaritem.unorderedList";
static NSString * _Nonnull const ZSSRichTextEditorToolbarOrderedList = @"com.zedsaid.toolbaritem.orderedList";
static NSString * _Nonnull const ZSSRichTextEditorToolbarHorizontalRule = @"com.zedsaid.toolbaritem.horizontalRule";
static NSString * _Nonnull const ZSSRichTextEditorToolbarIndent = @"com.zedsaid.toolbaritem.indent";
static NSString * _Nonnull const ZSSRichTextEditorToolbarOutdent = @"com.zedsaid.toolbaritem.outdent";
static NSString * _Nonnull const ZSSRichTextEditorToolbarInsertImage = @"com.zedsaid.toolbaritem.insertImage";
static NSString * _Nonnull const ZSSRichTextEditorToolbarInsertImageFromDevice = @"com.zedsaid.toolbaritem.insertImageFromDevice";
static NSString * _Nonnull const ZSSRichTextEditorToolbarInsertLink = @"com.zedsaid.toolbaritem.insertLink";
static NSString * _Nonnull const ZSSRichTextEditorToolbarRemoveLink = @"com.zedsaid.toolbaritem.removeLink";
static NSString * _Nonnull const ZSSRichTextEditorToolbarQuickLink = @"com.zedsaid.toolbaritem.quickLink";
static NSString * _Nonnull const ZSSRichTextEditorToolbarUndo = @"com.zedsaid.toolbaritem.undo";
static NSString * _Nonnull const ZSSRichTextEditorToolbarRedo = @"com.zedsaid.toolbaritem.redo";
static NSString * _Nonnull const ZSSRichTextEditorToolbarViewSource = @"com.zedsaid.toolbaritem.viewSource";
static NSString * _Nonnull const ZSSRichTextEditorToolbarParagraph = @"com.zedsaid.toolbaritem.paragraph";
static NSString * _Nonnull const ZSSRichTextEditorToolbarAll = @"com.zedsaid.toolbaritem.all";
static NSString * _Nonnull const ZSSRichTextEditorToolbarNone = @"com.zedsaid.toolbaritem.none";
static NSString * _Nonnull const ZSSRichTextEditorToolbarFonts = @"com.zedsaid.toolbaritem.fonts";

// source string for parsing JSON
static NSString * _Nonnull const ZSSEditorHTML = @"zss_editor.getHTML();";
static NSString * _Nonnull const ZSSEditorText = @"zss_editor.getText();";
static NSString * _Nonnull const ZSSEditorContent = @"document.activeElement.id=='zss_editor_content'";

@class ZSSRichTextEditorVC;
@class ZSSBarButtonItem;

NS_ASSUME_NONNULL_BEGIN

@protocol ZSSRichTextEditorDelegate <NSObject>

    @optional

    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor
              didChangeText: (nullable NSString*) text
                       html: (nullable NSString*) html;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didScrollToPosition: (NSInteger) position;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didRecognizeHashtag: (nullable NSString*) hashtag;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didRecognizeMention: (nullable NSString*) mention;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didReceiveUnrecognizedActionLabel: (nullable NSString*) label;
    - (BOOL) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor shouldInteractWithURL: (nullable NSURL*) url;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didChangeContentHeight: (CGFloat)height;
    - (void) richTextEditorDidFinishLoad: (nonnull ZSSRichTextEditorVC*) editor;
    - (void) richTextEditor: (nonnull ZSSRichTextEditorVC*) editor didChangeCaretYPosition: (CGFloat) caretYPosition
                 lineHeight: (CGFloat) lineHeight;
@end

/**
 *  The viewController used with ZSSRichTextEditor
 */
@interface ZSSRichTextEditorVC: UIViewController

    @property (nonatomic, readonly, strong) ZSSBarButtonItem*                   keyboardBtn; // keyboard dismiss button
    @property (nonatomic, readonly, strong) ZSSBarButtonItem*                   showSourceBtn;

    /**
     *  The base URL to use for the webView
     */
    @property (nonatomic, strong) NSURL * baseURL;

    /**
     *  If the HTML should be formatted to be pretty
     */
    @property (nonatomic) BOOL formatHTML;

    /**
     *  If the keyboard should be shown when the editor loads
     */
    @property (nonatomic) BOOL shouldShowKeyboard;

    /**
     * If the sub class recieves text did change events or not
     */
    @property (nonatomic) BOOL receiveEditorDidChangeEvents;

    /**
     *  The placeholder text to use if there is no editor content
     */
    @property (nonatomic, strong) NSString * placeholder;

    /**
     *  Color to tint the toolbar items
     */
    @property (nonatomic, strong) UIColor * toolbarItemTintColor;

    /**
     *  Color to tint selected items
     */
    @property (nonatomic, strong) UIColor * toolbarItemSelectedTintColor;

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
    - (void)setHTML:(NSString *)html;

    /**
     *  Returns the HTML from the Rich Text Editor
     *
     */
    - (void)getHTML:(void (^)(id, NSError* error))completionHandler;

    /**
     *  Returns the plain text from the Rich Text Editor
     *
     */
    - (void)getText:(void (^)(id, NSError* error))completionHandler;

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
     *  Text change callback with text and html
     */
    - (void) editorDidChangeWithText: (NSString*) text
                             andHTML: (NSString*) html;

    /**
     *  Hashtag callback with word
     */
    - (void) hashtagRecognizedWithWord: (NSString*) word;

    /**
     *  Mention callback with word
     */
    - (void) mentionRecognizedWithWord: (NSString*) word;

    /**
     *  Set custom css
     */
    - (void)setCSS: (NSString*) css;

@end

NS_ASSUME_NONNULL_END
