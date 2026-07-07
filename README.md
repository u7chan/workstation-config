# workstation-config

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

## 開発時の確認

```bash
./tests/static.sh
```

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。
