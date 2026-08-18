# Workstation構成ガイド

Ubuntu 26.04 WSL2 上の開発環境を、コードで定義し再現可能にするための IaC 構成です。

## 手動で準備するもの

bootstrapは次の作業を自動化しません。

1. WSLディストリビューションと一般ユーザーの作成
2. `git`と`gh`の導入
3. `gh auth login`によるGitHub HTTPS認証
4. このprivateリポジトリのclone

具体的なコマンドは[初期セットアップ手順](bootstrap-prerequisites.md)を参照してください。

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。

## Bootstrap

個人開発環境には、引数なしで`personal`プロファイルを適用します。

```bash
./bootstrap
```

個人用Roleを含めない環境では、必ず`base`を明示します。

```bash
./bootstrap base
```

`personal`は常に`base`を包含します。Ansibleの`base` roleはmiseの設定をtrustした後、Herdrだけを最新版へ解決し、残りのツールをlockfile固定で導入します。続いて`personal` roleが選択済みAI CLIを更新し、AI CLIの設定ディレクトリを準備してからHerdr公式integrationを導入・検証します。その後、bootstrapはchezmoiを適用し、AI CLI設定ディレクトリのmode 0700を再適用します。Claudeが選択されている場合だけ、リポジトリ直下のfragmentを`~/.claude/settings.json`へmergeしてからmise installを再実行します。

`personal`では任意RoleとしてDocker CEも既定で導入します。Dockerを導入しない
personal構成はAnsibleを直接実行し、`personal_docker_ce_enabled=false`を指定してください。
`base`ではDocker repository、package、service、groupのいずれも変更しません。

AI CLIをsubset化する場合は、`WORKSTATION_PERSONAL_AI_TOOLS`へカンマ区切りで指定します。未指定時は4種類すべてを対象にし、空文字を指定するとpersonal AI CLIの更新・integration導入を無効化します。

```bash
WORKSTATION_PERSONAL_AI_TOOLS=codex,opencode ./bootstrap personal
WORKSTATION_PERSONAL_AI_TOOLS= ./bootstrap personal
```

bootstrapはchezmoi管理対象をリポジトリの宣言状態へ非対話で整えます。管理対象ファイルのローカル変更は上書きしますが、secret、認証state、`~/.config/workstation/shell/local.bash`などの管理対象外ファイルは変更しません。

bootstrapは次の条件を事前検査します。

- Ubuntu 26.04
- WSL2
- root以外の一般ユーザー
- sudoを利用可能
- `base`または`personal`プロファイル

AnsibleはUbuntuのAPT版`ansible-core`を使用し、OS Pythonへpipで導入しません。

### Ubuntu 26.04 WSLのsystemd user session回避策

検証・運用には、Ubuntu 24.04など既存環境と区別できる専用distro名
`workstation-test-ubuntu26`を使用してください。

Ubuntu 26.04 WSL2のsystemd 259では、一度終了した`user@1000.service`が
WSLのcgroup再利用と衝突して再起動できない既知問題があります。base Roleは対象環境に限り
`/etc/systemd/system/user@.service.d/wsl-cgroup-workaround.conf`を配置し、
`DelegateSubgroup`を解除します。Ubuntu 24.04および非WSL環境には適用しません。

これは一時的な回避策です。Ubuntuまたはsystemd upstreamで問題が解消した後は、
systemdのバージョン条件とdrop-inの撤去を判断してください。適用後はWindows側で
`wsl.exe --terminate workstation-test-ubuntu26`を実行して再接続し、次を確認します。

```bash
./tests/wsl-restart-smoke.sh
```

## 構成

