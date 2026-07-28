# MySurge

面向 Surge iOS 的个人净化模块清单。项目只维护经过筛选的安装入口和少量自有引用模块，不保存代理节点、订阅、MITM 证书，也不复制第三方模块正文。

安装页：<https://vpromise.github.io/MySurge/>

## 模块清单

| 顺序 | 功能 | 来源 | 说明 |
|---:|---|---|---|
| 1 | 微博净化 | Yfamilys | 信息流、开屏及界面净化 |
| 2 | 微信公众号净化 | Yfamilys | 公众号文章广告 |
| 3 | 微信小程序净化 | QingRex | 小程序与相关页面广告 |
| 4 | 哔哩哔哩净化 | app2smile | 开屏、推荐、动态和播放页 |
| 5 | B 站 1080P | Yfamilys | 独立功能增强，可单独关闭 |
| 6 | YouTube 净化 | Maasea | 广告净化、画中画和后台播放 |
| 7 | 知乎净化 | Yfamilys | 列表广告及页面精简 |
| 8 | 小红书净化 | QingRex | 开屏、信息流和搜索页 |
| 9 | 12306 净化 | QingRex | 开屏和页面广告 |
| 10 | 滴滴出行净化 | QingRex | 页面活动和广告入口 |
| 11 | 高德地图净化 | QingRex | 使用通过 Surge 检查的转换版本 |
| 12 | 闲鱼净化 | QingRex | 开屏、首页和搜索页 |
| 13 | 菜鸟净化 | QingRex | 首页及相关页面 |
| 14 | 什么值得买净化 | QingRex | 开屏、首页和搜索页 |
| 15 | Vvebo 时间线修复 | QingRex | 与“微博净化”互斥，见下方说明 |
| 16 | 开屏及 URL 补漏 | Yfamilys | 通用 `AdBlock.module`，最后启用 |
| 17 | 广告规则拦截 | Yfamilys | 自有小模块引用 `AdvertisingLite.list` |

所有实际 URL、分类和冲突关系以 [`manifest.json`](manifest.json) 为准。

## 安装

1. 在 iPhone 或 iPad 上打开安装页。
2. 先安装对应 App 的专用模块，并逐个启动 App 验证。
3. 再安装 B 站 1080P 等功能增强模块。
4. 最后安装“开屏及 URL 补漏”和“广告规则拦截”。
5. 在 Surge iOS 中生成并安装自己的 MITM CA，启用 MITM、脚本和 URL Rewrite。

不要从 Quantumult X 配置复制 `p12` 或证书口令。Surge 应使用设备内自行生成并明确信任的 CA。

## 已知冲突

- “微博净化”和“Vvebo 时间线修复”都会处理 `api.weibo.cn` 的用户时间线接口。两者可以都安装，但不要同时启用。使用官方微博时启用“微博净化”；使用 Vvebo 时停用它并启用 Vvebo 修复。
- “开屏及 URL 补漏”覆盖面较广。如果出现登录、支付、图片或页面异常，先停用该模块，再停用对应 App 的专用模块。
- B 站净化与 B 站 1080P 已拆分为两个入口，便于独立排错。

## 来源策略

- Yfamilys 是本项目认可的主要聚合来源。
- Yfamilys 当前无法通过 Surge 6.7.0 检查的模块不直接安装；改用同一脚本的原始上游或已经通过检查的 QingRex 转换版本。
- 本项目不重新分发第三方模块，只保存远程安装地址。第三方内容及更新仍由各自作者维护。

## 本地验证

需要 macOS 上已安装 Surge：

```sh
./scripts/validate.sh
```

脚本会下载所有远程模块、检查 HTTP 内容类型、调用 Surge 官方检查器逐项验证，并验证组合配置和敏感信息边界。
