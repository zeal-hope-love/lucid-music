/*
 * Lucid Music - 联想建议数据模型
 */

export enum SuggestionType {
  SONG = 'song',
  ARTIST = 'artist',
  ALBUM = 'album'
}

@ObservedV2
export class SuggestionItem {
  @Trace text: string = ''
  @Trace type: SuggestionType = SuggestionType.SONG
  @Trace highlightText: string = ''

  constructor(text: string, type: SuggestionType = SuggestionType.SONG, highlightText: string = '') {
    this.text = text
    this.type = type
    this.highlightText = highlightText
  }
}
