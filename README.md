# MySurge

个人使用的 Surge iOS App 净化与功能增强模块。

安装页：<https://vpromise.github.io/MySurge/>

## 使用

1. 在 iPhone 或 iPad 上打开安装页。
2. 按需安装 App 专用模块，通用补漏最后启用。
3. 模块统一显示在 Surge 的 `vpromise` 分类中。

当前共 28 个模块，完整清单见 [`manifest.json`](manifest.json)。

## 维护

```sh
./scripts/sync.sh
./scripts/validate.sh
```

GitHub Actions 每周检查上游；有变化时自动创建更新 PR。

模块来源包括 Yfamilys、QingRex、fmz200、blackmatrix7、app2smile 和原始作者。
