# workstation-config

Ubuntu 26.04 WSL2を再現可能なワークステーションへ収束させるための構成です。

## 手動で準備するもの

bootstrapは次の作業を自動化しません。

1. WSLディストリビューションと一般ユーザーの作成
2. `git`と`gh`の導入
3. `gh auth login`によるGitHub HTTPS認証
4. このprivateリポジトリのclone

具体的なコマンドは[初期セットアップ手順](docs/bootstrap-prerequisites.md)を参照してください。

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

`personal`は常に`base`を包含します。適用順はAnsible、chezmoi、miseです。

bootstrapは次の条件を事前検査します。

- Ubuntu 26.04
- WSL2
- root以外の一般ユーザー
- sudoを利用可能
- `base`または`personal`プロファイル

AnsibleはUbuntuのAPT版`ansible-core`を使用し、OS Pythonへpipで導入しません。

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

## Bashのローカル設定

共通のBash初期化はchezmoi管理の`~/.config/workstation/shell/init.bash`から読み込みます。Ubuntu標準の`~/.bashrc`はそのまま残し、管理済み初期化ファイルを読み込むブロックだけを追加します。

マシン固有のworkspace aliasなどは、`~/.config/workstation/shell/local.bash`へ記述してください。このファイルはGitおよびchezmoiの管理対象外で、bootstrapは既存内容を変更せずmode 600を維持します。

```bash
# ~/.config/workstation/shell/local.bash
alias work='cd "$HOME/src/example"'
```

secret、認証情報、履歴、session stateは`local.bash`にも保存しないでください。

## Git・GitHub設定

GitHubへの接続はHTTPSへ統一します。bootstrapはAPTで`git`と`gh`を導入し、chezmoiは次の非機密設定だけを管理します。

- `user.name`: `u7chan`
- `user.email`: `34462401+u7chan@users.noreply.github.com`
- default branch: `main`
- global ignore: `~/.config/git/ignore`
- GitHubのSSH形式URLからHTTPSへの書き換え

認証とcredential helperは構成管理しません。初回clone前に次を手動で実行してください。

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

chezmoiのGit設定は、`gh auth setup-git`が`~/.gitconfig`へ追加したcredential helperを保持します。token、credential、SSH鍵、ssh-agent、keychain、署名鍵はこのリポジトリへ保存しません。
