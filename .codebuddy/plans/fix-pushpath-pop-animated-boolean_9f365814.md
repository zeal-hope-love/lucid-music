---
name: fix-pushpath-pop-animated-boolean
overview: "将 SearchPage.ets 和 HomePage.ets 中错误的 `{ animated: false }` 对象形式改回布尔值 `false`，修复编译错误。"
todos:
  - id: fix-searchpage-pop
    content: "将 SearchPage.ets:74 的 pop(undefined, { animated: false }) 改为 pop(false)"
    status: completed
  - id: fix-homepage-pushpath
    content: "将 HomePage.ets:45 的 pushPath(info, { animated: false }) 改为 pushPath(info, false)"
    status: completed
  - id: verify-build
    content: 执行编译验证，确认 ERROR 消除
    status: completed
    dependencies:
      - fix-searchpage-pop
      - fix-homepage-pushpath
---

## 需求
修正 NavPathStack `pushPath`/`pop` 方法的参数类型错误，消除编译 ERROR。

## 编译错误
```
ERROR: Argument of type '{ animated: boolean; }' is not assignable to parameter of type 'boolean'.
  At File: SearchPage.ets:74:42
```
HomePage.ets:45 处存在同类错误。

## 根因
在 lucid_music 使用的 API 版本中，`NavPathStack.pushPath` 和 `pop` 的第二个参数是 `boolean` 类型，不应传 `NavigationOptions` 对象。官方参考项目 `transitions-collection-master` 中全部使用布尔值形式，证实了 API 签名。

## 修改方案
将两处错误的 `{ animated: false }` 对象改为正确的布尔值 `false`。

### 具体修改

| 文件 | 行号 | 改前 | 改后 |
|------|------|------|------|
| `features/search/src/main/ets/view/SearchPage.ets` | 74 | `this.navPathStack.pop(undefined, { animated: false })` | `this.navPathStack.pop(false)` |
| `features/home/src/main/ets/view/HomePage.ets` | 45 | `pushPath(info, { animated: false })` | `pushPath(info, false)` |

### 验证
项目其余 6 处 `pushPath`/`pop` 调用均未使用 `{ animated: false }` 对象形式，无需修改。
