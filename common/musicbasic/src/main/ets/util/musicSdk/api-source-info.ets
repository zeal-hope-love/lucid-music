/*
 * api-source-info.ets - 各平台支持音质声明
 * 对齐 lx-music-mobile 的 supportQualitys
 */
export const supportQualitys: Record<string, Record<string, string>> = {
  'wy': { '128k': '标准', '320k': '高品质', 'flac': '无损', 'flac24bit': 'Hi-Res' },
  'tx': { '128k': '标准', '320k': '高品质', 'flac': '无损', 'flac24bit': 'Hi-Res' },
  'kg': { '128k': '标准', '320k': '高品质', 'flac': '无损', 'flac24bit': 'Hi-Res' },
  'kw': { '128k': '标准', '320k': '高品质', 'flac': '无损', 'flac24bit': 'Hi-Res' },
  'mg': { '128k': '标准', '320k': '高品质', 'flac': '无损', 'flac24bit': 'Hi-Res' }
}
