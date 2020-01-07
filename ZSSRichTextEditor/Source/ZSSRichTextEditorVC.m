//
//  ZSSRichTextEditorVC.m
//  ZSSRichTextEditor
//
//  Created by Nicholas Hubbard on 11/30/13.
//  Copyright (c) 2013 Zed Said Studio. All rights reserved.
//

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#import "ZSSRichTextEditorVC.h"

#import <RichTextEditor/RichTextEditor.h>

@import JavaScriptCore;

/*
https://useyourloaf.com/blog/how-to-percent-encode-a-url-string/
 usage:
 // Objective-C
 NSString *query = @"one&two =three";
 NSString *encoded = [query stringByAddingPercentEncodingForRFC3986];
 // "one%26two%20%3Dthree"
 */
@implementation NSString (URLEncoding)

- (nullable NSString*) stringByAddingPercentEncodingForRFC3986 {
    NSString* unreserved = @"-._~/?";
    NSMutableCharacterSet* allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString: unreserved];
    return [self stringByAddingPercentEncodingWithAllowedCharacters: allowed];
}

@end

#ifndef IS_IPAD
#   define IS_IPAD ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#endif

/**
 WKWebView modifications for hiding the inputAccessoryView
 **/
@interface WKWebView (HackishAccessoryHiding)
    @property (nonatomic, assign) BOOL hidesInputAccessoryView;
@end

@implementation WKWebView (HackishAccessoryHiding)

static const char* const hackishFixClassName = "WKWebBrowserViewMinusAccessoryView";
static Class hackishFixClass = Nil;

- (UIView*) hackishlyFoundBrowserView {

    UIView *browserView = nil;
    UIScrollView* scrollView = self.scrollView;
    for (UIView* subview in scrollView.subviews) {

        if ([NSStringFromClass([subview class]) hasPrefix:@"WKWebBrowserView"]) {

            browserView = subview;
            break;
        }
    }
    return browserView;
}

- (id) methodReturningNil {
    return nil;
}

- (void) ensureHackishSubclassExistsOfBrowserViewClass:(Class)browserViewClass {

    if (!hackishFixClass) {

        Class newClass = objc_allocateClassPair(browserViewClass, hackishFixClassName, 0);
        newClass = objc_allocateClassPair(browserViewClass, hackishFixClassName, 0);
        IMP nilImp = [self methodForSelector:@selector(methodReturningNil)];
        class_addMethod(newClass, @selector(inputAccessoryView), nilImp, "@@:");
        objc_registerClassPair(newClass);
        
        hackishFixClass = newClass;
    }
}

- (BOOL) hidesInputAccessoryView {

    UIView* browserView = [self hackishlyFoundBrowserView];
    return [browserView class] == hackishFixClass;
}

- (void) setHidesInputAccessoryView:(BOOL)value {

    UIView *browserView = [self hackishlyFoundBrowserView];
    if (browserView == nil) {
        return;
    }
    [self ensureHackishSubclassExistsOfBrowserViewClass:[browserView class]];
    
    if (value) {
        object_setClass(browserView, hackishFixClass);
    }
    else {
        Class normalClass = objc_getClass("WKWebBrowserView");
        object_setClass(browserView, normalClass);
    }
    [browserView reloadInputViews];
}

@end

@interface ZSSRichTextEditorVC() <WKUIDelegate,
                                  WKNavigationDelegate,
                                  WKScriptMessageHandler,

                                  UITextViewDelegate,
                                  UINavigationControllerDelegate,
                                  UIImagePickerControllerDelegate,
                                  
                                  HRColorPickerViewControllerDelegate,
                                  ZSSFontsViewControllerDelegate>
    /*
     *  Holder for all of the toolbar components
     */
    @property (nonatomic, strong) UIView*                  toolbarView;

    /*
     *  Toolbars containing ZSSBarButtonItems
     */
    @property (nonatomic, strong) UIToolbar*               toolbar;
    @property (nonatomic, strong) UIToolbar*               toolbar2;

    /*
     *  Scroll view containing the toolbar
     */
    @property (nonatomic, strong) UIScrollView*            toolbarScrollView;

    /*
     *  String for the HTML
     */
    @property (nonatomic, strong) NSString*                htmlString;

    /*
     *  WKWebView for writing/editing/displaying the content
     */
    @property (nonatomic, strong) WKWebView*               editorView;

    /*
     *  ZSSTextView for displaying the source code for what is displayed in the editor view
     */
    @property (nonatomic, strong) ZSSTextView*             sourceView;

    /*
     *  BOOL for holding if the resources are loaded or not
     */
    @property (nonatomic)         BOOL                     resourcesLoaded;

    /*
     *  Array holding the enabled editor items
     */
    @property (nonatomic, strong) NSArray*                 highlightedBarButtonLabels;

    /*
     *  NSString holding the selected links URL value
     */
    @property (nonatomic, strong) NSString*                selectedLinkURL;

    /*
     *  NSString holding the selected links title value
     */
    @property (nonatomic, strong) NSString*                selectedLinkTitle;

    /*
     *  NSString holding the selected image URL value
     */
    @property (nonatomic, strong) NSString*                selectedImageURL;

    /*
     *  NSString holding the selected image Alt value
     */
    @property (nonatomic, strong) NSString*                selectedImageAlt;

    /*
     *  CGFloat holding the selected image scale value
     */
    @property (nonatomic, assign) CGFloat                  selectedImageScale;

    /*
     *  NSString holding the base64 value of the current image
     */
    @property (nonatomic, strong) NSString*                imageBase64String;

    /*
     *  NSString holding the html
     */
    @property (nonatomic, strong) NSString*                internalHTML;

    @property (nonatomic, strong) NSString*                oldHTML;
    @property (nonatomic, strong) NSString*                oldText;

    /*
     *  NSString holding the css
     */
    @property (nonatomic, strong) NSString*                customCSS;

    /*
     *  BOOL for if the editor is loaded or not
     */
    @property (nonatomic)         BOOL                     editorLoaded;

    /*
     *  BOOL for if the editor is paste or not
     */
    @property (nonatomic)         BOOL                     editorPaste;
    /*
     *  Image Picker for selecting photos from users photo library
     */
    @property (nonatomic, strong) UIImagePickerController* imagePicker;

    // local var to hold first responder state after callback
    @property (nonatomic)         BOOL                     isFirstResponderUpdated;

    @property (nonatomic)         CGRect                   safeFrame;

@end

@implementation ZSSRichTextEditorVC

// Scale image from device
static CGFloat kJPEGCompression = 0.8;
static CGFloat kDefaultScale = 0.5;

#pragma mark - View Did Load Section

- (void) viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.editorLoaded = NO;
    self.receiveEditorDidChangeEvents = NO;
    self.shouldShowKeyboard = YES;
    self.formatHTML = YES;
}

