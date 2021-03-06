//
//  ViewController.m
//  DemoApp
//
//  Created by dannycosson on 10/10/14.
//
//

#import "HomeViewController.h"

#import <UIKit/UIKit.h>

#import "MaveSDK.h"
#import "UIViewController+MMDrawerController.h"
#import "MMDrawerBarButtonItem.h"


@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLeftMenuButton];
//    UILabel *label;
//    self.view.backgroundColor = [UIColor greenColor];
//    for (int i = 0; i < [self.view.subviews count]; i++) {
//        if ([self.view.subviews[i] class] == [UILabel class]) {
//            label = self.view.subviews[i];
//            label.textColor = [UIColor redColor];
//        }
//    }
}

- (IBAction)presentInvitePageAsModal:(id)sender {
    MaveSDK *mave = [MaveSDK sharedInstance];
    [mave presentInvitePageModallyWithBlock:^(UIViewController *inviteController) {
        [self presentViewController:inviteController animated:YES completion:nil];
    } dismissBlock:^(UIViewController *controller, NSUInteger numberOfInvitesSent) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    } inviteContext:@"home-page-modal"];
}

- (void)presentInvitePagePush:(id)sender {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *afterInvitesPage = [storyboard instantiateViewControllerWithIdentifier:@"PushAfterInvitesPage"];
    MaveSDK *mave = [MaveSDK sharedInstance];

    [mave presentInvitePagePushWithBlock:^(UIViewController *inviteController) {
        [self.navigationController pushViewController:inviteController animated:YES];
    } forwardBlock:^(UIViewController *controller, NSUInteger numberOfInvitesSent) {
        [controller.navigationController pushViewController:afterInvitesPage animated:YES];
    } backBlock:^(UIViewController *controller, NSUInteger numberOfInvitesSent) {
        [controller.navigationController popViewControllerAnimated:YES];
    } inviteContext:@"home-page-pushed"];
}

// Methods to present this home view in the drawer
- (void)setupLeftMenuButton {
    MMDrawerBarButtonItem *leftDrawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self action:@selector(leftDrawerButtonPress:)];
    [self.navigationItem setLeftBarButtonItem:leftDrawerButton];
}


- (void)leftDrawerButtonPress:(id)leftDrawerButtonPress {
    [self.mm_drawerController toggleDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
}


@end
