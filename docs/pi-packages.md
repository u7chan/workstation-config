# Pi Packages

このドキュメントは、Pi公式Package managerで導入するPackageの正本です。Packageの追加・更新時は、表のsource、要件、設定所有権、責務境界、検証手順を同時に確認します。

`personal`プロファイルで`personal_ai_tools`に`pi`が含まれる場合だけ、`update-ai --pi`がglobal user scopeへ導入・更新します。`base`ではPi本体もPackageも導入しません。Pi Package managerのnpm経路は、`~/.pi/agent/settings.json`の`npmCommand`を通じて次へ固定します。

```json
["mise", "exec", "node", "--", "safe-chain", "npm"]
```

現在の共通要件はNode.js `22.19.0`以上、Pi `0.84.2`以上です。Pi `0.84.2`は`@howaboua/pi-codex-conversion`のpeer dependencyに合わせています。Packageのバージョンは固定せず、Package managerの`install` / `update`で最新版を取得します。

| Source | 目的 / 提供tool | Upstream / 所有者 | Scope / 更新入口 | 要件 | 設定・runtime path | Safe-chain / 責務境界 | 更新時の検証 |
|---|---|---|---|---|---|---|---|
| `npm:pi-web-access` | Web access。`web_search`、`fetch_content`、`get_search_content`、`source_check` | `nicobailon/pi-web-access` / Pi Package managerが登録を所有 | `personal`かつPi選択時のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi` | 共通要件（Node `22.19+` / Pi `0.84.2+`） | 任意の`~/.pi/web-search.json`はユーザー管理。bootstrapは作成しない。API key、OAuth、cookie、cacheはruntime | `settings.json`の`npmCommand`からSafe-chain npmを使用。conversionの`web_run`を公開せず、Web機能は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、Pi起動後に4 toolの登録とzero-config検索を確認 |
| `npm:pi-codex-image-gen` | Codex loginを使う画像生成・編集。`codex_generate_image` | `jvm/pi-mono`の`packages/pi-codex-image-gen` / Pi Package managerが登録を所有 | `personal`かつPi選択時のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi` | Package固有のNode `20.6+`。共通要件はNode `22.19+` / Pi `0.84.2+` | 初期設定ファイルは作成しない。global出力は`~/.pi/agent/generated-images/`、project出力は`.pi/generated-images/`。生成画像とauth stateはGit管理しない | Safe-chain npm経路。conversionの`imagegen`を公開せず、画像生成・編集は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、tool登録、必要時に実画像生成と有効な出力形式・tracked files無変更を確認 |
| `npm:@howaboua/pi-codex-conversion` | Codex/GPT向けadapter。`exec_command`、`write_stdin`、`apply_patch`、`view_image`、prompt/tool adaptation | `IgorWarzocha/howaboua-pi-stuff`の`packages/pi-codex-conversion` / Pi Package managerが登録を所有 | `personal`かつPi選択時のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi` | Node `22.19+`。Pi関連peer dependencyは`0.84.2+`。x64/arm64 Linux native helperを含む | `~/.pi/agent/pi-codex-conversion.json`のうち`tools.webRun`、`imageGeneration`、`webRunOnly`、`imageGenerationOnly`の4キーだけを`update-ai`が管理。その他のキーは保持 | Safe-chain npm経路。4キーをfalseにしてconversionの`web_run` / `imagegen`を無効化し、Webは`pi-web-access`、画像生成は`pi-codex-image-gen`へ委譲。`view_image`は画像入力のため維持 | `./tests/pi-packages-smoke.sh`、Pi `0.84.1`拒否 / `0.84.2`受理の境界、Codex sessionでnative helperとtool surfaceを確認 |

## 更新・検証手順

1. `personal`プロファイルでPiを選択した状態で`./bootstrap`または`update-ai --pi`を実行する。
2. `pi list --no-approve`で3 sourceが各1件のuser packageとして登録されていることを確認する。
3. `./tests/pi-packages-smoke.sh`、`./tests/ai-clis-smoke.sh`、`./tests/static.sh`を実行する。
4. 実環境では、新しいPi Codex sessionでconversionの`exec_command`、`apply_patch`、`write_stdin`、`view_image`と、専用PackageのWeb/image toolの共存を確認する。認証・外部backend・native helperを使う確認はCIの必須条件にしない。

`settings.json`、各Packageの登録、`~/.pi/agent/npm/`はPiまたは`update-ai`の担当です。chezmoiはこれらのruntimeを管理しません。Package追加時はこの表と`docs/roles-boundary.md`の責務分界を更新し、Safe-chainの経路と未管理設定の保持をテストで固定します。
