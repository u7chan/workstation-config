# Workstation構成ガイド

Ubuntu 26.04 WSL2 上の開発環境を、コードで定義し再現可能にするための IaC 構成です。

## 手動で準備するもの

bootstrapは次の作業を自動化しません。

1. WSLディストリビューションと一般ユーザーの作成
2. `git`と`gh`の導入
3. `gh auth login`によるGitHub HTTPS認証
4. このprivateリポジトリのclone

具体的なコマンドは[初期セットアップ手順](bootstrap-prerequisites.md)を参照してください。

secret、認証state、履歴、ログ、cache、マシン固有設定はリポジトリへ保存しません。

## Bootstrap

個人開発環境には、引数なしで`personal`プロファイルを適用します。

```bash
./bootstrap
```

個人用Roleを含めない環境では、必ず`base`を明示します。

```bash
./bootstrap base
```

`personal`は常に`base`を包含します。Ansibleの`base` roleはmiseの設定をtrustした後、Herdrだけを最新版へ解決し、残りのツールをlockfile固定で導入します。続いて`personal` roleが選択済みAI CLIを更新し、AI CLIの設定ディレクトリを準備してからHerdr公式integrationを導入・検証します。その後、bootstrapはchezmoiを適用し、AI CLI設定ディレクトリのmode 0700を再適用します。Piが選択されている場合だけchezmoiがPi設定を配置します。WSL2/Windows Terminal向けキーバインド（画像貼り付け`Alt+V`、メッセージキュー復元`Alt+Up`）は`~/.pi/agent/keybindings.json`へ、openai-codexのGPT-5.6系コンパクション費用対策の`modelOverrides`は`~/.pi/agent/models.json`へ展開し、pi-web-accessのcuratorブラウザを開かない`workflow: "auto-summary"`デフォルトは`~/.pi/agent/web-search.json`へ`create`属性で配布します（既存ファイルは上書きせず、API key等の手動追加は維持）。未選択の場合はbootstrapが削除します。Claudeが選択されている場合だけ、リポジトリ直下のfragmentを`~/.claude/settings.json`へmergeしてからmise installを再実行します。

`personal`では任意RoleとしてDocker CEも既定で導入します。Dockerを導入しない
personal構成はAnsibleを直接実行し、`personal_docker_ce_enabled=false`を指定してください。
`base`ではDocker repository、package、service、groupのいずれも変更しません。

AI CLIをsubset化する場合は、`WORKSTATION_PERSONAL_AI_TOOLS`へカンマ区切りで指定します。未指定時は4種類すべてを対象にし、空文字を指定するとpersonal AI CLIの更新・integration導入を無効化します。

```bash
WORKSTATION_PERSONAL_AI_TOOLS=codex,opencode ./bootstrap personal
WORKSTATION_PERSONAL_AI_TOOLS= ./bootstrap personal
```

bootstrapはchezmoi管理対象をリポジトリの宣言状態へ非対話で整えます。管理対象ファイルのローカル変更は上書きしますが、secret、認証state、`~/.config/workstation/shell/local.bash`などの管理対象外ファイルは変更しません。

bootstrapは次の条件を事前検査します。

