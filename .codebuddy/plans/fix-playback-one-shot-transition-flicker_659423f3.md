---
name: fix-playback-one-shot-transition-flicker
overview: 修复歌词页→封面页切换时动画末尾的突变问题。根因是两个组件中共享 geometryTransition 元素的字体属性（fontWeight/fontFamily/fontColor）和封面 borderRadius 不一致，导致 geometryTransition 插值结束后属性跳变。
todos:
  - id: fix-musicinfo
    content: 修复 MusicInfoComponent.ets：统一歌名 fontWeight 为 700、歌手 fontWeight 为 500、歌手 fontFamily 为 HarmonyHeiTi-Medium
    status: completed
  - id: fix-lyrics
    content: 修复 LyricsComponent.ets：统一三处封面 borderRadius 从硬编码 6 改为 $r('app.float.cover_radius_label')
    status: completed
  - id: verify
    content: 验证歌词页→封面页切换动画末尾不再有阴影变浅和字体变细的突变
    status: completed
    dependencies:
      - fix-musicinfo
      - fix-lyrics
---

## 用户需求
修复播放详情页从歌词页切换到封面页时动画末尾的属性突变问题。具体表现为：封面阴影突然变浅、歌名和歌手字体突然变细。

## 核心问题
歌词页（LyricsComponent）和封面页（MusicInfoComponent）对同一 geometryTransition ID 的元素设置了不一致的属性，导致系统在动画插值结束后属性跳变。需要统一两个组件中对应元素的 fontWeight、fontFamily、borderRadius 等属性。

## 修复范围
- 歌名 Text：统一 fontWeight 为数字 700
- 歌手 Text：统一 fontWeight=500, fontFamily=HarmonyHeiTi-Medium
- 封面 Image：统一 borderRadius 使用资源引用 $r('app.float.cover_radius_label')

## 技术栈
- HarmonyOS ArkUI V2（@Component, @Prop, @StorageLink）
- geometryTransition 共享元素转场

## 修复方案

### 属性差异对齐

#### MusicInfoComponent.ets 修改点
1. **第149行** 歌名 fontWeight：`FontWeight.Bold` → `PlayerConstants.FONT_WEIGHT_700`（=700）
2. **第160行** 歌手 fontFamily：`PlayerConstants.FONT_FAMILY_BLACK`（'HarmonyHeiTi'）→ `PlayerConstants.FONT_FAMILY_MEDIUM`（'HarmonyHeiTi-Medium'）
3. **第162行** 歌手 fontWeight：`FontWeight.Regular` → `PlayerConstants.FONT_WEIGHT_500`（=500）

#### LyricsComponent.ets 修改点
1. **第107行** 封面 borderRadius（coverUrl 分支）：`6` → `$r('app.float.cover_radius_label')`
2. **第121行** 封面 borderRadius（loadFailed 分支）：`6` → `$r('app.float.cover_radius_label')`
3. **第127行** 封面 borderRadius（label 分支）：`6` → `$r('app.float.cover_radius_label')`

### 为什么这样修复
geometryTransition 在动画过程中会插值两个元素的可动画属性。当属性类型不一致（如 FontWeight.Bold 枚举 vs 数字 700，或硬编码数字 vs 资源引用），系统可能无法正确插值，导致动画末尾属性跳变。统一属性类型和值后，动画过渡平滑。
