/*
 * Lucid Music - 下载式封面组件
 * 背景：酷我（kw）图片 CDN 对无 Referer 的热链返回 403，而 HarmonyOS
 * Image(url) 无法为网络请求附加 Referer 头，导致大量封面不显示。
 * 方案：kw 来源封面用 http 带 Referer 下载字节 → createPixelMap 渲染；
 * 非 kw 来源仍走原生 Image(url)（其它平台封面已正常，零回归）。
 */
import { http } from '@kit.NetworkKit'
import { image } from '@kit.ImageKit'
import { Logger } from '../util/Logger'

const TAG = 'MusicCoverImage'

// 模块级 PixelMap 缓存，键为封面 URL，避免 Grid 滚动重渲染重复下载
const coverCache: Map<string, image.PixelMap> = new Map()

// 酷我 CDN 防盗链所需请求头
const KW_HEADER: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Referer': 'http://www.kuwo.cn/playlist'
}

@ComponentV2
export struct MusicCoverImage {
  @Param url: string = ''
  @Param source: string = ''
  @Param placeholder: Resource = $r('app.media.ic_avatar1')
  @Local pixelMap: image.PixelMap | null = null
  @Local failed: boolean = false

  aboutToAppear(): void {
    // 非 kw 来源无需下载，build 中直接走原生 Image(url)
    if (this.source !== 'kw' || !this.url) { return }
    const cached = coverCache.get(this.url)
    if (cached) { this.pixelMap = cached; return }
    this.downloadCover(this.url)
  }

  private async downloadCover(url: string): Promise<void> {
    // 酷我来源兜底：若 URL 仍为 https（旧缓存/历史数据），回退 http 明文避免 SSL 2300060
    const fetchUrl = (this.source === 'kw' && url.startsWith('https://')) ? 'http://' + url.slice(8) : url
    const httpReq = http.createHttp()
    try {
      const resp = await httpReq.request(fetchUrl, {
        method: http.RequestMethod.GET,
        header: KW_HEADER,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200 || !(resp.result instanceof ArrayBuffer)) {
        Logger.warn(TAG, `coverDownload err | HTTP ${resp.responseCode} | url=${url}`)
        this.failed = true
        return
      }
      const buffer = resp.result as ArrayBuffer
      const imageSource = image.createImageSource(buffer)
      const pm = await imageSource.createPixelMap()
      coverCache.set(url, pm)
      this.pixelMap = pm
      imageSource.release()
    } catch (e) {
      Logger.error(TAG, `coverDownload exception | url=${url} | err=${JSON.stringify(e)}`)
      this.failed = true
    } finally {
      httpReq.destroy()
    }
  }

  build() {
    if (this.source !== 'kw') {
      // 其它平台：原生 Image 直接渲染网络 URL
      Image(this.url)
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Fill)
        .borderRadius(8)
        .draggable(false)
        .alt(this.placeholder)
    } else if (this.pixelMap) {
      // 酷我：下载成功后渲染 PixelMap
      Image(this.pixelMap)
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Fill)
        .borderRadius(8)
        .draggable(false)
    } else {
      // 酷我加载中 / 失败：统一兜底占位图
      Image(this.placeholder)
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Fill)
        .borderRadius(8)
        .draggable(false)
    }
  }
}