- (void) viewWillAppear: (BOOL) animated {
    [super viewWillAppear: animated];

    // Add observers for keyboard showing or hiding notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillShowOrHide:)
                                                 name: UIKeyboardWillChangeFrameNotification
                                               object: nil];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];

    self.safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
    //NSLog(@"safeFrame: %f %f %f %f", safeFrame.origin.x, safeFrame.origin.y, safeFrame.size.width, safeFrame.size.height);

    [self createEditorView];
    [self createSourceView];
    [self createToolbarView];

    [self loadResources];

    // Image Picker used to allow the user insert images from the device (base64 encoded)
    [self setUpImagePicker];
}

- (void) viewWillDisappear: (BOOL) animated {
    [super viewWillDisappear: animated];

    // Remove observers for keyboard showing or hiding notifications
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIKeyboardWillChangeFrameNotification
                                                  object: nil];
}

#if DEBUG
+ (BOOL) isOrientationWide {

    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];

    BOOL isWide = (IS_IPAD || orientation == UIDeviceOrientationLandscapeLeft
                           || orientation == UIDeviceOrientationLandscapeRight);
    return isWide;
}
#endif

- (void) setSafeFrame {

    self.safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
    //NSLog(@"safeFrame: %f %f %f %f", _safeFrame.origin.x, _safeFrame.origin.y, _safeFrame.size.width, _safeFrame.size.height);

    self.editorView.frame = self.safeFrame;
    self.sourceView.frame = self.safeFrame;
}

- (void) viewWillTransitionToSize: (CGSize) size
        withTransitionCoordinator: (id <UIViewControllerTransitionCoordinator>) coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // Code here will execute before the rotation begins.
    // Equivalent to placing it in the deprecated method -[willRotateToInterfaceOrientation:duration:]

    [coordinator animateAlongsideTransition: ^(id<UIViewControllerTransitionCoordinatorContext> context) {

        // Place code here to perform animations during the rotation.
        // You can pass nil or leave this block empty if not necessary.
        // change any properties on your views

    } completion: ^(id<UIViewControllerTransitionCoordinatorContext> context) {

        // Code here will execute after the rotation has finished.
        // Equivalent to placing it in the deprecated method -[didRotateFromInterfaceOrientation:]

        [self setSafeFrame];

#if DEBUG
        BOOL isLandscape = [ZSSRichTextEditorVC isOrientationWide];
        if (isLandscape) {
            NSLog(@"landscape");
        }
        else {
            NSLog(@"portrait");
        }
#endif
    }];
}

- (void) createEditorView {

    // allocate config and contentController and add scriptMessageHandler
    WKWebViewConfiguration* config = [WKWebViewConfiguration new];

    WKUserContentController* contentController = [WKUserContentController new];
    [contentController addScriptMessageHandler: self
                                          name: @"jsm"];

    config.userContentController = contentController;

    // load scripts
    NSString* scriptString = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";

    WKUserScript* script = [[WKUserScript alloc] initWithSource: scriptString
                                                  injectionTime: WKUserScriptInjectionTimeAtDocumentEnd
                                               forMainFrameOnly: YES];
    [contentController addUserScript: script];

    // set data detection to none so it doesn't conflict
    config.dataDetectorTypes = WKDataDetectorTypeNone;

    self.editorView = [[WKWebView alloc] initWithFrame: _safeFrame
                                         configuration: config];

    // TODO: Is this behavior correct? Is it the right replacement?
    // self.editorView.keyboardDisplayRequiresUserAction = NO;
    [ZSSRichTextEditorVC allowDisplayingKeyboardWithoutUserAction];

    self.editorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight ;
    self.editorView.UIDelegate = self;
    self.editorView.navigationDelegate = self;
    self.editorView.hidesInputAccessoryView = YES;
    self.editorView.scrollView.bounces = YES;

    // backgroundColor works
    // backgroundColor will be the view's backgroundColor
    self.editorView.opaque = false;
    self.editorView.backgroundColor = [UIColor clearColor];
    
    [self.view addSubview: self.editorView];
}

- (void) createSourceView {

    self.sourceView = [[ZSSTextView alloc] initWithFrame: _safeFrame];

    self.sourceView.hidden = YES;
    self.sourceView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.sourceView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.sourceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.sourceView.autoresizesSubviews = YES;
    self.sourceView.adjustsFontForContentSizeCategory = YES;
    self.sourceView.delegate = self;

    //self.sourceView.font = [UIFont fontWithName:@"Courier" size:13.0];
    self.sourceView.font = [UIFont preferredFontForTextStyle: UIFontTextStyleSubheadline];

    //self.sourceView.textColor = [UIColor redColor]; // doesn't work
    self.sourceView.textColor = [UIColor labelColor];

    // UITextView dark mode is not supported by Apple as of 2019-12-31
    self.sourceView.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.sourceView.opaque = false;
    //self.sourceView.backgroundColor = [UIColor clearColor];
    self.sourceView.backgroundColor = [UIColor whiteColor];

    [self.view addSubview: self.sourceView];
}

- (void) createToolbarScrollView {
    
    CGFloat frameWidth = _safeFrame.size.width;

    // scrolling view
    CGFloat scrollWidth = IS_IPAD ? frameWidth : frameWidth - 2*44;
    self.toolbarScrollView = [[UIScrollView alloc] initWithFrame: CGRectMake(0,
                                                                             0,
                                                                             scrollWidth,
                                                                             44)];
    self.toolbarScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.toolbarScrollView.showsHorizontalScrollIndicator = NO;

    // toolbarScrollView's backgroundColor will be the view's backgroundColor

    self.toolbar = [UIToolbar new];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // toolbar's backgroundColor will be the toolbarScrollView's backgroundColor

    NSMutableArray* items = [NSMutableArray array];

    UIBarButtonItem* negativeSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFixedSpace target: nil action: nil];
    negativeSpace.width = -14;
    [items addObject: negativeSpace];
    for (int type = ZSSBarButtonItemTypeBold;
             type <= ZSSBarButtonItemTypeQuickLink;
             type++) {

        ZSSBarButtonItem* item = [ZSSBarButtonItem barButtonItemForItemType: type
                                                                     target: self
                                                                     action: @selector(barButtonItemAction:)];
        [items addObject: item];
    }
    self.toolbar.items = items;
    [items addObject: negativeSpace];

    CGFloat toolbarWidth = (CGFloat)((items.count-1) * 37.2);
    self.toolbar.frame = CGRectMake(0,
                                    0,
                                    toolbarWidth,
                                    44);
    [self.toolbar sizeToFit];

    [self.toolbarScrollView addSubview: self.toolbar];

    // make it scroll
    self.toolbarScrollView.contentSize = CGSizeMake(toolbarWidth,
                                                    44);
}

