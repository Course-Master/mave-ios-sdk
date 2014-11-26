//
//  InvitePageViewController.m
//  MaveSDKDevApp
//
//  Created by dannycosson on 10/1/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import "MaveSDK.h"
#import "MAVEInvitePageViewController.h"
#import "MAVEInviteExplanationView.h"
#import "MAVEABTableViewController.h"
#import "MAVEABCollection.h"
#import "MAVENoAddressBookPermissionView.h"
#import "MAVEConstants.h"

@interface MAVEInvitePageViewController ()

@end

@implementation MAVEInvitePageViewController

- (void)loadView {
    [super loadView];
    // On load keyboard is hidden
    self.isKeyboardVisible = NO;
    self.keyboardFrame = [self keyboardFrameWhenHidden];

    [self setupNavigationBar];
    if ([self canTryAddressBookInvites]) {
        [self determineAndSetViewBasedOnABPermissions];
    } else {
        self.view = [self createEmptyFallbackView];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Subscribe to events that change frame size
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self
                      selector:@selector(keyboardWillChangeFrame:)
                          name:UIKeyboardWillChangeFrameNotification
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(deviceDidRotate:)
                          name:UIDeviceOrientationDidChangeNotification
                        object:nil];

    // Register the viewed invite page event with our API
    MaveSDK *gk = [MaveSDK sharedInstance];
    [gk.HTTPManager trackInvitePageOpenRequest:gk.userData];
}

- (void)viewDidAppear:(BOOL)animated {
    if (![self canTryAddressBookInvites]) {
        [self presentShareSheet];
    }
}

- (void)dealloc {
    NSLog(@"called dealloc");
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter removeObserver:self
                             name:UIKeyboardWillChangeFrameNotification
                           object:nil];
    [defaultCenter removeObserver:self
                             name:UIDeviceOrientationDidChangeNotification
                           object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Cleanup to dismiss, then call the block method, passing back the
// number of invites sent to the containing app
- (void)dismissSelf:(unsigned int)numberOfInvitesSent {
    // Cleanup for dismiss
    [self.view endEditing:YES];

    // Call dismissal block
    InvitePageDismissalBlock dismissalBlock = [MaveSDK sharedInstance].invitePageDismissalBlock;
    dismissalBlock(self, numberOfInvitesSent);
}

- (void)dismissAfterCancel {
    [self dismissSelf:0];
}

//
// Handle frame changing events
//

// returns what the frame would be for a hidden keyboard (origin below app frame)
// based on  current application frame
- (CGRect)keyboardFrameWhenHidden {
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
    return CGRectMake(0, appFrame.origin.y + appFrame.size.height, 0, 0);
}

- (void)deviceDidRotate:(NSNotification *)notification {
    // If keyboard is visible during rotate, the keyboard frame change event will
    // resize our view correctly so no need to do anything here
    if (!self.isKeyboardVisible) {
        self.keyboardFrame = [self keyboardFrameWhenHidden];
        [self layoutInvitePageViewAndSubviews];
    }
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    self.keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    if (self.keyboardFrame.origin.y == [self keyboardFrameWhenHidden].origin.y) {
        self.isKeyboardVisible = NO;
    } else {
        self.isKeyboardVisible = YES;
    }
    [self layoutInvitePageViewAndSubviews];
}

- (BOOL)shouldDisplayInviteMessageView {
    if ([self.ABTableViewController.selectedPhoneNumbers count] == 0) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)canTryAddressBookInvites {
    // Right now, we'll only try our address book flow for US devices until we can
    // thoroughly test different countries
    NSString *countryCode = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    if ([countryCode isEqualToString:MAVECountryCodeUnitedStates]) {
        return YES;
    }
    return NO;
}

//
// Load the correct view(s) with data
//
- (void)setupNavigationBar {
    MAVEDisplayOptions *displayOptions = [MaveSDK sharedInstance].displayOptions;
    
    self.navigationItem.title = displayOptions.navigationBarTitleCopy;
    self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: displayOptions.navigationBarTitleTextColor,
            NSFontAttributeName: displayOptions.navigationBarTitleFont,
    };
    self.navigationController.navigationBar.barTintColor = displayOptions.navigationBarBackgroundColor;
    
    UIBarButtonItem *cancelBarButtonItem = displayOptions.navigationBarCancelButton;
    cancelBarButtonItem.target = self;
    cancelBarButtonItem.action = @selector(dismissAfterCancel);
    [self.navigationItem setLeftBarButtonItem:cancelBarButtonItem];
}