- Ubuntu 26.04
- WSL2（[WSL本体のバージョンと実行方式](bootstrap-prerequisites.md#wsl本体のバージョンと実行方式)は別）
- root以外の一般ユーザー
- sudoを利用可能
- `base`または`personal`プロファイル

AnsibleはUbuntuのAPT版`ansible-core`を使用し、OS Pythonへpipで導入しません。

### Ubuntu 26.04 WSLのsystemd user session回避策

Ubuntu 26.04 WSL2のsystemd 259では、一度終了した`user@1000.service`が
再起動できない問題を[#25](https://github.com/u7chan/workstation-config/issues/25)で確認し、
`DelegateSubgroup=init.scope`を解除する回避策を導入しました。base Roleは対象環境に限り
`/etc/systemd/system/user@.service.d/wsl-cgroup-workaround.conf`を配置し、
`DelegateSubgroup`を解除します。Ubuntu 24.04および非WSL環境には適用しません。

上流の[WSL Issue #40593](https://github.com/microsoft/WSL/issues/40593)では、
複数distroのsystemdが同じcgroup namespaceを共有することで衝突する事例も報告されています。
[PR #41512](https://github.com/microsoft/WSL/pull/41512)はnamespace分離を導入し、
2.9.13に収録されました。3.0.1にはその後続修正が含まれます。
分離は`.wslconfig`の`[wsl2] isolateDistroCgroup`に依存し、
[3.0.1の既定値はtrue](https://github.com/microsoft/WSL/blob/3.0.1/src/windows/common/WslCoreConfig.h)です。
ただし、この修正が#25の原因まで解消したとは断定していません。

**回避策は維持します。** 一時的な設定ですが、WSL本体3.xという版番号だけでは撤去しません。
不要と判断できた場合も、対象バージョン・isolation設定などの条件を明記した後続Issueで、
Ansibleの配置条件・既存drop-inの削除・テストの変更を設計します。

#### WSL本体3.0.1での検証結果（2026-10-03）

[#197の検証コメント](https://github.com/u7chan/workstation-config/issues/197#issuecomment-5955950067)を
もとに記録しています。Windowsホスト側のCodexAppがPowerShellから専用distroを操作し、
日常利用中のdistroの設定変更・停止、ホストのisolation設定変更は行っていません。

| 項目 | 検証条件 |
|---|---|
| WSL本体／実行方式 | `3.0.1.0` ／ WSL2（`wsl --list --verbose`のVERSION=2） |
| カーネル | `wsl --version`: `6.18.40.1-1`、`uname -r`: `6.18.40.1-microsoft-standard-WSL2` |
| Ubuntu／systemdパッケージ | `26.04.1 LTS` ／ `259.5-0ubuntu3.4` |
| ユーザー／boot設定 | 両専用distroともUID/GID=1000、`Linger=no`、`systemd=true`、`initTimeout`の明示値なし |
| isolation | ホストに明示値なし。上記バージョンの既定値true。共存10組すべてでPID1のcgroup namespace IDが異なることを確認 |
| 対象ソース | `c181ce68bb25e9f7e0094e930e8e58908001b3fd`の`ansible/roles/base/tasks/systemd_workaround.yml` |

同じAnsibleタスクを両専用distroへ適用し、対象drop-inだけを退避・復元して比較しました。
回避策ありの実効設定は`DelegateSubgroup=`（空）、なしは`DelegateSubgroup=init.scope`です。
次の「成功」は、一般ユーザーでuser managerが`active`かつ`running`になったことを指します。

| 条件 | 回避策あり | 回避策なし |
|---|---|---|
| 作成直後の初回一般ユーザー起動 | 未適用 | 両方成功 |
| 専用peer停止中のprimary起動、primaryのterminate・再起動 | 成功 | 成功 |
| primary→peer、peer→primaryの順次起動 | 両方成功 | 両方成功 |
| 両ランチャーをほぼ同時に開始（各3回） | すべて成功 | すべて成功 |
| `loginctl terminate-user tester`後の単純なWSL再接続 | inactive、user busなし | inactive、user busなし |
| 停止確認後、`/bin/login -f tester`で新しいPAMセッションを生成（各3回） | すべて成功 | すべて成功 |

強制終了後の単純なWSL再接続では、両条件でuser managerが`inactive/dead`でした。
この試行のunitログにcgroupの`Device or resource busy`はなく、
新しいPAMセッションを作ると起動しました。セッションが再作成されないことが原因候補ですが、
観測とコードからの推論であり、WSL側の修正を検証した結果ではありません。
**単純なWSL再接続と新しいPAMログインは区別して記録します。**

日常distroは常時稼働していたため、専用peer停止中でもホスト全体の単一distro条件ではありません。
同時起動もランチャーを続けて開始したもので、内部初期化の厳密な同期は保証しません。
namespaceの比較は同時に稼働しているPID1のIDで行い、停止をまたいだIDや、
両方で`0::/init.scope`となった`/proc/1/cgroup`の文字列だけでは分離を判定していません。

旧WSL版、isolation無効、ホストVMの完全停止からの起動、異なるUID・Linger・systemdパッチ版、
Dockerコンテナ起動・画像貼り付け・AI CLI等の全体smokeは未検証です。
専用distroでは既存の`wsl-workaround`・`links`静的検査が成功しましたが、
`./tests/static.sh`と`./tests/wsl-restart-smoke.sh`の全体は未実行です。
`./bootstrap base`は初回に完了メッセージへ到達したものの、補助スクリプトの終了記録でエラーがあり、
再実行も`Resolve installed Herdr binary`で失敗したため、全体の正常終了・冪等性は成功扱いにしません。
この導入上の別件とWSL本体3.x・回避策との因果関係も未確定です。
根拠が不足しているため、現行Ansibleの適用条件と運用環境の回避策を維持します。

#### 再検証の進め方

Windowsホスト側のCodexAppなどから対象名を指定して操作します。
検証対象を停止しても担当エージェント自身が終了しない構成にしてください。

1. 人間が既存distro名を確認し、[初期セットアップ手順](bootstrap-prerequisites.md)に従って
   `wsl --install Ubuntu-26.04 --name workstation-test-ubuntu26`で専用distroを作成します。
   複数distroの比較には別名の専用peerも用意し、初回ユーザー作成・リポジトリ取得を行います。
   日常環境と同じUIDを使う条件や`Linger`値を記録します。
2. user managerの比較には`./bootstrap base`、または同じsystemd回避タスクの最小適用で足ります。
   personalのAI CLI・Herdr integrationは必須ではありません。導入失敗とuser managerの結果は区別します。
3. 専用distroの対象drop-inだけを退避・復元し、`sudo systemctl daemon-reload`後に実効設定を確認します。
   回避策なしの比較中にbootstrapを再実行するとdrop-inが再配置されるため、実行しません。
4. 初回起動・ユーザーセッション終了後・対象distro再起動後・複数distroの順次／同時起動を比較します。
   再起動は`wsl --terminate <検証用distro名>`の後、`wsl --list --verbose`でStoppedを確認してから行います。
   終了に問題がある場合は専用distroの`[boot] initTimeout`とログも記録し、cgroup問題と混同しません
   （[上流Issue #41596](https://github.com/microsoft/WSL/issues/41596)）。
5. セッション終了は専用distroの全ユーザーシェル・GUIを閉じ、必要ならそのrootセッションから
   `loginctl terminate-user <検証ユーザー>`を実行します。user managerの停止を確認した後、
   単純なWSL再接続と、rootからの`/bin/login -f <検証ユーザー>`による新しいPAMログインを別々に確認します。
6. 各一般ユーザーセッションで次を確認します。失敗時はunitログの必要な行だけを記録します。

   ```bash
   systemctl is-active "user@$(id -u).service"
   systemctl --user is-system-running
   systemctl show "user@$(id -u).service" -p DropInPaths -p DelegateSubgroup
   loginctl show-user "$USER" -p Linger
   readlink /proc/1/ns/cgroup
   cat /proc/1/cgroup
   journalctl -b -u "user@$(id -u).service"
   ```

7. 比較後はdrop-inと一時sudo設定を元に戻します。成果物を退避し、人間が対象名とデータの有無を
   確認してから`wsl --unregister <検証用distro名>`で専用distroだけを削除します。

日常利用中のdistroへの強制ログアウト・設定変更・停止、`wsl --shutdown`、
WSL本体のダウングレード、ホストのisolation設定変更は行いません。
実施できない再現経路は未検証として記録し、回避策を維持します。

`personal`相当のCLI・PATH・integrationを準備した環境では、対象distro再起動後に次の全体smokeも実行します。
`base`のみの場合は上記user manager検査と区別し、全体smoke未実行を成功と扱いません。

```bash
./tests/wsl-restart-smoke.sh
```

### WSLのbinfmtエラーとWindows interop

WSLの[PR #40621](https://github.com/microsoft/WSL/pull/40621)は、
別distro終了時のbinfmt登録の一括消去を防ぐため、`/proc/sys/fs/binfmt_misc/status`を
read-onlyで保護します。これは個別の登録・解除を妨げるものではありません。
systemd-binfmtのflushはこの保護により失敗することがあり、
[上流Issue #41226](https://github.com/microsoft/WSL/issues/41226)でも、
機能に影響がなければ無視してよいと説明されています。

上記の専用distroでは`systemd-binfmt.service`がfailed、システム全体がdegradedでも、
`WSLInterop`と既存の`python3.14`登録はenabledでした。statusは`tmpfs ro,mode=755`で、
通常比較26観測とPAM追加6観測すべてで`cmd.exe /d /c ver`が成功しました。
全てのbinfmt用途の正常性を確認したわけではありません。

状態を切り分けるときは、登録やクリップボードを変更しない次の確認を行います。

```bash
systemctl status systemd-binfmt.service --no-pager
journalctl -b -u systemd-binfmt.service
findmnt -T /proc/sys/fs/binfmt_misc/status
cat /proc/sys/fs/binfmt_misc/WSLInterop
cmd.exe /d /c ver
```

必要に応じて`/usr/lib/binfmt.d/*.conf`と対応する既存登録も照合します。
`degraded`だけでWindows interopの喪失と判断せず、機能が動いている場合は
serviceのmask・無効化、失敗状態のreset、binfmt登録の追加・削除を対処として行いません。
登録消失による`Exec format error`は別の症状です。
クリップボードへの影響と代替経路は[wl-clipboard（WSLgクリップボード）](#wl-clipboardwslgクリップボード)を参照してください。

## 構成

```text
.
|-- bootstrap             # 単一の実行入口
|-- ansible/              # OS基盤とプロファイル別Role
|-- home/                 # chezmoi source
|-- provisioning/         # bootstrapが$HOMEへ配置する設定の配布元（mise設定など）
|-- scripts/              # AI CLI更新スクリプトと個人CLI
|-- claude/               # Claude Code設定のfragment
|-- docs/                 # ガイド類
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

## PostgreSQLクライアント（psql）

PostgreSQLサーバーやdaemonは導入せず、クライアントのみをAPTの`postgresql-client`
パッケージで`base`プロファイルに導入します。miseのtool定義やlockfileには追加しません。
バージョンはUbuntu 26.04のAPT repositoryが提供する版に従います。

接続情報や認証情報（`.pgpass`など）は管理対象外です。導入後は次で確認できます。

```bash
psql --version
./tests/psql-smoke.sh
```

## wl-clipboard（WSLgクリップボード）

Piの画像貼り付け（`Alt+V`）はクリップボードを`wl-paste`（Wayland）→`xclip`（X11）→
`powershell.exe`（WSL interop）の順で読み取ります。WSLgが有効なWSL2では、Windows側の
スクリーンショット（`Win+Shift+S`）がWSLgのクリップボードbridge経由でWayland側には
`image/bmp`として見え、Piが内部でPNGへ変換して添付します。

このため`wl-clipboard`を`base_apt_packages`に追加しています（issue #178）。従来は
`wl-paste`も`xclip`も未導入のため、クリップボード読み取りがWSL interop経由の
`powershell.exe`に依存し、binfmt_miscの登録消失（`Exec format error`）で`Alt+V`の
画像貼り付けが無言で失敗していました。`wl-clipboard`を導入すると`wl-paste`が先に成功
するため、WSLInteropが停止していても画像を読み取れます。失敗モードがほぼ直交する
（WSLg停止 vs interop喪失）ため、実質的な二重化です。副次効果としてPiのテキスト
貼り付けや`/copy`（`wl-copy`経路）も安定化します。なお`.wslconfig`でWSLgを無効化
すると本経路は使えません。

導入後は次で確認できます。

```bash
wl-paste --list-types
./tests/wl-clipboard-smoke.sh
```

`Win+Shift+S`でスクリーンショットを撮った直後に`wl-paste --list-types`へ
`image/bmp`（または`image/png`）が含まれていれば、Piの`Alt+V`で画像を貼り付けられます。
WSLInterop停止状態（`powershell.exe`が`Exec format error`になる状態）でも同じく有効です。

`systemd-binfmt.service`のfailedやシステム全体のdegradedは、必ずしも登録消失を意味しません。
[WSLのbinfmtエラーとWindows interop](#wslのbinfmtエラーとwindows-interop)の手順で、
Windows実行ファイルの実行可否と登録状態を切り分けてください。

## 開発時の確認

```bash
./tests/static.sh
```

## miseの管理範囲

`base`と`personal`の両プロファイルで、次のランタイムとportable CLIをmise経由で導入します。

- Node.js LTS、Bun 1.x、uv
- ripgrep、fd、tree-sitter CLI、Neovim 0.12.x、Hunk、Lazygit、Lazydocker、Yazi、Starship、Herdr、cagent、Playwright CLI

`ripgrep`はPi Package専用の一時依存ではなく、`base` / `personal`の両profileでmiseが恒久的に管理する共通CLIです。`pi-session-recall`の`session_search`はglobal sessions root全体を`rg -i -F`で検索するため、global JSONLが増えても高速かつliteralな検索を標準経路として再現できます。`rg`がない場合のgrep / Node scan fallbackはPackage側に残りますが、workstationではrgを優先backendとして利用します。

Python本体はmiseで管理しません。プロジェクトの`.python-version`に基づくPythonと`.venv`はuvに委譲し、Ubuntuの`python3`はOS管理のままにします。nvm、APT版Neovim、ツールごとの手動PATH追加は使用しません。

対話シェルでは`mise activate bash --shims`を使い、mise管理ツールのshimをPATHの先頭に置きます。バージョン固有のインストール先を直接PATHへ残さないため、bootstrapやmise更新後も既存のユーザー用バイナリが管理対象CLIを隠しません。

CLIツールの用途と基本的な起動方法は[CLIツールガイド](cli-tools.md)を参照してください。

`provisioning/mise/config.toml`はグローバルmise設定の配布元、`provisioning/mise/mise.lock`はUbuntu 26.04 x86_64で検証する実バージョンとダウンロード情報を保持します。これらはmiseのプロジェクト設定として検出されないパスに置き、bootstrapが`~/.config/mise/`へ配置します。Herdr以外はbootstrapがlocked modeで導入するため、lockfileにない版への暗黙更新は行いません。HerdrはAI CLIとしての更新頻度を優先し、bootstrapごとに`latest`を解決してローカルのlockfileを更新します。

Pi本体はmiseのtool定義および`mise.lock`では管理しません。`personal`の`update-ai`がmise管理のNode.js/npm環境へ入り、Safe-chain経由で`@earendil-works/pi-coding-agent@latest`を`--ignore-scripts`付きで導入・更新します。Piを選択したときは続けてPi公式Package managerで`npm:pi-web-access`、`npm:pi-codex-image-gen`、`npm:@howaboua/pi-codex-conversion`、`npm:@ogulcancelik/pi-session-recall`をglobal packageとして導入・更新します。

更新時は、Ubuntu 26.04 x86_64で次を実行し、差分と動作を確認します。

- `MISE_CONFIG_DIR`でリポジトリの`provisioning/mise/`をグローバル設定ディレクトリに切り替え、`~/.config/mise/config.toml`を参照・更新対象から除外します
- `MISE_CONFIG_FILE`（`MISE_GLOBAL_CONFIG_FILE`）は、リポジトリが`$HOME`配下にある場合に`~/.config/mise/config.toml`が祖先ディレクトリのプロジェクト設定として優先されるため、この用途では機能しません

```bash
MISE_CONFIG_DIR="$PWD/provisioning/mise" mise upgrade
MISE_CONFIG_DIR="$PWD/provisioning/mise" mise lock -g --platform linux-x64
MISE_CONFIG_DIR="$PWD/provisioning/mise" MISE_LOCKED=1 mise install
```

Playwright CLI の Chromium は、`base` Role の mise tool 導入後に CLI が要求する revision を `playwright-cli install-browser chromium` で揃えます。手動で `mise upgrade` を実行した場合は、次回 smoke の headless `about:blank` open→close で revision のズレやブラウザ不足を検知します。

```bash
./tests/playwright-cli-smoke.sh
```

smoke が失敗した場合は、次の1コマンドで Chromium を再同期してから smoke を再実行します。

```bash
playwright-cli install-browser chromium
./tests/playwright-cli-smoke.sh
```

## Neovim

設定はchezmoiが`~/.config/nvim`へ配置し、Neovim本体はmiseだけで管理します。初回起動時にプラグインを取得します。

```bash
./tests/neovim-smoke.sh
type -a nvim
mise which nvim
```

プラグイン更新の担当者は、Neovimで`:Lazy update`を実行し、生成された`lazy-lock.json`の差分と上記smoke testを確認してください。Masonで導入するLSP serverとTreesitter parserは生成物のためGit管理しません。

### LSPサーバー

Mason経由で次の4つのLSPサーバーを導入・管理します。

| サーバー | Masonパッケージ名 | 用途 |
|---|---|---|
| lua_ls | `lua-language-server` | Lua (Neovim設定) |
| ts_ls | `typescript-language-server` | TypeScript / JavaScript |
| jsonls | `json-lsp` | JSON |
| bashls | `bash-language-server` | Bashスクリプト |

各LSPサーバーは`vim.lsp.config`と`vim.lsp.enable`で有効化します。`automatic_enable = false`はLSPの自動有効化だけを止め、`ensure_installed`に宣言したサーバーはsetup時に未導入であれば自動installされます。そのため初回起動から利用可能です。smoke testはinstall状態を検証し、不足時は明示的にinstallします。

### Treesitterパーサー管理方針

nvim-treesitterは `main` ブランチを使用します（`master` はアーカイブ済み）。Neovim 0.12以降の組み込みTreesitterでハイライト・インデントを有効化し、プラグインはパーサー管理に専念します。パーサーのコンパイルには `tree-sitter` CLI (>= 0.26.1) が必須で、miseで管理します。

管理パーサー (13個): bash, json, lua, markdown, markdown_inline, query, vim, vimdoc, javascript, typescript, tsx, yaml, toml

パーサーの追加はsmoke testのインストールスクリプトとファイル存在確認の更新をセットで行います。`:TSInstall` は非同期のため、headless smoke testではLuaから`require("nvim-treesitter").install()`を呼び出し`vim.wait`で完了を確認します。

### WSLクリップボード連携

WSL環境では`/proc/version`を確認し、Windows側の`clip.exe`と`powershell.exe`が利用可能であれば`vim.g.clipboard`にWSL専用のcopy/pasteコマンドを設定します。

- **copy**: `clip.exe` (レジスタ `"+"` と `"*"` の両方)
- **paste**: `powershell.exe -NoLogo -NoProfile -Command [Console]::Out.Write((Get-Clipboard -Raw).replace("`r", ""))` (レジスタ `"+"` と `"*"` の両方、CRLF除去済み)
- **cache_enabled = 0**: 更新検出を毎回行う

WSLまたはclipboardコマンドが利用できない環境では、Neovimの自動プロバイダー検出へフォールバックし、起動を妨げません。基本設定として`clipboard=unnamedplus`を維持します。

### 主要UI機能とキーマップ

#### 基本操作

| キー | 機能 |
|---|---|
| `<leader>w` | ファイル保存 |
| `<Esc>` | 検索ハイライト解除 |
| `[d` / `]d` | 前/次のdiagnosticへジャンプ |
| `<leader>q` | diagnostic一覧表示 |

#### ファイルツリー (nvim-tree)

| キー | 機能 |
|---|---|
| `<leader>e` | ツリー表示切替 |
| `<leader>E` | ツリーへフォーカス |
| `<leader>f` | 現在ファイルをツリーで表示 |
| `yp` | 相対パスをコピー |
| `yP` | 絶対パスをコピー |

#### バッファ操作 (Bufferline)

| キー | 機能 |
|---|---|
| `<S-h>` | 前のバッファ |
| `<S-l>` | 次のバッファ |
| `<leader>bp` | バッファピッカー |
| `<leader>bc` | 現在のバッファを閉じる |
| `<leader>bo` | 他のバッファを閉じる |
| `<leader>1`~`<leader>9` | 指定位置のバッファへ移動 |

#### LSP

| キー | 機能 |
|---|---|
| `gd` | 定義へジャンプ |
| `gr` | 参照一覧 |
| `K` | ホバー表示 |
| `<leader>rn` | リネーム |
| `<leader>ca` | コードアクション |
| `<leader>lf` | フォーマット (非同期) |

#### その他

| キー | 機能 |
|---|---|
| `<leader>m` | Masonを開く |
| `<leader>ff` | ファイル検索 (Telescope) |
| `<leader>fg` | grep検索 (Telescope) |
| `<leader>fb` | バッファ一覧 (Telescope) |
| `<leader>fh` | ヘルプ検索 (Telescope) |

Catppuccin Mocha colorschemeを使用し、lualine (global statusline)、nvim-scrollbar (cursor/diagnostic/gitsigns/handle表示、searchハイライト連携なし)、Gitsigns (current line blame、1000ms遅延) を統合します。

### 自動テストとWSL手動確認

headlessのsmoke testはプラグイン同期、4つのLSPサーバー、13個のTreesitterパーサー、プラグイン読込、オプション値、キーマップ、clipboard設定、`vim.deprecated`を検証します。

```bash
./tests/neovim-smoke.sh
```

WSL環境での手動確認は、Windows側のクリップボード連携を検証します。

1. Neovimでテキストをyank (`y`)
2. Windows側のアプリケーションで貼り付け (`Ctrl+V`) できることを確認
3. Windows側でテキストをコピー (`Ctrl+C`)
4. Neovimで貼り付け (`p`) できることを確認

クリップボードが動作しない場合は、WSL側で`clip.exe`と`powershell.exe`が利用可能か確認してください。

```bash
which clip.exe
which powershell.exe
cat /proc/version | grep -i microsoft
```

## Yazi

Yazi本体はmise、`~/.config/yazi/yazi.toml`とpackage宣言はchezmoiで管理します。標準テーマと標準キーマップを使い、plugin本体、flavor本体、cache、履歴、preview生成物、runtime stateはGit管理しません。fresh HOME相当の設定読込は次で確認できます。

```bash
./tests/yazi-smoke.sh
```

pluginやflavorを追加・更新する場合は`package.toml`の宣言を更新して`ya pkg install`を実行し、取得物をcommitせず上記smoke testを再実行してください。Yazi本体の更新は「miseの管理範囲」の手順でlockfileも更新します。

## Herdr、cagentとAI CLI

<!-- TODO: u7chan.file-viewer の安定版リリース後に導入管理を見直す。 -->

Herdrと`cagent`本体はmiseで管理します。Herdrはbootstrapごとに`latest`を解決するため、リポジトリのlockfileに記録されたHerdr版は固定値として扱いません。`cagent`は`github:u7chan/code-agent-launcher` backendからLinux x64 release assetをlocked installし、`mise.lock`にURL、checksum、provenanceを固定します。Codex、Claude Code、OpenCode、Piは`personal`プロファイルだけで導入し、`personal_ai_tools`で選択されたCLIだけにHerdr公式integrationを導入します。integrationはAI CLI本体の導入後に`herdr integration install <agent>`で設定し、`herdr integration status`で選択対象が`current`であることを検証します。選択から外れた既存integrationは自動削除しません。`base`プロファイルではAI CLI本体・integrationとも導入しません。CodexとPiはnpmをSafe-chain経由で導入し、Piは`--ignore-scripts`を付けます。Claude CodeとOpenCodeは各公式installerで最新版を導入します。AI CLIの認証は手動です。

Herdr integrationが生成するhook/pluginはHerdrが所有し、chezmoi sourceには含めません。AI CLIの既存設定本体は、現在の所有関係を維持します。

| Agent | Herdrが生成・更新するruntime artifact | chezmoiの管理範囲 |
|---|---|---|
| Codex | `~/.codex/hooks.json`、`~/.codex/herdr-agent-state.sh` | `~/.codex/config.toml`。Herdrが要求する`[features] hooks = true`を含む |
| Claude Code | `~/.claude/settings.json`のHerdr hook entries、`~/.claude/hooks/herdr-agent-state.sh` | `~/.claude/statusline.py`（chezmoi）、および`claude/settings.json`の`theme`・`statusLine`（bootstrap merge）。それ以外の個人設定はユーザー管理 |
| OpenCode | `~/.config/opencode/plugins/herdr-agent-state.js` | `~/.config/opencode/opencode.json` |
| Pi | `~/.pi/agent/extensions/herdr-agent-state.ts` | ユーザー設定・`~/.pi/agent/sessions/**`・履歴は管理しない。ただしPi選択時のみchezmoiが管理するのは3ファイルのみ: WSL2/Windows Terminal向けキーバインド（画像貼り付け`Alt+V`、メッセージキュー復元`Alt+Up`）の`~/.pi/agent/keybindings.json`、openai-codexのGPT-5.6系modelOverrides（コンパクション費用対策）の`~/.pi/agent/models.json`、pi-web-accessのcuratorを開かない`workflow: "auto-summary"`デフォルトを`create`属性で配布する`~/.pi/agent/web-search.json`（既存ファイルは上書きしないため、API key等の手動追加はユーザーruntime）。Pi Packageのsession recallもglobal user runtimeとして扱う |

auth、履歴、DB、session、cache、ログ、Herdr生成stateはGit管理しません。Herdr公式integrationの詳細な対象パスとnative session restoreの条件は[公式integrationドキュメント](https://herdr.dev/docs/integrations/)を参照してください。

PiのHerdr extensionとPi Packagesは別の管理境界にあり、前者はHerdr、後者はPi Package managerが所有します。Package導入時も`~/.pi/agent/extensions/herdr-agent-state.ts`を上書きせず、Piの組み込みツール登録を変更しません。

Pi本体と4つのPi Packageの更新入口は`update-ai --pi`です。`personal_ai_tools`に`pi`が含まれるbootstrapでは同じ処理が走り、`myupdate`も設定された選択対象を`update-ai`へ渡します。Piはv0.84.2以上、Node.jsはv22.19以上を前提とし、各Packageが未導入なら`pi install <source>`、導入済みなら`pi update <source>`を実行します。Packageの詳細な用途、要件、設定所有権、Safe-chain経路、責務境界は[Pi Packages一覧](pi-packages.md)を正本とします。

`update-ai`はPi公式の`npmCommand`を`["mise", "exec", "node", "--", "safe-chain", "npm"]`へ設定し、既存の`settings.json`をJSONとして読み戻してこのキーだけをatomicにmergeします。Packageの登録、`~/.pi/agent/npm/`、`~/.pi/agent/sessions/**`、`~/.pi/agent/session-recall.json`、その他のユーザー設定はPiまたはユーザーが所有し、chezmoiは管理しません。

chezmoiがPiユーザー設定として管理する例外は3ファイルです。1つ目がWSL2/Windows Terminal向けのPiキーバインドです。Windows Terminalは`Ctrl+V`を自身で処理するため、Piの`app.clipboard.pasteImage`を`Alt+V`へ、`app.message.dequeue`を`Alt+Up`へ割り当てた`home/dot_pi/agent/keybindings.json`をchezmoiが管理します。2つ目が`home/dot_pi/agent/models.json`の`modelOverrides`です。`modelOverrides`は他の設定ファイルに依存せず、piは`~/.pi/agent/models.json`のみを読込み元にします（`~/.pi/config.json`はpiの設定ファイルとして存在しない）。`modelOverrides`はモデルの役割と利用コストに応じたcontext budgetをcontext windowへ反映するものです。GPT-6 Astra / GPT-5.6 Sol / Terraは`contextWindow`を256384へ上書きして自動コンパクションを240,000（`contextWindow - reserveTokens`、既定reserve 16K）で発火させ、GPT-5.6 Lunaは`contextWindow: 1050000`で最大context window付近まで使えるようにします。budgetの判断理由とCodex側（model catalog）の実装は[AIモデルのcontext budgetポリシー](ai-model-context-budget.md)を正本とします。3つ目が`home/dot_pi/agent/create_web-search.json`です。pi-web-access v0.10.4以降の`web_search`はcuratorブラウザが自動オープンしてサマリーのApprove待ちになるため、`create`属性で`workflow: "auto-summary"`だけを配布し、ブラウザを開かずモデル生成サマリーを返します。pi-web-access 0.29.0で設定パスが`~/.pi/web-search.json`からpiのagent dir（`~/.pi/agent/web-search.json`）へ変更されたため、配布先もagent dirとし、旧ファイルが残っていて新パスにファイルが無い場合だけbootstrapがchezmoi apply前に新パスへ移動してから配置します（新旧両方がある場合は移行せず、旧ファイルは残りますが0.29.0以降は読まれません）。`create`属性のため既存ファイルを上書きせず、API key等の手動追加は次回bootstrapでも維持されます。bootstrapは`personal_ai_tools`に`pi`が含まれる場合だけ`WORKSTATION_PI_SELECTED=true`をchezmoiへ渡して配置し、未選択・baseプロファイルでは`~/.pi/agent/keybindings.json`と`~/.pi/agent/models.json`を削除します（`~/.pi/agent/web-search.json`と旧`~/.pi/web-search.json`も同様に削除します）。完全管理の2ファイルはローカルで直接編集した内容が次回bootstrap時にリポジトリの宣言状態へ戻りますが、`~/.pi/agent/web-search.json`は`create`属性のため編集内容が維持されます。

```bash
update-ai
./tests/ai-clis-smoke.sh
./tests/pi-packages-smoke.sh
```

chezmoiが管理するのは`~/.codex/config.toml`、`~/.config/opencode/opencode.json`、`~/.config/cagent/config.yaml`などのallowlist化した非機密設定だけです。`cagent`設定はCodexを既定agent、`reasoner`を既定profileとし、CodexとOpenCode GoのLaunch ProfileおよびHerdrのstart/run templateを定義します。既定profileは設定の`default_profile`を変更して切り替えます。auth、履歴、DB、session、cache、ログ、Herdr生成stateはGit管理しません。

`base`ではmise解決とversionだけ、`personal`では設定・doctor・profile別dry-runまで確認します。いずれも実Agentや外部モデルは起動しません。

```bash
./tests/cagent-smoke.sh base
./tests/cagent-smoke.sh personal
```

### cagent v1.0.0 Launch Profiles への移行

cagent v1.0.0では旧形式の`levels`/`models`設定に後方互換がなく、設定を手動で移行する必要があります。
既存の`~/.config/cagent/config.yaml`をバックアップしてから、bootstrapで新しいLaunch Profile形式の
設定を適用してください。

```bash
# 既存設定のバックアップ
cp ~/.config/cagent/config.yaml ~/.config/cagent/config.yaml.v0.3.bak

# bootstrapで新しい設定を適用
./bootstrap personal

# 移行後の確認
cagent --version
cagent doctor
cagent profiles
cagent --dry-run reasoner
```

v0.3.xの`default_agent`/`default_level`とagent別の`levels`/`models`設定は、v1.0.0の
Launch Profileへ手動で移行する必要があります。移行の概要は
[cagent READMEのv0.3.x→v1.0.0移行ガイド](https://github.com/u7chan/code-agent-launcher?tab=readme-ov-file#v03x%E3%81%8B%E3%82%89v100%E3%81%B8%E3%81%AE%E6%89%8B%E5%8B%95%E7%A7%BB%E8%A1%8C)
を参照してください。

現行の設定で定義するLaunch Profileは次の5つです。

| Profile | Agent | Model | Effort |
|---|---|---|---|
| `worker-codex` | Codex | `gpt-5.6-luna` | `max` |
| `worker-opencode` | OpenCode Go | `deepseek-v4-flash` | — (TODO) |
| `reasoner` | Codex | `gpt-5.6-sol` | `high` |
| `reviewer` | Codex | `gpt-5.6-sol` | `xhigh` |
| `orchestrator` | OpenCode Go | `deepseek-v4-pro` | — (TODO) |

Herdr templateは`{level}`から`{profile}`に変更され、Herdr Startで任意のLaunch Profileを
指定した会話セッションを起動できます。

```bash
./tests/cagent-smoke.sh base
./tests/cagent-smoke.sh personal
```

WSL再起動後は次を実行し、Herdr、cagent、および選択済みAI CLIがmise配下または所定のLinux binaryへ解決され、Windows側のshimへフォールバックせず、選択済みHerdr integrationが`current`であることを確認します。引数なしの場合は既定の4種類（Codex / Claude Code / OpenCode / Pi）を確認します。subsetを適用した場合は、選択したCLIを引数に渡します。

```bash
./tests/wsl-restart-smoke.sh
WORKSTATION_PERSONAL_AI_TOOLS=codex,opencode ./bootstrap personal
./tests/wsl-restart-smoke.sh codex opencode
```

native session restoreの実機確認では、選択済みCLIをHerdrのpane内で起動してsessionを作成した後、WSLを再起動し、Herdrへ再接続します。各paneが通常のshellではなく、対応するCLIのnative sessionとして復元されることを確認してください。認証や実モデルへのリクエストは自動テストの対象にしません。

シェル初期化が反映されない場合は、一時的にmiseのshimを有効化してcommand hashを破棄してから再確認します。

```bash
eval "$(~/.local/bin/mise activate bash --shims)"
hash -r
type -a gh herdr cagent codex claude opencode pi
```

Codexは通常の`HOME`にある`~/.codex/config.toml`を読みます。restart smokeの`codex features list`は、この設定がCodex起動時に正常に解析されることも検証します。

#### Codex Apps integrationの無効化

Codexは既定でApps integrationが有効であり、起動時に集約MCP server `codex_apps`が読み込まれ、GitHubを含む多数のtoolが利用候補として公開されます。GitHub操作には`global-agent-skills`の自作`gh`スキルとdispatcherを使用する方針であり、Codex組み込みのGitHub app/connectorは使用しません。実際、組み込みGitHub toolにはGitHub Appの権限不足により403エラーが発生します。

```text
GitHub API error 403: {"message":"Resource not accessible by integration", ...}
```

不要なMCP toolの誤選択、権限確認、失敗後のフォールバックを避けるため、`~/.codex/config.toml`の`[features]`セクションで`apps = false`を設定し、集約MCP serverの公開を無効化します。

```toml
[features]
apps = false
```

`[apps.github] enabled = false`では集約MCP server `codex_apps`自体は無効化されず、`/mcp`にtool一覧が残ります。そのため、stable feature flagである`features.apps`を無効化します。

この設定は`codex_apps`の読み込みを停止するだけで、ユーザーが明示的に追加する`mcp_servers`の利用可否を一律に制限しません。また、`global-agent-skills`の自作`gh`スキルや`gh` CLI、Codexのplugin機能全体には影響しません。

#### モデル別context budget（model catalog）

Codexの`model_context_window` / `model_auto_compact_token_limit`は全モデルへ一様に適用されるglobal overrideのため、モデル別のbudgetには使えません。このため`~/.codex/config.toml`には`model_catalog_json`だけを置き、`~/.codex/model-catalogs/workstation.json`（chezmoi管理は`home/dot_codex/model-catalogs/workstation.json`）でモデル別のbudgetを表現します。

- GPT-6 Astra / GPT-5.6 Sol / Terra: `context_window: 272000` + `auto_compact_token_limit: 240000`（約240Kでauto-compact）
- GPT-5.6 Luna（`worker-codex`）: `context_window: 872000` + `auto_compact_token_limit: 784800`（カタログの`max_context_window`範囲内で最大context windowを許可。1.05M根拠はポリシーdocを参照）

カタログはcodexバンドルカタログのコピーにポリシー上書きを適用したもので、codexは`auto_compact_token_limit`を`context_window`の90%へクランプします。cagentのprofileはcodexへmodel / effortだけを渡すため、cagent設定の変更は不要で、カタログのモデル別値が`worker-codex`のLunaにもそのまま効きます。budgetの設計原則、判断理由、カタログ再生成手順は[AIモデルのcontext budgetポリシー](ai-model-context-budget.md)を参照してください。

### 開発ツールの手動更新

`personal`プロファイルは、開発ツールをまとめて同期更新する`myupdate`を配置します。必要なときに手動で実行し、次の順序で処理します。

1. `personal_ai_tools`で選択したAI CLIを`update-ai`で更新（空ならスキップ）
2. `mise upgrade herdr`

各処理は失敗時に5秒待ってその処理だけを1回再試行し、失敗しても後続処理を続けます。標準出力・標準エラーへ結果を直接表示し、いずれかの処理が2回とも失敗した場合は終了コード1を返します。多重起動はロックで抑止し、競合時は終了コード3で終了します。再provisioningのmise、AI CLI更新も同じロックへ参加します。Herdrの更新主体はmiseであり、`herdr update`は使用しません。

```bash
myupdate
```

更新対象は`~/.config/workstation/myupdate.conf`へ展開されます。手動テストなどで一時的に変更する場合は、`WORKSTATION_UPDATE_AI_TOOLS=codex,pi myupdate`のように環境変数で上書きできます。空文字を指定するとAI CLI更新をスキップします。

Piを選択した更新では、Pi本体の更新後に`pi-web-access`、`pi-codex-image-gen`、`@howaboua/pi-codex-conversion`、`@ogulcancelik/pi-session-recall`の導入・更新と登録確認まで行います。bootstrapと`myupdate`を複数回実行しても、Pi Package managerが同じglobal sourceを重複登録しないようにします。conversionのmanaged configも同じ処理で冪等に更新します。

## Bashのローカル設定

共通のBash初期化はchezmoi管理の`~/.config/workstation/shell/init.bash`から読み込みます。Ubuntu標準の`~/.bashrc`はそのまま残し、管理済み初期化ファイルを読み込むブロックだけを追加します。

共通aliasとして`g=git`、`h=herdr`、`open <path>`を管理します。`open`はWSL標準の`explorer.exe`と`wslpath`を使い、Windows側のエクスプローラーでLinuxのファイルまたはディレクトリを開きます。

マシン固有のworkspace aliasなどは、`~/.config/workstation/shell/local.bash`へ記述してください。このファイルはGitおよびchezmoiの管理対象外で、bootstrapは既存内容を変更せずmode 600を維持します。

## 個人CLI

`personal`プロファイルは、リポジトリの`scripts/personal-bin/`から次のCLIを`~/.local/bin`へ配置します。`base`プロファイルには配置しません。

日常的な使い方と短縮コマンドは[個人CLIコマンドガイド](personal-cli.md)を参照してください。

### Git cleanup

マージ済みPRのローカル作業ブランチを片付ける場合は、そのブランチをcheckoutしたprimary worktreeで実行します。

```bash
gpc
```

未追跡ファイルを含むdirty tree、linked worktree、未マージPR、PRのhead不一致、`main`・`master`・`develop`以外のbaseでは停止します。成功時だけbaseへ切り替え、`origin`からfast-forwardして、対象PRのローカルhead branchだけを削除します。remote branch、他のローカルブランチ、worktree、stashは変更しません。

Agent worktreeの一括整理は、primary worktreeから実行します。既定はdry-runです。

```bash
gac
gac --apply
gac --apply --force
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

`myclaude`はprovider別設定を読み、同じmodelをClaude Codeの各model tierへ割り当てて起動します。

```bash
myclaude --list
myclaude zai
myclaude deepseek --version
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

bootstrapは公式のバージョン付きインストールスクリプトをダウンロードし、チェックサムを検証してから実行します。再実行時は、既存のSafe-chainバージョンを確認し、pinと一致する場合はスキップします。旧Bun globalインストール（`~/.bun/bin/safe-chain`）からの移行は全環境で完了済みのため、bootstrapによる削除タスクは撤去しています。残骸が見つかった場合は手動で削除してください。

shell integration（`~/.safe-chain/scripts/init-posix.sh`）は、chezmoi管理の`init.bash`から読み込みます。Safe-chainのインストーラーが`~/.bashrc`へ直接追加するsource行は、bootstrapが削除するため、 unmanagedな`~/.bashrc`への依存を残しません。

`~/.safe-chain/`以下のバイナリ、生成されたCA証明書、malware list、取得データはすべて機器固有の生成物です。リポジトリおよびchezmoiの管理対象外とし、手動でコピーしません。

更新時は、新しいリリースのバージョンとチェックサムを`ansible/vars/main.yml`へ記入し、Ubuntu 26.04 x86_64で次を実行して動作を確認してください。

```bash
./bootstrap base
./tests/safe-chain-smoke.sh
```

CodexとPiの更新は`update-ai`がminimum-package-age例外を一時指定します。Pi本体には`@earendil-works/*`、Package manager内部npmには処理中の`pi-web-access`、`pi-codex-image-gen`、`@howaboua/pi-codex-conversion`、`@ogulcancelik/pi-session-recall`だけを対象外にします。`npmCommand`はmiseとSafe-chainを通るため、これらの例外はmalware検査を無効化しません。Pi本体のnpm更新には`--ignore-scripts`を付けます。

Pi Packagesの導入、重複登録防止、未管理設定の保持は外部モデルを使わずに確認できます。

```bash
pi --version
pi list
./tests/pi-packages-smoke.sh
```

Piのキーバインド・models.json・web-search.jsonの配置はjqとchezmoiを使って確認できます。`WORKSTATION_PI_SELECTED`の有無による`.chezmoiignore`の切替と、選択時の配置内容、非選択時に既存ファイルを触らないことを検証します。

```bash
./tests/pi-keybindings-smoke.sh
```

pi-web-access 0.29.0以降が読む`~/.pi/agent/web-search.json`は`home/dot_pi/agent/create_web-search.json`の`create`属性で配布します。選択時にファイルが無ければ非機密デフォルト（`workflow: "auto-summary"`）だけが展開されること、既存ファイル（API key等を手動追加済み）が上書きされないこと、未選択時に`.chezmoiignore`が対象外にして既存ファイルを触らないことを検証します。bootstrapは旧`~/.pi/web-search.json`が残っていて`~/.pi/agent/web-search.json`が無い場合だけ、`create`属性がデフォルトだけの新ファイルを作る前に新パスへ移動します（新旧両方がある場合は移行されないため、旧ファイルにだけ追加したAPI key等は0.29.0以降は読まれません）。

```bash
./tests/pi-web-search-smoke.sh
```

実際に`Alt+V`で画像を貼り付け、`Alt+Up`でメッセージキューを復元できるかはWindows Terminal上のPi入力欄での人力確認が必要です。

手動のWeb access smokeでは、Piを起動して`web_search`、`fetch_content`、`get_search_content`、`source_check`が表示されることを確認します。API keyなしのzero-config search、Codex subscription login済み環境でのOpenAI search認証再利用は外部ネットワーク状態に依存するため、CIの必須条件にはしません。

画像生成の手動smokeは`openai-codex`へ`/login`した新しいPi sessionで行います。`OPENAI_API_KEY`を設定せずに画像生成を依頼し、`codex_generate_image`の呼び出し、結果の表示、追跡可能な保存path、有効かつ0 byteでないPNG/JPEG/WebP、tracked filesに差分がないことを確認します。続けて生成画像の背景変更などを依頼し、元画像を残したまま編集結果が別画像として得られることを確認します。実モデルと外部backendを使うためCIの必須条件にはしません。

Codex conversionの手動smokeは`node --version`がv22.19以上、`pi --version`がv0.84.2以上のUbuntu 26.04 WSL2で行います。新しいPi sessionでCodex modelを選択し、`exec_command`による`pwd` / `git status --short`、`apply_patch`によるfixture編集、長時間コマンドの`write_stdin`継続、画像fixtureへの`view_image`を確認します。`/codex`のstatusにWeb/image toolが表示されず、`pi-web-access`の4つのWeb toolと`codex_generate_image`は同時に表示されることを確認します。`file` / `ldd`と実行smokeで`exec_bridge`、`apply_patch`、`view_image`のbundled helperを確認し、`GLIBC_* not found`、loader error、`exec_bridge` startup failureがないことを確認します。非Codex/GPT modelへ切り替えた後は通常のPi tool surfaceへ戻り、adapter toolが残留しないことも確認します。認証・外部backend・native helperを使うためCIの必須条件にはしません。

Pi session recallの手動smokeは、同一・別project directoryのglobal session scopeとprivacy boundaryを確認します。`/tmp/pi-recall-project-a`で`RECALL_SMOKE_7F31A`のような一意なmarkerを含むsession A1を作成して終了し、`/tmp/pi-recall-project-b`の新規session B1からmarkerを自然言語で質問してください。`session_search`がcurrent cwdに限定されずA1の`~/.pi/agent/sessions/**`を発見し、`session_query`がA1の判断を回答することを確認します。query modelを`openai-codex`（または`/session-recall`で選択したmodel）にして実際の回答まで確認します。sessionには機微情報が含まれる可能性があり、`session_query`は選択した会話をquery modelへ送るため、送信先と認証状態を確認してください。認証・外部LLMが必要なためCIの必須条件にはしません。

CIのstatic jobは`ubuntu-slim`上でbootstrapやmise installを行わず、`tests/static.sh`がmanaged tool設定と実環境の`command -v rg` / `rg --version`を検証します。そのためCIだけはAPTで`ripgrep`を導入します。これはworkstationの導入経路をAPTへ変更するものではなく、mise管理の恒久的なrg優先backendをCIで再現するための依存関係です。

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

GitHubへの接続はHTTPSへ統一します。初回clone前の`git`と`gh`は[初期セットアップ手順](bootstrap-prerequisites.md)に従いAPTで手動準備します。bootstrap後はmiseが管理する`gh`がlockfileでバージョン固定され、`PATH`上でAPT版より優先されるため、再セットアップ時の再現性はmiseが保証します。APT版`gh`は認証専用で残るため、不要になったら手動で削除します。chezmoiは次の非機密設定だけを管理します。

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
  plm = !git fetch origin main --verbose
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