- (void) createViewSourceKeyboardView {

    CGFloat frameWidth = _safeFrame.size.width;

    UIView* toolbarCropper = [[UIView alloc] initWithFrame: CGRectMake(frameWidth - 2*44,
                                                                       0,
                                                                       2*44,
                                                                       44)];
    toolbarCropper.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    toolbarCropper.clipsToBounds = YES;

    self.toolbar2 = [UIToolbar new];
    self.toolbar2.frame = CGRectMake(0,
                                     0,
                                     2*44 + 14,
                                     44);
    self.toolbar2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    // toolbar2's backgroundColor will be the view's backgroundColor

    NSMutableArray* items = [NSMutableArray array];

    UIBarButtonItem* negativeSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFixedSpace target: nil action: nil];
    negativeSpace.width = -14;
    [items addObject: negativeSpace];

    // show source button
    ZSSBarButtonItem* btn3 = [ZSSBarButtonItem barButtonItemForItemType: ZSSBarButtonItemTypeShowSource
                                                                 target: self
                                                                 action: @selector(showHTMLSource:)];
    [items addObject: btn3];

    // keyboard button
    ZSSBarButtonItem* btn4 = [ZSSBarButtonItem barButtonItemForItemType: ZSSBarButtonItemTypeKeyboard
                                                                 target: self
                                                                 action: @selector(dismissKeyboard)];
    [items addObject: btn4];

    self.toolbar2.items = items;
    [toolbarCropper addSubview: self.toolbar2];

    UIView* line2 = [[UIView alloc] initWithFrame: CGRectMake(0,
                                                              0,
                                                              0.6f,
                                                              44)];
    line2.backgroundColor = [UIColor lightGrayColor];
    line2.alpha = 0.7f;
    [toolbarCropper addSubview: line2];

    [self.toolbarView addSubview: toolbarCropper];
}

- (void) createToolbarView {

    [self createToolbarScrollView];

    CGFloat x = _safeFrame.origin.x;
    CGFloat y = _safeFrame.size.height - 44;
    CGFloat w = _safeFrame.size.width - x;

    // toolbarView
    self.toolbarView = [[UIView alloc] initWithFrame: CGRectMake(x,
                                                                 y,
                                                                 w,
                                                                 44)];
    self.toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [self.toolbarView addSubview: self.toolbarScrollView];

    if (IS_IPAD)
        return;

    [self createViewSourceKeyboardView];

    [self updateHighlightForBarButtonItems];

    self.toolbarView.alpha = 0.0;
    [self.view addSubview: self.toolbarView];
}

- (void) setToolbarItemTintColor: (UIColor*) color {

    _toolbarItemTintColor = color;

    for (ZSSBarButtonItem* item in self.toolbar.items) {
        item.tintColor = color;
    }
    for (ZSSBarButtonItem* item in self.toolbar2.items) {
        item.tintColor = color;
    }
}

- (void) setToolbarItemSelectedTintColor: (UIColor*) color {
    
    _toolbarItemSelectedTintColor = color;
}

- (void) setUpImagePicker {
    
    self.imagePicker = [UIImagePickerController new];

    self.imagePicker.delegate = self;
    self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    self.imagePicker.allowsEditing = YES;
    self.selectedImageScale = kDefaultScale; // by default scale to half the size
}

#pragma mark - Convenience replacement for keyboardDisplayRequiresUserAction in WKWebview

+ (void) allowDisplayingKeyboardWithoutUserAction {

    Class class = NSClassFromString(@"WKContentView");

    NSOperatingSystemVersion iOS_11_3_0 = (NSOperatingSystemVersion){11, 3, 0};
    NSOperatingSystemVersion iOS_12_2_0 = (NSOperatingSystemVersion){12, 2, 0};
    NSOperatingSystemVersion iOS_13_0_0 = (NSOperatingSystemVersion){13, 0, 0};

    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_13_0_0]) {
        SEL selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
        ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
        method_setImplementation(method, override);
    }
   else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_12_2_0]) {
        SEL selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
        ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
        method_setImplementation(method, override);
    }
    else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_11_3_0]) {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
            ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
        method_setImplementation(method, override);
    } else {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, id arg3) {
            ((void (*)(id, SEL, void*, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3);
        });
        method_setImplementation(method, override);
    }
}

#pragma mark - Resources Section

- (void) loadResources {

    if (self.resourcesLoaded)
        return;

    // Define correct bundle for loading resources
    NSBundle* bundle = [NSBundle bundleForClass:[ZSSRichTextEditorVC class]];

    // Create a string with the contents of editor.html
    NSString *filePath = [bundle pathForResource:@"editor" ofType:@"html"];
    NSData *htmlData = [NSData dataWithContentsOfFile:filePath];
    NSString *htmlString = [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];

    // Add jQuery.js to the html file
    NSString *jquery = [bundle pathForResource:@"jQuery" ofType:@"js"];
    NSString *jqueryString = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:jquery] encoding:NSUTF8StringEncoding];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<!-- jQuery -->" withString:jqueryString];

    // Add JSBeautifier.js to the html file
    NSString *beautifier = [bundle pathForResource:@"JSBeautifier" ofType:@"js"];
    NSString *beautifierString = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:beautifier] encoding:NSUTF8StringEncoding];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<!-- jsbeautifier -->" withString:beautifierString];

    // Add ZSSRichTextEditor.js to the html file
    NSString *source = [bundle pathForResource:@"ZSSRichTextEditor" ofType:@"js"];
    NSString *jsString = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:source] encoding:NSUTF8StringEncoding];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<!--editor-->" withString:jsString];

    [self.editorView loadHTMLString: htmlString baseURL: self.baseURL];

    self.resourcesLoaded = YES;
}

#pragma mark - Editor Modification Section

- (void) setCSS: (NSString *)css {
    
    self.customCSS = css;
    
    if (self.editorLoaded) {
        [self updateCSS];
    }
}

- (void) updateCSS {
    
    if (self.customCSS != NULL && [self.customCSS length] != 0) {

        NSString *js = [NSString stringWithFormat: @"zss_editor.setCustomCSS(\"%@\");", self.customCSS];
        [self evaluateJavaScript: js];
    }
}

- (void) setPlaceholderText {
    
    // Call the setPlaceholder javascript method if a placeholder has been set
    if (self.placeholder != NULL && [self.placeholder length] != 0) {
        
        NSString *js = [NSString stringWithFormat: @"zss_editor.setPlaceholder(\"%@\");", self.placeholder];
        [self evaluateJavaScript: js];
    }
}

- (void) setFooterHeight: (float)footerHeight {
    
    // Call the setFooterHeight javascript method
    NSString *js = [NSString stringWithFormat: @"zss_editor.setFooterHeight(\"%f\");", footerHeight];
    [self evaluateJavaScript: js];
}

- (void) setContentHeight: (float)contentHeight {
    
    // Call the contentHeight javascript method
    NSString *js = [NSString stringWithFormat: @"zss_editor.contentHeight = %f;", contentHeight];
    [self evaluateJavaScript: js];
}

#pragma mark - Editor Interaction

- (void) focusTextEditor {
    
    //TODO: Is this behavior correct? Is it the right replacement?
    //self.editorView.keyboardDisplayRequiresUserAction = NO;
    [ZSSRichTextEditorVC allowDisplayingKeyboardWithoutUserAction];

    [self evaluateJavaScript: @"zss_editor.focusEditor();"];
}

- (void) blurTextEditor {

    [self evaluateJavaScript: @"zss_editor.blurEditor();"];
}

- (void) setHTML: (NSString*) html {
    
    self.internalHTML = html;
    
    if (self.editorLoaded)
        [self updateHTML];
}

