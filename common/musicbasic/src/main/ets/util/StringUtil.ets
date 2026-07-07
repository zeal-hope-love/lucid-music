/*
 * Lucid Music - 字符串工具类
 * 关键词标红、截断等纯函数
 */

/** 高亮片段类型 */
interface HighlightSegment {
  text: string
  isHighlight: boolean
}

/**
 * 将匹配到的关键词包装为高亮标记（用于 Span 逐段渲染）
 * @param text 原始文本
 * @param keyword 搜索关键词
 * @returns 高亮后的片段数据数组
 */
export function splitHighlightKeyword(text: string, keyword: string): HighlightSegment[] {
  if (!keyword || keyword.trim().length === 0) {
    const seg: HighlightSegment = { text: text, isHighlight: false }
    return [seg]
  }

  const result: HighlightSegment[] = []
  const lowerText: string = text.toLowerCase()
  const lowerKeyword: string = keyword.toLowerCase()
  let lastIndex: number = 0
  let matchIndex: number = lowerText.indexOf(lowerKeyword, lastIndex)

  while (matchIndex !== -1) {
    if (matchIndex > lastIndex) {
      const nonMatch: HighlightSegment = {
        text: text.substring(lastIndex, matchIndex),
        isHighlight: false
      }
      result.push(nonMatch)
    }
    const match: HighlightSegment = {
      text: text.substring(matchIndex, matchIndex + keyword.length),
      isHighlight: true
    }
    result.push(match)

    lastIndex = matchIndex + keyword.length
    matchIndex = lowerText.indexOf(lowerKeyword, lastIndex)
  }

  if (lastIndex < text.length) {
    const remaining: HighlightSegment = {
      text: text.substring(lastIndex),
      isHighlight: false
    }
    result.push(remaining)
  }

  if (result.length === 0) {
    const seg: HighlightSegment = { text: text, isHighlight: false }
    return [seg]
  }
  return result
}

/**
 * 截断文本并追加省略号
 * @param text 原始文本
 * @param maxLen 最大字符数
 * @returns 截断后的文本
 */
export function trimAndEllipsis(text: string, maxLen: number): string {
  if (!text || text.length <= maxLen) {
    return text
  }
  return text.substring(0, maxLen) + '...'
}