```text
.
|-- bootstrap             # 単一の実行入口
|-- ansible/              # OS基盤とプロファイル別Role
|-- home/                 # chezmoi source
|-- mise/                 # mise設定
`-- tests/                # bootstrap基盤の検証
```

## 再実行

処理が中断した場合も、同じbootstrapコマンドを再実行できます。2回目はAnsibleの変更とchezmoiの差分が0になることを検証対象とします。

## Docker CE（personal限定）

`personal`のDocker RoleはDocker公式stable APT repositoryからDocker CE、CLI、
containerd、Buildx、Compose pluginを導入し、`docker.service`と
`containerd.service`をsystemdで有効化します。Docker Desktop連携とrootless Dockerは
使用せず、versionは固定しません。

初回適用で現在のユーザーが`docker` groupへ追加された場合、groupを現在のsessionへ
反映するため、すべての当該WSL sessionを終了して再接続してください。その後、sudoを
使わずに次を実行します。smoke testが作成したcontainerやCompose resourceは終了時に
削除されます。

```bash
./tests/docker-smoke.sh
```

このtestはlocalの`default` Docker context、service状態、`docker info`、Buildx、
Compose、およびsmoke containerを検証します。

## PostgreSQLクライアント（psql）

PostgreSQLサーバーやdaemonは導入せず、クライアントのみをAPTの`postgresql-client`
パッケージで`base`プロファイルに導入します。miseのtool定義やlockfileには追加しません。
バージョンはUbuntu 26.04のAPT repositoryが提供する版に従います。

接続情報や認証情報（`.pgpass`など）は管理対象外です。導入後は次で確認できます。

```bash
psql --version
./tests/psql-smoke.sh
```

## 開発時の確認

```bash
./tests/static.sh
```

## miseの管理範囲

`base`と`personal`の両プロファイルで、次のランタイムとportable CLIをmise経由で導入します。

- Node.js LTS、Bun 1.x、uv
- ripgrep、fd、tree-sitter CLI、Neovim 0.12.x、Hunk、Lazygit、Lazydocker、Yazi、Starship、Herdr、cagent、Playwright CLI

Python本体はmiseで管理しません。プロジェクトの`.python-version`に基づくPythonと`.venv`はuvに委譲し、Ubuntuの`python3`はOS管理のままにします。nvm、APT版Neovim、ツールごとの手動PATH追加は使用しません。

CLIツールの用途と基本的な起動方法は[CLIツールガイド](cli-tools.md)を参照してください。

`provisioning/mise/config.toml`はグローバルmise設定の配布元、`provisioning/mise/mise.lock`はUbuntu 26.04 x86_64で検証する実バージョンとダウンロード情報を保持します。これらはmiseのプロジェクト設定として検出されないパスに置き、bootstrapが`~/.config/mise/`へ配置します。Herdr以外はbootstrapがlocked modeで導入するため、lockfileにない版への暗黙更新は行いません。HerdrはAI CLIとしての更新頻度を優先し、bootstrapごとに`latest`を解決してローカルのlockfileを更新します。

Pi本体はmiseのtool定義および`mise.lock`では管理しません。`personal`の`update-ai`がmise管理のNode.js/npm環境へ入り、Safe-chain経由で`@earendil-works/pi-coding-agent@latest`を`--ignore-scripts`付きで導入・更新します。Piを選択したときは続けてPi公式Package managerで`npm:pi-web-access`をglobal packageとして導入・更新します。

更新時は、Ubuntu 26.04 x86_64で次を実行し、差分と動作を確認します。

- `MISE_CONFIG_DIR`でリポジトリの`provisioning/mise/`をグローバル設定ディレクトリに切り替え、`~/.config/mise/config.toml`を参照・更新対象から除外します
- `MISE_CONFIG_FILE`（`MISE_GLOBAL_CONFIG_FILE`）は、リポジトリが`$HOME`配下にある場合に`~/.config/mise/config.toml`が祖先ディレクトリのプロジェクト設定として優先されるため、この用途では機能しません

```bash
MISE_CONFIG_DIR="$PWD/provisioning/mise" mise upgrade
MISE_CONFIG_DIR="$PWD/provisioning/mise" mise lock -g --platform linux-x64
MISE_CONFIG_DIR="$PWD/provisioning/mise" MISE_LOCKED=1 mise install
```

## Neovim

設定はchezmoiが`~/.config/nvim`へ配置し、Neovim本体はmiseだけで管理します。初回起動時にプラグインを取得します。

```bash
./tests/neovim-smoke.sh
type -a nvim
mise which nvim
```

プラグイン更新の担当者は、Neovimで`:Lazy update`を実行し、生成された`lazy-lock.json`の差分と上記smoke testを確認してください。Masonで導入するLSP serverとTreesitter parserは生成物のためGit管理しません。

### LSPサーバー

Mason経由で次の4つのLSPサーバーを導入・管理します。

| サーバー | Masonパッケージ名 | 用途 |
|---|---|---|
| lua_ls | `lua-language-server` | Lua (Neovim設定) |
| ts_ls | `typescript-language-server` | TypeScript / JavaScript |
| jsonls | `json-lsp` | JSON |
| bashls | `bash-language-server` | Bashスクリプト |

各LSPサーバーは`vim.lsp.config`と`vim.lsp.enable`で有効化します。`automatic_enable = false`はLSPの自動有効化だけを止め、`ensure_installed`に宣言したサーバーはsetup時に未導入であれば自動installされます。そのため初回起動から利用可能です。smoke testはinstall状態を検証し、不足時は明示的にinstallします。

### Treesitterパーサー管理方針

nvim-treesitterは `main` ブランチを使用します（`master` はアーカイブ済み）。Neovim 0.12以降の組み込みTreesitterでハイライト・インデントを有効化し、プラグインはパーサー管理に専念します。パーサーのコンパイルには `tree-sitter` CLI (>= 0.26.1) が必須で、miseで管理します。

管理パーサー (13個): bash, json, lua, markdown, markdown_inline, query, vim, vimdoc, javascript, typescript, tsx, yaml, toml

パーサーの追加はsmoke testのインストールスクリプトとファイル存在確認の更新をセットで行います。`:TSInstall` は非同期のため、headless smoke testではLuaから`require("nvim-treesitter").install()`を呼び出し`vim.wait`で完了を確認します。

### WSLクリップボード連携

WSL環境では`/proc/version`を確認し、Windows側の`clip.exe`と`powershell.exe`が利用可能であれば`vim.g.clipboard`にWSL専用のcopy/pasteコマンドを設定します。

- **copy**: `clip.exe` (レジスタ `"+"` と `"*"` の両方)
- **paste**: `powershell.exe -NoLogo -NoProfile -Command [Console]::Out.Write((Get-Clipboard -Raw).replace("`r", ""))` (レジスタ `"+"` と `"*"` の両方、CRLF除去済み)
- **cache_enabled = 0**: 更新検出を毎回行う

WSLまたはclipboardコマンドが利用できない環境では、Neovimの自動プロバイダー検出へフォールバックし、起動を妨げません。基本設定として`clipboard=unnamedplus`を維持します。

### 主要UI機能とキーマップ

#### 基本操作

| キー | 機能 |
|---|---|
| `<leader>w` | ファイル保存 |
| `<Esc>` | 検索ハイライト解除 |
| `[d` / `]d` | 前/次のdiagnosticへジャンプ |
| `<leader>q` | diagnostic一覧表示 |

#### ファイルツリー (nvim-tree)

| キー | 機能 |
|---|---|
| `<leader>e` | ツリー表示切替 |
| `<leader>E` | ツリーへフォーカス |
| `<leader>f` | 現在ファイルをツリーで表示 |
| `yp` | 相対パスをコピー |
| `yP` | 絶対パスをコピー |

#### バッファ操作 (Bufferline)

| キー | 機能 |
|---|---|
| `<S-h>` | 前のバッファ |
| `<S-l>` | 次のバッファ |
| `<leader>bp` | バッファピッカー |
| `<leader>bc` | 現在のバッファを閉じる |
| `<leader>bo` | 他のバッファを閉じる |
| `<leader>1`~`<leader>9` | 指定位置のバッファへ移動 |

#### LSP

| キー | 機能 |
|---|---|
| `gd` | 定義へジャンプ |
| `gr` | 参照一覧 |
| `K` | ホバー表示 |
| `<leader>rn` | リネーム |
| `<leader>ca` | コードアクション |
| `<leader>lf` | フォーマット (非同期) |

#### その他

| キー | 機能 |
|---|---|
| `<leader>m` | Masonを開く |
| `<leader>ff` | ファイル検索 (Telescope) |
| `<leader>fg` | grep検索 (Telescope) |
| `<leader>fb` | バッファ一覧 (Telescope) |
| `<leader>fh` | ヘルプ検索 (Telescope) |

Catppuccin Mocha colorschemeを使用し、lualine (global statusline)、nvim-scrollbar (cursor/diagnostic/gitsigns/handle表示、searchハイライト連携なし)、Gitsigns (current line blame、1000ms遅延) を統合します。

### 自動テストとWSL手動確認

headlessのsmoke testはプラグイン同期、4つのLSPサーバー、13個のTreesitterパーサー、プラグイン読込、オプション値、キーマップ、clipboard設定、`vim.deprecated`を検証します。

```bash
./tests/neovim-smoke.sh
```

WSL環境での手動確認は、Windows側のクリップボード連携を検証します。

1. Neovimでテキストをyank (`y`)
2. Windows側のアプリケーションで貼り付け (`Ctrl+V`) できることを確認
3. Windows側でテキストをコピー (`Ctrl+C`)
4. Neovimで貼り付け (`p`) できることを確認

クリップボードが動作しない場合は、WSL側で`clip.exe`と`powershell.exe`が利用可能か確認してください。

```bash
which clip.exe
which powershell.exe
cat /proc/version | grep -i microsoft
```

## Yazi

Yazi本体はmise、`~/.config/yazi/yazi.toml`とpackage宣言はchezmoiで管理します。標準テーマと標準キーマップを使い、plugin本体、flavor本体、cache、履歴、preview生成物、runtime stateはGit管理しません。fresh HOME相当の設定読込は次で確認できます。

```bash
./tests/yazi-smoke.sh
```

pluginやflavorを追加・更新する場合は`package.toml`の宣言を更新して`ya pkg install`を実行し、取得物をcommitせず上記smoke testを再実行してください。Yazi本体の更新は「miseの管理範囲」の手順でlockfileも更新します。

## Herdr、cagentとAI CLI

Herdrと`cagent`本体はmiseで管理します。Herdrはbootstrapごとに`latest`を解決するため、リポジトリのlockfileに記録されたHerdr版は固定値として扱いません。`cagent`は`github:u7chan/code-agent-launcher` backendからLinux x64 release assetをlocked installし、`mise.lock`にURL、checksum、provenanceを固定します。Codex、Claude Code、OpenCode、Piは`personal`プロファイルだけで導入し、`personal_ai_tools`で選択されたCLIだけにHerdr公式integrationを導入します。integrationはAI CLI本体の導入後に`herdr integration install <agent>`で設定し、`herdr integration status`で選択対象が`current`であることを検証します。選択から外れた既存integrationは自動削除しません。`base`プロファイルではAI CLI本体・integrationとも導入しません。CodexとPiはnpmをSafe-chain経由で導入し、Piは`--ignore-scripts`を付けます。Claude CodeとOpenCodeは各公式installerで最新版を導入します。AI CLIの認証は手動です。

Herdr integrationが生成するhook/pluginはHerdrが所有し、chezmoi sourceには含めません。AI CLIの既存設定本体は、現在の所有関係を維持します。

| Agent | Herdrが生成・更新するruntime artifact | chezmoiの管理範囲 |
|---|---|---|
| Codex | `~/.codex/hooks.json`、`~/.codex/herdr-agent-state.sh` | `~/.codex/config.toml`。Herdrが要求する`[features] hooks = true`を含む |
| Claude Code | `~/.claude/settings.json`のHerdr hook entries、`~/.claude/hooks/herdr-agent-state.sh` | `~/.claude/statusline.py`（chezmoi）、および`claude/settings.json`の`theme`・`statusLine`（bootstrap merge）。それ以外の個人設定はユーザー管理 |
| OpenCode | `~/.config/opencode/plugins/herdr-agent-state.js` | `~/.config/opencode/opencode.json` |
| Pi | `~/.pi/agent/extensions/herdr-agent-state.ts` | ユーザー設定・session・履歴は管理しない |

auth、履歴、DB、session、cache、ログ、Herdr生成stateはGit管理しません。Herdr公式integrationの詳細な対象パスとnative session restoreの条件は[公式integrationドキュメント](https://herdr.dev/docs/integrations/)を参照してください。

PiのHerdr extensionと`pi-web-access`は別の管理境界にあり、前者はHerdr、後者はPi Package managerが所有します。`pi-web-access`導入時も`~/.pi/agent/extensions/herdr-agent-state.ts`を上書きせず、Piの組み込みツール登録を変更しません。

Pi本体と`pi-web-access`の更新入口は`update-ai --pi`です。`personal_ai_tools`に`pi`が含まれるbootstrapでは同じ処理が走り、`myupdate`も設定された選択対象を`update-ai`へ渡します。Piはv0.37.3以上を前提とし、未導入時は`pi install npm:pi-web-access`、導入済みなら`pi update npm:pi-web-access`を実行します。Pi packageの登録と`~/.pi/agent/npm/`はPiが管理し、chezmoiは管理しません。

Pi Package manager内部のnpm経路は、Pi公式の`npmCommand`設定を`["mise", "exec", "node", "--", "safe-chain", "npm"]`へ設定して固定します。`update-ai`は既存の`~/.pi/agent/settings.json`をJSONとして読み戻し、このキーだけをatomicにmergeするため、`settings.json`全体や`packages`配列を直接管理しません。`npm:pi-web-access`の`packages`への追加・更新はPi公式Package managerが行い、既存のpackagesエントリ、認証、ユーザー設定などの未管理キーは保持します。

`pi-web-access`は次のツールを提供します。

- `web_search`
- `fetch_content`
- `get_search_content`
- `source_check`

初期状態はzero-config routing（Exa MCP、PiのCodex loginが利用可能な場合のOpenAI search）を使用します。API key、OAuth token、cookie、auth state、cache、履歴はリポジトリで管理しません。任意設定の`~/.pi/web-search.json`も手動管理とし、今回のbootstrapでは作成・コピーしません。

```bash
update-ai
./tests/ai-clis-smoke.sh
```

chezmoiが管理するのは`~/.codex/config.toml`、`~/.config/opencode/opencode.json`、`~/.config/cagent/config.yaml`などのallowlist化した非機密設定だけです。`cagent`設定はCodexを既定agent、`reasoner`を既定profileとし、CodexとOpenCode GoのLaunch ProfileおよびHerdrのstart/run templateを定義します。既定profileは設定の`default_profile`を変更して切り替えます。auth、履歴、DB、session、cache、ログ、Herdr生成stateはGit管理しません。

`base`ではmise解決とversionだけ、`personal`では設定・doctor・profile別dry-runまで確認します。いずれも実Agentや外部モデルは起動しません。

```bash
./tests/cagent-smoke.sh base
./tests/cagent-smoke.sh personal
```

### cagent v1.0.0 Launch Profiles への移行

cagent v1.0.0では旧形式の`levels`/`models`設定に後方互換がなく、設定を手動で移行する必要があります。
既存の`~/.config/cagent/config.yaml`をバックアップしてから、bootstrapで新しいLaunch Profile形式の
設定を適用してください。

```bash
# 既存設定のバックアップ
cp ~/.config/cagent/config.yaml ~/.config/cagent/config.yaml.v0.3.bak

