# AI CLIの使用量（quota）取得

Codex（ChatGPT Plus）と OpenCode Go の使用量がどこから来て、どう正規化されているかのナレッジです。取得コードの正本は [pi-console の `src/pi_console/usage.py`](https://github.com/u7chan/pi-console/blob/main/src/pi_console/usage.py) にあり、workstation-config はコードも設定も持ちません。このdocは、同じ調査を繰り返さないための手順と実測結果を残します。

## 結論

| provider | エンドポイント | credential（Pi 経由の例） | ヘッダ |
| --- | --- | --- | --- |
| Codex (`openai-codex`) | `GET https://chatgpt.com/backend-api/wham/usage` | `pi auth print-bearer-token --provider openai-codex` | `Authorization: Bearer <JWT>` |
| OpenCode Go (`opencode-go`) | `GET https://opencode.ai/inference/go/v1/usage` | `pi auth print-api-key --provider opencode-go` | `Authorization: <API key>` |

- Pi 経由なら追加のAPIキー発行やダッシュボード操作は不要です。Pi が保存済みの資格情報をそのまま使います。
- API 側は Pi かどうかを見ていないため、有効な API key / OAuth access token を直接渡しても取れます（後述）。
- 返る値は**使用率**（0〜100、使った割合）です。残量ではありません。
- どちらも非公開・非保証の内部APIです。予告なく変わる前提で扱います。
- 認証が生きているかだけなら `pi auth check --provider openai-codex` / `pi auth check --provider opencode-go` が `ready` を返します（credential は表示されません）。

## credential の出どころ（Pi は必須ではない）

API 側は「Pi から送られたか」を見ていません。`Authorization` に入れた credential が有効なら 200 を返します。Pi は credential の保管庫で、`pi auth print-*` は保存済みの値を出すだけです。

- **OpenCode Go**: `oc_...` の API key。OpenCode Console（<https://opencode.ai/console>）で Go / Go Plus に加入して発行した key を直接渡せます。OAuth の access token のような短命の更新は不要で、失効するまで使えます。使用量も Console で確認できます。
- **Codex**: ChatGPT アカウントの OAuth access token（JWT、`access_token`）。Pi や Codex CLI などの OAuth ログインで得られます。**access token は期限付き**で、更新には refresh token が必要です。Pi は `print-bearer-token` の実行時に期限切れを更新します。手動で渡す場合は、期限切れのたびに再ログインするか、refresh を自分で実装します。ChatGPT Plus の加入だけでは静的な API key は発行されません。

直接渡す例です。値は secret manager や `read -s` で入れ、シェル履歴に残さないでください。

```bash
# OpenCode Go
read -r -s KEY && echo
curl -fsS https://opencode.ai/inference/go/v1/usage \
  -H "Authorization: $KEY" \
  -H 'Accept: application/json' \
| jq '.usage'
```

```bash
# Codex
read -r -s TOKEN && echo
curl -fsS https://chatgpt.com/backend-api/wham/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/json' \
| jq '.rate_limit'
```

- OpenCode Go は `Authorization: Bearer <key>` でも通ります（2026-10-24 実測）。実装は素の key を送っています。
- 実測で必要なヘッダは `Authorization` と `Accept: application/json` だけです（`User-Agent` は任意）。ChatGPT の Web セッション Cookie で通るかは未検証です。

## Pi 経由で確認する

`jq` で必要な項目だけ射影します。**トークン・アカウント識別子を画面・ログ・シェル履歴に残さない**ため、`set -x` / `curl -v` / `echo "$TOKEN"` は使いません。

```bash
# Codex（Plus の実測例）
TOKEN=$(pi auth print-bearer-token --provider openai-codex)
curl -fsS https://chatgpt.com/backend-api/wham/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/json' \
| jq '{plan_type,
       rate_limit: (.rate_limit | {primary_window, secondary_window}),
       credits: (.credits | {has_credits, unlimited, overage_limit_reached, balance}),
       models: (.model_usage | keys)}'
```

```bash
# OpenCode Go
KEY=$(pi auth print-api-key --provider opencode-go)
curl -fsS https://opencode.ai/inference/go/v1/usage \
  -H "Authorization: $KEY" \
  -H 'Accept: application/json' \
| jq '.usage'
```

- `print-*` は1行だけ返します。Codex は `eyJ...` の JWT、OpenCode Go は `oc_...` のAPIキーです。
- 生の応答をそのまま保存しないでください。Codex は `email` / `user_id` / `account_id` を含みます。
- HTTP status だけ見るなら `curl -s -o /dev/null -w '%{http_code}\n' ...` を使います。

## Codex の応答

### 実測例（Plus / 2026-10-24）

```json
{
  "plan_type": "plus",
  "rate_limit": {
    "primary_window": {
      "used_percent": 85,
      "limit_window_seconds": 604800,
      "reset_at": 1793405801,
      "reset_after_seconds": 555225
    },
    "secondary_window": null
  },
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "overage_limit_reached": false,
    "balance": "0"
  },
  "models": ["gpt-6-astra"]
}
```

| フィールド | 意味 |
| --- | --- |
| `plan_type` | `plus` / `pro` などのプラン名。画面の「Plan」に出す |
| `rate_limit.primary_window` | 使用率とリセット時刻。`used_percent` が 0〜100 の使用率 |
| `rate_limit.secondary_window` | 2本目の窓。無ければ `null` |
| `limit_window_seconds` | 窓の長さ。`18000` = 5時間、`604800` = 7日 |
| `reset_at` | リセット時刻（epoch 秒） |
| `reset_after_seconds` | リセットまでの残り秒。`reset_at` が無いときの代替 |
| `credits.balance` | 追加クレジット残高。**数値文字列**（`"0"`）で返る |
| `model_usage` | モデル名 → `{available, available_at}` のマップ |

2026-10-24 時点の Plus は **weekly 1本だけ**を返しました（`primary_window` が604800秒、`secondary_window` は `null`）。5時間窓を返すプランでは primary / secondary のどちらかに入るため、画面は固定の slot ではなく `limit_window_seconds` で種類を決めています。

`/backend-api/codex/usage` という兄弟パスもありますが、2026-10-16 の実測では同じトークンで **403** でした（2026-10-24 の再確認では 200）。実装は実績のある `wham/usage` を使います。

`additional_rate_limits` / `code_review_rate_limit` / `rate_limit_reset_credits` / `spend_control` / `promo` も返りますが、現在の画面は使っていません。

## OpenCode Go の応答

### 実測例（2026-10-24）

```json
{
  "usage": {
    "rolling": {"status": "ok", "percent": 0,  "resetsAt": "2026-10-24T18:50:51.000Z"},
    "weekly":  {"status": "ok", "percent": 14, "resetsAt": "2026-10-26T00:00:00.000Z"},
    "monthly": {"status": "ok", "percent": 76, "resetsAt": "2026-11-10T12:50:11.000Z"}
  }
}
```

- 窓の名前がそのまま `rolling` / `weekly` / `monthly` で返るので、Codex のような長さからの振り分けは不要です。
- `percent` は 0〜100 の**使用率**です。`0` は「未使用」であり「取得不能」ではありません。
- `resetsAt` は RFC3339 の文字列（ミリ秒付き）です。pi-console は文字列だけを採用し、数値なら空（不明）にします。
- `status` は API の語をそのまま保持します。空なら `ok` とみなします。

## 正規化（画面の契約）

pi-console は両 provider を同じ3行へ揃えます。

| id | ラベル | Codex の条件 | OpenCode Go |
| --- | --- | --- | --- |
| `rolling` | ローリング | `limit_window_seconds <= 21600`（6時間） | `usage.rolling` |
| `weekly` | 週次 | `limit_window_seconds <= 691200`（8日） | `usage.weekly` |
| `monthly` | 月次 | それより長い | `usage.monthly` |

- Codex 側の境界を5時間・7日ちょうどではなく6時間・8日にしているのは、プラン差やAPIの揺れを吸収するためです。長さが読めない値は `rolling` に寄せます。
- Codex の `reset_at`（epoch 秒）は UTC の ISO（`...Z`）へ変換します。OpenCode Go の `resetsAt` はそのまま渡します。**画面が2形式を扱わずに済むようにするため**です。
- 窓が無い場合も API は3行（`status: "unavailable"`）で返しますが、Web 画面は値の無い行を描きません。0% と混同しないためです。

## pi-console での実装

- `GET /api/usage` が認証付きで返します。契約は `{ok, stale, fetched_at, providers: [{id, name, status, plan, warning?, windows: [...]}]}` です。
- credential は `pi auth print-*` からその場で取り、**メモリだけ**に置きます。ファイルにもログにも応答にも残しません。
- キャッシュは5分（`CACHE_SECONDS = 300`）。画面のポーリング間隔に合わせています。
- HTTP と credential 取得はそれぞれ8秒で打ち切り、応答本文は256 KiBまでです。
- provider ごとに独立して失敗します。片方が落ちても他方は返し、両方落ちたら前回の結果 + `stale: true`、前回が無ければ `ok: false` + `detail` です。
- 失敗理由は `HTTP 401` / `API connection failed` / `credential command failed (exit code 7)` のような固定分類と数値コードだけです。HTTP の reason・本文・例外文字列は外へ出しません。

## ハマりどころ

1. **`/backend-api/codex/usage` を使わない。** 過去に403でした。`wham/usage` が実績のあるパスです。
2. **401 は credential が無効・期限切れ。** Pi 経由なら `pi auth check --provider openai-codex` が `ready` か確認し、駄目なら Pi で `/login` し直します。直接渡しているなら、Codex は access token の期限切れ、OpenCode Go は key の失効を疑います。
3. **`secondary_window: null` を0%にしない。** データが無い窓は描かず、サーバは `unavailable` として返します。Codex の Plus では weekly しか返らないことがあります。
4. **`percent` は使用率。** 残量表示に反転しないでください。
5. **OpenCode Go のパスは `/inference/go/v1/usage`。** host は `opencode.ai` です。
6. **`credits.balance` は文字列。** 数値として読むなら変換が要ります。
7. **生の応答には個人情報が入る。** Codex の `email` / `user_id` / `account_id` をログ・キャッシュ・Issueへコピーしないでください。
8. **5分キャッシュ。** 消費直後は表示が遅れます。
9. **`pi` が PATH に無いと credential を取れません。** pi-console は `--pi-bin` で差し替えられます。無ければ両 provider が `unavailable` になり、サーバは落ちません。
10. **Codex のトークンは usage API 専用のキーではありません。** ChatGPT アカウントの OAuth bearer なので、パスワードに近い扱いが必要です。refresh token はさらに強力なので、ファイル共有やログ出力をしないでください。

## 実装の変遷

- 2026-10-16: 常看板（herdr-status-board）の Codex 週次表示のため、Pi の OAuth トークンで `wham/usage` を直接叩いて見つけました。`internal/codexusage` として実装し、識別子を捨てるホワイトリストcache・5分間隔・失敗後1分という形にしました。
- 続いて `internal/opencodeusage` を追加し、OpenCode Go の3窓を同じ看板に並べました。
- 2026-10-18: 常看板を廃止し、pi-console の `/api/usage` へ移植しました。workstation-config からプラグインのlink管理も外れています。
- 旧プラグインのcache（`<state>/codex-usage.json` / `opencode-usage.json`）は数値と時刻だけですが、不要なら削除して構いません。

## 参照

- [pi-console `src/pi_console/usage.py`](https://github.com/u7chan/pi-console/blob/main/src/pi_console/usage.py) — 取得・正規化・キャッシュの正本
- [pi-console `docs/design.md`](https://github.com/u7chan/pi-console/blob/main/docs/design.md) — `/api/usage` の契約
- [pi-console `docs/security.md`](https://github.com/u7chan/pi-console/blob/main/docs/security.md) — credential の扱い
- [OpenCode Go](https://opencode.ai/docs/go/) — API key の発行と Console での使用量確認
- [herdr-status-board](https://github.com/u7chan/herdr-status-board) — 初実装（廃止済み）
- [AIモデルのcontext budgetポリシー](ai-model-context-budget.md) — 利用枠を踏まえたcontext budget
