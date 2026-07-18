---
name: fix-eapi-ecb-pkcs7-padding
overview: 将 eapi ECB 加密从 NoPadding+zeroPad 改为 PKCS7 padding，对齐 lx-music-mobile Java 层 Cipher.getInstance("AES") 的实际行为（默认 PKCS5Padding）。
todos:
  - id: fix-ecb-pkcs7
    content: MusicApiUtils.ets：aesEcbEncryptBase64 改用 AES128|ECB|PKCS7，去掉 zeroPad，删除零填充函数
    status: completed
  - id: verify-build
    content: 编译验证，运行后检查热搜是否正常
    status: completed
    dependencies:
      - fix-ecb-pkcs7
---

## 问题
eapi 热搜请求返回 `httpCode=200, resultLen=0`，加密后的数据服务端无法解密。

## 根因
lx-music-mobile 中 `AES_MODE.ECB_128_NoPadding` 枚举值实际为 `'AES'`，传入 Java `Cipher.getInstance("AES")` 后等同于 `AES/ECB/PKCS5Padding`（即 PKCS7 填充）。

HarmonyOS 端当前使用 `AES128|ECB|NoPadding` + 手动 `zeroPad` 零填充，产生的密文与服务端期望的 PKCS7 填充密文完全不同，导致服务端解密失败返回空响应。

## 修复目标
将 AES-ECB 加密模式从 NoPadding+零填充改为 PKCS7，对齐 lx-music-mobile 实际行为。

## 实现方案
修改 `MusicApiUtils.ets` 中 `aesEcbEncryptBase64` 函数：

**修改前（第 67-70 行）：**
```typescript
const cipher = cryptoFramework.createCipher('AES128|ECB|NoPadding')
await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null!)
const padded = zeroPad(plain)
const out = await cipher.doFinal({ data: padded })
```

**修改后：**
```typescript
const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null!)
const out = await cipher.doFinal({ data: plain })
```

仅 `aesEcbEncryptBase64` 被 eapi 使用，不影响 weapi（weapi 走独立的 CBC 路径）。

## 修改文件
- `features/search/src/main/ets/service/MusicApiUtils.ets`
  - 第 67 行：`AES128|ECB|NoPadding` → `AES128|ECB|PKCS7`
  - 第 69-70 行：删除 `zeroPad` 调用，直接将 `plain` 传入 `doFinal`
  - 第 44-50 行：删除不再使用的 `zeroPad` 函数
