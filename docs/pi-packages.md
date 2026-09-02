# Pi Packages

このドキュメントは、Pi公式のPackage managerで導入するPackageの正本です。Packageを追加・更新するときは、表に記載したsource、要件、設定の所有権、責務境界、検証手順をまとめて確認します。

`personal`プロファイルで`personal_ai_tools`に`pi`が含まれる場合だけ、`update-ai --pi`がglobalのuser scopeへ導入・更新します。`base`ではPi本体もPackageも導入しません。Pi Package managerのnpm経路は、`~/.pi/agent/settings.json`の`npmCommand`で次のコマンドに固定します。

```json
["mise", "exec", "node", "--", "safe-chain", "npm"]
```

現在の共通要件は、Node.js `22.19.0`以上、Pi `0.84.2`以上です。Piの最低バージョンは、`@howaboua/pi-codex-conversion`のpeer dependency要件に合わせています。`pi-session-recall` upstream自体の要件はNode.js `>=18.0.0` / Pi `v0.40+`ですが、workstationでは共通要件を適用します。Packageのバージョンは固定せず、Package managerの`install` / `update`で最新版を取得します。

| Source | 目的 / 提供するtool | Upstream / 所有者 | 適用範囲 / 更新入口 | 要件 | 設定・runtime path | Safe-chain / 責務境界 | 更新時の検証 |
|---|---|---|---|---|---|---|---|
| `npm:pi-web-access` | Web access。`web_search`、`fetch_content`、`get_search_content`、`source_check` | `nicobailon/pi-web-access` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | 共通要件（Node `22.19+` / Pi `0.84.2+`） | 非機密デフォルト（`~/.pi/web-search.json` の `workflow: "auto-summary"`）だけはchezmoiが`create`属性でPi選択時のみ配布（sourceは`home/dot_pi/create_web-search.json`）。既存ファイルは上書きしないため、API key等はユーザーが手動追加（runtime）。OAuth、cookie、cacheはruntimeで管理 | `settings.json`の`npmCommand`からSafe-chain npmを使用。conversionの`web_run`は公開せず、Web機能は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、`./tests/pi-web-search-smoke.sh`、Pi起動後の4 toolの登録、zero-config検索を確認 |
| `npm:pi-codex-image-gen` | Codex loginを使う画像生成・編集。`codex_generate_image` | `jvm/pi-mono`の`packages/pi-codex-image-gen` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | Package固有のNode `20.6+`。共通要件はNode `22.19+` / Pi `0.84.2+` | `~/.pi/agent/extensions/codex-image-gen.json`はbootstrapで作成しない。globalの保存先は`~/.pi/agent/generated-images/`、projectの保存先は`.pi/generated-images/`。生成画像とauth stateはGit管理しない | Safe-chain npm経路を使用。conversionの`imagegen`は公開せず、画像生成・編集は本Packageに委譲 | `./tests/pi-packages-smoke.sh`、tool登録、必要に応じた実画像生成、有効な出力形式、tracked filesに差分がないことを確認 |
| `npm:@howaboua/pi-codex-conversion` | Codex/GPT向けadapter。`exec_command`、`write_stdin`、`apply_patch`、`view_image`、prompt/tool adaptation | `IgorWarzocha/howaboua-pi-stuff`の`packages/pi-codex-conversion` / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | Node `22.19+`。Pi関連peer dependencyは`0.84.2+`。x64/arm64向けのLinux native helperを含む | `~/.pi/agent/pi-codex-conversion.json`のうち、`tools.webRun`、`tools.imageGeneration`、`tools.webRunOnly`、`tools.imageGenerationOnly`の4キーだけを`update-ai`が管理し、その他のキーは保持 | Safe-chain npm経路を使用。4キーを`false`にしてconversionの`web_run` / `imagegen`を無効化し、Webは`pi-web-access`、画像生成は`pi-codex-image-gen`へ委譲。`view_image`は画像入力のため維持 | `./tests/pi-packages-smoke.sh`、Pi `0.84.1`の拒否 / `0.84.2`の受理を含む境界テスト、Codex sessionでnative helperとtool surfaceを確認 |
| `npm:@ogulcancelik/pi-session-recall` | 過去sessionのオンデマンド検索・質問。`session_search`、`session_query` | [ogulcancelik/pi-extensions](https://github.com/ogulcancelik/pi-extensions/tree/main/packages/pi-session-recall) / 登録はPi Package managerが所有 | `personal`でPiを選択した場合のglobal user package。`bootstrap`、`myupdate`、`update-ai --pi`から更新 | upstreamはNode `>=18` / Pi `0.40+`。ripgrep (`rg`)を推奨（workstationの共通要件はNode `22.19+` / Pi `0.84.2+`） | `~/.pi/agent/sessions/**`はPiのglobal session JSONL、`~/.pi/agent/session-recall.json`はquery modelのユーザー設定。session、履歴、auth state、設定はGit管理しない | `session_search`はcurrent cwdではなく`~/.pi/agent/sessions`全体を`rg -i -F`でliteral / case-insensitive検索し、grep / Node scanへfallbackする。`session_query`は選択sessionのuser/assistantメッセージとtool callをquery modelへ送り、thinkingとtool outputは除外する。background indexing / vector DBは追加しない | `rg --version`、`./tests/pi-packages-smoke.sh`、同一・別project directoryのunique marker検索、`openai-codex` query modelの手動smokeを確認 |

`ripgrep`はこのPackageだけの一時依存ではありません。`session_search`はglobal sessions root配下の複数projectのJSONLを、literal fixed-stringかつcase-insensitiveでオンデマンド検索するため、`rg -i -F`を恒久的な優先backendにします。高速なCLIを共通の`base` / `personal`環境へmiseで配布し、同じ検索契約を開発環境で再現します。`provisioning/mise/config.toml`の`ripgrep = "latest"`とlockfileがworkstation側の導入元・検証版を定義します。

`rg`が使えない環境でも、Package upstreamのgrep、Node scan fallbackは残します。したがって`rg`は機能を壊さない絶対条件ではありませんが、workstationではglobal sessionを安定して検索するための標準経路です。CIの`ubuntu-slim`はbootstrapやmise installを実行しないため、`.github/workflows/ci.yml`のstatic jobでは`ansible-core`と一緒に`ripgrep`、`shellcheck`、`yamllint`、`ansible-lint`をAPTで導入します。`tests/static.sh`はmanaged tool設定だけでなく、実環境の`command -v rg`と`rg --version`も検証するため、CIでもこの恒久的なruntime契約を再現します。

## 更新・検証手順

1. `personal`プロファイルでPiを選択した状態で、`./bootstrap`または`update-ai --pi`を実行する。
2. `rg --version`が成功し、`pi list --no-approve`で、4つのsourceがそれぞれ1件ずつuser packageとして登録されていることを確認する。
3. `./tests/pi-packages-smoke.sh`、`./tests/ai-clis-smoke.sh`、`./tests/static.sh`を実行する。
4. 実環境では、新しいPi Codex sessionでconversionの`exec_command`、`apply_patch`、`write_stdin`、`view_image`と、専用Packageが提供するWeb/image/recall toolの共存を確認する。認証・外部backend・native helperを使う確認はCIの必須条件にしない。

`settings.json`、各Packageの登録、`~/.pi/agent/npm/`はPiまたは`update-ai`が管理し、chezmoiはこれらのruntimeを管理しません。`~/.pi/agent/sessions/**`にはprojectをまたいだ過去会話が保存され、`session_query`は選択した会話を現在のquery model（または`/session-recall`で選択したmodel）へ送信します。したがって、機微情報を含むsessionを検索・queryする前に、送信先modelと認証境界を確認してください。session JSONL、query model設定、auth state、履歴、cacheはこのリポジトリへコピー・同期しません。Packageを追加するときは、この表と`docs/roles-boundary.md`の責務分界を更新し、Safe-chainの経路と未管理設定の保持をテストで固定します。

`session_search`はPiのglobal sessions root全体を対象にするため、現在のproject directoryはprivacy boundaryではありません。別projectのsessionもunique markerで発見できます。検索はliteral fixed-stringでありsemantic searchではなく、upstreamはbackground indexingやvector DBを作りません。

## pi-session-recall 手動smoke

1. `/tmp/pi-recall-project-a`でPi session A1を開始し、`RECALL_SMOKE_7F31A`のような一意なmarkerと設計判断を会話へ残して終了する。
2. `/tmp/pi-recall-project-b`で完全に新しいsession B1を開始し、markerについて`session_search`を使う自然言語の質問を行う。
3. 検索結果にproject Aのsession JSONLが含まれ、`session_query`がA1を読み込んで判断内容を回答することを確認する。同一directoryの別sessionでも同じ確認を行う。
4. query modelを`openai-codex`（または`/session-recall`で選択した利用可能なmodel）にして、実際の`session_query`回答を確認する。認証・外部LLMが必要なためCIの必須条件にはせず、実行できない場合は未実施として扱う。
