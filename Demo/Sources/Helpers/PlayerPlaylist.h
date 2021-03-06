//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import SRGLetterbox;

NS_ASSUME_NONNULL_BEGIN

@interface PlayerPlaylist : NSObject <SRGLetterboxControllerPlaylistDataSource, SRGLetterboxControllerPlaybackTransitionDelegate>

- (instancetype)initWithMedias:(NSArray<SRGMedia *> *)medias currentIndex:(NSInteger)currentIndex;

@end

NS_ASSUME_NONNULL_END
