---
name: fix-search-suggestions-and-netease-hotsearch
overview: 修复两个问题：(1) 网易云热门搜索 EAPI 加密密钥编码错误导致无法获取数据 (2) 搜索联想建议 API 返回空导致 UI 不显示建议
todos:
  - id: fix-eapi-key
    content: 修复 EAPI AES 密钥编码：第 51 行 buffer.from 的编码参数从 'base64' 改为 'utf-8'
    status: completed
  - id: fix-suggest-fallback
    content: 在 suggest() 中添加多平台降级回退链：当前平台失败后依次尝试 QQ→网易云→酷我→咪咕
    status: completed
---

## 问题
两个运行时 Bug（编译通过但功能不工作）：

### Bug1：搜索提示不显示
输入关键词后，搜索框下方的联想建议区域一片空白。根因是当前平台（酷狗）suggest API 可能不可用或返回空，`suggestions` 数组为空，`ForEach` 渲染空 Column。需要添加多平台降级回退链。

### Bug2：网易云热搜获取失败
EAPI 加密时 AES 密钥编码方式错误。`e82ckenh8dichen8` 是 16 字符明文密钥（恰好 16 字节 = AES-128 标准），却被以 base64 解码，导致密钥破坏、加密结果无效、网易云服务器拒绝请求。

## 修改范围
仅修改一个文件：`MusicApiService.ets`，两处改动：
1. 第 51 行：`'base64'` → `'utf-8'`
2. `suggest()` 方法：添加降级回退链


## 修复方案

### 修复1：EAPI 密钥编码（第 51 行）

```typescript
// 修改前（错误）
data: new Uint8Array(buffer.from(EAPI_KEY_BASE64, 'base64').buffer)

// 修改后（正确）
data: new Uint8Array(buffer.from('e82ckenh8dichen8', 'utf-8').buffer)
```

直接使用 `'utf-8'` 编码获取 16 字节密钥，与 lx-music-mobile 一致。

### 修复2：搜索联想降级回退链（第 174-190 行）

```typescript
public static async suggest(keyword: string, platform: string): Promise<SuggestionItem[]> {
  const pid = MusicApiService.platformToId(platform)
  // 主平台尝试
  const primary = await MusicApiService.suggestByPlatform(pid, keyword)
  if (primary.length > 0) return primary

  // 降级回退链：依次尝试其他平台
  const fallbackOrder = ['tx', 'wy', 'kw', 'mg'].filter(p => p !== pid)
  for (const fbPid of fallbackOrder) {
    const result = await MusicApiService.suggestByPlatform(fbPid, keyword)
    if (result.length > 0) return result
  }
  return []
}
```

新增私有方法 `suggestByPlatform(pid, keyword)` 封装 switch-case 分发逻辑，供主方法和降级链复用。

