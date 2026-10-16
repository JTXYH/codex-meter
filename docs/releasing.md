# 发布 Codex Meter

Codex Meter 使用 Sparkle 2 检查更新。GitHub Release 必须同时包含安装包、SHA-256 校验文件和已签名的 `appcast.xml`。

## 分支与版本

- `V1.0` 保存升级到 2.0 前的线上 master，停留在 1.7.0 发布提交。
- `master` 维护 2.x。发布标签使用 `v2.0.0` 这样的语义版本。
- `Resources/Info.plist` 中的 `CFBundleShortVersionString` 是显示版本；`CFBundleVersion` 是更新排序使用的构建号，必须持续递增，不能在大版本升级时归零。

修改版本后，同步更新各语言 README 和 `docs/releases/` 下的发布说明。提交前运行 `swift test`，核对原生界面截图、文档链接和本次变更涉及的回归。

## 打包

```bash
./scripts/package-release.sh
```

脚本会先清空 `dist/` 的全部旧产物，再生成 Apple Silicon 与 Intel 通用应用、压缩包、校验文件和更新源。`dist/` 只存放可重新生成的产物，不要用于保存其他文件。

更新签名使用登录钥匙串 `codex-meter` 账户中的现有 Ed25519 私钥。公钥在 `Resources/Info.plist` 中。不要重新生成或提交私钥，否则已有用户可能无法验证更新。

生成的三个发布附件：

- `CodexMeter-<version>-macOS.zip`
- `CodexMeter-<version>-macOS.zip.sha256`
- `appcast.xml`

检查应用代码签名、通用架构、ZIP 完整性、SHA-256 以及安装包和更新源的 Ed25519 签名。签名后不要手工修改更新源。

## 发布到 GitHub

先推送完成验证的提交和对应版本标签，再创建 Release。附件全部上传并核对后，将其设为最新正式版本。发布说明使用 `docs/releases/v<version>.md`。

应用从下列稳定地址检查更新：

```text
https://github.com/JTXYH/codex-meter/releases/latest/download/appcast.xml
```

发布后核对下载附件、版本号、构建号和更新源 URL。旧 JSON 更新服务会自动读取最新 Release，无须重新部署。

## Developer ID 与 Apple 公证

未指定签名身份时，脚本生成 ad-hoc 签名应用；Sparkle 更新签名不等于 Apple 公证。发布说明应如实写明签名状态。

已有 Developer ID 和钥匙串公证配置时，可运行：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="codex-meter-notary" \
./scripts/package-release.sh
```

脚本会启用 Hardened Runtime、提交公证、附加公证票据，再生成最终安装包和更新签名。
