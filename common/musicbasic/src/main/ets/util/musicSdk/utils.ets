/*
 * musicSdk/utils - 通用工具函数
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer, util } from '@kit.ArkTS'

// ===== 平台ID转换 =====
export function platformToId(platform: string): string {
  const m: Record<string, string> = { 'kugou': 'kg', 'qq': 'tx', 'netease': 'wy', 'kuwo': 'kw', 'migu': 'mg' }
  return m[platform] || platform
}

// ===== 时长格式化 =====
export function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0 || !isFinite(seconds)) { return '--:--' }
  const s = Math.floor(seconds)
  const m = Math.floor(s / 60)
  const h = Math.floor(m / 60)
  if (h > 0) {
    return `${h}:${String(m % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
  }
  return `${m}:${String(s % 60).padStart(2, '0')}`
}

// ===== 播放量格式化 =====
export function formatPlayCount(count: number): string {
  if (!count || count <= 0) { return '0' }
  if (count >= 100000000) {
    return (count / 100000000).toFixed(1) + '亿'
  }
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万'
  }
  return String(count)
}

// ===== 文件大小格式化 =====
export function formatSize(bytes: number): string {
  if (!bytes || bytes <= 0) { return '0 B' }
  const units = ['B', 'KB', 'MB', 'GB']
  let i = 0
  let size = bytes
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024
    i++
  }
  return size.toFixed(i === 0 ? 0 : 1) + ' ' + units[i]
}

// ===== SHA1哈希 =====
export async function sha1Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA1')
  await md.update({ data: new Uint8Array(buffer.from(input, 'utf-8').buffer) })
  const r = await md.digest()
  let h = ''
  for (const b of r.data) { h += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16) }
  return h
}

// ===== 随机字符串 =====
export function randomStr(length: number): string {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  let result = ''
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
}

// ===== 字节数组转十六进制（小写） =====
export function bytesToLowerHex(bytes: Uint8Array): string {
  let h = ''
  for (const b of bytes) { h += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16) }
  return h
}
