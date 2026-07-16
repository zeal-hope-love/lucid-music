/*
 * Lucid Music - 音源管理器
 * 单例，管理用户导入 JS 脚本源的完整生命周期：
 *   在线导入（URL下载） / 本地导入（文件选择器）
 *   JSDoc 元数据解析 / 互斥激活 / 删除清理
 */
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { AudioSourceModel, AudioSourceOrigin } from '../model/AudioSourceModel'
import { AudioSourceDb } from './AudioSourceDb'

const TAG = 'AudioSourceManager'
const AUDIO_SOURCE_DIR = 'audiosources'

/** 激活脚本结果 */
export interface ActiveScriptResult {
  model: AudioSourceModel
  content: string
}

/** 导入结果 */
export interface ImportResult {
  success: boolean
  message: string
  model?: AudioSourceModel
}

export class AudioSourceManager {
  private static instance: AudioSourceManager | null = null
  private db: AudioSourceDb = AudioSourceDb.getInstance()
  private context: Context | null = null

  static getInstance(): AudioSourceManager {
    if (AudioSourceManager.instance === null) {
      AudioSourceManager.instance = new AudioSourceManager()
    }
    return AudioSourceManager.instance
  }

  /** 初始化，需要 UIAbilityContext */
  init(context: Context): void {
    this.context = context
    this.db.init(context)
  }

  // ==================== 获取列表 ====================

  /** 获取全部已导入音源 */
  async getAll(): Promise<AudioSourceModel[]> {
    return this.db.getAll()
  }

  // ==================== 在线导入 ====================

