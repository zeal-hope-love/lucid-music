/*
 * Lucid Music - 时间格式化工具
 */

/**
 * 秒数转换为 mm:ss 格式
 * @param seconds 秒数
 * @returns 格式化后的时间字符串，如 "3:06"
 */
export function formatDuration(seconds: number): string {
  if (seconds < 0 || !isFinite(seconds)) {
    return '00:00'
  }
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins}:${secs.toString().padStart(2, '0')}`
}