- (void)determineAndSetViewBasedOnABPermissions {
    // If address book permission already granted, load contacts view right now
    ABAuthorizationStatus addrBookStatus = ABAddressBookGetAuthorizationStatus();
    if (addrBookStatus == kABAuthorizationStatusAuthorized) {
        self.view = [self createAddressBookInviteView];
        [self layoutInvitePageViewAndSubviews];
        [MAVEABCollection createAndLoadAddressBookWithCompletionBlock:^(NSDictionary *indexedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.ABTableViewController updateTableData:indexedData];
            });
         }];

    // If status not determined, prompt for permission then load data
    // If permission not granted, swap empty for for permission denied view
    } else if (addrBookStatus == kABAuthorizationStatusNotDetermined) {
        self.view = [self createEmptyFallbackView];
        [MAVEABCollection createAndLoadAddressBookWithCompletionBlock:^(NSDictionary *indexedData) {
            if ([indexedData count] > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.view = [self createAddressBookInviteView];
                    [self layoutInvitePageViewAndSubviews];
                    [self.ABTableViewController updateTableData:indexedData];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.view = [[MAVENoAddressBookPermissionView alloc] init];
                });
            }
         }];

    // If status already denied, leave blank page for now
    } else if (addrBookStatus == kABAuthorizationStatusDenied ||
               addrBookStatus == kABAuthorizationStatusRestricted) {
        self.view = [self createEmptyFallbackView];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.view = [[MAVENoAddressBookPermissionView alloc] init];
        });
    }
}

- (UIView *)createEmptyFallbackView {
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    [view setBackgroundColor:[UIColor whiteColor]];
    return view;
}

- (UIView *)createAddressBookInviteView {
    // Instantiate the view controllers for child views
    self.ABTableViewController = [[MAVEABTableViewController alloc] initTableViewWithParent:self];
    self.inviteExplanationView = [[MAVEInviteExplanationView alloc] init];
    self.inviteMessageContainerView = [[MAVEInviteMessageContainerView alloc] init];
    [self.inviteMessageContainerView.inviteMessageView.sendButton
        addTarget:self action:@selector(sendInvites) forControlEvents: UIControlEventTouchUpInside];
    
    __weak typeof(self) weakSelf = self;
    self.inviteMessageContainerView.inviteMessageView.textViewContentChangingBlock = ^void() {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf layoutInvitePageViewAndSubviews];
        });
    };
    
    UIView *containerView = [[UIView alloc] init];
    [self.ABTableViewController.tableView addSubview:self.ABTableViewController.aboveTableContentView];
    [containerView addSubview:self.ABTableViewController.tableView];
    [containerView addSubview:self.inviteMessageContainerView];
    return containerView;
}

- (void)layoutInvitePageViewAndSubviews {
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
    CGRect containerFrame = CGRectMake(0,
                                       0,
                                       appFrame.origin.x + appFrame.size.width,
                                       self.keyboardFrame.origin.y);

    CGRect tableViewFrame = CGRectMake(containerFrame.origin.x,
                                       containerFrame.origin.y,
                                       containerFrame.size.width,
                                       containerFrame.size.height);

    CGFloat inviteViewHeight = [self.inviteMessageContainerView.inviteMessageView
                            computeHeightWithWidth:containerFrame.size.width];

    // Extend bottom of table view content so invite message view doesn't overlap it
    UIEdgeInsets abTableViewInsets = self.ABTableViewController.tableView.contentInset;
    abTableViewInsets.bottom = inviteViewHeight;
    self.ABTableViewController.tableView.contentInset = abTableViewInsets;

    // Put the invite message view off bottom of screen unless we should display it,
    // then it goes at the very bottom
    CGFloat inviteViewOffsetY = containerFrame.origin.y + containerFrame.size.height;
    if ([self shouldDisplayInviteMessageView]) {
        inviteViewOffsetY -= inviteViewHeight;
    }

    CGRect inviteMessageViewFrame = CGRectMake(0,
                                               inviteViewOffsetY,
                                               containerFrame.size.width,
                                               inviteViewHeight);

    self.view.frame = containerFrame;
    self.ABTableViewController.tableView.frame = tableViewFrame;
    self.ABTableViewController.aboveTableContentView.frame =
        CGRectMake(0, tableViewFrame.origin.y - containerFrame.size.height,
               containerFrame.size.width, containerFrame.size.height);
    self.inviteMessageContainerView.frame = inviteMessageViewFrame;
    
    //
    // Add in the explanation view if text has been set
    //
    if ([self.inviteExplanationView.messageCopy.text length] > 0) {
        CGRect prevInviteExplanationViewFrame = self.inviteExplanationView.frame;
        // use ceil so rounding errors won't cause tiny gap below the table header view
        CGFloat inviteExplanationViewHeight = ceil([self.inviteExplanationView
                                                    computeHeightWithWidth:containerFrame.size.width]);
        CGRect inviteExplanationViewFrame = CGRectMake(0, 0, containerFrame.size.width,
                                                       ceil(inviteExplanationViewHeight));

        // table header view needs to be re-assigned when frame changes or the rest
        // of the table doesn't get offset and the header overlaps it
        if (!CGRectEqualToRect(inviteExplanationViewFrame, prevInviteExplanationViewFrame)) {
            self.inviteExplanationView.frame = inviteExplanationViewFrame;
            self.ABTableViewController.tableView.tableHeaderView = self.inviteExplanationView;
            // match above table color to explanation view color so it looks like one view
            self.ABTableViewController.aboveTableContentView.backgroundColor =
                self.inviteExplanationView.backgroundColor;
        }
    }
}
//
// Respond to children's Events
//

