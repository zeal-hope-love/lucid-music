/*
 * Lucid Music - 后台长时任务工具类
 */
import { wantAgent, common } from '@kit.AbilityKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from 'musicbasic'

const TAG = 'BackgroundUtil'

export class BackgroundUtil {
  /**
   * 启动后台长时任务（音频播放保活）
   */
  public static startContinuousTask(context?: common.UIAbilityContext): void {
    if (!context) {
      Logger.error(TAG, 'startContinuousTask failed: context undefined')
      return
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      }],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
      try {
        backgroundTaskManager.startBackgroundRunning(context,
          backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj)
          .then(() => {
            Logger.info(TAG, 'startBackgroundRunning succeeded')
          })
          .catch((error: BusinessError) => {
            Logger.error(TAG, `startBackgroundRunning failed: code ${error.code}`)
          })
      } catch (error) {
        Logger.error(TAG, `startBackgroundRunning exception: ${(error as BusinessError).message}`)
      }
    }).catch((error: BusinessError) => {
      Logger.error(TAG, `getWantAgent failed: code ${error.code}`)
    })
  }

  /**
   * 停止后台长时任务
   */
  public static stopContinuousTask(context: common.UIAbilityContext): void {
    try {
      backgroundTaskManager.stopBackgroundRunning(context).then(() => {
        Logger.info(TAG, 'stopBackgroundRunning succeeded')
      }).catch((error: BusinessError) => {
        Logger.error(TAG, `stopBackgroundRunning failed: code ${error.code}`)
      })
    } catch (error) {
      Logger.error(TAG, `stopBackgroundRunning exception: ${(error as BusinessError).message}`)
    }
  }
}
