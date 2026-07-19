/*
 * kw/comment.ets - 酷我音乐评论
 * 对齐 lx-music-mobile kw/comment.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, CommentItem } from 'musicbasic'
import type { CommentResult } from '../types'

const TAG = 'KwMusicApi'

export async function getComment(songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
  const empty: CommentResult = { source: 'kw', comments: [], total: 0, page, limit, maxPage: 1 }
  try {
    const url = `http://ncomment.kuwo.cn/com.s?f=web&type=get_comment&aapiver=1&prod=kwplayer_ar_10.5.2.0&digest=15&sid=${songmid}&start=${limit * (page - 1)}&msgflag=1&count=${limit}&newver=3&uid=0`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `kw getComment http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] != '200') { Logger.warn(TAG, `kw getComment err: code=${body['code']}`); return empty }
    const total = (body['comments_counts'] as number) || 0
    return {
      source: 'kw',
      comments: filterComment((body['comments'] as Record<string, Object>[]) || []),
      total,
      page,
      limit,
      maxPage: Math.ceil(total / limit) || 1
    }
  } catch (e) {
    Logger.error(TAG, `kw getComment err: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterComment(rawList: Record<string, Object>[]): Array<CommentItem> {
  if (!rawList) { return [] }
  return rawList.map((item: Record<string, Object>) => {
    const data = new CommentItem()
    data.id = String(item['id'] as number)
    data.text = (item['msg'] as string) || ''
    data.timeStr = item['time'] ? formatTime(Number(item['time']) * 1000) : ''
    data.userName = (item['u_name'] as string) || ''
    data.avatar = (item['u_pic'] as string) || ''
    data.userId = String(item['u_id'] as number)
    data.likedCount = (item['like_num'] as number) || 0
    const mpic = item['mpic'] as string | undefined
    data.images = mpic ? [decodeURIComponent(mpic)] : []
    const child = item['child_comments'] as Record<string, Object>[] | undefined
    data.reply = child ? child.map(i => {
      const r = new CommentItem()
      r.id = String(i['id'] as number)
      r.text = (i['msg'] as string) || ''
      r.timeStr = i['time'] ? formatTime(Number(i['time']) * 1000) : ''
      r.userName = (i['u_name'] as string) || ''
      r.avatar = (i['u_pic'] as string) || ''
      r.userId = String(i['u_id'] as number)
      r.likedCount = (i['like_num'] as number) || 0
      const cm = i['mpic'] as string | undefined
      r.images = cm ? [cm] : []
      return r
    }) : []
    return data
  })
}

function formatTime(ts: number): string {
  if (!ts) { return '' }
  const d = new Date(ts)
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}
