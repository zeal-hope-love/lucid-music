/*
 * tx/comment.ets - QQ音乐评论
 * 对齐 lx-music-mobile tx/comment.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, CommentItem } from 'musicbasic'
import type { CommentResult } from '../types'

const TAG = 'TxMusicApi'

const emojis: Record<string, string> = {
  'e400846': '😘', 'e400874': '😴', 'e400825': '😃', 'e400847': '😙', 'e400835': '😍', 'e400873': '😳',
  'e400836': '😎', 'e400867': '😭', 'e400832': '😊', 'e400837': '😏', 'e400875': '😫', 'e400831': '😉',
  'e400855': '😡', 'e400823': '😄', 'e400862': '😨', 'e400844': '😖', 'e400841': '😓', 'e400830': '😈',
  'e400828': '😆', 'e400833': '😋', 'e400822': '😀', 'e400843': '😕', 'e400829': '😇', 'e400824': '😂',
  'e400834': '😌', 'e400877': '😷', 'e400132': '🍉', 'e400181': '🍺', 'e401067': '☕️', 'e400186': '🥧',
  'e400343': '🐷', 'e400116': '🌹', 'e400126': '🍃', 'e400613': '💋', 'e401236': '❤️', 'e400622': '💔',
  'e400637': '💣', 'e400643': '💩', 'e400773': '🔪', 'e400102': '🌛', 'e401328': '🌞', 'e400420': '👏',
  'e400914': '🙌', 'e400408': '👍', 'e400414': '👎', 'e401121': '✋', 'e400396': '👋', 'e400384': '👉',
  'e401115': '✊', 'e400402': '👌', 'e400905': '🙈', 'e400906': '🙉', 'e400907': '🙊', 'e400562': '👻',
  'e400932': '🙏', 'e400644': '💪', 'e400611': '💉', 'e400185': '🎁', 'e400655': '💰', 'e400325': '🐥',
  'e400612': '💊', 'e400198': '🎉', 'e401685': '⚡️', 'e400631': '💝', 'e400768': '🔥', 'e400432': '👑',
}

function replaceEmoji(msg: string): string {
  const result = msg.match(/\[em\]e\d+\[\/em\]/g)
  if (!result) return msg
  const uniq = Array.from(new Set(result))
  let r = msg
  for (const item of uniq) {
    const code = item.replace(/^\[em\](e\d+)\[\/em\]$/, '$1')
    r = r.replace(new RegExp(item.replace('[em]', '\\[em\\]').replace('[/em]', '\\[\\/em\\]'), 'g'), emojis[code] || '')
  }
  return r
}

function formatTime(time: number): number | null {
  return String(time).length < 10 ? null : parseInt(time + '000')
}

export async function getComment(songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
  const empty: CommentResult = { source: 'tx', comments: [], total: 0, page, limit, maxPage: 1 }
  try {
    const _requestObj = http.createHttp()
    const resp = await _requestObj.request('http://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg', {
      method: http.RequestMethod.POST,
      header: { 'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)' },
      extraData: `uin=0&format=json&cid=205360772&reqtype=2&biztype=1&topid=${songmid}&cmd=8&needmusiccrit=1&pagenum=${page - 1}&pagesize=${limit}`,
      connectTimeout: 8000, readTimeout: 8000,
    })
    if (resp.responseCode !== 200) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0) { return empty }
    const comment = body['comment'] as Record<string, Object>
    const commentlist = (comment['commentlist'] as Record<string, Object>[]) || []
    const total = (comment['commenttotal'] as number) || 0
    return {
      source: 'tx',
      comments: filterComment(commentlist),
      total,
      page,
      limit,
      maxPage: Math.ceil(total / limit) || 1,
    }
  } catch (e) {
    Logger.error(TAG, `tx getComment err: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterComment(rawList: Record<string, Object>[]): Array<CommentItem> {
  return rawList.map((item: Record<string, Object>) => {
    let time = formatTime(item['time'] as number)
    let timeStr: string = ''
    if (time) {
      const d = new Date(time)
      const pad = (n: number) => n.toString().padStart(2, '0')
      timeStr = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
    }
    const data = new CommentItem()
    data.id = `${item['rootcommentid']}_${item['commentid']}`
    data.text = item['rootcommentcontent'] ? replaceEmoji(item['rootcommentcontent'] as string).replace(/\\n/g, '\n') : ''
    data.time = time || 0
    data.timeStr = timeStr
    data.userName = item['rootcommentnick'] ? (item['rootcommentnick'] as string).substring(1) : ''
    data.avatar = (item['avatarurl'] as string) || ''
    data.userId = (item['encrypt_rootcommentuin'] as string) || ''
    data.likedCount = (item['praisenum'] as number) || 0
    data.reply = []
    return data
  })
}
