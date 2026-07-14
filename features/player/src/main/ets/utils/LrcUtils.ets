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

import { util } from '@kit.ArkTS';
import { LrcEntry, Word } from '../viewmodel/LrcEntry';
import Logger from './LoggerAdapter';

const lrcLineRegex: RegExp = new RegExp('\\[\\d{2,}:\\d{2}((\\.|:)\\d{2,})\\]', 'g');
const lrcTimeRegex1: RegExp = new RegExp('\\[\\d{2,}', 'i');
const lrcTimeRegex2: RegExp = new RegExp('\\d{2}\\.\\d{2,}', 'i');

const krcLineRegex = new RegExp('\\[(\\d+),(\\d+)\\](.*)');
const krcWordRegex1 = new RegExp('<(\\d+),(\\d+),(\\d+)>([^<]*)', 'g');
const krcWordRegex2 = new RegExp('<(\\d+),(\\d+),(\\d+)>(.*)');

export async function getRawStringData(context: Context, rawFilePath: string): Promise<string> {
  let value = await context.resourceManager.getRawFileContent(rawFilePath);
  let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  let stringData = textDecoder.decodeToString(value, { stream: false });
  return stringData;
}

export function parseLrcLyric(text: string): Array<LrcEntry> {
  if (!text) {
    return [];
  }
  let lyric: string[] = text.split('\n');
  let lrc: LrcEntry[] = [];
  for (let i = 0; i < lyric.length; i++) {
    let lineTime = lyric[i].match(lrcLineRegex);
    let lineText = lyric[i].replace(lrcLineRegex, '');
    if (lineTime && lineText) {
      for (let j = 0; j < lineTime.length; j++) {
        let min = Number(String(lineTime[j].match(lrcTimeRegex1)).slice(1));
        let sec = Number.parseFloat(String(lineTime[j].match(lrcTimeRegex2)));
        let timeInSeconds = (min * 60 + sec) * 1000;
        lrc.push({
          lineStartTime: timeInSeconds,
          lineDuration: 0,
          lineWords: lineText,
          words: []
        });
      }
    }
  }
  if (lrc && lrc.length > 0) {
    lrc.sort((a, b) => {
      return a.lineStartTime - b.lineStartTime;
    })
    for (let i = 0; i < lrc.length; i++) {
      if (i === lrc.length - 1) {
        lrc[i].lineDuration = Number.MAX_VALUE;
      } else {
        lrc[i].lineDuration = lrc[i+1].lineStartTime - lrc[i].lineStartTime;
      }
    }
  } else {
    Logger.error('Failed to parse the lyrics.');
  }
  return lrc;
}

export function parseKrcLyric(lyricText: string): LrcEntry[] {
  const lines: string[] = lyricText.split('\n');
  const lyricLines: LrcEntry[] = [];

  for (const line of lines) {
    const matches = line.match(krcLineRegex);
    if (matches) {
      const lineStartTime = Number.parseInt(matches[1]);
      const lineDuration = Number.parseInt(matches[2]);
      const lineWordsText = matches[3];
      const words: Word[] = [];
      const wordsMatches = lineWordsText.match(krcWordRegex1);
      let lineWords: string = '';
      if (wordsMatches) {
        for (const wordMatch of wordsMatches) {
          const wordMatches = wordMatch.match(krcWordRegex2);
          if (wordMatches) {
            const wordStartTime = Number.parseInt(wordMatches[1]);
            const wordDuration = Number.parseInt(wordMatches[2]);
            const wordText = wordMatches[4];
            lineWords += wordText;
            words.push({
              text: wordText,
              wordStartTime: wordStartTime,
              duration: wordDuration
            });
          }
        }
      }
      lyricLines.push({
        lineStartTime: lineStartTime,
        lineDuration: lineDuration,
        lineWords: lineWords,
        words: words
      });
    }
  }
  lyricLines.sort((a, b) => {
    return a.lineStartTime - b.lineStartTime;
  })
  return lyricLines;
}

export function angleToRadian(angle: number): number {
  return angle * Math.PI / 180;
}