- (void) updateHTML {

    NSString* html = self.internalHTML;

    self.sourceView.text = html;
    
    NSString* cleanedHTML = [self removeQuotesFromHTML: html];
    NSString* trigger = [NSString stringWithFormat: @"zss_editor.setHTML(\"%@\");", cleanedHTML];
    [self evaluateJavaScript: trigger];
}

- (void) insertHTML: (NSString*) html {

    NSString* cleanedHTML = [self removeQuotesFromHTML: html];
    NSString* trigger = [NSString stringWithFormat: @"zss_editor.insertHTML(\"%@\");", cleanedHTML];
    [self evaluateJavaScript: trigger];
}

- (void) getHTML: (void (^)(id, NSError* error)) completionHandler {

    [self.editorView evaluateJavaScript: @"zss_editor.getHTML();"
                      completionHandler: ^(NSString* result, NSError* error) {

        if (error != NULL) {
            NSLog(@"HTML Parsing Error: %@", error);
        }

        //NSLog(@"result:\n%@", result);
        NSString* html = [self removeQuotesFromHTML: result];
        //NSLog(@"html:\n%@", html);

        [self tidyHTML: html completionHandler: ^(NSString* result, NSError* error) {

            completionHandler(result, error);
        }];
    }];
}

- (void) getText: (void (^)(id, NSError* error)) completionHandler {
    
    [self.editorView evaluateJavaScript: @"zss_editor.getText();"
                      completionHandler: ^(NSString* result, NSError* error) {
        
        if (error != NULL)
            NSLog(@"Text Parsing Error: %@", error);

        completionHandler(result, error);
    }];
}

- (void) updateEditor {

    [self getHTMLAndTextWithCompletionHandler: ^(NSString* html,
                                                 NSString* text) {

        if (![html isEqualToString: self.oldHTML]) {

            self.oldHTML = html;
            self.oldText = text;

            if ([self.delegate respondsToSelector: @selector(richTextEditor:didChangeText:html:)]) {

                // call delegate
                [self.delegate richTextEditor: self
                                didChangeText: text
                                         html: [self processQuotesFromHTML: html]];
            }

            [self checkForMentionOrHashtagInText: text];
        }
    }];
}

- (void) getHTMLAndTextWithCompletionHandler: (void (^)(NSString* html, NSString* text)) completion {

    [self.editorView evaluateJavaScript: @"zss_editor.getHTML();"
                      completionHandler: ^(id object, NSError* error) {

        NSString* html = object;
        html = [self removeQuotesFromHTML: html];

        [self tidyHTML: html completionHandler: ^(NSString* html, NSError* error) {

            [self.editorView evaluateJavaScript: @"zss_editor.getText();"
                              completionHandler: ^(id object, NSError* error) {

                NSString* text = object;
                completion(html, text);
            }];
        }];
    }];
}

- (void) showHTMLSource: (ZSSBarButtonItem*) barButtonItem {

    if (self.sourceView.hidden) {

        [self getHTML: ^(NSString *result, NSError * _Nullable error) {
            self.sourceView.text = result;
        }];

        self.sourceView.hidden = NO;
        barButtonItem.tintColor = [UIColor labelColor];
        self.editorView.hidden = YES;
        [self enableToolbarItems: NO];

    } else {

        [self setHTML: self.sourceView.text];
        barButtonItem.tintColor = [self barButtonItemDefaultColor];
        self.sourceView.hidden = YES;
        self.editorView.hidden = NO;
        [self enableToolbarItems: YES];
    }
}

- (void) dismissKeyboard {

    [self.view endEditing: YES];
}

- (BOOL) isFirstResponder {

    [self.editorView evaluateJavaScript: @"document.activeElement.id=='zss_editor_content'"
                      completionHandler: ^(NSNumber *result, NSError *error) {
        
        // save the result as a bool and then update the UI
        self.isFirstResponderUpdated = [result boolValue];
        if (self.isFirstResponderUpdated == true) {
            [self becomeFirstResponder];
        } else {
            [self resignFirstResponder];
        }
    }];
    
    //this state is old and will quickly be updated after the callback above completes
    //TODO: refactor to find a more elegant approach
    return self.isFirstResponderUpdated;
}

- (void) setHeading: (NSString*) heading {

    NSString* js = [NSString stringWithFormat: @"zss_editor.setHeading('%@');", heading];
    [self evaluateJavaScript: js];
}

- (void) evaluateJavaScript: (NSString*) js {

    [self.editorView evaluateJavaScript: js
                      completionHandler: ^(id _Nullable object, NSError* _Nullable error) {
        if (error != nil) {
            NSLog(@"ZSSRichTextEditor Error: %@", error.localizedDescription);
            NSLog(@"js: %@", js);
        }
    }];
}

- (void) showFontsPicker {

    // save the selection location
    [self evaluateJavaScript: @"zss_editor.prepareInsert();"];

    // Call picker
    ZSSFontsViewController *fontPicker = [ZSSFontsViewController cancelableFontPickerViewControllerWithFontFamily:ZSSFontFamilyDefault];
    fontPicker.delegate = self;
    [self.navigationController pushViewController:fontPicker animated:YES];
}

- (void) setSelectedFontFamily:(ZSSFontFamily)fontFamily {
    
    NSString *fontFamilyString;
    
    switch (fontFamily) {

        case ZSSFontFamilyDefault:
            fontFamilyString = @"Arial, Helvetica, sans-serif";
            break;
            
        case ZSSFontFamilyGeorgia:
            fontFamilyString = @"Georgia, serif";
            break;
            
        case ZSSFontFamilyPalatino:
            fontFamilyString = @"Palatino Linotype, Book Antiqua, Palatino, serif";
            break;
            
        case ZSSFontFamilyTimesNew:
            fontFamilyString = @"Times New Roman, Times, serif";
            break;
            
        case ZSSFontFamilyTrebuchet:
            fontFamilyString = @"Trebuchet MS, Helvetica, sans-serif";
            break;
            
        case ZSSFontFamilyVerdana:
            fontFamilyString = @"Verdana, Geneva, sans-serif";
            break;
            
        case ZSSFontFamilyCourierNew:
            fontFamilyString = @"Courier New, Courier, monospace";
            break;
            
        default:
            fontFamilyString = @"Arial, Helvetica, sans-serif";
            break;
    }
    
    NSString *trigger = [NSString stringWithFormat: @"zss_editor.setFontFamily(\"%@\");", fontFamilyString];
    [self evaluateJavaScript: trigger];
}

- (void) colorWithTag: (int) tag
             andTitle: (NSString*) title {

    // save the selection location
    [self evaluateJavaScript: @"zss_editor.prepareInsert();"];

    // call the picker
    HRColorPickerViewController* colorPicker = [HRColorPickerViewController cancelableFullColorPickerViewControllerWithColor: [UIColor whiteColor]];
    colorPicker.delegate = self;
    colorPicker.tag = tag;
    colorPicker.title = title;
    [self.navigationController pushViewController: colorPicker
                                         animated: YES];
}

