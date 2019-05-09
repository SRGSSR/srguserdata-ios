//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlaylistViewController.h"

#import "NSDateFormatter+Demo.h"
#import "PlayerViewController.h"
#import "SRGUserData_demo-Swift.h"

#import <libextobjc/libextobjc.h>
#import <SRGDataProvider/SRGDataProvider.h>

@interface PlaylistViewController ()

@property (nonatomic) SRGPlaylist *playlist;

@property (nonatomic) NSArray<NSString *> *mediaURNs;
@property (nonatomic) NSArray<SRGMedia *> *medias;

@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation PlaylistViewController

#pragma mark Object lifecycle

- (instancetype)initWithPlaylist:(SRGPlaylist *)playlist
{
    if (self = [super init]) {
        self.playlist = playlist;
    }
    return self;
}

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistEntriesDidChange:)
                                               name:SRGPlaylistEntriesDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:SRGIdentityService.currentIdentityService];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didFinishSynchronization:)
                                               name:SRGUserDataDidFinishSynchronizationNotification
                                             object:SRGUserData.currentUserData];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
    
    if (self.playlist.type == SRGPlaylistTypeStandard) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                               target:self
                                                                                               action:@selector(updatePlaylist:)];
    }
    
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.request cancel];
    }
}

#pragma mark Data

- (void)refresh
{
    [self.request cancel];
    
    [self updateMediaURNsWithCompletionBlock:^(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs) {
        SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider mediasWithURNs:URNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (self.refreshControl.refreshing) {
                [self.refreshControl endRefreshing];
            }
            
            if (error) {
                return;
            }
            
            [self.tableView reloadDataAnimatedWithOldObjects:self.medias newObjects:medias section:0 updateData:^{
                self.medias = medias;
            }];
        }] requestWithPageSize:50];
        [request resume];
        self.request = request;
    }];
}

- (void)updateMediaURNsWithCompletionBlock:(void (^)(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs))completionBlock
{
    BOOL ascending = ! [self.playlist.uid isEqualToString:SRGPlaylistUidWatchLater];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylistEntry.new, date) ascending:ascending];
    [SRGUserData.currentUserData.playlists playlistEntriesInPlaylistWithUid:self.playlist.uid matchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGPlaylistEntry *> * _Nullable playlistEntries, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSArray<NSString *> *mediaURNs = [playlistEntries valueForKeyPath:@keypath(SRGPlaylistEntry.new, uid)];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray<NSString *> *previousMediaURNs = self.mediaURNs;
            self.mediaURNs = mediaURNs;
            completionBlock(mediaURNs, previousMediaURNs);
        });
    }];
}

- (void)reloadData
{
    NSString *title = self.playlist.name;
    self.title = title;
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.medias.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (SRGIdentityService.currentIdentityService.loggedIn) {
        NSDate *synchronizationDate = SRGUserData.currentUserData.user.synchronizationDate;
        NSString *synchronizationDateString = synchronizationDate ? [NSDateFormatter.demo_relativeDateAndTimeFormatter stringFromDate:synchronizationDate] : NSLocalizedString(@"Never", nil);
        return [NSString stringWithFormat:NSLocalizedString(@"Last synchronization: %@", nil), synchronizationDateString];
    }
    else {
        return nil;
    }
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = self.medias[indexPath.row].title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SRGMedia *media = self.medias[indexPath.row];
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:media.URN];
    
    PlayerPlaylist *playerPlaylist = [[PlayerPlaylist alloc] initWithMedias:self.medias currentIndex:indexPath.row];
    PlayerViewController *playerViewController = [[PlayerViewController alloc] initWithURN:media.URN time:historyEntry.lastPlaybackTime playerPlaylist:playerPlaylist];
    [self presentViewController:playerViewController animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SRGMedia *media = self.medias[indexPath.row];
        [SRGUserData.currentUserData.playlists discardPlaylistEntriesWithUids:@[media.URN] fromPlaylistWithUid:self.playlist.uid completionBlock:nil];
    }
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self refresh];
}

- (void)updatePlaylist:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Update playlist name", nil)
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"Playlist name", nil);
        textField.text = self.playlist.name;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleDefault handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alertController.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) {
            [SRGUserData.currentUserData.playlists savePlaylistWithName:name uid:self.playlist.uid completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (! error) {
                        [self reloadData];
                    }
                });
            }];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark Notifications

- (void)playlistEntriesDidChange:(NSNotification *)notification
{
    [self updateMediaURNsWithCompletionBlock:^(NSArray<NSString *> *URNs, NSArray<NSString *> *previousURNs) {
        if (! [previousURNs isEqual:self.mediaURNs]) {
            [self refresh];
        }
    }];
}

- (void)didLogout:(NSNotification *)notification
{
    [self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)didFinishSynchronization:(NSNotification *)notification
{
    [self.tableView reloadData];
}

@end
