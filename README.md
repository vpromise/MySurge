# MySurge

个人使用的 Surge iOS App 净化与功能增强模块。

安装页：<https://vpromise.github.io/MySurge/>

## 使用

1. 在 iPhone 或 iPad 上打开安装页。
2. 按需安装 App 专用模块，通用补漏最后启用。
3. 模块统一显示在 Surge 的 `vpromise` 分类中。

当前共 29 个模块，完整清单见 [`manifest.json`](manifest.json)。

微博国际版现名「微博轻享版」，使用独立的 `weibo-intl` 模块；不要与官方微博净化或 Vvebo 修复同时启用。当前引用 QingRex 的[轻享版模块](https://github.com/QingRex/LoonKissSurge/blob/main/Surge/微博轻享版去广告.sgmodule)，上游标注日期为 2025-07-09，覆盖 `weibointl.api.weibo.cn`、`api.weibo.cn`、`bootpreload.uve.weibo.com`，处理开屏、时间线、发现页和评论区广告。上游未声明具体 App 版本上限，尚未在真机验证最新版本。

高德模块改用 [Repcz / 可莉的原生重写](https://github.com/Repcz/Tool/blob/X/Surge/Module/Kelee/Amap_remove_ads.sgmodule)，上游标注日期为 2026-10-20，解决旧 `Amap_remove_ads.js` 返回 404 的问题。仅解密 `m5.amap.com`、`ai.amap.com`、`m5-zb.amap.com`、`center.amap.com`、`sns.amap.com`、`info.amap.com`，不再引用远程高德 JavaScript。高德及轻享版模块使用 Body Rewrite/JQ，需要支持该功能的 Surge 版本与授权；模块作者信息保持不变，Repcz 的 MIT 许可见 [`LICENSES/Repcz-MIT.txt`](LICENSES/Repcz-MIT.txt)。

## 其他源的替代候选

Yfamilys 在 GitHub 托管 runner 返回 403 时，现有任务保留已锁定快照；本地读取仍成功。本次保留这些模块的范围，候选差异如下，不能当作内容完全相同的镜像直接替换：

| 当前模块 | 候选 | 差异 |
| --- | --- | --- |
| 官方微博 | [zmqcherish 原始模块](https://github.com/zmqcherish/proxy-script/blob/main/weibo.sgmodule) | 同源脚本处理信息流、开屏；未包含现有自定义皮肤规则。 |
| 微信公众号 | [yjqiang 原始模块](https://github.com/yjqiang/surge_scripts/blob/main/modules/wechat/wechat.sgmodule) | 同样仅解密 `mp.weixin.qq.com`，处理 `getappmsgad`；脚本实现不同。 |
| 知乎 | [app2smile 原始模块](https://github.com/app2smile/rules/blob/master/module/zhihu.sgmodule) | 覆盖开屏、推荐流及回答广告；解密域名更少，未覆盖现有全部页面精简规则。 |
| 开屏补漏 | [ConnersHua 原始模块](https://github.com/ConnersHua/RuleGo/blob/master/Surge/Module/Block/Advertising.sgmodule) | 含通用广告路径匹配，覆盖和误伤范围与现有规则不同。 |
| AdvertisingLite | [blackmatrix7 规则集](https://github.com/blackmatrix7/ios_rule_script/blob/master/rule/Surge/AdvertisingLite/AdvertisingLite.list) | 可从 GitHub 直读，规则数量与内容不同，需要单独检查误伤。 |

## 维护

```sh
./scripts/sync.sh
python3 scripts/test-modules.py
./scripts/validate-ci.sh
./scripts/validate.sh
```

GitHub Actions 每周检查上游；有变化时自动创建更新 PR。
模块变更 PR 也会运行离线响应样例检查及公开资源校验。`validate.sh` 只检查隔离生成的配置文件，不加载配置。

模块来源包括 Yfamilys、QingRex、Repcz、fmz200、blackmatrix7、app2smile 和原始作者。
