/*
 * PlayerViewModel - 迷你播放器 ViewModel（移植自 MusicHome）
 * 所有播放操作委托给 AudioPlayerController 统一处理。
 */
import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { AppStorageKeys, Logger, MusicAppState, MusicDbApi, SongItem } from 'musicbasic';
import { AudioPlayerController } from '../controller/AudioPlayerController';

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

  /** 封面来源：coverUrl 优先，label 兜底。 */
  public songCover(): Resource | string {
    const item = this.appState.getCurrentSongItem();
    if (item) {
      if (item.coverUrl) {
        return item.coverUrl;
      }
      return item.label;
    }
    return $r('app.string.page_show');
  }

  public togglePlayPause(): void {
    AudioPlayerController.getInstance().togglePlay();
    Logger.info(`${TAG}: togglePlayPause`);
  }

  public playNext(): void {
    AudioPlayerController.getInstance().playNext();
  }

  public playPrevious(): void {
    AudioPlayerController.getInstance().playPrevious();
  }

  public openFullScreenWithSharedElementTransition(uiContext: UIContext): void {
    Logger.info(`${TAG}: openFullScreenWithSharedElementTransition`);
  }

  public pushPlaylistDetail(pageIndexInfos: NavPathStack): void {
    Logger.info(`${TAG}: pushPlaylistDetail`);
  }
}
