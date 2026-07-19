/*
 * tx/hotSearch.ets - QQ音乐热搜
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'
import { QQHotKeyBody } from './qqTypes'

const TAG = 'TxMusicApi'

export async function hotSearch(): Promise<string[]> {
  try {
    const body: QQHotKeyBody = { 'comm': { 'ct': '19', 'cv': '1803', 'guid': '0', 'patch': '118', 'psrf_access_token_expiresAt': 0, 'psrf_qqaccess_token': '', 'psrf_qqopenid': '', 'psrf_qqunionid': '', 'tmeAppID': 'qqmusic', 'tmeLoginType': 0, 'uin': '0', 'wid': '0' }, 'hotkey': { 'method': 'GetHotkeyForQQMusicPC', 'module': 'tencent_musicsoso_hotkey.HotkeyService', 'param': { 'search_id': '', 'uin': 0 } } }
    const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'Content-Type': 'application/json', 'Referer': 'https://y.qq.com/portal/player.html' }, extraData: JSON.stringify(body), connectTimeout: 5000, readTimeout: 5000 })
    if (resp.responseCode !== 200) { return [] }
    const data: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (data['code'] !== 0 || !data['hotkey']) { return [] }
    const hotData = (data['hotkey'] as Record<string, Object>)['data'] as Record<string, Object>
    const vecHotkey = hotData ? hotData['vec_hotkey'] as Record<string, Object>[] : []
    return vecHotkey ? vecHotkey.map(h => h['query'] as string).filter(Boolean) : []
  } catch (e) { Logger.error(TAG, `tx hotSearch error: ${JSON.stringify(e)}`); return [] }
}
