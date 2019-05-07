//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayerViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>

@interface PlayerViewController ()

@property (nonatomic, copy) NSString *URN;
@property (nonatomic) SRGPosition *position;

@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;
@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;     // top-level object, retained

@property (nonatomic, weak) IBOutlet UIButton *closeButton;
@property (nonatomic, weak) IBOutlet UIButton *playlistsButton;

@end

@implementation PlayerViewController

#pragma mark Object lifecycle

- (instancetype)initWithURN:(NSString *)URN time:(CMTime)time
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    PlayerViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.URN = URN;
    viewController.position = [SRGPosition positionBeforeTime:time];
    return viewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.URN) {
        [self.letterboxController playURN:self.URN atPosition:self.position withPreferredSettings:nil];
        
        @weakify(self)
        [self.letterboxController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
            @strongify(self)
            
            if (self.URN) {
                [SRGUserData.currentUserData.history saveHistoryEntryWithUid:self.URN lastPlaybackTime:time deviceUid:UIDevice.currentDevice.name completionBlock:nil];
            }
        }];
    }
}

#pragma mark Home indicator

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.letterboxView.userInterfaceHidden;
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, BOOL minimal, CGFloat heightOffset) {
        CGFloat alpha = (minimal || ! hidden) ? 1.f : 0.f;
        self.closeButton.alpha = alpha;
        self.playlistsButton.alpha = alpha;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (@available(iOS 11, *)) {
            [self setNeedsUpdateOfHomeIndicatorAutoHidden];
        }
    }];
}

#pragma mark Actions

- (IBAction)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addToPlaylist:(id)sender
{
    SRGMedia *media = self.letterboxController.media;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add to playlist", nil)
                                                                             message:media.title
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(SRGPlaylist.new, discarded)];
    NSSortDescriptor *typeSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, type) ascending:NO];
    NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGPlaylist.new, name) ascending:YES];
    NSArray<SRGPlaylist *> *playlists = [SRGUserData.currentUserData.playlists playlistsMatchingPredicate:predicate sortedWithDescriptors:@[typeSortDescriptor, nameSortDescriptor]];
    
    for (SRGPlaylist *playlist in playlists) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:playlist.name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [SRGUserData.currentUserData.playlists savePlaylistEntryWithUid:media.URN inPlaylistWithUid:playlist.uid completionBlock:nil];
        }];
        [alertController addAction:action];
        
        if ([playlist.uid isEqualToString:SRGPlaylistUidWatchLater]) {
            alertController.preferredAction = action;
        }
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