# bootstrapで新しい設定を適用
./bootstrap personal

# 移行後の確認
cagent --version
cagent doctor
cagent profiles
cagent --dry-run reasoner
```

v0.3.xの`default_agent`/`default_level`とagent別の`levels`/`models`設定は、v1.0.0の
Launch Profileへ手動で移行する必要があります。移行の概要は
[cagent READMEのv0.3.x→v1.0.0移行ガイド](https://github.com/u7chan/code-agent-launcher?tab=readme-ov-file#v03x%E3%81%8B%E3%82%89v100%E3%81%B8%E3%81%AE%E6%89%8B%E5%8B%95%E7%A7%BB%E8%A1%8C)
を参照してください。

現行の設定で定義するLaunch Profileは次の5つです。

| Profile | Agent | Model | Effort |
|---|---|---|---|
| `worker-codex` | Codex | `gpt-5.6-luna` | `max` |
| `worker-opencode` | OpenCode Go | `deepseek-v4-flash` | — (TODO) |
| `reasoner` | Codex | `gpt-5.6-sol` | `high` |
| `reviewer` | Codex | `gpt-5.6-sol` | `xhigh` |
| `orchestrator` | OpenCode Go | `deepseek-v4-pro` | — (TODO) |

Herdr templateは`{level}`から`{profile}`に変更され、Herdr Startで任意のLaunch Profileを
指定した会話セッションを起動できます。

```bash
./tests/cagent-smoke.sh base
./tests/cagent-smoke.sh personal
```

WSL再起動後は次を実行し、Herdr、cagent、および選択済みAI CLIがmise配下または所定のLinux binaryへ解決され、Windows側のshimへフォールバックせず、選択済みHerdr integrationが`current`であることを確認します。引数なしの場合は既定の4種類（Codex / Claude Code / OpenCode / Pi）を確認します。subsetを適用した場合は、選択したCLIを引数に渡します。

```bash
./tests/wsl-restart-smoke.sh
WORKSTATION_PERSONAL_AI_TOOLS=codex,opencode ./bootstrap personal
./tests/wsl-restart-smoke.sh codex opencode
```

native session restoreの実機確認では、選択済みCLIをHerdrのpane内で起動してsessionを作成した後、WSLを再起動し、Herdrへ再接続します。各paneが通常のshellではなく、対応するCLIのnative sessionとして復元されることを確認してください。認証や実モデルへのリクエストは自動テストの対象にしません。

シェル初期化が反映されない場合は、一時的にmiseを有効化してcommand hashを破棄してから再確認します。

```bash
eval "$(~/.local/bin/mise activate bash)"
hash -r
type -a herdr cagent codex claude opencode pi
```

Codexは通常の`HOME`にある`~/.codex/config.toml`を読みます。restart smokeの`codex features list`は、この設定がCodex起動時に正常に解析されることも検証します。

#### Codex Apps integrationの無効化

Codexは既定でApps integrationが有効であり、起動時に集約MCP server `codex_apps`が読み込まれ、GitHubを含む多数のtoolが利用候補として公開されます。GitHub操作には`global-agent-skills`の自作`gh`スキルとdispatcherを使用する方針であり、Codex組み込みのGitHub app/connectorは使用しません。実際、組み込みGitHub toolにはGitHub Appの権限不足により403エラーが発生します。

```text
GitHub API error 403: {"message":"Resource not accessible by integration", ...}
```

不要なMCP toolの誤選択、権限確認、失敗後のフォールバックを避けるため、`~/.codex/config.toml`の`[features]`セクションで`apps = false`を設定し、集約MCP serverの公開を無効化します。

```toml
[features]
apps = false
```

`[apps.github] enabled = false`では集約MCP server `codex_apps`自体は無効化されず、`/mcp`にtool一覧が残ります。そのため、stable feature flagである`features.apps`を無効化します。

この設定は`codex_apps`の読み込みを停止するだけで、ユーザーが明示的に追加する`mcp_servers`の利用可否を一律に制限しません。また、`global-agent-skills`の自作`gh`スキルや`gh` CLI、Codexのplugin機能全体には影響しません。

### 開発ツールの手動更新

`personal`プロファイルは、開発ツールをまとめて同期更新する`myupdate`を配置します。必要なときに手動で実行し、次の順序で処理します。

1. `personal_ai_tools`で選択したAI CLIを`update-ai`で更新（空ならスキップ）
2. `mise upgrade herdr`

各処理は失敗時に5秒待ってその処理だけを1回再試行し、失敗しても後続処理を続けます。標準出力・標準エラーへ結果を直接表示し、いずれかの処理が2回とも失敗した場合は終了コード1を返します。多重起動はロックで抑止し、競合時は終了コード3で終了します。再provisioningのmise、AI CLI更新も同じロックへ参加します。Herdrの更新主体はmiseであり、`herdr update`は使用しません。

```bash
myupdate
```

更新対象は`~/.config/workstation/myupdate.conf`へ展開されます。手動テストなどで一時的に変更する場合は、`WORKSTATION_UPDATE_AI_TOOLS=codex,pi myupdate`のように環境変数で上書きできます。空文字を指定するとAI CLI更新をスキップします。

Piを選択した更新では、Pi本体の更新後に`pi-web-access`の導入・更新と登録確認まで行います。bootstrapと`myupdate`を複数回実行しても、Pi Package managerが同じglobal sourceを重複登録しないようにします。

## Bashのローカル設定

共通のBash初期化はchezmoi管理の`~/.config/workstation/shell/init.bash`から読み込みます。Ubuntu標準の`~/.bashrc`はそのまま残し、管理済み初期化ファイルを読み込むブロックだけを追加します。

マシン固有のworkspace aliasなどは、`~/.config/workstation/shell/local.bash`へ記述してください。このファイルはGitおよびchezmoiの管理対象外で、bootstrapは既存内容を変更せずmode 600を維持します。

## 個人CLI

`personal`プロファイルは、リポジトリの`scripts/personal-bin/`から次のCLIを`~/.local/bin`へ配置します。`base`プロファイルには配置しません。

日常的な使い方と短縮コマンドは[個人CLIコマンドガイド](personal-cli.md)を参照してください。

### Git cleanup

マージ済みPRのローカル作業ブランチを片付ける場合は、そのブランチをcheckoutしたprimary worktreeで実行します。

```bash
gpc
```

未追跡ファイルを含むdirty tree、linked worktree、未マージPR、PRのhead不一致、`main`・`master`・`develop`以外のbaseでは停止します。成功時だけbaseへ切り替え、`origin`からfast-forwardして、対象PRのローカルhead branchだけを削除します。remote branch、他のローカルブランチ、worktree、stashは変更しません。

Agent worktreeの一括整理は、primary worktreeから実行します。既定はdry-runです。

```bash
gac
gac --apply
gac --apply --force
```

対象はGitに登録されている`../<repo-name>-worktrees/`配下のworktreeと、それぞれに紐づくローカルブランチだけです。名前だけで推定したブランチ、別パスのworktree、remote branchは対象にしません。`--apply`は削除前に全対象を検査し、dirty worktreeまたは既定remote branchへ未マージのブランチが一つでもあれば、何も削除せず停止します。`--force`はこの検査を上書きしますが、検出範囲は広げません。

### HTTP server

カレントディレクトリをlocalhostだけへ公開する場合は`http`、LANへ公開する場合は`http-lan`を使います。引数はPython標準の`http.server`へ渡します。

```bash
http 8000
http-lan 8000
```

`http-lan`は確認なしで`0.0.0.0`へbindし、起動時に警告とLAN用URLを表示します。Windows Firewallなどホスト側の設定は変更しません。

### Claude provider launcher

`myclaude`はprovider別設定を読み、同じmodelをClaude Codeの各model tierへ割り当てて起動します。

```bash
myclaude --list
myclaude zai
myclaude deepseek --version
```

設定はGit管理外の`~/.config/envs/<provider>/.env`へ置きます。ファイルは現在ユーザー所有の通常ファイルかつmode 600でなければ実行を拒否します。

```dotenv
BASE_URL="https://provider.example"
API_KEY="replace-with-secret"
MODEL="provider/model-name"
```

```bash
chmod 600 ~/.config/envs/<provider>/.env
```

`.env`はshellとしてsourceせず、`BASE_URL`、`API_KEY`、`MODEL`の3キーだけを解析します。値やAPI keyは表示せず、secretファイル自体もリポジトリやchezmoiでは管理しません。

開発時のfixture testは次で実行します。破壊操作は一時Gitリポジトリ内だけで行います。

```bash
./tests/personal-cli-smoke.sh
```

## Safe-chain

[Aikido Safe-chain](https://github.com/AikidoSec/safe-chain)は、npm/yarn/pnpm/npx/pnpx、Bun、およびpip/uv/poetry経由でインストールされる悪意あるパッケージをブロックします。本体は[AikidoSec/safe-chain](https://github.com/AikidoSec/safe-chain)の公式GitHub Releaseから導入し、バージョンは`ansible/vars/main.yml`の`safe_chain_version`で固定します。現在のpin対象は**1.5.12**です。

bootstrapは公式のバージョン付きインストールスクリプトをダウンロードし、チェックサムを検証してから実行します。再実行時は、既存のSafe-chainバージョンを確認し、pinと一致する場合はスキップします。従来のBun globalインストール（`~/.bun/bin/safe-chain`）が残っていれば、公式バイナリへ移行する際に削除します。

shell integration（`~/.safe-chain/scripts/init-posix.sh`）は、chezmoi管理の`init.bash`から読み込みます。Safe-chainのインストーラーが`~/.bashrc`へ直接追加するsource行は、bootstrapが削除するため、 unmanagedな`~/.bashrc`への依存を残しません。

`~/.safe-chain/`以下のバイナリ、生成されたCA証明書、malware list、取得データはすべて機器固有の生成物です。リポジトリおよびchezmoiの管理対象外とし、手動でコピーしません。

更新時は、新しいリリースのバージョンとチェックサムを`ansible/vars/main.yml`へ記入し、Ubuntu 26.04 x86_64で次を実行して動作を確認してください。

```bash
./bootstrap base
./tests/safe-chain-smoke.sh
```

CodexとPiの更新は`update-ai`がminimum-package-age例外を一時指定します。Pi本体には`@earendil-works/*`、`pi-web-access`のPackage manager内部npmには`pi-web-access`だけを対象外にします。`npmCommand`はmiseとSafe-chainを通るため、これらの例外はmalware検査を無効化しません。Pi本体のnpm更新には`--ignore-scripts`を付けます。

Pi Web Accessの導入確認は外部モデルを使わずに次で行えます。

```bash
pi --version
pi list
./tests/pi-web-access-smoke.sh
```

手動のPi smokeでは、Piを起動して`web_search`、`fetch_content`、`get_search_content`、`source_check`が表示されることを確認します。API keyなしのzero-config search、Codex subscription login済み環境でのOpenAI search認証再利用は外部ネットワーク状態に依存するため、CIの必須条件にはしません。

## プロンプト

シェルプロンプトはStarshipで一元管理します。本体はmise、設定はchezmoi管理の`~/.config/starship.toml`で行います。Bashは`init.bash`でStarshipを一度だけ初期化し、独自のPS1や`git_branch`関数は使用しません。

現在のpresetはCatppuccin Mochaベースのpowerlineスタイルです。Nerd Font対応フォントがないとセパレーターやアイコンが文字化けするため、ターミナル側の設定を合わせてください。`line_break`を無効にしているため、プロンプトは1行で表示されます。設定を変更した場合は次を実行してください。

```bash
chezmoi apply ~/.config/starship.toml
```

```bash
# ~/.config/workstation/shell/local.bash
alias work='cd "$HOME/src/example"'
```

secret、認証情報、履歴、session stateは`local.bash`にも保存しないでください。

## Git・GitHub設定

GitHubへの接続はHTTPSへ統一します。初回clone前の`git`と`gh`は手動で準備し、bootstrapでもbaseパッケージとして導入することで、再セットアップ時の再現性を保証します。`gh`はbootstrap時のAPT導入後、Ansibleのプロビジョニングでmise管理へ移行し、lockfileでバージョンを固定します。chezmoiは次の非機密設定だけを管理します。

- `user.name`: `u7chan`
- `user.email`: `34462401+u7chan@users.noreply.github.com`
- default branch: `main`
- global ignore: `~/.config/git/ignore`
- GitHubのSSH形式URLからHTTPSへの書き換え
- 以下のGit alias

```gitconfig
[alias]
  s = status
  ss = status -s
  b = branch
  sw = switch
  swc = switch -c
  swm = switch main
  f = fetch --verbose
  fa = fetch --all --verbose
  fp = fetch --prune --verbose
  fap = fetch --all --prune --verbose
  pl = pull --verbose
  plr = pull --rebase --verbose
  plm = !git fetch origin main --verbose
  p = push --verbose
  puo = push -u origin HEAD
  cm = commit
  cma = commit --amend --no-edit
  lg = log --oneline --graph --decorate
  last = log -1 HEAD
  unstage = restore --staged .
  discard = restore .
```

上記に含まれないaliasや、`safe.directory=*`、token、credential、SSH鍵、ssh-agent、keychain、署名鍵はこのリポジトリへ保存しません。

認証とcredential helperは構成管理しません。初回clone前に次を手動で実行してください。

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

chezmoiのGit設定は、`gh auth setup-git`が`~/.gitconfig`へ追加したcredential helperを保持します。token、credential、SSH鍵、ssh-agent、keychain、署名鍵はこのリポジトリへ保存しません。
