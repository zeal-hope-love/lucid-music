/*
 * wy/comment.ets - 网易云评论
 * 对齐 lx-music-mobile wy/comment.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, CommentItem } from 'musicbasic'
import { weapiRequest } from './utils/request'
import type { CommentResult, CursorCacheItem, CursorInfo } from '../types'

const TAG = 'WyMusicApi'

const emojis: Array<[string, string]> = [
  ['大笑', '😃'], ['可爱', '😊'], ['憨笑', '☺️'], ['色', '😍'], ['亲亲', '😙'],
  ['惊恐', '😱'], ['流泪', '😭'], ['亲', '😚'], ['呆', '😳'], ['哀伤', '😔'],
  ['呲牙', '😁'], ['吐舌', '😝'], ['撇嘴', '😒'], ['怒', '😡'], ['奸笑', '😏'],
  ['汗', '😓'], ['痛苦', '😖'], ['惶恐', '😰'], ['生病', '😨'], ['口罩', '😷'],
  ['大哭', '😂'], ['晕', '😵'], ['发怒', '👿'], ['开心', '😄'], ['鬼脸', '😜'],
  ['皱眉', '😞'], ['流感', '😢'], ['爱心', '❤️'], ['心碎', '💔'], ['钟情', '💘'],
  ['星星', '⭐️'], ['生气', '💢'], ['便便', '💩'], ['强', '👍'], ['弱', '👎'],
  ['拜', '🙏'], ['牵手', '👫'], ['跳舞', '👯‍♀️'], ['禁止', '🙅‍♀️'], ['这边', '💁‍♀️'],
  ['爱意', '💏'], ['示爱', '👩‍❤️‍👨'], ['嘴唇', '👄'], ['狗', '🐶'], ['猫', '🐱'],
  ['猪', '🐷'], ['兔子', '🐰'], ['小鸡', '🐤'], ['公鸡', '🐔'], ['幽灵', '👻'],
  ['圣诞', '🎅'], ['外星', '👽'], ['钻石', '💎'], ['礼物', '🎁'], ['男孩', '👦'],
  ['女孩', '👧'], ['蛋糕', '🎂'], ['18', '🔞'], ['圈', '⭕'], ['叉', '❌'],
]

function applyEmoji(text: string): string {
  let r = text
  for (const e of emojis) r = r.replaceAll(`[${e[0]}]`, e[1])
  return r
}

function formatTimeStr(ts: number): string {
  if (!ts) return ''
  const d = new Date(ts)
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// 评论游标缓存（对齐 lx cursorTools）
const cursorCache: Record<string, CursorCacheItem> = {}
function getCursor(id: string, page: number, limit: number): CursorInfo {
  let cacheData = cursorCache[id]
  if (!cacheData) cacheData = cursorCache[id] = { cursor: 0, prevCursor: 0, orderType: 1, offset: 0, page: 0 }
  let orderType: number, cursor: number, offset: number
  if (page == 1) {
    cacheData.page = 1
    cursor = cacheData.cursor = cacheData.prevCursor = Date.now()
    orderType = 1
    offset = 0
  } else if (cacheData.page) {
    cursor = cacheData.cursor
    if (page > cacheData.page) { orderType = 1; offset = (page - cacheData.page - 1) * limit }
    else if (page < cacheData.page) { orderType = 0; offset = (cacheData.page - page - 1) * limit }
    else { cursor = cacheData.cursor = cacheData.prevCursor; offset = cacheData.offset; orderType = cacheData.orderType }
  } else {
    cursor = Date.now(); orderType = 1; offset = 0
  }
  return { orderType, cursor, offset }
}
function setCursor(id: string, cursor: number, orderType: number, offset: number, page: number): void {
  const cacheData = cursorCache[id] || (cursorCache[id] = { cursor: 0, prevCursor: 0, orderType: 1, offset: 0, page: 0 })
  cacheData.prevCursor = cacheData.cursor
  cacheData.cursor = cursor
  cacheData.orderType = orderType
  cacheData.offset = offset
  cacheData.page = page
}

export async function getComment(songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
  const empty: CommentResult = { source: 'wy', comments: [], total: 0, page, limit, maxPage: 1 }
  try {
    const id = 'R_SO_4_' + songmid
    const cursorInfo = getCursor(songmid, page, limit)
    const body = await weapiRequest('comment/resource/comments/get', {
      cursor: cursorInfo.cursor,
      offset: cursorInfo.offset,
      orderType: cursorInfo.orderType,
      pageNo: page,
      pageSize: limit,
      rid: id,
      threadId: id,
    })
    if (!body || body['code'] !== 200) { Logger.warn(TAG, `wy getComment failed code=${body?.['code']}`); return empty }
    const data = body['data'] as Record<string, Object>
    setCursor(songmid, data['cursor'] as number, cursorInfo.orderType, cursorInfo.offset, page)
    const total = data['totalCount'] as number || 0
    return {
      source: 'wy',
      comments: filterComment(data['comments'] as Record<string, Object>[] || []),
      total,
      page,
      limit,
      maxPage: Math.ceil(total / limit) || 1,
    }
  } catch (e) {
    Logger.error(TAG, `wy getComment err: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterComment(rawList: Record<string, Object>[]): Array<CommentItem> {
  return rawList.map((item: Record<string, Object>) => {
    const data = new CommentItem()
    data.id = String(item['commentId'] as number)
    data.text = item['content'] ? applyEmoji(item['content'] as string) : ''
    data.time = (item['time'] as number) || 0
    data.timeStr = item['time'] ? formatTimeStr(item['time'] as number) : ''
    const ip = item['ipLocation'] as Record<string, Object> | undefined
    data.location = ip?.['location'] as string || ''
    const user = item['user'] as Record<string, Object>
    data.userName = (user?.['nickname'] as string) || ''
    data.avatar = (user?.['avatarUrl'] as string) || ''
    data.userId = String(user?.['userId'] as number)
    data.likedCount = (item['likedCount'] as number) || 0
    data.reply = []
    return data
  })
}
