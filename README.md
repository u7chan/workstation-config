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
- [base / personal の責務分界](docs/roles-boundary.md): 各プロファイルの担当範囲と適用条件。

## 開発時の確認

```bash
./tests/static.sh
```

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。

## Public 化前の gate

Public 化前は、PR と `main` ブランチへの push で gitleaks による secret scan CI を通してください。検出された場合は `.gitleaks.toml` で最小限の allowlist を検討するか、secret を取り除いてからマージしてください。visibility 変更や credential ローテーション、履歴 rewrite はこの CI では行いません。
