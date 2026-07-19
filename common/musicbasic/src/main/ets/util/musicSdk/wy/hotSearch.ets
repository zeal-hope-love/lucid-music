/*
 * wy/hotSearch.ets - 网易云热搜
 */
import { Logger } from 'musicbasic'
import { eapiRequest } from './utils/request'

const TAG = 'WyMusicApi'

export async function hotSearch(): Promise<string[]> {
  try {
    const body = await eapiRequest('/api/search/chart/detail', { id: 'HOT_SEARCH_SONG#@#' })
    if (body && body['code'] === 200 && body['data']) {
      const items = ((body['data'] as Record<string, Object>)['itemList'] as Record<string, Object>[])
        .map(h => h['searchWord'] as string).filter(Boolean)
      Logger.info(TAG, `wy hotSearch: ${items.length} items`)
      return items
    }
    Logger.warn(TAG, `wy hotSearch failed, code=${body?.['code']}`)
  } catch (e) { Logger.error(TAG, `wy hotSearch err: ${JSON.stringify(e)}`) }
  return []
}
