---
name: fix-eapi-no-padding
overview: 去掉 EAPI 加密中错误的 PKCS7 Padding，改为 NoPadding 模式（对齐 lx-music-mobile），修复网易云封面获取
todos:
  - id: fix-eapi-zeropad
    content: MusicApiUtils.ets：将 pkcs7Pad 函数替换为 zeroPad 零填充，aesEcbEncryptBase64 第 84 行改为零填充调用
    status: completed
---

## 问题
网易云 EAPI 加密错误导致封面获取失败。lx-music-mobile 使用 AES-128-ECB-NoPadding，但我们的 `aesEcbEncryptBase64` 声明 NoPadding 后手动做了 PKCS7 padding，两种 padding 格式不同导致加密结果错误，网易云服务器无法解析。

## 根因
- PKCS7 padding：补 N 字节，每字节值为 N（如缺 3 字节则补 `0x03 0x03 0x03`）
- lx-music-mobile 实际行为：零填充（补 `0x00`）或输入恰好 16 字节对齐
- 两者产生的密文不同 → EAPI params 被服务器拒绝 → 封面返回空

## 修复
`MusicApiUtils.ets` 中：`pkcs7Pad` 函数替换为 `zeroPad`，补足到 16 字节边界时使用 `0x00` 而非 PKCS7 标志位。

## 修改文件
仅 `features/search/src/main/ets/service/MusicApiUtils.ets` 一处。

## 具体改动
用 `zeroPad` 函数替换 `pkcs7Pad` 函数（行 53-61），并在 `aesEcbEncryptBase64` 调用处（行 84）替换调用。

### zeroPad 实现
```typescript
function zeroPad(input: Uint8Array): Uint8Array {
  const blockSize = 16
  const remainder = input.length % blockSize
  if (remainder === 0) { return input }
  const padded = new Uint8Array(input.length + (blockSize - remainder))
  padded.set(input)
  // 省略显式置零——Uint8Array 构造器自动初始化为 0
  return padded
}
```

### 差异
| 行号 | 旧 | 新 |
|------|-----|-----|
| 53-61 | `pkcs7Pad`：补 `padLen` 值 | `zeroPad`：补 `0x00` |
| 84 | `pkcs7Pad(plainBytes)` | `zeroPad(plainBytes)` |

## 影响范围
- `pkcs7Pad` 虽被 export，但全项目仅 `aesEcbEncryptBase64` 内部使用，无外部调用方
- `zeroPad` 不 export，与 lx-music-mobile 行为对齐
- 不影响 QQ、酷狗等其他平台
