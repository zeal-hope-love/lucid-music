/*
 * Lucid Music - 底部栏显隐状态
 * 由 Index.ets 统一管理，NavDestination 生命周期驱动显隐。
 * - miniPlayerVisible: 迷你播放条可见性（Tab 页 / Search 页 / 二级页为 true，Playback 页为 false）
 * - tabBarVisible: Tab 导航栏可见性（仅 Tab 页为 true）
 */
@ObservedV2
export class BottomBarVisibility {
  @Trace miniPlayerVisible: boolean = true
  @Trace tabBarVisible: boolean = true
}