- (void) setSelectedColor: (UIColor*) color
                      tag: (int) tag {

    NSString *hex = [NSString stringWithFormat: @"#%06x", HexColorFromUIColor(color)];
    NSString *trigger;
    if (tag == 1) {
        trigger = [NSString stringWithFormat: @"zss_editor.setTextColor(\"%@\");", hex];
    } else { //if (tag == 2) {
        trigger = [NSString stringWithFormat: @"zss_editor.setBackgroundColor(\"%@\");", hex];
    }
    [self evaluateJavaScript: trigger];
}

- (void) undo: (ZSSBarButtonItem *)barButtonItem {

    [self evaluateJavaScript: @"zss_editor.undo();"];
}

- (void) redo: (ZSSBarButtonItem *)barButtonItem {

    [self evaluateJavaScript: @"zss_editor.redo();"];
}

- (void) removeLink {

    [self evaluateJavaScript: @"zss_editor.unlink();"];
    
    if (_receiveEditorDidChangeEvents)
        [self updateEditor];
}

- (void) quickLink {

    [self evaluateJavaScript: @"zss_editor.quickLink();"];
    
    if (_receiveEditorDidChangeEvents)
        [self updateEditor];
}

- (void) showInsertLinkDialogWithLink: (NSString*) url
                                title: (NSString*) title {

    NSString* insertButtonTitle = !self.selectedLinkURL ? NSLocalizedString(@"Insert", nil) : NSLocalizedString(@"Update", nil);

    UIAlertController* alertController = [UIAlertController alertControllerWithTitle: NSLocalizedString(@"Insert Link", nil)
                                                                             message: nil
                                                                      preferredStyle: UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {

        textField.placeholder = NSLocalizedString(@"URL (required)", nil);
        if (url)
            textField.text = url;
        textField.clearButtonMode = UITextFieldViewModeAlways;
    }];

    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {

        textField.placeholder = NSLocalizedString(@"Title", nil);
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.secureTextEntry = NO;
        if (title)
            textField.text = title;
    }];

    [alertController addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"Cancel", nil)
                                                         style: UIAlertActionStyleCancel
                                                       handler: ^(UIAlertAction* action) {
    }]];

    [alertController addAction: [UIAlertAction actionWithTitle: insertButtonTitle
                                                         style: UIAlertActionStyleDefault
                                                       handler: ^(UIAlertAction* action) {

        UITextField* linkURL = [alertController.textFields objectAtIndex:0];
        UITextField* title = [alertController.textFields objectAtIndex:1];

        if (!self.selectedLinkURL) {
            [self insertLink: linkURL.text
                       title: title.text];
            //NSLog(@"insert link");
        } else {
            [self updateLink: linkURL.text
                       title: title.text];
        }
    }]];

    [self presentViewController: alertController
                       animated: YES
                     completion: NULL];
}

- (void) insertLink: (NSString*) url
              title: (NSString*) title {

    NSString* js = [NSString stringWithFormat: @"zss_editor.insertLink(\"%@\", \"%@\");", url, title];
    [self evaluateJavaScript: js];
}

- (void) updateLink: (NSString*) url
              title: (NSString*) title {

    NSString* js = [NSString stringWithFormat: @"zss_editor.updateLink(\"%@\", \"%@\");", url, title];
    [self evaluateJavaScript: js];
}

- (void) insertImage {

    // save the selection location
    [self evaluateJavaScript: @"zss_editor.prepareInsert();"];

    [self showInsertImageDialogWithLink: self.selectedImageURL
                                    alt: self.selectedImageAlt];
}

- (void) insertImageFromDevice {

    // save the selection location
    [self evaluateJavaScript: @"zss_editor.prepareInsert();"];

    [self showInsertImageDialogFromDeviceWithScale: self.selectedImageScale
                                               alt: self.selectedImageAlt];
}

- (void) insertLink {

    // save the selection location
    [self evaluateJavaScript: @"zss_editor.prepareInsert();"];

    // show the dialog for inserting or editing a link
    [self showInsertLinkDialogWithLink: self.selectedLinkURL
                                 title: self.selectedLinkTitle];
}

- (void) showInsertImageDialogWithLink: (NSString*) url
                                   alt: (NSString*) alt {

    NSString* insertButtonTitle = !self.selectedImageURL ? NSLocalizedString(@"Insert", nil) :
    NSLocalizedString(@"Update", nil);

    UIAlertController* alertController = [UIAlertController alertControllerWithTitle: NSLocalizedString(@"Insert Image", nil)
                                                                             message: nil
                                                                      preferredStyle: UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {

        textField.placeholder = NSLocalizedString(@"URL (required)", nil);
        if (url)
            textField.text = url;
        textField.clearButtonMode = UITextFieldViewModeAlways;
    }];

    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {

        textField.placeholder = NSLocalizedString(@"Alt", nil);
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.secureTextEntry = NO;
        if (alt)
            textField.text = alt;
    }];

    [alertController addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"Cancel", nil)
                                                         style: UIAlertActionStyleCancel
                                                       handler: ^(UIAlertAction* action) {
        [self focusTextEditor];
    }]];

    [alertController addAction: [UIAlertAction actionWithTitle: insertButtonTitle
                                                         style: UIAlertActionStyleDefault
                                                       handler: ^(UIAlertAction* action) {

        UITextField* imageURL = [alertController.textFields objectAtIndex:0];
        UITextField* alt = [alertController.textFields objectAtIndex:1];

        if (!self.selectedImageURL) {
           [self insertImage: imageURL.text
                         alt: alt.text];
        } else {
           [self updateImage: imageURL.text
                         alt: alt.text];
        }
        [self focusTextEditor];
    }]];

    [self presentViewController: alertController
                       animated: YES
                     completion: NULL];
}

- (void) showInsertImageDialogFromDeviceWithScale: (CGFloat) scale
                                              alt: (NSString*) alt {
    // insert button title
    NSString* insertButtonTitle = !self.selectedImageURL ? NSLocalizedString(@"Pick Image", nil) :
    NSLocalizedString(@"Pick New Image", nil);

    UIAlertController* alertController = [UIAlertController alertControllerWithTitle: NSLocalizedString(@"Embed Image from Device", nil)
                                                                             message: nil
                                                                      preferredStyle: UIAlertControllerStyleAlert];
    // add alt text field
    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {
        
        textField.placeholder = NSLocalizedString(@"Alt", nil);
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.secureTextEntry = NO;
        if (alt)
            textField.text = alt;
    }];

    // add scale text field
    [alertController addTextFieldWithConfigurationHandler: ^(UITextField* textField) {

        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.secureTextEntry = NO;
        textField.placeholder = NSLocalizedString(@"Image scale (default is 0.5)", nil);
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    // cancel action
    [alertController addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"Cancel", nil)
                                                         style: UIAlertActionStyleCancel
                                                       handler: ^(UIAlertAction* action) {
        [self focusTextEditor];
    }]];

    // insert action
    [alertController addAction: [UIAlertAction actionWithTitle: insertButtonTitle
                                                         style: UIAlertActionStyleDefault
                                                       handler: ^(UIAlertAction* action) {

        UITextField* textFieldAlt = [alertController.textFields objectAtIndex: 0];
        UITextField* textFieldScale = [alertController.textFields objectAtIndex: 1];

        self.selectedImageScale = [textFieldScale.text floatValue]? : kDefaultScale;
        self.selectedImageAlt = textFieldAlt.text? : @"";

        [self presentViewController: self.imagePicker
                           animated: YES
                         completion: nil];
    }]];

    [self presentViewController: alertController
                       animated: YES
                     completion: NULL];
}

