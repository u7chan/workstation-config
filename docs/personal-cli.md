# 個人CLIコマンドガイド

`personal`プロファイルで`~/.local/bin`へ配置される個人用コマンドの早見表です。

## 早見表

| やりたいこと | コマンド | 覚え方 |
|---|---|---|
| マージ済みPRの作業ブランチを片付ける | `gpc` | Git PR Cleanup |
| Agent用worktreeを確認する（dry-run） | `gac` | Git Agent Cleanup |
| Agent用worktreeを実際に片付ける | `gac --apply` | まず引数なしで対象を確認 |
| カレントディレクトリを自分だけに公開する | `http 8000` | localhost限定 |
| カレントディレクトリをLANへ公開する | `http-lan 8000` | 同一LANの端末からアクセス可能 |
| Claude Codeをprovider指定で起動する | `myclaude <provider>` | My Claude |
| 登録済みproviderを一覧表示する | `myclaude --list` |  |
| 選択したAI CLIとHerdrをまとめて更新する | `myupdate` | My update |

各コマンドのヘルプは`<command> --help`で確認できます。ただし`myupdate`はオプションを受け付けないため、`myupdate --help`でも更新処理が開始されます。

## Git cleanup

### `gpc`

現在のローカルブランチに対応するGitHub PRがマージ済みなら、base branchへ戻って最新化し、元のローカルブランチを削除します。

```bash
gpc
```

実行前に次を満たす必要があります。

- primary worktreeで実行している
- 未追跡ファイルを含めてworktreeがcleanである
- 現在のブランチに対応するPRがマージ済みである
- ローカルbranchの先端がPRのheadと一致している
- PRのbaseが`main`、`master`、`develop`のいずれかである
- `gh`がインストール済みで、GitHubへ認証済みである

成功時はbase branchへswitchし、`origin`からfast-forwardした後、元のローカルbranchだけを削除します。remote branch、linked worktree、stashには触れません。

### `gac`

primary worktreeと同じ階層にある`<repository-name>-worktrees/`配下から、Gitに登録済みのAgent worktreeと対応するローカルbranchをまとめて片付けます。

```bash
# 対象と危険要因を表示するだけ
gac

# 安全性チェックを通過した場合だけ削除
gac --apply

# dirtyまたは未マージでも強制削除
gac --apply --force
```

最初は必ず引数なしのdry-runで対象を確認してください。

通常の`--apply`は、対象内にdirty worktreeまたは既定remote branchへ未マージのbranchが一つでもあれば、何も削除せず停止します。`--force`はこの安全性チェックだけを上書きし、探索範囲を広げません。base branch、別ディレクトリのworktree、remote branchは削除対象外です。

## HTTP server

### `http`

カレントディレクトリを`127.0.0.1`だけにbindして公開します。ほかの端末からはアクセスできません。

```bash
http 8000
http 9000 --directory ./dist
```

引数はPython標準の`http.server`へ渡されます。portを省略した場合は`8000`です。終了は`Ctrl-C`です。

### `http-lan`

カレントディレクトリを`0.0.0.0`へbindし、LANからアクセスできる状態で公開します。

```bash
http-lan 8000
```

確認なしで全network interfaceへ公開するため、機密ファイルを含むディレクトリでは実行しないでください。Windows Firewallなどホスト側の設定は変更しません。引数と終了方法は`http`と同じです。

## Claude provider launcher

### `myclaude`

provider別の設定を読み、指定modelをClaude Codeの全model tierへ割り当てて起動します。`myclaude`以降の引数はClaude Codeへそのまま渡します。

```bash
myclaude --list
myclaude zai
myclaude deepseek --version
```

設定ファイルはGit管理外の`~/.config/envs/<provider>/.env`へ置きます。

```dotenv
BASE_URL="https://provider.example"
API_KEY="replace-with-secret"
MODEL="provider/model-name"
```

```bash
chmod 600 ~/.config/envs/<provider>/.env
```

設定ファイルは現在のユーザーが所有する通常ファイルで、mode `600`である必要があります。shellとしてsourceせず、`BASE_URL`、`API_KEY`、`MODEL`の3キーだけを読み取ります。secretファイルはリポジトリやchezmoiで管理しません。

## 開発ツールの手動更新

### `myupdate`

`personal_ai_tools`で選択したAI CLIを`update-ai`で更新し、続いてmise管理のHerdrを`mise upgrade herdr`で更新します。引数・オプションは受け付けず、`WORKSTATION_UPDATE_AI_TOOLS`環境変数でのみ挙動を変更します。各処理は失敗時に5秒待って1回だけ再試行し、失敗しても後続処理を続けます。多重起動はロックで抑止し、競合時は終了コード3で終了します。

```bash
myupdate
```

更新対象の選択方法（`WORKSTATION_UPDATE_AI_TOOLS`による上書き）、Pi Packageの処理内容、再provisioningとの排他制御の詳細は[Workstation構成ガイド](workstation.md#開発ツールの手動更新)を参照してください。

## 開発時の確認

個人CLIを変更した場合は次を実行します。

```bash
./tests/personal-cli-smoke.sh
./tests/static.sh
```
