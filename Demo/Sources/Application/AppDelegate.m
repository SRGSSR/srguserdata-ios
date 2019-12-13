//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "HistoryViewController.h"
#import "MediasViewController.h"
#import "PlaylistsViewController.h"
#import "PreferencesViewController.h"
#import "SettingsViewController.h"

#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://hummingbird.rts.ch/api/profile"]
                                                                                       websiteURL:[NSURL URLWithString:@"https://www.rts.ch/profile"]];
    
    NSString *cachesDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *fileURL = [[NSURL fileURLWithPath:cachesDirectory] URLByAppendingPathComponent:@"UserData-demo.sqlite"];
    SRGUserData.currentUserData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                                 serviceURL:[NSURL URLWithString:@"https://profil.rts.ch/api"]
                                                            identityService:SRGIdentityService.currentIdentityService];
    
    SRGDataProvider.currentDataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL()];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDidLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:nil];
    
    MediasViewController *mediasViewController = [[MediasViewController alloc] init];
    UINavigationController *mediasNavigationController = [[UINavigationController alloc] initWithRootViewController:mediasViewController];
    mediasNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Medias", nil) image:[UIImage imageNamed:@"media"] tag:0];
    
    HistoryViewController *historyViewController = [[HistoryViewController alloc] init];
    UINavigationController *historyNavigationController = [[UINavigationController alloc] initWithRootViewController:historyViewController];
    historyNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"History", nil) image:[UIImage imageNamed:@"history"] tag:1];
    
    PlaylistsViewController *playlistsViewController = [[PlaylistsViewController alloc] init];
    UINavigationController *playlistsNavigationController = [[UINavigationController alloc] initWithRootViewController:playlistsViewController];
    playlistsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Playlists", nil) image:[UIImage imageNamed:@"playlists-large"] tag:2];
    
    PreferencesViewController *preferencesViewController = [[PreferencesViewController alloc] initWithPath:nil inDomain:@"userdata-demo"];
    UINavigationController *preferencesNavigationController = [[UINavigationController alloc] initWithRootViewController:preferencesViewController];
    preferencesNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil) image:[UIImage imageNamed:@"preferences"] tag:3];
    
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:[UIImage imageNamed:@"settings"] tag:4];
    
#if TARGET_OS_TV
    mediasNavigationController.navigationBarHidden = YES;
    historyNavigationController.navigationBarHidden = YES;
    playlistsNavigationController.navigationBarHidden = YES;
    preferencesNavigationController.navigationBarHidden = YES;
    settingsNavigationController.navigationBarHidden = YES;
#endif
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[mediasNavigationController, historyNavigationController, playlistsNavigationController, preferencesNavigationController, settingsNavigationController];
    
    self.window.rootViewController = tabBarController;
    return YES;
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    if ([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Information", nil)
                                                                                 message:NSLocalizedString(@"You have been logged out. Please login again to synchronize your data.", nil)
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleCancel handler:nil]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}

@end
