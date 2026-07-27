# Bootstrap前の初期セットアップ

この手順は、Windowsホストから新しいUbuntu 26.04 WSL2を作成し、`workstation-config`をcloneするまでの人間操作を記録したものです。bootstrapはここに記載するユーザー作成や認証を自動化しません。

## 1. Ubuntu 26.04 WSL2を作成する

PowerShellで管理者権限を開き、利用可能なディストリビューションを確認します。

```powershell
wsl --list --online
```

`Ubuntu-26.04` が含まれていることを確認し、任意の名前でインストールします。以下は `sandbox` という名前の例です。

```powershell
wsl --install Ubuntu-26.04 --name sandbox
```

> [!NOTE]
> `wsl --install` は初回実行時に WSL 本体もインストールするため、再起動を求められたら再起動し、もう一度同じコマンドを実行してください。

インストール後、指定した名前で起動します。

```powershell
wsl -d sandbox
```

以降の `wsl -d`、`wsl --terminate`、`wsl --unregister` では、ここで指定した名前を使います。

初回起動時の案内に従って、Linuxのユーザー名とパスワードを設定します。このユーザーはrootではなく、sudoを利用できる必要があります。

初回セットアップ後のシェルは、Windowsホスト側のディレクトリから始まる場合があります。以降の作業をLinuxホームディレクトリで行うため、次を実行します。

```bash
cd
```

<details>
<summary>作り直す場合（破壊的操作）</summary>

作り直す場合は`wsl --unregister`で削除できます。

⚠️ **注意:** `wsl --unregister` は対象ディストリビューションのLinuxファイルシステム、home、インストール済みパッケージ、設定、未退避データをすべて削除する破壊的操作です。対象名を確認し、必要なファイルを退避してから実行してください。

```powershell
wsl --list --verbose
wsl --unregister sandbox
```

</details>

<details>
<summary>Windows Terminalを設定する</summary>

ディストリビューションを作成した後、Windows Terminalのプロファイルやキー操作などを設定する場合は、[Windows Terminal設定](windows-terminal.md)を参照してください。

</details>

## 2. GitとGitHub CLIを準備する

検証時のUbuntu 26.04イメージにはGitが含まれていましたが、イメージ差を吸収するためAPTでGitと`gh`の存在を保証します。

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y git gh && git --version && gh --version
```

## 3. GitHubへHTTPSで認証する

ブラウザ認証を行い、Gitのcredential helperを設定します。

```bash
gh auth login --hostname github.com --git-protocol https --web && gh auth setup-git && gh auth status
```

> [!NOTE]
> `gh auth setup-git` は、Git の HTTPS 認証を `gh` に委譲する設定を行います。これにより、`git clone https://github.com/...` などを実行した際に毎回パスワードや token を入力する必要がなくなります。
>
> `gh auth status` は、GitHub への認証状態を確認するコマンドです。`Logged in to github.com as <username>` と表示されれば成功です。

token、credential、認証stateはこのリポジトリへ保存しません。

## 4. リポジトリをcloneしてbootstrapする

```bash
git clone https://github.com/u7chan/workstation-config.git && cd workstation-config && ./bootstrap
```

> [!TIP]
> 引数なしでは`personal`プロファイルを適用します。個人用Roleを含めない場合は`./bootstrap base`を明示してください。各プロファイルの違いは [base / personal の責務分界](roles-boundary.md) を参照してください。

```bash
./bootstrap base
```
