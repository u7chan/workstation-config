# workstation-config

[![Secret Scan](https://github.com/u7chan/workstation-config/actions/workflows/secret-scan.yml/badge.svg?branch=main)](https://github.com/u7chan/workstation-config/actions/workflows/secret-scan.yml)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

Ubuntu 26.04 WSL2 上の開発環境を、コードで定義し再現可能にするための IaC 構成です。

## Tech Stack

| カテゴリ | 使用技術 |
|---|---|
| OS | Ubuntu 26.04 on WSL2 |
| Provisioning | Ansible |
| Dotfiles | chezmoi |
| ランタイム管理 | mise |
| Shell | Bash + Starship |
| コンテナ | Docker CE |
| エディタ | Neovim |
| ファイルマネージャ | Yazi |
| AI CLI | Codex / Claude Code / OpenCode / Herdr |
| CI | GitHub Actions + gitleaks |

## Quick start

初回はWindowsホスト側でWSLディストリビューション、Linuxユーザー、GitHub認証を準備してからcloneします。

```bash
git clone https://github.com/u7chan/workstation-config.git
cd workstation-config
./bootstrap
```

個人用Roleを含めない環境では、`base`を明示します。

```bash
./bootstrap base
```

## Docs

- [Bootstrap前の初期セットアップ](docs/bootstrap-prerequisites.md): WSL作成、distro名指定、削除時の注意、GitHub認証、bootstrap前の確認。
- [Workstation構成ガイド](docs/workstation.md): profile、Ansible role、mise、chezmoi、Docker、Neovim、Yazi、AI CLI、開発時の検証。
- [CLIツールガイド](docs/cli-tools.md): miseで管理するターミナルツールの用途、導入元、基本的な起動方法。
- [個人CLIコマンドガイド](docs/personal-cli.md): Git cleanup、簡易HTTP server、Claude provider launcherの早見表と使い方。
- [base / personal の責務分界](docs/roles-boundary.md): 各プロファイルの担当範囲と適用条件。
- [Windows Terminal設定](docs/windows-terminal.md): 設定雛形の意図、WSLディストリビューション名の確認、反映・復元手順。

## Development Checks

ローカルで静的チェックを実行します。

```bash
./tests/static.sh
```

## Secret Management

> [!IMPORTANT]
> secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。
