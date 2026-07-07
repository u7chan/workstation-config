# base / personal の責務分界

このドキュメントは、`workstation-config` の2つのプロファイル `base` と `personal` が
それぞれ担当する責務を表形式でまとめたものです。

`personal` は常に `base` を包含します。`base` のみを適用する場合は `./bootstrap base` を、
個人用ワークステーションには引数なしの `./bootstrap`（`personal`）を使用してください。

## 責務分界表

| 責務 | base | personal | 備考 |
|---|---|---|---|
| 対象環境の事前検査（Ubuntu 26.04 / WSL2 / x86_64 / 一般ユーザー / sudo） | 担当 | 担当 | `bootstrap` と `ansible/playbook.yml` で共通して実施 |
| Ansible profile の選択 | `base` | `personal` | `workstation_profile` extra var で制御 |
| Ubuntu 26.04 WSL2 の systemd 259 回避策 | 担当 | — | `base` role。対象環境（Ubuntu 26.04 WSL2 + systemd 259）のみ適用 |
| ベース APT パッケージ（build-essential, ca-certificates, curl, git, gh） | 担当 | — | `base` role の `base_apt_packages` |
| `~/.local/bin` の作成 | 担当 | — | `base` role |
| chezmoi バイナリの導入 | 担当 | — | `base` role。chezmoi source の適用は `bootstrap` で共通 |
| mise バイナリ・設定・lockfile の導入 | 担当 | — | `base` role。`mise/config.toml` / `mise.lock` |
| Safe-chain の導入・更新 | 担当 | — | `base` role。バージョンは `ansible/vars/main.yml` で固定 |
| マシン固有ローカル設定 `~/.config/workstation/shell/local.bash` の雛形 | 担当 | — | `base` role。内容は手動で編集し、Git 管理外 |
| 共通 Bash 初期化（mise, Safe-chain, Starship, ローカル設定読み込み） | 担当 | 担当 | chezmoi 管理の `init.bash`。両プロファイルで有効 |
| mise 管理ツール（Node.js LTS, Bun 1.x, uv, ripgrep, fd, Neovim 0.12.x, Yazi, Starship, Herdr） | 担当 | 担当 | mise は `base` で導入。両プロファイルで有効 |
| AI CLI（Codex / Claude Code / OpenCode）本体の導入 | — | 担当 | `update-ai` 経由。`personal` のみ実行 |
| AI CLI 設定（Codex / OpenCode） | — | 担当 | chezmoi source として配置。使用主体は `personal` |
| 個人 CLI スクリプト（clp, git-agent-cleanup, git-pr-cleanup, http, http-lan） | — | 担当 | `personal` role の `scripts/personal-bin/` |
| agent-skills リポジトリの clone と AI CLI への symlink | — | 担当 | `personal` role の `agent_skills.yml` |
| Docker CE の導入 | — | 担当（オプション） | `docker_ce` role。`personal_docker_ce_enabled=false` で無効化可能 |

## 補足

- `base` に含まれない責務は `personal` にも含まれません。`personal` は `base` を包含するため、
  `personal` プロファイルでは上表の `base` 列が「担当」の項目もすべて適用されます。
- Docker CE は `personal` の任意 Role です。`personal` 適用時も
  `--extra-vars personal_docker_ce_enabled=false` で導入をスキップできます。
- `base` では Docker repository、package、service、group を一切変更しません。
- AI CLI 設定ファイルは chezmoi source として存在するため、`base` プロファイル適用時も
  ディスク上に配置されますが、AI CLI 本体は `personal` でのみ導入されるため、
  これらの設定が機能するのは `personal` プロファイルです。
