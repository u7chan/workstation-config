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
| ベース APT パッケージ（build-essential, ca-certificates, curl, git, jq, postgresql-client） | 担当 | — | `base` role の `base_apt_packages` |
| `~/.local/bin` の作成 | 担当 | — | `base` role |
| chezmoi バイナリの導入 | 担当 | — | `base` role。chezmoi source の適用は `bootstrap` で共通 |
| mise バイナリ・設定・lockfile の導入 | 担当 | — | `base` role。`provisioning/mise/config.toml` / `mise.lock` |
| Safe-chain の導入・更新 | 担当 | — | `base` role。バージョンは `ansible/vars/main.yml` で固定 |
| マシン固有ローカル設定 `~/.config/workstation/shell/local.bash` の雛形 | 担当 | — | `base` role。内容は手動で編集し、Git 管理外 |
| 共通 Bash 初期化（mise, Safe-chain, Starship, ローカル設定読み込み） | 担当 | 担当 | chezmoi 管理の `init.bash`。両プロファイルで有効 |
| mise 管理ツール（Node.js LTS, Bun 1.x, uv, ripgrep, fd, gh, Neovim 0.12.x, Hunk, Lazygit, Lazydocker, Yazi, Starship, Herdr, cagent, Playwright CLI） | 担当 | 担当 | mise は `base` で導入。`cagent`はlockedなGitHub Release assetで両プロファイルに導入 |
| AI CLI（Codex / Claude Code / OpenCode / Pi）本体の導入 | — | 担当 | `update-ai` 経由。`personal_ai_tools` で導入するツールを選択可能 |
| Pi Packages（`pi-web-access` / `pi-codex-image-gen` / `@howaboua/pi-codex-conversion` / `@ogulcancelik/pi-session-recall`） | — | 担当 | `personal_ai_tools` に `pi` が含まれる場合だけ、Pi公式Package managerでglobal install/update。`base`では導入しない。詳細は[Pi Packages一覧](pi-packages.md)を参照 |
| Herdr integration（Codex / Claude Code / OpenCode / Pi） | — | 担当 | AI CLI導入後にHerdr公式installerで`personal_ai_tools`の選択対象だけを導入・検証。非選択integrationは自動削除しない |
| AI CLI 設定（Codex / Claude Code / OpenCode / cagent） | — | 担当 | Codex / OpenCode / cagent は chezmoi source として配置。`~/.claude/statusline.py` は chezmoi で管理し、`claude/settings.json` の `theme` / `statusLine` は `personal` profile かつ Claude 選択時に bootstrap が fragment merge で管理。`cagent`の使用主体はCodexとOpenCodeを導入する`personal` |
| 個人 CLI スクリプト（myclaude, gac, gpc, http, http-lan, myupdate） | — | 担当 | `personal` role の `scripts/personal-bin/` |
| 開発ツールの手動更新 | — | 担当 | `myupdate`で選択済みAI CLI、mise管理のHerdrを同期更新。再provisioningとも排他 |
| Docker CE の導入 | — | 担当（オプション） | `docker_ce` role。`personal_docker_ce_enabled=false` で無効化可能 |

Pi本体とPi Packagesは`personal`の`update-ai`がmise管理のNode.js/npmとSafe-chain経由で導入・更新します。`personal_ai_tools`でPiが選択されている場合だけglobal scopeへ導入し、`base`では変更しません。要件、Packageごとの所有権、設定merge、Safe-chain経路、検証手順は[Pi Packages一覧](pi-packages.md)に集約しています。

表の`ripgrep`はPi Package登録ではなく、`base` / `personal`共通のmise管理CLIです。`pi-session-recall`の`session_search`がglobal sessions rootを検索する際の優先backendとして恒久的に利用します。Package側のgrep / Node scan fallbackは維持し、CIの`ubuntu-slim`だけはstatic checkの`command -v rg` / `rg --version`を満たすためworkflowでAPT導入します。したがって、CIのAPT追加はworkstationの責務境界やmiseの導入経路を変更しません。

Pi Packageのsource、要件、設定所有権、Safe-chain経路、責務境界、検証手順は[Pi Packages一覧](pi-packages.md)に集約します。ここでは`base` / `personal`の導入条件とHerdrとの大まかな境界だけを扱います。

Herdr integrationの生成hook/pluginはHerdrのruntime管理対象であり、chezmoi sourceには追加しません。Codexの`config.toml`やOpenCodeの`opencode.json`など既存の非機密設定はchezmoiが管理しますが、Herdrが追加するhook/plugin部分はHerdrが所有します。Piでは`herdr-agent-state.ts`とPi Packagesを別管理し、互いのファイル・登録を上書きしません。Pi Packagesが所有する登録、conversionのmanaged fragment、`pi-codex-image-gen`の生成画像と任意設定もユーザーruntimeとして扱います。`@ogulcancelik/pi-session-recall`の`~/.pi/agent/sessions/**`と`session-recall.json`もユーザーruntimeであり、global sessionの本文をchezmoiやGitへ取り込みません。Claude Codeでは、Herdrが生成する`~/.claude/settings.json`のhook entriesと`~/.claude/hooks/herdr-agent-state.sh`をHerdrが所有し、bootstrapがfragmentからmergeする`theme` / `statusLine`とは管理境界を分けます。認証情報、session、履歴、cache、ログ、生成画像、生成stateはどちらの管理対象にも含めません。

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
