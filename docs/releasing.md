# Codex Meter 发布指南

Codex Meter 使用 Sparkle 2 进行应用内更新。每个发布包都必须使用同一个 Ed25519 私钥签名，并与生成的 `appcast.xml` 一起上传到 GitHub Release。

## 一次性密钥配置

当前公钥已写入 `Resources/Info.plist`，对应的私钥保存在 macOS 登录钥匙串的 `codex-meter` 账户下。不要重新生成密钥，否则已安装版本将无法验证新更新。

把私钥备份到仓库以外的安全位置：

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account codex-meter \
  -x /path/outside/repository/codex-meter-sparkle-private-key
```

备份文件等同于更新签名密码，不得提交到 Git、上传到 Release 或发给他人。

## 发布一个版本

1. 同时递增 `CFBundleShortVersionString` 和 `CFBundleVersion`。
2. 运行：

   ```bash
   ./scripts/package-release.sh
   ```

3. 将脚本输出的三个文件上传到同一个 `v<version>` GitHub Release：

   - `CodexMeter-<version>-macOS.zip`
   - `CodexMeter-<version>-macOS.zip.sha256`
   - `appcast.xml`

`appcast.xml` 包含更新包的 Ed25519 签名，并且文件本身也会被签名。应用通过 GitHub 的 `releases/latest/download/appcast.xml` 稳定地址获取它。

## Developer ID 签名与 Apple 公证

Sparkle 可以让已经手动允许运行的 ad-hoc 版本在后续安全更新，但只有 Developer ID 签名和 Apple 公证才能合法消除首次下载时的 Gatekeeper 开发者警告。

首先把公证凭据保存到钥匙串：

```bash
xcrun notarytool store-credentials codex-meter-notary
```

然后使用 Developer ID 发布：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="codex-meter-notary" \
./scripts/package-release.sh
```

脚本会为应用和 Sparkle 辅助程序启用 Hardened Runtime，提交 ZIP 到 Apple 公证，将公证票据 staple 到 App，再生成最终更新包。

## 过渡说明

当前旧版本只会打开浏览器下载，所以第一个内置 Sparkle 的版本仍需用户手动安装一次。从该版本开始，后续版本才会走应用内更新链路。
