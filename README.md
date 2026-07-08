# workstation-config

[![Secret Scan](https://img.shields.io/github/actions/workflow/status/u7chan/workstation-config/secret-scan.yml?branch=main&label=Secret%20Scan&style=flat&logo=github)](https://github.com/u7chan/workstation-config/actions/workflows/secret-scan.yml)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

Ubuntu 26.04 WSL2を再現可能なワークステーションへ収束させるための構成です。

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
- [base / personal の責務分界](docs/roles-boundary.md): 各プロファイルの担当範囲と適用条件。

## 技術スタック

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

## 開発時の確認

```bash
./tests/static.sh
```

## Secret 管理

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。
