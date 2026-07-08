# Workstation構成ガイド

Ubuntu 26.04 WSL2を再現可能なワークステーションへ収束させるための構成です。

## 手動で準備するもの

bootstrapは次の作業を自動化しません。

1. WSLディストリビューションと一般ユーザーの作成
2. `git`と`gh`の導入
3. `gh auth login`によるGitHub HTTPS認証
4. このprivateリポジトリのclone

具体的なコマンドは[初期セットアップ手順](bootstrap-prerequisites.md)を参照してください。

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。

## Bootstrap

個人ワークステーションには、引数なしで`personal`プロファイルを適用します。

```bash
./bootstrap
```

個人用Roleを含めない環境では、必ず`base`を明示します。

```bash
./bootstrap base
```

`personal`は常に`base`を包含します。適用順はAnsible、chezmoi、mise、Herdr integrationです。

`personal`では任意RoleとしてDocker CEも既定で導入します。Dockerを導入しない
personal構成はAnsibleを直接実行し、`personal_docker_ce_enabled=false`を指定してください。
`base`ではDocker repository、package、service、groupのいずれも変更しません。

bootstrapはchezmoi管理対象をリポジトリの宣言状態へ非対話で収束させます。管理対象ファイルのローカル変更は上書きしますが、secret、認証state、`~/.config/workstation/shell/local.bash`などの管理対象外ファイルは変更しません。

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

## 開発時の確認

```bash
./tests/static.sh
```

## miseの管理範囲

`base`と`personal`の両プロファイルで、次のランタイムとportable CLIをmise経由で導入します。

- Node.js LTS、Bun 1.x、uv
- ripgrep、fd、Neovim 0.12.x、Yazi、Starship、Herdr

Python本体はmiseで管理しません。プロジェクトの`.python-version`に基づくPythonと`.venv`はuvに委譲し、Ubuntuの`python3`はOS管理のままにします。nvm、APT版Neovim、ツールごとの手動PATH追加は使用しません。

`mise/config.toml`は更新範囲、`mise/mise.lock`はUbuntu 26.04 x86_64で検証する実バージョンとダウンロード情報を保持します。bootstrapはlocked modeで導入するため、lockfileにない版への暗黙更新は行いません。

更新時は、Ubuntu 26.04 x86_64で次を実行し、差分と動作を確認します。

```bash
MISE_CONFIG_FILE="$PWD/mise/config.toml" mise upgrade
MISE_CONFIG_FILE="$PWD/mise/config.toml" mise lock --platform linux-x64
MISE_CONFIG_FILE="$PWD/mise/config.toml" MISE_LOCKED=1 mise install
```

## Neovim

設定はchezmoiが`~/.config/nvim`へ配置し、Neovim本体はmiseだけで管理します。初回起動時にプラグインを取得します。

```bash
./tests/neovim-smoke.sh
type -a nvim
mise which nvim
```

プラグイン更新の担当者は、Neovimで`:Lazy update`を実行し、生成された`lazy-lock.json`の差分と上記smoke testを確認してください。Masonで導入するLSP serverとTreesitter parserは生成物のためGit管理しません。

## Yazi

Yazi本体はmise、`~/.config/yazi/yazi.toml`とpackage宣言はchezmoiで管理します。標準テーマと標準キーマップを使い、plugin本体、flavor本体、cache、履歴、preview生成物、runtime stateはGit管理しません。fresh HOME相当の設定読込は次で確認できます。

```bash
./tests/yazi-smoke.sh
```

pluginやflavorを追加・更新する場合は`package.toml`の宣言を更新して`ya pkg install`を実行し、取得物をcommitせず上記smoke testを再実行してください。Yazi本体の更新は「miseの管理範囲」の手順でlockfileも更新します。

## HerdrとAI CLI

Herdr本体はmiseで管理します。Codex、Claude Code、OpenCodeは`personal`プロファイルだけで導入し、Herdrのintegration installerには所有させません。CodexはnpmをSafe-chain経由、Claude CodeとOpenCodeは各公式installerで最新版を導入します。AI CLIの認証は手動です。

