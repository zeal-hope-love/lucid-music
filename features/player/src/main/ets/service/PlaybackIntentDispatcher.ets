/*
 * PlaybackIntentDispatcher - 播放意图分发器
 */
import {
  Logger, MusicAppState, PlaybackIntentState,
  PlaybackIntentLogEvent, PlaybackShellConstants
} from 'musicbasic'

const TAG = 'PlaybackIntentDispatcher'

/**
 * 播放意图分发：当 PlaybackIntentState 变化时，更新 MusicAppState 并触发回调
 * @param appState 全局播放状态
 * @param intentState 播放意图状态
 * @param onOpenPlayerUi 打开全屏播放器 UI 的回调
 */
export function dispatchShellPlaybackIntent(
  appState: MusicAppState,
  intentState: PlaybackIntentState,
  onOpenPlayerUi: () => void
): void {
  Logger.info(`${TAG}: dispatchShellPlaybackIntent version=${intentState.requestVersion}`)

  try {
    // 处理远程播放
    if (intentState.remoteUrl) {
      Logger.info(`${TAG}: remote playback - url=${intentState.remoteUrl}`)
      intentState.resetRemote()
    }

    // 处理本地歌曲播放
    if (intentState.pendingPlaySongId >= 0) {
      const index = appState.playQueueIds.indexOf(intentState.pendingPlaySongId)
      if (index >= 0) {
        appState.selectIndex = index
        Logger.info(`${TAG}: song found in queue at index=${index}`)
      }
      intentState.pendingPlaySongId = -1
    }

    // 打开全屏播放器 UI
    if (intentState.openPlayerUi) {
      Logger.info(`${TAG}: openPlayerUi`)
      intentState.openPlayerUi = false
      onOpenPlayerUi()
    }
  } catch (e) {
    Logger.error(`${TAG}: dispatch error ${JSON.stringify(e)}`)
  }
}