  /**
   * 在线导入：下载 URL 指向的 JS 脚本
   */
  async importFromUrl(url: string): Promise<ImportResult> {
    if (url.trim().length === 0) {
      return { success: false, message: '请输入有效的地址' }
    }
    try {
      const domain = this.extractDomain(url)
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          'Referer': domain,
        },
        connectTimeout: 60000,
        readTimeout: 60000,
      })
      if (resp.responseCode !== 200) {
        return { success: false, message: `下载失败，HTTP ${resp.responseCode}` }
      }
      const content: string = resp.result as string
      if (content.length > 9_000_000) {
        return { success: false, message: '脚本文件过大（超过 9MB）' }
      }
      return this.saveScript('', content, 'online', url)
    } catch (e) {
      return { success: false, message: '网络请求失败，请检查地址' }
    }
  }

  // ==================== 本地导入 ====================

  /**
   * 本地导入：读取指定路径的 JS 脚本文件
   */
  async importFromLocal(filePath: string): Promise<ImportResult> {
    try {
      const content: string = fileIo.readTextSync(filePath)
      const slashIdx = Math.max(filePath.lastIndexOf('/'), filePath.lastIndexOf('\\'))
      const origName = slashIdx >= 0 ? filePath.substring(slashIdx + 1) : filePath
      return await this.saveScript(origName, content, 'local', filePath)
    } catch (e) {
      return { success: false, message: '读取文件失败' }
    }
  }

  // ==================== 保存脚本（核心） ====================

  /**
   * 保存脚本到沙箱并持久化元数据
   */
  private async saveScript(
    origFileName: string, content: string, source: AudioSourceOrigin, sourceUrl: string
  ): Promise<ImportResult> {
    if (this.context === null) {
      return { success: false, message: '管理器未初始化' }
    }
    // 解析 JSDoc 提取元数据
    const meta = AudioSourceManager.parseScriptMeta(content)

    // 写文件到沙箱
    const dirPath = this.context.filesDir + '/' + AUDIO_SOURCE_DIR
    const dirCheck = fileIo.accessSync(dirPath)
    if (!dirCheck) {
      fileIo.mkdirSync(dirPath, true)
    }
    const fileName = 'source_' + Date.now().toString() +
      (origFileName.length > 0 ? '_' + origFileName : '') + '.js'
    const destPath = dirPath + '/' + fileName
    const fd = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    const encoder = new util.TextEncoder()
    const data = encoder.encode(content)
    fileIo.writeSync(fd.fd, data.buffer)
    fileIo.closeSync(fd)

    // 创建模型
    const model = new AudioSourceModel()
    model.id = 'src_' + Date.now().toString() + '_' + Math.floor(Math.random() * 10000).toString()
    model.name = meta.name.length > 0 ? meta.name : (origFileName || '未知音源')
    model.version = meta.version
    model.source = source
    model.url = sourceUrl
    model.filePath = destPath
    model.enabled = false
    model.importedAt = Date.now()
    model.description = meta.description

    // 持久化
    const all = await this.db.getAll()
    all.push(model)
    await this.db.saveAll(all)

    return { success: true, message: '导入成功', model: model }
  }

  // ==================== JSDoc 解析 ====================

  /**
   * 从脚本头部注释提取元数据
   * 支持 LX Music 块注释格式：
   *   /*
   *    * @name 音源名称
   *    * @version 1.0.0
   *    * @description 描述
   *    *\u002f
   * 和行注释格式：
   *   // @name 音源名称
   */
  static parseScriptMeta(content: string): Record<string, string> {
    const result: Record<string, string> = {}
    result['name'] = ''
    result['version'] = ''
    result['author'] = ''
    result['description'] = ''
    const metaRe = /^\s?[*\s]*@(\w+)\s+(.+)$/gm

    // 优先匹配块注释 /* ... */
    const blockRe = /\/\*[\s\S]*?\*\//
    const blockMatch = content.match(blockRe)
    if (blockMatch) {
      const block = blockMatch[0]
      let m = metaRe.exec(block)
      while (m !== null) {
        const key = m[1].toLowerCase()
        const val = m[2].trim()
        if (key === 'name' && val.length <= 24) {
          result['name'] = val
        } else if (key === 'version' && val.length <= 36) {
          result['version'] = val
        } else if (key === 'author' && val.length <= 56) {
          result['author'] = val
        } else if (key === 'description' && val.length <= 36) {
          result['description'] = val
        }
        m = metaRe.exec(block)
      }
    }

    // 回退：行注释 // @key value
    if (result['name'].length === 0) {
      const lines = content.split('\n')
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()
        if (line.startsWith('// @')) {
          const parts = line.substring(3).split(/\s+/)
          const key = parts[0].toLowerCase()
          const val = parts.slice(1).join(' ').trim()
          if (key === 'name' && val.length <= 24 && result['name'].length === 0) {
            result['name'] = val
          } else if (key === 'version' && val.length <= 36 && result['version'].length === 0) {
            result['version'] = val
          } else if (key === 'author' && val.length <= 56 && result['author'].length === 0) {
            result['author'] = val
          } else if (key === 'description' && val.length <= 36 && result['description'].length === 0) {
            result['description'] = val
          }
        }
        if (line.startsWith('//') === false && line.length > 0) {
          break // 离开连续注释区
        }
      }
    }

    return result
  }

  // ==================== 激活切换 ====================

  /**
   * 互斥激活：同一时间只有一个音源 enabled=true
   */
  async toggleEnabled(id: string, enabled: boolean): Promise<void> {
    const all = await this.db.getAll()
    let changed = false
    for (let i = 0; i < all.length; i++) {
      if (enabled && all[i].id !== id && all[i].enabled) {
        all[i].enabled = false
        changed = true
      }
      if (all[i].id === id && all[i].enabled !== enabled) {
        all[i].enabled = enabled
        changed = true
      }
    }
    if (changed) {
      await this.db.saveAll(all)
    }
  }

  // ==================== 删除 ====================

  /**
   * 删除音源：清理文件 + 持久化移除记录
   */
  async deleteSource(id: string): Promise<void> {
    const all = await this.db.getAll()
    const newList: AudioSourceModel[] = []
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        // 删除沙箱中的脚本文件
        try {
          fileIo.unlinkSync(all[i].filePath)
        } catch (_) {
          // 文件可能已不存在
        }
        // 不加入新列表 = 删除
      } else {
        newList.push(all[i])
      }
    }
    if (newList.length !== all.length) {
      await this.db.saveAll(newList)
    }
  }

  // ==================== 获取激活脚本 ====================

  /** 获取当前激活的音源脚本内容 */
  async getActiveScript(): Promise<ActiveScriptResult | null> {
    const all = await this.db.getAll()
    for (let i = 0; i < all.length; i++) {
      if (all[i].enabled) {
        const content: string = fileIo.readTextSync(all[i].filePath)
        return { model: all[i], content: content }
      }
    }
    return null
  }

  // ==================== 工具 ====================

  /** 从 URL 提取域名 */
  private extractDomain(url: string): string {
    const idx = url.indexOf('://')
    if (idx >= 0) {
      const after = url.substring(idx + 3)
      const slashIdx = after.indexOf('/')
      return slashIdx >= 0 ? url.substring(0, idx + 3 + slashIdx) : url
    }
    return url
  }
}