- (void) insertImage: (NSString*) url
                 alt: (NSString*) alt {
    
    NSString* js = [NSString stringWithFormat: @"zss_editor.insertImage(\"%@\", \"%@\");", url, alt];
    [self evaluateJavaScript: js];
}

- (void) updateImage: (NSString*) url
                 alt: (NSString*) alt {
    
    NSString* js = [NSString stringWithFormat: @"zss_editor.updateImage(\"%@\", \"%@\");", url, alt];
    [self evaluateJavaScript: js];
}

- (void) insertImageBase64String: (NSString*) imageBase64String
                             alt: (NSString*) alt {
    
    NSString* js = [NSString stringWithFormat: @"zss_editor.insertImageBase64String(\"%@\", \"%@\");", imageBase64String, alt];
    [self evaluateJavaScript: js];
}

- (void) updateImageBase64String: (NSString*) imageBase64String
                             alt: (NSString*) alt {

    NSString* js = [NSString stringWithFormat: @"zss_editor.updateImageBase64String(\"%@\", \"%@\");", imageBase64String, alt];
    [self evaluateJavaScript: js];
}

- (void) updateToolBarWithButtonName: (NSString *) name {

    // Items that are enabled
    NSArray *itemNames = [name componentsSeparatedByString:@","];
    
    // Special case for link
    NSMutableArray *itemsModified = [[NSMutableArray alloc] init];
    for (NSString *linkItem in itemNames) {
        NSString *updatedItem = linkItem;
        if ([linkItem hasPrefix:@"link:"]) {
            updatedItem = @"link";
            self.selectedLinkURL = [linkItem stringByReplacingOccurrencesOfString:@"link:" withString:@""];
        } else if ([linkItem hasPrefix:@"link-title:"]) {
            self.selectedLinkTitle = [self stringByDecodingURLFormat:[linkItem stringByReplacingOccurrencesOfString:@"link-title:" withString:@""]];
        } else if ([linkItem hasPrefix:@"image:"]) {
            updatedItem = @"image";
            self.selectedImageURL = [linkItem stringByReplacingOccurrencesOfString:@"image:" withString:@""];
        } else if ([linkItem hasPrefix:@"image-alt:"]) {
            self.selectedImageAlt = [self stringByDecodingURLFormat:[linkItem stringByReplacingOccurrencesOfString:@"image-alt:" withString:@""]];
        } else {
            self.selectedImageURL = nil;
            self.selectedImageAlt = nil;
            self.selectedLinkURL = nil;
            self.selectedLinkTitle = nil;
        }
        [itemsModified addObject:updatedItem];
    }

    self.highlightedBarButtonLabels = [itemsModified copy];
    [self updateHighlightForBarButtonItems];
}

#pragma mark - UITextView Delegate

- (void) textViewDidChange: (UITextView*) textView {

    CGRect line = [textView caretRectForPosition: textView.selectedTextRange.start];
    CGFloat overflow = line.origin.y + line.size.height - ( textView.contentOffset.y + textView.bounds.size.height - textView.contentInset.bottom - textView.contentInset.top );

    if (overflow > 0) {

        // We are at the bottom of the visible text and introduced a line feed, scroll down (iOS 7 does not do it)
        // Scroll caret to visible area
        CGPoint offset = textView.contentOffset;
        offset.y += overflow + 7; // leave 7 pixels margin

        // Cannot animate with setContentOffset:animated: or caret will not appear
        [UIView animateWithDuration: .2
                         animations: ^{

            [textView setContentOffset: offset];
        }];
    }
}

#pragma mark - WKScriptMessageHandler Delegate

- (void) userContentController: (WKUserContentController*) userContentController
       didReceiveScriptMessage: (WKScriptMessage*) message {

    NSString *messageString = (NSString *)message.body;
    NSLog(@"Message received: %@", messageString);

    /*
     Callback for when text is changed, written by @madebydouglas derived from richardortiz84 https://github.com/nnhubbard/ZSSRichTextEditor/issues/5
     */

    if ([messageString isEqualToString: @"paste"]) {
        self.editorPaste = YES;
    }

    if ([messageString isEqualToString: @"input"]) {

        if (_receiveEditorDidChangeEvents)
            [self updateEditor];

        [self getText: ^(NSString * result, NSError * _Nullable error) {
            [self checkForMentionOrHashtagInText: result];
        }];

        if (self.editorPaste) {
            [self blurTextEditor];
            self.editorPaste = NO;
        }
    }
}

#pragma mark - WKNavigationDelegate Delegate

- (void) webView: (WKWebView*) webView decidePolicyForNavigationAction: (WKNavigationAction*) navigationAction decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler {

    NSString *query = [navigationAction.request.URL query];
    NSString *urlString = [navigationAction.request.URL absoluteString];

    NSLog(@"web request");
    NSLog(@"%@", urlString);
    NSLog(@"%@", query);

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {

        BOOL shouldInteract = NO;
        if ([self.delegate respondsToSelector: @selector(richTextEditor:shouldInteractWithURL:)]) {

            // call delegate
            shouldInteract = [self.delegate richTextEditor: self
                                     shouldInteractWithURL: navigationAction.request.URL];
        }
        if (shouldInteract) {
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            decisionHandler(WKNavigationActionPolicyAllow);
        }
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {

        //On the old UIWebView delegate it returned false Bool here
        //TODO: what should we do now?

    } else if ([urlString rangeOfString:@"callback://0/"].location != NSNotFound) {

        // We received the callback
        NSString *className = [urlString stringByReplacingOccurrencesOfString:@"callback://0/" withString:@""];
        [self updateToolBarWithButtonName:className];

    } else if ([urlString rangeOfString:@"debug://"].location != NSNotFound) {

        NSLog(@"Debug Found");

        // We received the callback
        NSString *debug = [urlString stringByReplacingOccurrencesOfString:@"debug://" withString:@""];
        debug = [debug stringByRemovingPercentEncoding];
        NSLog(@"%@", debug);

    } else if ([urlString rangeOfString:@"scroll://"].location != NSNotFound) {

        if ([self.delegate respondsToSelector: @selector(richTextEditor:didScrollToPosition:)]) {

            NSInteger position = [[urlString stringByReplacingOccurrencesOfString:@"scroll://" withString:@""] integerValue];

            // call delegate
            [self.delegate richTextEditor: self
                      didScrollToPosition: position];
        }
    }
}

- (void) webView: (WKWebView*) webView didFinishNavigation: (WKNavigation*) navigation {

    self.editorLoaded = YES;

    if (!self.internalHTML)
        self.internalHTML = @"";

    [self updateHTML];

    if (self.placeholder)
        [self setPlaceholderText];

    if (self.customCSS)
        [self updateCSS];

    if (self.shouldShowKeyboard) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self focusTextEditor];
        });
    }

    /*
     Create listeners for when text is changed, solution by @madebydouglas derived from richardortiz84 https://github.com/nnhubbard/ZSSRichTextEditor/issues/5
     */

    NSString *inputListener = @"document.getElementById('zss_editor_content').addEventListener('input', function() {window.webkit.messageHandlers.jsm.postMessage('input');});";
    NSString *pasteListener = @"document.getElementById('zss_editor_content').addEventListener('paste', function() {window.webkit.messageHandlers.jsm.postMessage('paste');});";

    [self evaluateJavaScript: inputListener];
    [self evaluateJavaScript: pasteListener];

    // call delegate
    if ([self.delegate respondsToSelector: @selector(richTextEditorDidFinishLoad:)]) {
        [self.delegate richTextEditorDidFinishLoad: self];
    }
}

