# base / personal の責務分界

このドキュメントは、`workstation-config` の2つのプロファイル `base` と `personal` が
それぞれ担当する責務を表形式でまとめたものです。

`personal` は常に `base` を包含します。`base` のみを適用する場合は `./bootstrap base` を、
個人用開発環境には引数なしの `./bootstrap`（`personal`）を使用してください。

## 責務分界表

| 責務 | base | personal | 備考 |
|---|---|---|---|
| 対象環境の事前検査（Ubuntu 26.04 / WSL2 / x86_64 / 一般ユーザー / sudo） | 担当 | 担当 | `bootstrap` で Ubuntu 26.04 / WSL2 / x86_64 / 一般ユーザー / sudo を検証。<br>`ansible/playbook.yml` では Ubuntu 26.04 / x86_64 と `workstation_profile` を検証。 |
| Git パッケージ導入 | 担当 | 担当（継承） | `base_apt_packages` |
| Git 共通設定（`init.defaultBranch`, `core.excludesFile`, GitHub URL rewrite） | 担当 | 担当（継承） | `home/modify_dot_gitconfig` |
| Git alias | 担当 | 担当（継承） | 比較的標準的な運用 alias。`home/modify_dot_gitconfig` で管理 |
| Git ユーザー設定（`user.name` / `user.email`） | — | 担当 | `ansible/roles/personal/templates/git_config.j2`。変数 `personal_git_user_name` / `personal_git_user_email` で制御 |
| credential helper / auth state / `safe.directory=*` | — | — | いずれの role も管理しない |
| Ansible profile の選択 | `base` | `personal` | `workstation_profile` extra var で制御 |
| Ubuntu 26.04 WSL2 の systemd 259 回避策 | 担当 | — | `base` role。対象環境（Ubuntu 26.04 WSL2 + systemd 259）のみ適用 |
| ベース APT パッケージ（build-essential, ca-certificates, curl, git, gh, jq） | 担当 | — | `base` role の `base_apt_packages` |
| `~/.local/bin` の作成 | 担当 | — | `base` role |
| chezmoi バイナリの導入 | 担当 | — | `base` role。chezmoi source の適用は `bootstrap` で共通 |
| mise バイナリ・設定・lockfile の導入 | 担当 | — | `base` role。`provisioning/mise/config.toml` / `mise.lock` |
| Safe-chain の導入・更新 | 担当 | — | `base` role。バージョンは `ansible/vars/main.yml` で固定 |
| マシン固有ローカル設定 `~/.config/workstation/shell/local.bash` の雛形 | 担当 | — | `base` role。内容は手動で編集し、Git 管理外 |
| 共通 Bash 初期化（mise, Safe-chain, Starship, ローカル設定読み込み） | 担当 | 担当 | chezmoi 管理の `init.bash`。両プロファイルで有効 |
| mise 管理ツール（Node.js LTS, Bun 1.x, uv, ripgrep, fd, Neovim 0.12.x, Hunk, Lazygit, Lazydocker, Yazi, Starship, Herdr, cagent） | 担当 | 担当 | mise は `base` で導入。`cagent`はlockedなGitHub Release assetで両プロファイルに導入 |
| AI CLI（Codex / Claude Code / OpenCode）本体の導入 | — | 担当 | `update-ai` 経由。`personal_ai_tools` で導入するツールを選択可能 |
| AI CLI 設定（Codex / OpenCode / cagent） | — | 担当 | chezmoi source として配置。`cagent`の使用主体はCodexとOpenCodeを導入する`personal` |
| 個人 CLI スクリプト（clp, gac, gpc, http, http-lan） | — | 担当 | `personal` role の `scripts/personal-bin/` |
| agent-skills リポジトリの clone と AI CLI への symlink | — | 担当 | `personal` role の `agent_skills.yml`。`personal_agent_skills_enabled=false` で無効化可能 |
| Docker CE の導入 | — | 担当（オプション） | `docker_ce` role。`personal_docker_ce_enabled=false` で無効化可能 |

## 補足

- `base` に含まれない責務は `personal` にも含まれません。`personal` は `base` を包含するため、
  `personal` プロファイルでは上表の `base` 列が「担当」の項目もすべて適用されます。
- 将来的に work プロファイルを追加する場合は `personal` を継承し、`user.name` / `user.email` を上書きする想定。
- Docker CE は `personal` の任意 Role です。`personal` 適用時も
  `--extra-vars personal_docker_ce_enabled=false` で導入をスキップできます。
- `base` では Docker repository、package、service、group を一切変更しません。
- AI CLI 設定ファイルは chezmoi source として存在するため、`base` プロファイル適用時も
  ディスク上に配置されますが、AI CLI 本体は `personal` でのみ導入されるため、
  これらの設定が機能するのは `personal` プロファイルです。
