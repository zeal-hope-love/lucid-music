/*
 * Lucid Music - EntryAbility
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { getAppRuntime, Logger, WindowUtil } from 'musicbasic'
import { MediaService, JsVmBridge } from 'player'
import { AudioSourceManager } from 'search'
import { BusinessError } from '@kit.BasicServicesKit'

export default class EntryAbility extends UIAbility {
  onCreate() {
    getAppRuntime().context = this.context
    Logger.info('EntryAbility: onCreate')
  }

  onDestroy() {
    Logger.info('EntryAbility: onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    Logger.info('EntryAbility: onWindowStageCreate')
    windowStage.loadContent('pages/Index', (err) => {
      try {
        getAppRuntime().uiContext = windowStage.getMainWindowSync().getUIContext()
      } catch (error) {
        Logger.error(`getMainWindowSync error ${JSON.stringify(error)}`)
      }
      if (err.code) {
        Logger.error(`Failed to load content: ${JSON.stringify(err)}`)
        return
      }
      Logger.info('Content loaded successfully')
      MediaService.getInstance()
      AudioSourceManager.getInstance().init(this.context)
      JsVmBridge.getInstance().init()
      try {
        WindowUtil.getInstance().setWindowStage(windowStage)
        WindowUtil.getInstance().setUIContext()
        WindowUtil.getInstance().updateWindowInfo()
      } catch (e) {
        Logger.error(`WindowUtil init error: ${(e as BusinessError).message}`)
      }
    })
  }

  onWindowStageDestroy() {
    Logger.info('EntryAbility: onWindowStageDestroy')
  }

  onForeground() {
    Logger.info('EntryAbility: onForeground')
  }

  onBackground() {
    Logger.info('EntryAbility: onBackground')
    MediaService.getInstance().onApplicationBackground()
  }
}
