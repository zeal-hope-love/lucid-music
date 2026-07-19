/*
 * mg/comment.ets - 咪咕音乐评论
 * 对齐 lx-music-mobile mg/comment.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, CommentItem } from 'musicbasic'
import type { CommentResult } from '../types'

const TAG = 'MgMusicApi'

export async function getComment(songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
  const empty: CommentResult = { source: 'mg', comments: [], total: 0, page, limit, maxPage: 1 }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM3.0/user/comment/stack/v1.0?pageSize=${limit}&queryType=1&resourceId=${songmid}&resourceType=2&commentId=`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `mg getComment http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== '000000') { Logger.warn(TAG, `mg getComment err: code=${body['code']}`); return empty }
    const data = body['data'] as Record<string, Object>
    const total = parseInt((data['commentNums'] as string) || '0') || 0
    return {
      source: 'mg',
      comments: filterComment((data['comments'] as Record<string, Object>[]) || []),
      total,
      page,
      limit,
      maxPage: Math.ceil(total / limit) || 1
    }
  } catch (e) {
    Logger.error(TAG, `mg getComment err: ${JSON.stringify(e)}`)
    return empty
  }
}

function formatTimeStr(ts: string): string {
  if (!ts) { return '' }
  const d = new Date(Number(ts))
  if (isNaN(d.getTime())) { return '' }
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function filterComment(rawList: Record<string, Object>[]): Array<CommentItem> {
  return rawList.map((item: Record<string, Object>) => {
    const data = new CommentItem()
    data.id = String(item['commentId'] as string)
    data.text = (item['commentInfo'] as string) || ''
    data.timeStr = formatTimeStr((item['commentTime'] as string) || '')
    const user = item['user'] as Record<string, Object> | undefined
    data.userName = (user?.['nickName'] as string) || ''
    data.avatar = (user?.['middleIcon'] as string) || (user?.['bigIcon'] as string) || (user?.['smallIcon'] as string) || ''
    data.userId = String(user?.['userId'] as string)
    const opNum = item['opNumItem'] as Record<string, Object> | undefined
    data.likedCount = (opNum?.['thumbNum'] as number) || 0
    const reply = item['replyComments'] as Record<string, Object>[] | undefined
    data.reply = reply ? reply.map(c => {
      const r = new CommentItem()
      r.id = String(c['replyId'] as string)
      r.text = (c['replyInfo'] as string) || ''
      r.timeStr = formatTimeStr((c['replyTime'] as string) || '')
      const ru = c['user'] as Record<string, Object> | undefined
      r.userName = (ru?.['nickName'] as string) || ''
      r.avatar = (ru?.['middleIcon'] as string) || ''
      r.userId = String(ru?.['userId'] as string)
      return r
    }) : []
    return data
  })
}
