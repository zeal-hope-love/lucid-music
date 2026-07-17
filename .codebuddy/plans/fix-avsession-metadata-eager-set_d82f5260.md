---
name: fix-avsession-metadata-eager-set
overview: 修复 QQ/网易云媒体中心元数据不显示：metadata 先立即设置 title/artist/duration，封面异步加载后补充，不再被慢封面拖累
todos:
  - id: fix-update-metadata
    content: AVSessionController.ets 重构 updateMetadata()：先立即 setAVMetadata(title/artist/duration)，再异步加载封面歌词后二次 setAVMetadata 更新
    status: completed
  - id: fix-init-session-metadata
    content: AudioPlayerController.ets initSessionMetadata()：updateMetadata 调用前加 await
    status: completed
    dependencies:
      - fix-update-metadata
---

## 问题
QQ 和网易云在媒体中心不显示歌名、歌手、封面等元数据，只有酷狗正常。用户质疑为什么跟平台有关，明明统一走 store。

## 根因
1. `initSessionMetadata()` 中调用 `updateMetadata()` 没有 `await`
2. `updateMetadata()` 内部先下载封面（HTTP 最长 10s timeout），下载完成后才调用 `setAVMetadata` 设置元数据
3. 酷狗封面 URL 响应快 → 元数据及时置入；QQ/网易云封面 URL 慢或失败 → `setAVMetadata` 被延迟甚至丢失，导致 title/artist/duration 也一并丢失

## 修复目标
- 元数据（title/artist/duration）立即显示，不依赖封面加载速度
- 封面和歌词异步加载后补充更新


## 实现方案

### 修改文件：2 个

**1. `AVSessionController.ets` — `updateMetadata()` 方法**

当前流程：加载封面（阻塞 5~10s）→ 构建 metadata → setAVMetadata

修改后流程：
1. 立即构建不含封面的 metadata → `setAVMetadata`（title/artist/duration 必达媒体中心）
2. 异步加载封面和歌词 → 再次 `setAVMetadata` 更新

```typescript
public async updateMetadata(...): Promise<void> {
    if (!this.avSessionImpl) { return }
    // 步骤①：立即设置基本信息
    const title = typeof titleStr === 'string' ? titleStr : '未知歌曲'
    const artist = typeof artistStr === 'string' ? artistStr : '未知歌手'
    const baseMeta: avSession.AVMetadata = {
        assetId: `${songId}`, title, artist, duration,
        avQueueName: 'AudioPlayerQueue', avQueueId: `${songId}`
    }
    this.avSessionImpl.setAVMetadata(baseMeta)

    // 步骤②：异步加载封面和歌词
    let mediaImage: PixelMap | undefined = undefined
    let lyric: string | undefined = undefined
    // ... 加载封面和歌词逻辑（同原有代码）...

    // 步骤③：更新含封面/歌词的完整元数据
    if (mediaImage || lyric) {
        const fullMeta: avSession.AVMetadata = { ...baseMeta, mediaImage }
        if (lyric) { fullMeta.lyric = lyric }
        this.avSessionImpl.setAVMetadata(fullMeta)
    }
}
```

**2. `AudioPlayerController.ets` — `initSessionMetadata()` 方法**

`updateMetadata()` 调用前加 `await`，确保步骤①的 `setAVMetadata` 在 `play()` 之前完成：

```typescript
await this.avSessionController.updateMetadata(...)
```

### 设计要点
- 步骤①的 `setAVMetadata` 不包含 `mediaImage`，系统媒体中心会用默认图标，但 title/artist 必达
- 封面/歌词加载在 try-catch 内，失败不影响已显示的基本信息
- `await` 只等待步骤①完成，封面异步在步骤②③中后台进行
- 与平台无关：无论酷狗/QQ/网易云，基本信息始终在 `play()` 前完成同步