#pragma mark - Mention & Hashtag Support Section

- (void) checkForMentionOrHashtagInText: (NSString *)text {
    
    if ([text containsString:@" "] && [text length] > 0) {

        NSString *lastWord = nil;
        NSString *matchedWord = nil;
        BOOL containsHashtag = NO;
        BOOL containsMention = NO;

        NSRange range = [text rangeOfString:@" " options:NSBackwardsSearch];
        lastWord = [text substringFromIndex:range.location];
        
        if (lastWord != nil) {
            
            //Check if last word typed starts with a #
            NSRegularExpression *hashtagRegex = [NSRegularExpression regularExpressionWithPattern:@"#(\\w+)" options:0 error:nil];
            NSArray *hashtagMatches = [hashtagRegex matchesInString:lastWord options:0 range:NSMakeRange(0, lastWord.length)];
            
            for (NSTextCheckingResult *match in hashtagMatches) {
                
                NSRange wordRange = [match rangeAtIndex:1];
                NSString *word = [lastWord substringWithRange:wordRange];
                matchedWord = word;
                containsHashtag = YES;
            }
            
            if (!containsHashtag) {
                
                //Check if last word typed starts with a @
                NSRegularExpression *mentionRegex = [NSRegularExpression regularExpressionWithPattern:@"@(\\w+)" options:0 error:nil];
                NSArray *mentionMatches = [mentionRegex matchesInString:lastWord options:0 range:NSMakeRange(0, lastWord.length)];
                
                for (NSTextCheckingResult *match in mentionMatches) {
                    
                    NSRange wordRange = [match rangeAtIndex:1];
                    NSString *word = [lastWord substringWithRange:wordRange];
                    matchedWord = word;
                    containsMention = YES;
                }
            }
        }

        if (containsHashtag &&
            [self.delegate respondsToSelector: @selector(richTextEditor:didRecognizeHashtag:)]) {

            // call delegate
            [self.delegate richTextEditor: self
                      didRecognizeHashtag: matchedWord];
        }

        if (containsMention &&
            [self.delegate respondsToSelector: @selector(richTextEditor:didRecognizeMention:)]) {

            // call delegate
            [self.delegate richTextEditor: self
                      didRecognizeMention: matchedWord];
        }
    }
}

#pragma mark - Callbacks

// Blank implementation
- (void) editorDidScrollWithPosition:(NSInteger)position {}

#pragma mark - Image Picker Delegate

