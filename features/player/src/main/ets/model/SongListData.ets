/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { SongItem } from "../viewmodel/SongData"

const songList: SongItem[] = [
  {
    id: 1,
    title: $r('app.string.song_title_one'),
    singer: $r('app.string.singer_one'),
    mark: $r('app.media.ic_vip'),
    label: $r('app.media.ic_dream'),
    src: 'Delacey - Dream It Possible.flac',
    index: 0,
    lyric: 'lrcfiles/DreamItPossible.lrc',
    isDarkBackground: true,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 2,
    title: $r('app.string.song_title_two'),
    singer: $r('app.string.singer_two'),
    mark: $r('app.media.ic_sq'),
    label: $r('app.media.ic_avatar2'),
    src: 'world.wav',
    index: 1,
    lyric: '',
    isDarkBackground: false,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 3,
    title: $r('app.string.song_title_three'),
    singer: $r('app.string.singer_three'),
    mark: $r('app.media.ic_vip'),
    label: $r('app.media.ic_avatar2'),
    src: 'power.wav',
    index: 2,
    lyric: '',
    isDarkBackground: true,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 4,
    title: $r('app.string.song_title_four'),
    singer: $r('app.string.singer_four'),
    mark: $r('app.media.ic_sq'),
    label: $r('app.media.ic_avatar4'),
    src: 'power.wav',
    index: 3,
    lyric: '',
    isDarkBackground: true,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 5,
    title: $r('app.string.song_title_five'),
    singer: $r('app.string.singer_five'),
    mark: $r('app.media.ic_vip'),
    label: $r('app.media.ic_avatar5'),
    src: 'world.wav',
    index: 4,
    lyric: '',
    isDarkBackground: false,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 6,
    title: $r('app.string.song_title_six'),
    singer: $r('app.string.singer_six'),
    mark: $r('app.media.ic_sq'),
    label: $r('app.media.ic_avatar6'),
    src: 'boisterous.wav',
    index: 5,
    lyric: '',
    isDarkBackground: true,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 7,
    title: $r('app.string.song_title_seven'),
    singer: $r('app.string.singer_seven'),
    mark: $r('app.media.ic_vip'),
    label: $r('app.media.ic_avatar5'),
    src: 'world.wav',
    index: 6,
    lyric: '',
    isDarkBackground: true,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 8,
    title: $r('app.string.song_title_eight'),
    singer: $r('app.string.singer_eight'),
    mark: $r('app.media.ic_sq'),
    label: $r('app.media.ic_avatar8'),
    src: 'power.wav',
    index: 7,
    lyric: '',
    isDarkBackground: false,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 9,
    title: $r('app.string.song_title_nine'),
    singer: $r('app.string.singer_nine'),
    mark: $r('app.media.ic_vip'),
    label: $r('app.media.ic_avatar9'),
    src: 'power.wav',
    index: 8,
    lyric: '',
    isDarkBackground: false,
    coverUrl: '',
    lyricText: ''
  },
  {
    id: 10,
    title: $r('app.string.song_title_ten'),
    singer: $r('app.string.singer_ten'),
    mark: $r('app.media.ic_sq'),
    label: $r('app.media.ic_avatar10'),
    src: 'world.wav',
    index: 9,
    lyric: '',
    isDarkBackground: false,
    coverUrl: '',
    lyricText: ''
  }
]

export { songList }
