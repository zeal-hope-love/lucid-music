/*
 * PlayerViewModel - 迷你播放器 ViewModel（移植自 MusicHome）
 */
import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { AppStorageKeys, Logger, MusicAppState, MusicDbApi, SongItem } from 'musicbasic';

const TAG = 'PlayerViewModel';

@ObservedV2
export class PlayerViewModel {
  @Trace public appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  public songTitle(): string | Resource {
    const item = this.appState.getCurrentSongItem();
    return item?.title ?? 'Lucid Music';
  }

  public songSinger(): string | Resource {
    const item = this.appState.getCurrentSongItem();
    return item?.singer ?? '未在播放';
  }

  public songCover(): Resource {
    const item = this.appState.getCurrentSongItem();
    if (item !== undefined) {
      return item.label;
    }
    return $r('app.string.page_show');
  }

  public togglePlayPause(): void {
    this.appState.isPlay = !this.appState.isPlay;
    Logger.info(`${TAG}: togglePlayPause isPlay=${this.appState.isPlay}`);
  }

  public playNext(): void {
    if (this.appState.selectIndex < this.appState.playQueueIds.length - 1) {
      this.appState.selectIndex++;
    }
  }

  public playPrevious(): void {
    if (this.appState.selectIndex > 0) {
      this.appState.selectIndex--;
    }
  }

  public openFullScreenWithSharedElementTransition(uiContext: UIContext): void {
    Logger.info(`${TAG}: openFullScreenWithSharedElementTransition`);
  }

  public pushPlaylistDetail(pageIndexInfos: NavPathStack): void {
    Logger.info(`${TAG}: pushPlaylistDetail`);
  }
}
