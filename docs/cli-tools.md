# CLIツールガイド

このリポジトリでは、次のターミナルツールをmiseで管理します。`base`と`personal`のどちらのプロファイルにも導入され、`./bootstrap`または`./bootstrap base`で利用可能になります。

バージョンは`provisioning/mise/mise.lock`に固定します。更新時は[Workstation構成ガイド](workstation.md#miseの管理範囲)の手順でlockfileを更新してください。

| ツール | 用途 | 起動 | 導入元 |
|---|---|---|---|
| [Hunk](https://github.com/modem-dev/hunk) | 変更セットをレビューするためのインタラクティブなdiff viewer | `hunk diff` | `modem-dev/hunk` |
| [Lazygit](https://github.com/jesseduffield/lazygit) | Git操作用のターミナルUI | `lazygit` | `jesseduffield/lazygit` |
| [Lazydocker](https://github.com/jesseduffield/lazydocker) | Docker resourceを操作・確認するターミナルUI | `lazydocker` | `jesseduffield/lazydocker` |
| [Herdr](https://github.com/ogulcancelik/herdr) | terminal上でAgentを多重化するCLI | `herdr` | `ogulcancelik/herdr` |
| [Yazi](https://github.com/sxyazi/yazi) | 非同期I/Oベースのファイルマネージャ | `yazi` | `sxyazi/yazi` |
| [Starship](https://github.com/starship/starship) | shell prompt | Bash起動時に自動で有効化 | `starship/starship` |
| [cagent](https://github.com/u7chan/code-agent-launcher) | Agent起動コマンドを統一するlauncher | `cagent --help` | `u7chan/code-agent-launcher` |
| [fzf](https://github.com/junegunn/fzf) | インタラクティブな曖昧検索 | `fzf` | `junegunn/fzf` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | 頻繁に使うディレクトリへの高速ジャンプ（fzf連携） | `z <query>`, `zi` | `ajeetdsouza/zoxide` |

## Gitと変更レビュー

Git操作には`lazygit`、Agentが生成した変更のレビューには`hunk diff`を使います。Hunkは`--watch`で作業ツリーの更新を追従できます。

```bash
lazygit
hunk diff
hunk diff --watch
hunk show HEAD~1
```

HunkをGit pagerとして常用する場合は、利用者が明示的に次を設定します。リポジトリのbootstrapは既存のGit pager設定を変更しません。

```bash
git config --global core.pager "hunk pager"
```

## Docker

Docker CEを導入した`personal`プロファイルでは、Docker daemonが利用可能な状態で`lazydocker`を起動します。

初回の`personal`適用でユーザーが`docker` groupへ追加された場合は、現在のWSL sessionには反映されません。すべての当該WSL sessionを終了して再接続してから`lazydocker`を起動してください。

```bash
lazydocker
```

Docker CEを無効化した`personal`構成や`base`プロファイルでもbinaryは導入されますが、Docker daemonの導入・起動は行いません。

## ディレクトリ移動の高速化

`zoxide`は`cd`の履歴を自動学習し、よく使うディレクトリへ高速にジャンプします。

```bash
z workspace   # 履歴から "workspace" にマッチするディレクトリへジャンプ
zi            # fzfでインタラクティブに選択
```

Bash初期化時に`zoxide init bash`を実行しており、`z` / `zi` コマンドが使えます。シェルの`cd`を使い続けることで自動的に履歴が蓄積されます。

### Yaziの`Z`キーとの連携

Yazi内で`Z`を押すとzoxideの履歴一覧からディレクトリを選んでジャンプできます。ただし**zoxideの履歴が空だと「No directory history found」エラーになります**。初回はシェルでいくつか`cd`して履歴を貯めるか、手動で登録してください：

```bash
zoxide add ~/workspace
zoxide add ~/.config
```

その後Yaziを再起動すれば`Z`が使えるようになります。

## 設定の管理

- YaziとStarshipの設定はchezmoiで管理します。詳細は[Workstation構成ガイド](workstation.md#yazi)を参照してください。
- Hunk、Lazygit、Lazydocker、Herdr、cagentのユーザー設定は、必要になった時点で各ツールの公式ドキュメントを確認してください。現在はHerdrとcagentの非機密設定だけをchezmoiで管理しています。
- 認証情報、履歴、cache、runtime stateはリポジトリで管理しません。