- (void) imagePickerControllerDidCancel: (UIImagePickerController *)picker{

    // Dismiss the Image Picker
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void) imagePickerController: (UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info{
    
    UIImage *selectedImage = info[UIImagePickerControllerEditedImage]?:info[UIImagePickerControllerOriginalImage];
    
    //Scale the image
    CGSize targetSize = CGSizeMake(selectedImage.size.width * self.selectedImageScale, selectedImage.size.height * self.selectedImageScale);
    UIGraphicsBeginImageContext(targetSize);
    [selectedImage drawInRect:CGRectMake(0,0,targetSize.width,targetSize.height)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //Compress the image, as it is going to be encoded rather than linked
    NSData *scaledImageData = UIImageJPEGRepresentation(scaledImage, kJPEGCompression);
    
    //Encode the image data as a base64 string
    NSString *imageBase64String = [scaledImageData base64EncodedStringWithOptions:0];
    
    //Decide if we have to insert or update
    if (!self.imageBase64String) {
        [self insertImageBase64String:imageBase64String alt:self.selectedImageAlt];
    } else {
        [self updateImageBase64String:imageBase64String alt:self.selectedImageAlt];
    }
    
    self.imageBase64String = imageBase64String;
    
    // Dismiss the Image Picker
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void) barButtonItemAction: (ZSSBarButtonItem*) sender {

    NSString* trigger;

    switch (sender.itemType) {

        case ZSSBarButtonItemTypeBold:
            trigger = @"zss_editor.setBold();";
            break;

        case ZSSBarButtonItemTypeItalic:
            trigger = @"zss_editor.setItalic();";
            break;

        case ZSSBarButtonItemTypeSubscript:
            trigger = @"zss_editor.setSubscript();";
            break;

        case ZSSBarButtonItemTypeSuperscript:
            trigger = @"zss_editor.setSuperscript();";
            break;

        case ZSSBarButtonItemTypeStrikeThrough:
            trigger = @"zss_editor.setStrikeThrough();";
            break;

        case ZSSBarButtonItemTypeUnderline:
            trigger = @"zss_editor.setUnderline();";
            break;

        case ZSSBarButtonItemTypeRemoveFormat:
            trigger = @"zss_editor.removeFormating();";
            break;

        case ZSSBarButtonItemTypeFonts:
            [self showFontsPicker];
            return;

        case ZSSBarButtonItemTypeUndo:
            trigger = @"zss_editor.undo();";
            break;

        case ZSSBarButtonItemTypeRedo:
            trigger = @"zss_editor.redo();";
            break;

        case ZSSBarButtonItemTypeJustifyLeft:
            trigger = @"zss_editor.setJustifyLeft();";
            break;

        case ZSSBarButtonItemTypeJustifyCenter:
            trigger = @"zss_editor.setJustifyCenter();";
            break;

        case ZSSBarButtonItemTypeJustifyRight:
            trigger = @"zss_editor.setJustifyRight();";
            break;

        case ZSSBarButtonItemTypeJustifyFull:
            trigger = @"zss_editor.setJustifyFull();";
            break;

        case ZSSBarButtonItemTypeH1:
        case ZSSBarButtonItemTypeH2:
        case ZSSBarButtonItemTypeH3:
        case ZSSBarButtonItemTypeH4:
        case ZSSBarButtonItemTypeH5:
        case ZSSBarButtonItemTypeH6:

            [self setHeading: sender.label];
            return;

        case ZSSBarButtonItemTypeParagraph:
            trigger = @"zss_editor.setParagraph();";
            break;

        case ZSSBarButtonItemTypeTextColor:
            [self colorWithTag: 1
                      andTitle: NSLocalizedString(@"Text Color", nil)];
            return;
            
        case ZSSBarButtonItemTypeBgColor:
            [self colorWithTag: 2
                      andTitle: NSLocalizedString(@"Background Color", nil)];
            return;
            
        case ZSSBarButtonItemTypeUnorderedList:
            trigger = @"zss_editor.setUnorderedList();";
            break;
        
        case ZSSBarButtonItemTypeOrderedList:
            trigger = @"zss_editor.setOrderedList();";
            break;
        
        case ZSSBarButtonItemTypeHorizontalRule:
            trigger = @"zss_editor.setHorizontalRule();";
            break;
        
        case ZSSBarButtonItemTypeIndent:
            trigger = @"zss_editor.setIndent();";
            break;

        case ZSSBarButtonItemTypeOutdent:
            trigger = @"zss_editor.setOutdent();";
            break;

        case ZSSBarButtonItemTypeImage:

            [self insertImage];
            return;

        case ZSSBarButtonItemTypeImageFromDevice:

            [self insertImageFromDevice];
            return;

        case ZSSBarButtonItemTypeInsertLink: {

            [self insertLink];
            return;
        }

        case ZSSBarButtonItemTypeRemoveLink:
            trigger = @"zss_editor.unlink();";
            break;

        case ZSSBarButtonItemTypeQuickLink:
            trigger = @"zss_editor.quickLink();";
            break;

        case ZSSBarButtonItemTypeShowSource:
            [self showHTMLSource: sender];
            return;

        case ZSSBarButtonItemTypeKeyboard:
            [self dismissKeyboard];
            return;

        default:
            return;
    }
    [self evaluateJavaScript: trigger];
}

#pragma mark - Keyboard

- (UIWindow*) textEffectsWindow {
    __block UIWindow* keyboardWindow = nil;
    [UIApplication.sharedApplication.windows enumerateObjectsUsingBlock: ^(__kindof UIWindow* _Nonnull obj,
                                                                           NSUInteger idx,
                                                                           BOOL * _Nonnull stop) {
        if ([obj.class isEqual: NSClassFromString(@"UITextEffectsWindow").class]) {
            keyboardWindow = obj;
            *stop = YES;
        }
    }];
    return keyboardWindow;
}

- (void) hideTextEffectsWindow {

    self.textEffectsWindow.layer.opacity = 0;
}

- (void) keyboardWillShowOrHide: (NSNotification*) notification {

    // User Info
    NSDictionary* userInfo = notification.userInfo;
    CGFloat duration = [[userInfo objectForKey: UIKeyboardAnimationDurationUserInfoKey] floatValue];
    int curve = [[userInfo objectForKey: UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect keyboardRect = [[userInfo objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];

    // Correct Curve
    UIViewAnimationOptions animationOptions = curve << 16;

    [UIView animateWithDuration: duration
                          delay: 0
                        options: animationOptions
                     animations: ^{

        CGRect newFrame = self.safeFrame;
        NSLog(@"safeFrame: %f %f %f %f", newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height);

        CGFloat screeenHeight = self.safeFrame.size.height;
        CGFloat ch = screeenHeight;

        if (keyboardRect.origin.y < screeenHeight) {

            // show keyboard
            if (self.sourceView.hidden)
                [self hideTextEffectsWindow];

            self.toolbarView.alpha = 1.0;

            CGRect kbRect = [self.toolbarView.superview convertRect: keyboardRect
                                                           fromView: nil];
            CGRect toolbarFrame = self.toolbarView.frame;

            toolbarFrame.size.width = newFrame.size.width;
            toolbarFrame.origin.x = newFrame.origin.x;

            toolbarFrame.origin.y = kbRect.origin.y;
            if (!self.sourceView.hidden)
                toolbarFrame.origin.y -= toolbarFrame.size.height;

            self.toolbarView.frame = toolbarFrame;

            newFrame.size.height = toolbarFrame.origin.y;

            ch = newFrame.size.height;

        } else {

            // hide keyboard
            self.toolbarView.alpha = 0.0;
        }

        // Provide editor with keyboard height and editor view height
        [self setContentHeight: ch];

        self.editorView.scrollView.contentInset = UIEdgeInsetsZero;
        self.editorView.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;

        self.editorView.frame = newFrame;
        self.sourceView.frame = newFrame;

    } completion: nil];
}

#pragma mark - Utilities

- (NSString*) processQuotesFromHTML: (NSString*) html {

    //NSLog(@"%s", __FUNCTION__);
    //NSLog(@"html before: %@", html);

    html = [html stringByReplacingOccurrencesOfString: @"\\\"" withString: @"\""];

    //NSLog(@"html after: %@", html);
    return html;
}

- (NSString*) removeQuotesFromHTML: (NSString*) html {

    html = [html stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    html = [html stringByReplacingOccurrencesOfString:@"“" withString:@"&quot;"];
    html = [html stringByReplacingOccurrencesOfString:@"”" withString:@"&quot;"];
    html = [html stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    html = [html stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

    return html;
}

- (void) tidyHTML: (NSString*) html completionHandler: (void (^ _Nullable)(_Nullable id, NSError * _Nullable error)) completionHandler {

    html = [html stringByReplacingOccurrencesOfString:@"<br>" withString:@"<br />"];
    html = [html stringByReplacingOccurrencesOfString:@"<hr>" withString:@"<hr />"];

    if (self.formatHTML) {
                
        html = [NSString stringWithFormat:@"style_html(\"%@\");", html];
        [self.editorView evaluateJavaScript: html
                          completionHandler: ^(NSString *result, NSError *error) {
            
            if (error != NULL) {
                NSLog(@"HTML Tidying Error: %@", error);
            }
            
            NSLog(@"%@", result);
            
            completionHandler(result, error);
        }];
        
    } else {
        completionHandler(html, NULL);
    }
}

- (NSString*) stringByDecodingURLFormat: (NSString*) string {

    NSString* result = [string stringByReplacingOccurrencesOfString: @"+"
                                                         withString: @" "];
    result = [result stringByAddingPercentEncodingForRFC3986];

    return result;
}

#pragma mark - utilities

- (UIColor*) barButtonItemDefaultColor {

    if (self.toolbarItemTintColor)
        return self.toolbarItemTintColor;

    return [UIColor colorNamed: @"tintColor"];
}

- (UIColor*) barButtonItemSelectedDefaultColor {

    if (self.toolbarItemSelectedTintColor)
        return self.toolbarItemSelectedTintColor;

    return [UIColor labelColor];
}

- (void) updateHighlightForBarButtonItems {

    NSArray* items = self.toolbar.items;
    for (ZSSBarButtonItem* item in items) {

        if ([item respondsToSelector: @selector(label)]) {
            if ([self.highlightedBarButtonLabels containsObject: item.label]) {
                item.tintColor = [self barButtonItemSelectedDefaultColor];
            } else {
                item.tintColor = [self barButtonItemDefaultColor];
            }
        }
    }

    NSArray* items2 = self.toolbar2.items;
    for (ZSSBarButtonItem* item in items2) {
        item.tintColor = [self barButtonItemDefaultColor];
    }
}

- (void) enableToolbarItems: (BOOL) enable {

    NSArray* items = self.toolbar.items;
    for (ZSSBarButtonItem* item in items) {
        item.enabled = enable;
    }
}

#pragma mark - Memory Warning Section
- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
