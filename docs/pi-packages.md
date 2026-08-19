# Pi Packages

このドキュメントは、Pi公式のPackage managerで導入するPackageの正本です。Packageを追加・更新するときは、表に記載したsource、要件、設定の所有権、責務境界、検証手順をまとめて確認します。

`personal`プロファイルで`personal_ai_tools`に`pi`が含まれる場合だけ、`update-ai --pi`がglobalのuser scopeへ導入・更新します。`base`ではPi本体もPackageも導入しません。Pi Package managerのnpm経路は、`~/.pi/agent/settings.json`の`npmCommand`で次のコマンドに固定します。

```json
["mise", "exec", "node", "--", "safe-chain", "npm"]
```

現在の共通要件は、Node.js `22.19.0`以上、Pi `0.84.2`以上です。Piの最低バージョンは、`@howaboua/pi-codex-conversion`のpeer dependency要件に合わせています。Packageのバージョンは固定せず、Package managerの`install` / `update`で最新版を取得します。

| Source | 目的 / 提供するtool | Upstream / 所有者 | 適用範囲 / 更新入口 | 要件 | 設定・runtime path | Safe-chain / 責務境界 | 更新時の検証 |
|---|---|---|---|---|---|---|---|
| `npm:pi-web-access` | Web access。`web_search`、`fetch_content`、`get_search_content`、`source_check` | `nicobailon/pi-web-access` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | 共通要件（Node `22.19+` / Pi `0.84.2+`） | 任意の`~/.pi/web-search.json`はユーザー管理。bootstrapでは作成しない。API key、OAuth、cookie、cacheはruntimeで管理 | `settings.json`の`npmCommand`からSafe-chain npmを使用。conversionの`web_run`は公開せず、Web機能は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、Pi起動後の4 toolの登録、zero-config検索を確認 |
| `npm:pi-codex-image-gen` | Codex loginを使う画像生成・編集。`codex_generate_image` | `jvm/pi-mono`の`packages/pi-codex-image-gen` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | Package固有のNode `20.6+`。共通要件はNode `22.19+` / Pi `0.84.2+` | `~/.pi/agent/extensions/codex-image-gen.json`はbootstrapで作成しない。globalの保存先は`~/.pi/agent/generated-images/`、projectの保存先は`.pi/generated-images/`。生成画像とauth stateはGit管理しない | Safe-chain npm経路を使用。conversionの`imagegen`は公開せず、画像生成・編集は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、tool登録、必要に応じた実画像生成、有効な出力形式、tracked filesに差分がないことを確認 |
| `npm:@howaboua/pi-codex-conversion` | Codex/GPT向けadapter。`exec_command`、`write_stdin`、`apply_patch`、`view_image`、prompt/tool adaptation | `IgorWarzocha/howaboua-pi-stuff`の`packages/pi-codex-conversion` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | Node `22.19+`。Pi関連peer dependencyは`0.84.2+`。x64/arm64向けのLinux native helperを含む | `~/.pi/agent/pi-codex-conversion.json`のうち、`tools.webRun`、`tools.imageGeneration`、`tools.webRunOnly`、`tools.imageGenerationOnly`の4キーだけを`update-ai`が管理し、その他のキーは保持 | Safe-chain npm経路を使用。4キーを`false`にしてconversionの`web_run` / `imagegen`を無効化し、Webは`pi-web-access`、画像生成は`pi-codex-image-gen`へ委譲。`view_image`は画像入力のため維持 | `./tests/pi-packages-smoke.sh`、Pi `0.84.1`の拒否 / `0.84.2`の受理を含む境界テスト、Codex sessionでnative helperとtool surfaceを確認 |

## 更新・検証手順

1. `personal`プロファイルでPiを選択した状態で、`./bootstrap`または`update-ai --pi`を実行する。
2. `pi list --no-approve`で、3つのsourceがそれぞれ1件ずつuser packageとして登録されていることを確認する。
3. `./tests/pi-packages-smoke.sh`、`./tests/ai-clis-smoke.sh`、`./tests/static.sh`を実行する。
4. 実環境では、新しいPi Codex sessionでconversionの`exec_command`、`apply_patch`、`write_stdin`、`view_image`と、専用Packageが提供するWeb/image toolの共存を確認する。認証・外部backend・native helperを使う確認はCIの必須条件にしない。

`settings.json`、各Packageの登録、`~/.pi/agent/npm/`はPiまたは`update-ai`が管理し、chezmoiはこれらのruntimeを管理しません。Packageを追加するときは、この表と`docs/roles-boundary.md`の責務分界を更新し、Safe-chainの経路と未管理設定の保持をテストで固定します。
