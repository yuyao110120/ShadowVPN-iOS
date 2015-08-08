//
//  KDLoggerViewController.m
//  Moving
//
//  Created by Blankwonder on 8/12/14.
//  Copyright (c) 2014 Sensoro. All rights reserved.
//

#import "LoggerViewController.h"
#import "KDAlertView.h"
#import "KDUtilities.h"
#import "Constant.h"
#import <MobileCoreServices/UTCoreTypes.h>

@interface LoggerViewController () {
    UITextView *_textView;

    NSFileHandle *_logFileHandler;
}

@end

@implementation LoggerViewController

- (void)loadView {
    _textView = [[UITextView alloc] init];
    _textView.editable = NO;
    
    self.view = _textView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *groupContainerPath = [[NSFileManager defaultManager]
                                    containerURLForSecurityApplicationGroupIdentifier:
                                    kAppGroupIdentifier].path;
    
    _logFileHandler = [NSFileHandle fileHandleForReadingAtPath:[groupContainerPath stringByAppendingPathComponent:@"log.txt"]];
    
    KDUtilDefineWeakSelfRef
    [_logFileHandler setReadabilityHandler:^(NSFileHandle *handler) {
        NSData *data = [handler readDataToEndOfFile];
        
        dispatch_async( dispatch_get_main_queue(),^{
            [((UITextView *)weakSelf.view).textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]];
            [weakSelf performSelector:@selector(scrollToBottom) withObject:nil afterDelay:0.1];
        });
        
    }];
    
    self.title = @"Console";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(copyToPasteboard)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scrollToBottom];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)copyToPasteboard {
    [[UIPasteboard generalPasteboard] setString:_textView.text];
    
    [KDAlertView showMessage:@"Copied to pasteboard" cancelButtonTitle:@"OK"];
}

- (void)scrollToBottom {
    [_textView scrollRectToVisible:CGRectMake(0, _textView.contentSize.height - 1, 320, 1) animated:YES];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:^{}];
}

- (void)dealloc {
    [_logFileHandler setReadabilityHandler:nil];
    [_logFileHandler closeFile];
}

@end
