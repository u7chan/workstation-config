# AIモデルのcontext budgetポリシー

このdocは、AIモデルごとのcontext windowとauto-compaction閾値（context budget）を決めるときの設計原則と現在の運用値の正本（canonical source）です。価格表やprovider固有仕様をここに固定せず、現在のモデルポリシーと判断理由だけを管理します。

## 設計原則

- モデルが提供する最大context windowを、そのまま常用上限にしない。最大context windowは「モデル性能」であり、運用するのは「context budget（予算）」として別物です。
- budgetは **役割 × usage cost × context benefit** で決めます。価格そのものではなく、次の材料を見ます。
  1. モデルの役割（reasoning / reviewer / orchestrator か、worker / sub-agent か）
  2. subscription / provider の利用枠（ChatGPT PlusのWork / Codex利用枠の保護など）
  3. context長による段階課金・usage multiplier の有無
  4. cached input を含む実運用上の消費特性
  5. compact後に必要な出力・作業余白
  6. 長大contextを使うことで得られる作業上の利益
- reasoning / 高コスト側のモデルは小さめのbudgetでauto-compactさせ、利用枠を保護してよい。
- low-costなworker / sub-agent向けモデルは、長大contextを許可して作業スループットを優先してよい。
- provider / modelの料金体系・利用枠が変わったらbudgetを再評価する。
- 新しいモデルを追加するときは「最大contextをそのまま使う」のではなく、この原則でbudgetを判断する。

## 現在のモデルポリシー

| Model | Role | Context budget |
|---|---|---|
| GPT-6 Astra | reasoning / high-cost | 約240Kでcompact |
| GPT-5.6 Sol | reasoning / reviewer | 約240Kでcompact |
| GPT-5.6 Terra | reasoning / mid-cost | 約240Kでcompact |
| GPT-5.6 Luna | worker / sub-agent | 最大context windowを許可 |

判断理由（現在時点の概要。価格表は持たない）:

- Astra / Sol / Terraは高コスト側のため、ChatGPT PlusのWork / Codex利用枠の保護を優先し、約240Kでauto-compactさせる。
- Lunaは低コスト・高スループットのworker向けモデルのため、最大context windowを使えるようにし、長い作業をコンパクションなしで進められるようにする。

## 実装マッピング

### Pi（`home/dot_pi/agent/models.json`）

- `modelOverrides`の`contextWindow`でcontext windowを上書きします。piの自動コンパクションは`contextWindow - reserveTokens`（既定reserve 16,384）で発火します。
- GPT-6 Astra / GPT-5.6 Sol / Terra: `contextWindow: 256384` → 240,000でcompact。
- GPT-5.6 Luna: `contextWindow: 1050000` → 約1,033,616でcompact。

### Codex（`home/dot_codex/`）

- `config.toml`の`model_catalog_json`で`~/.codex/model-catalogs/workstation.json`を読み込みます。カタログはバンドル / リモートカタログを置き換えるため、全モデル分のメタデータを含みます。
- `config.toml`に`model_context_window` / `model_auto_compact_token_limit`を置きません。これらは全モデルへ一様に適用されるglobal overrideであり、モデル別budgetと相容れないためです。
- カタログの`context_window`（物理窓）と`auto_compact_token_limit`（budget）でモデル別値を表現します。codexは`auto_compact_token_limit`を`context_window`の90%へクランプします。
- GPT-6 Astra / GPT-5.6 Sol / Terra: `context_window: 272000` + `auto_compact_token_limit: 240000`。
- GPT-5.6 Luna: `context_window: 1050000` + `auto_compact_token_limit: 945000`（90%）。
- cagentのprofileはcodexへmodel / effortだけを渡すため、`worker-codex`のLunaにもカタログのモデル別値がそのまま効きます。cagent設定の変更は不要です。

### カタログの再生成手順

`model-catalogs/workstation.json`はcodexバンドルカタログのコピーにポリシー上書きを適用したものです。codexを更新してモデルメタデータが変わったら、次のコマンドで再生成します。

```bash
codex debug models --bundled \
  | jq 'del(.models[].base_instructions)
        | .models |= map(
            if .slug == "gpt-6-astra" or .slug == "gpt-5.6-sol" or .slug == "gpt-5.6-terra" then
              .auto_compact_token_limit = 240000
            elif .slug == "gpt-5.6-luna" then
              .context_window = 1050000 | .auto_compact_token_limit = 945000
            else .
            end)' \
  > home/dot_codex/model-catalogs/workstation.json
```

- `base_instructions`は`model_messages.instructions_template`との重複のため削除します（カタログ読み込みには不要です）。
- 検証は`codex debug models`でモデル数とbudget値を確認し、`tests/static/codex.sh`がファイル構造を検証します。実モデルへのリクエストは自動テストの必須条件にしません。

## 再評価のトリガー

- 新しいモデルを利用し始めたとき
- providerの料金・利用枠・usage multiplierが変わったとき
- Codex / Piのコンパクション仕様（reserve、クランプ率）が変わったとき
