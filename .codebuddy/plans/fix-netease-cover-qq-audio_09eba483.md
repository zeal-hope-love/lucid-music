---
name: fix-netease-cover-qq-audio
overview: 修复网易云封面获取（对齐 lx-music 的 EAPI 加密实现）和 QQ 音频请求失败问题（对齐 MusicHome 的日志和响应处理）。
todos:
  - id: rewrite-eapi-encrypt
    content: 重写 MusicApiUtils.ets 的 eapiEncrypt 和 aesEcbEncrypt，对齐 lx-music 完整 base64→AES→base64→hex 流程
    status: completed
  - id: enhance-tx-logs
    content: 增强 TxMusicApi.ets 的 tryJson/tryForm/extractUrl 诊断日志，修复 catch(_) 吞异常问题
    status: completed
---

## 问题背景
两个运行时功能缺陷需要修复：
1. 网易云音乐封面图片获取失败
2. QQ 音乐音频播放 URL 请求失败

## 修复目标

### 网易云封面
当前 EAPI 加密实现与 lx-music 官方实现存在关键差异 — 缺少明文 base64 编码和密文 base64 解码两个步骤。对齐 lx-music 的完整加密流程，使封面 API（`/api/song/detail`）能正确返回 `al.picUrl`。

### QQ 音频
当前 TxMusicApi 的请求结构与 MusicHome 参考实现一致，但缺乏诊断日志和详细的错误处理。增强日志输出以捕获实际失败原因（HTTP 状态码、响应内容、各阶段返回值），便于定位根因。

## 技术方案

### 根因分析

#### 网易云 EAPI 加密缺陷

lx-music EAPI 完整流程（4 步）：
```
plain → base64编码 → AES加密 → base64解码 → hex输出
```

当前 lucid_music 实现（仅 2 步，跳过了两个 base64 转换）：
```
plain → buffer.from(utf-8) → AES加密 → hex输出
```

两者的密文完全无法匹配，导致网易云 API 服务器解密失败，封面接口返回错误。

#### QQ 音频
请求结构经与 MusicHome 逐行对比，确认一致。问题可能在运行时环境差异（网络/超时/响应格式），当前 `catch (_)` 吞掉异常导致无法诊断。需补齐日志覆盖全部失败路径。

### 修改方案

#### 1. 重写 `aesEcbEncrypt` + `eapiEncrypt`（MusicApiUtils.ets）

**`aesEcbEncrypt` 改为接收/返回 base64 字符串：**
- 输入：base64 编码的明文
- 内部：base64 解码 → 字节 → PKCS7 填充 → AES-ECB 加密 → base64 编码
- 输出：base64 密文

**`eapiEncrypt` 对齐 lx-music 完整流程：**
1. 构建 `plain = url + '-36cd479b6b5-' + jsonStr + '-36cd479b6b5-' + md5Hex`
2. `plain` → base64 编码（`util.Base64Helper`）
3. 调用 `aesEcbEncrypt(base64plain)` → base64 密文
4. base64 密文 → base64 解码 → 字节 → hex 大写输出

#### 2. 增强 TxMusicApi 日志（TxMusicApi.ets）

参照 MusicHome 模式，在以下位置补充日志：
- `tryJson` / `tryForm`：打印 HTTP 状态码和响应内容前 300 字符
- `extractUrl`：打印各层的 code、keys、midurlinfo、purl 值
- 异常处理：`catch` 中打印异常消息而非静默吞掉

### 数据流

```
┌─ eapiEncrypt(url, data) ──────────────────────────┐
│ 1. jsonStr = JSON.stringify(data)                  │
│ 2. digest = md5Hex("nobody" + url + "use" + ...)   │
│ 3. plain = url + "-36cd479b6b5-" + jsonStr + ...  │
│ 4. b64plain = Base64Helper.encode(plain)           │  ← 新增
│ 5. b64cipher = aesEcbEncrypt(b64plain)             │  ← 修改
│ 6. bytes = Base64Helper.decode(b64cipher)          │  ← 新增
│ 7. hex = bytesToHexUpper(bytes)                    │
│ 8. return hex                                      │
└────────────────────────────────────────────────────┘
```

## 实现细节

### 目录结构
仅修改现有文件，不新增文件：

```
features/search/src/main/ets/service/
├── MusicApiUtils.ets    # [MODIFY] 重写 eapiEncrypt 和 aesEcbEncrypt
├── platform/
│   └── TxMusicApi.ets   # [MODIFY] 增强 tryJson/tryForm/extractUrl 日志
```

### 修改点摘要

**MusicApiUtils.ets（核心修改）：**
- 删除现有 `aesEcbEncrypt`（76-89行），重写为接收/返回 base64 的版本
- 重写 `eapiEncrypt`（92-98行），插入缺失的 base64 编解码步骤
- 由于 `aesEcbEncrypt` 是私有函数，不影响其他模块

**TxMusicApi.ets（辅助修改）：**
- `tryJson`：在 HTTP 请求后打印 `responseCode` 和 `rawResp.substring(0, 300)`
- `tryForm`：同上
- `extractUrl`：在 `midurlinfo` 空、`purl` 空时打印诊断信息
- `catch` 块：从 `catch (_)` 改为 `catch (e)` 并打印错误消息

### 性能与可靠性
- 新增两个 base64 转换操作，均为 O(n) 复杂度，不影响请求时长的数量级
- 日志输出使用 `Logger.info/warn`，复用项目已有的日志基础设施
- 不引入新的依赖或接口变更，向后完全兼容