`personal`プロファイルでは[`u7chan/agent-skills`](https://github.com/u7chan/agent-skills)を`~/workspace/agent-skills`へHTTPSでcloneし、`~/.claude/skills`と`~/.codex/skills`をそのリポジトリへのsymlinkとして作成します。personal bootstrapを再実行すると、agent-skillsは`main`ブランチの最新状態へ更新されます。既存の実ディレクトリやファイルは上書きしないため、同名のパスがある場合は内容を確認して退避してからbootstrapを再実行してください。

Codex、Claude Code、OpenCode本体の更新入口は`update-ai`だけです。Codex更新時は`@openai/codex`だけをSafe-chainのminimum package age対象外にしますが、malware検査は維持します。Claude Codeは`DISABLE_AUTOUPDATER=1`、OpenCodeは`~/.config/opencode/opencode.json`の`autoupdate: false`で内蔵自動更新を停止します。

```bash
update-ai
./tests/ai-clis-smoke.sh
```

chezmoiが管理するのは`~/.codex/config.toml`、`~/.config/opencode/opencode.json`などのallowlist化した非機密設定だけです。auth、履歴、DB、session、cache、ログ、Herdr生成stateはGit管理しません。

WSL再起動後は次を実行し、HerdrとCodexがmise配下のLinux binaryへ解決され、Windows側のCodex shimへフォールバックしないことを確認します。

```bash
./tests/wsl-restart-smoke.sh
```

シェル初期化が反映されない場合は、一時的にmiseを有効化してcommand hashを破棄してから再確認します。

```bash
eval "$(~/.local/bin/mise activate bash)"
hash -r
type -a herdr codex
```

Codexは通常の`HOME`にある`~/.codex/config.toml`を読みます。restart smokeの`codex features list`は、この設定がCodex起動時に正常に解析されることも検証します。

## Bashのローカル設定

共通のBash初期化はchezmoi管理の`~/.config/workstation/shell/init.bash`から読み込みます。Ubuntu標準の`~/.bashrc`はそのまま残し、管理済み初期化ファイルを読み込むブロックだけを追加します。

マシン固有のworkspace aliasなどは、`~/.config/workstation/shell/local.bash`へ記述してください。このファイルはGitおよびchezmoiの管理対象外で、bootstrapは既存内容を変更せずmode 600を維持します。

## 個人CLI

`personal`プロファイルは、リポジトリの`scripts/personal-bin/`から次のCLIを`~/.local/bin`へ配置します。`base`プロファイルには配置しません。

### Git cleanup

マージ済みPRのローカル作業ブランチを片付ける場合は、そのブランチをcheckoutしたprimary worktreeで実行します。

```bash
git-pr-cleanup
# Gitの外部サブコマンドとしても同じ処理
git pr-cleanup
```

未追跡ファイルを含むdirty tree、linked worktree、未マージPR、PRのhead不一致、`main`・`master`・`develop`以外のbaseでは停止します。成功時だけbaseへ切り替え、`origin`からfast-forwardして、対象PRのローカルhead branchだけを削除します。remote branch、他のローカルブランチ、worktree、stashは変更しません。

Agent worktreeの一括整理は、primary worktreeから実行します。既定はdry-runです。

```bash
git-agent-cleanup
git-agent-cleanup --apply
git-agent-cleanup --apply --force
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

`clp`はprovider別設定を読み、同じmodelをClaude Codeの各model tierへ割り当てて起動します。

```bash
clp --list
clp zai
clp deepseek --version
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

Codexの更新だけは`update-ai`がminimum-package-age例外を一時指定します。この例外はmalware検査を無効化しません。

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

GitHubへの接続はHTTPSへ統一します。初回clone前の`git`と`gh`は手動で準備し、bootstrapでもbaseパッケージとして導入することで、再セットアップ時の再現性を保証します。`gh`はUbuntu 26.04のuniverseパッケージを利用し、バージョンは固定せずディストリビューションの更新に追従します。chezmoiは次の非機密設定だけを管理します。

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
  plm = !git fetch origin main:main --verbose
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
