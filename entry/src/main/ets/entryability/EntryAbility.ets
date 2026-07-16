/*
 * Lucid Music - EntryAbility
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { getAppRuntime, Logger, WindowUtil, AudioSourceManager } from 'musicbasic'
import { MediaService, JsVmBridge } from 'player'
import { BusinessError } from '@kit.BasicServicesKit'

export default class EntryAbility extends UIAbility {
  onCreate() {
    getAppRuntime().context = this.context
    AppStorage.setOrCreate('context', this.context)
    Logger.info('EntryAbility: onCreate')
  }

  onDestroy() {
    Logger.info('EntryAbility: onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    Logger.info('EntryAbility: onWindowStageCreate')

    // 沉浸式全屏：状态栏和导航栏透明，内容延伸到系统栏区域
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      mainWindow.setWindowLayoutFullScreen(true)
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000'
      })
    })

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
