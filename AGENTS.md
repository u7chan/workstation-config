# workstation-config

Ubuntu 26.04 WSL2 上の開発環境をコードで定義し、再現可能にするための IaC リポジトリです。

## 使用技術

| カテゴリ | 技術 |
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

## ドキュメント Index

| ドキュメント | 内容 |
|---|---|
| [README.md](README.md) | 人間向け。リポジトリ全体の概要、Quick start、静的チェック |
| [docs/bootstrap-prerequisites.md](docs/bootstrap-prerequisites.md) | WSL作成、ユーザー作成、GitHub認証、clone前の手順 |
| [docs/workstation.md](docs/workstation.md) | profile、Ansible role、mise、chezmoi、各種ツール、検証 |
| [docs/roles-boundary.md](docs/roles-boundary.md) | `base` / `personal` の責務分界と適用条件 |
| [home/README.md](home/README.md) | chezmoi source ディレクトリの説明 |
