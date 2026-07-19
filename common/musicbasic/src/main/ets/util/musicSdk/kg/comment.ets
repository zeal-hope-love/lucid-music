/*
 * kg/comment.ets - 酷狗音乐评论
 * 对齐 lx-music-mobile kg/comment.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, CommentItem } from 'musicbasic'
import { signatureParams } from './utils/crypto'
import type { CommentResult } from '../types'

const TAG = 'KgMusicApi'

const MID = '16249512204336365674023395779019'
const CODE = 'fc4be23b4e972707f36b8a828a93ba8a'

export async function getComment(songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
  const empty: CommentResult = { source: 'kg', comments: [], total: 0, page, limit, maxPage: 1 }
  try {
    const hash = songmid
    const timestamp = Date.now()
    const params = `dfid=0&mid=${MID}&clienttime=${timestamp}&uuid=0&extdata=${hash}&appid=1005&code=${CODE}&schash=${hash}&clientver=11409&p=${page}&clienttoken=&pagesize=${limit}&ver=10&kugouid=0`
    const url = `http://m.comment.service.kugou.com/r/v1/rank/newest?${params}&signature=${await signatureParams(params)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.24' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `kg getComment http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['err_code'] !== 0) { Logger.warn(TAG, `kg getComment err: code=${body['err_code']}`); return empty }
    const total = (body['count'] as number) || 0
    return {
      source: 'kg',
      comments: filterComment((body['list'] as Record<string, Object>[]) || []),
      total,
      page,
      limit,
      maxPage: Math.ceil(total / limit) || 1
    }
  } catch (e) {
    Logger.error(TAG, `kg getComment err: ${JSON.stringify(e)}`)
    return empty
  }
}

function replaceAt(raw: string, atList: Record<string, Object>[]): string {
  let r = raw
  for (const atobj of atList) {
    r = r.replaceAll(`[at=${atobj['id']}]`, `@${atobj['name']} `)
  }
  return r
}

function filterComment(rawList: Record<string, Object>[]): Array<CommentItem> {
  return rawList.map((item: Record<string, Object>) => {
    const data = new CommentItem()
    data.id = String(item['id'] as number)
    const atList = item['atlist'] as Record<string, Object>[] | undefined
    const content = (item['content'] as string) || ''
    data.text = atList ? replaceAt(content, atList) : content
    const images = item['images'] as Record<string, Object>[] | undefined
    data.images = images ? images.map(i => i['url'] as string) : []
    data.location = (item['location'] as string) || ''
    data.timeStr = (item['addtime'] as string) || ''
    data.userName = (item['user_name'] as string) || ''
    data.avatar = (item['user_pic'] as string) || ''
    data.userId = String(item['user_id'] as number)
    const like = item['like'] as Record<string, Object> | undefined
    data.likedCount = like ? (like['likenum'] as number) || 0 : 0
    data.reply = []
    return data
  })
}
