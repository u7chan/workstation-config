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
| GPT-6.1 Sol | reasoning / reviewer | 約240Kでcompact |
| GPT-5.6 Sol | reasoning / reviewer | 約240Kでcompact |
| GPT-5.6 Terra | reasoning / mid-cost | 約240Kでcompact |
| GPT-5.6 Luna | worker / sub-agent | 最大context windowを許可 |
| GPT-6 Luna | worker / sub-agent | 最大context windowを許可 |

判断理由（現在時点の概要。価格表は持たない）:

- Astra / GPT-6.1 Sol / GPT-5.6 Sol / Terraは高コスト側のため、ChatGPT PlusのWork / Codex利用枠の保護を優先し、約240Kでauto-compactさせる。
- GPT-5.6 Luna / GPT-6 Lunaは低コスト・高スループットのworker向けモデルのため、最大context windowを使えるようにし、長い作業をコンパクションなしで進められるようにする。

## 実装マッピング

### Pi（`home/dot_pi/agent/models.json`）

- `modelOverrides`の`contextWindow`でcontext windowを上書きします。piの自動コンパクションは`contextWindow - reserveTokens`（既定reserve 16,384）で発火します。
- GPT-6 Astra / GPT-6.1 Sol / GPT-5.6 Sol / Terra: `contextWindow: 256384` → 240,000でcompact。
- GPT-5.6 Luna / GPT-6 Luna: `contextWindow: 1050000` → 約1,033,616でcompact。

### 適用範囲

- 対象はPiの`openai-codex` providerです。Codex CLIはPiへ移行したため`home/dot_codex/`と`model-catalogs/workstation.json`を削除し、budgetはPiの`modelOverrides`だけで表現します。
- Codex CLIのmodel catalogはプロンプト本文を各モデルへ埋め込む全置換カタログで、per-model budgetのためだけに数百KiBの生成物を持ち続ける必要がありました。この管理コストも削除の理由です。

## 再評価のトリガー

- 新しいモデルを利用し始めたとき。`modelOverrides`の対象外モデルはprovider既定のcontext windowで動作します。利用を始める場合はこの原則でbudgetを判断してください
- providerの料金・利用枠・usage multiplierが変わったとき
- Piのコンパクション仕様（reserve、クランプ率）が変わったとき