- (void)ABTableViewControllerNumberSelectedChanged:(unsigned long)num {
    // If called from the table view's "did select row at index path" method we'll already be
    // in the main thread anyway, but dispatch it asynchronously just in case we ever call
    // from somewhere else.
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            [self layoutInvitePageViewAndSubviews];
        }];
        [self.inviteMessageContainerView.inviteMessageView updateNumberPeopleSelected:num];
    });
}


//
// Send invites and update UI when done
//
- (void)sendInvites {
    DebugLog(@"Sending invites");
    NSString *message = self.inviteMessageContainerView.inviteMessageView.textView.text;
    NSArray *phones = [self.ABTableViewController.selectedPhoneNumbers allObjects];
    if ([phones count] == 0) {
        NSLog(@"Pressed Send but no recipients selected");
        return;
    }
    
    MaveSDK *mave = [MaveSDK sharedInstance];
    MAVEHTTPManager *httpManager = mave.HTTPManager;
    [httpManager sendInvitesWithPersons:phones
                                message:message
                                 userId:mave.userData.userID
               inviteLinkDestinationURL:mave.userData.inviteLinkDestinationURL
                        completionBlock:^(NSError *error, NSDictionary *responseData) {
        if (error != nil) {
            DebugLog(@"Invites failed to send, error: %@, response: %@",
                  error, responseData);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAndResetAfterSendInvitesFailure:error];
            });
        } else {
            DebugLog(@"Invites sent! response: %@", responseData);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.inviteMessageContainerView.sendingInProgressView completeSendingProgress];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissSelf:(unsigned int)[phones count]];
            });
        }
    }];
    [self.inviteMessageContainerView makeSendingInProgressViewActive];
}

- (void)showErrorAndResetAfterSendInvitesFailure:(NSError *)error {
    [self.inviteMessageContainerView makeInviteMessageViewActive];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invites not sent"
                                                    message:@"Server was unavailable or internet connection failed"
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil];
    [alert show];
    [self performSelector:@selector(dismissSendInvitesFailedAlertView:)
               withObject:alert
               afterDelay:3.0];
}

- (void)dismissSendInvitesFailedAlertView:(UIAlertView *)alertView {
    [alertView dismissWithClickedButtonIndex:0 animated:YES];
}

// Do Share sheet invites instead
- (void)presentShareSheet {
    MaveSDK *mave = [MaveSDK sharedInstance];
    NSMutableArray *activityItems = [[NSMutableArray alloc] init];
    [activityItems addObject:mave.defaultSMSMessageText];
    if ([mave.appId isEqualToString:MAVEPartnerApplicationIDSwig] ||
        [mave.appId isEqualToString:MAVEPartnerApplicationIDSwigEleviter]) {
        [activityItems addObject:[NSURL URLWithString:MAVEInviteURLSwig]];
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                            initWithActivityItems:activityItems
                                            applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeAddToReadingList];
    activityVC.completionHandler = ^void (NSString *activityType, BOOL completed) {
        unsigned int numberShares = completed ? 1 : 0;
        [self dismissSelf:numberShares];
    };
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
