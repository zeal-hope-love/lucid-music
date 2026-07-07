/*
 * Lucid Music - 平台枚举常量
 * 5 大平台标识及中文标签映射
 */
export enum Platform {
  KG = 'kg',
  TX = 'tx',
  WY = 'wy',
  KW = 'kw',
  MG = 'mg'
}

export const PlatformLabels: Record<Platform, string> = {
  [Platform.KG]: '酷狗',
  [Platform.TX]: 'QQ音乐',
  [Platform.WY]: '网易云',
  [Platform.KW]: '酷我',
  [Platform.MG]: '咪咕'
}

export const PlatformColors: Record<Platform, string> = {
  [Platform.KG]: '#FF6B35',
  [Platform.TX]: '#31C27C',
  [Platform.WY]: '#C62F2F',
  [Platform.KW]: '#FFD700',
  [Platform.MG]: '#E91E63'
}
