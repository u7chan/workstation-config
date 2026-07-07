# Bootstrap前の初期セットアップ

この手順は、Windowsホストから新しいUbuntu 26.04 WSL2を作成し、`workstation-config`をcloneするまでの人間操作を記録したものです。bootstrapはここに記載するユーザー作成や認証を自動化しません。

## 1. Ubuntu 26.04 WSL2を作成する

PowerShellで実行します。

```powershell
wsl --install Ubuntu-26.04
wsl -d Ubuntu-26.04
```

ディストリビューション名を明示する場合は、`--name`を指定します。以降の
`wsl -d`、`wsl --terminate`、`wsl --unregister`では、ここで指定した名前を使います。

```powershell
wsl --install Ubuntu-26.04 --name sandbox
wsl -d sandbox
```

初回起動時の案内に従ってLinuxのユーザー名とパスワードを設定します。このユーザーはrootではなく、sudoを利用できる必要があります。

次のコマンドが`0`以外を表示することを確認します。

```bash
id -u
```

初回起動がrootになり一般ユーザーが存在しない場合は、root shellで作成します。`<username>`は実際のユーザー名へ置き換えてください。

```bash
adduser <username>
usermod --append --groups sudo <username>
```

既存の`/etc/wsl.conf`へ次を追記した後、PowerShellからディストリビューションを再起動します。

```ini
[user]
default=<username>
```

```powershell
wsl --terminate Ubuntu-26.04
wsl -d Ubuntu-26.04
```

ディストリビューション名を変えた場合は、実際の名前へ読み替えてください。

```powershell
wsl --terminate sandbox
wsl -d sandbox
```

作り直す場合は`wsl --unregister`で削除できます。これは対象ディストリビューションのLinuxファイルシステム、home、インストール済みパッケージ、設定、未退避データをすべて削除する破壊的操作です。対象名を確認し、必要なファイルを退避してから実行してください。

```powershell
wsl --list --verbose
wsl --unregister sandbox
```

## 2. GitとGitHub CLIを準備する

検証時のUbuntu 26.04イメージにはGitが含まれていましたが、イメージ差を吸収するためAPTでGitと`gh`の存在を保証します。

```bash
sudo apt-get update
sudo apt-get install --yes git gh
git --version
gh --version
```

## 3. GitHubへHTTPSで認証する

ブラウザ認証を行い、Gitのcredential helperを設定します。

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

token、credential、認証stateはこのリポジトリへ保存しません。

## 4. リポジトリをcloneしてbootstrapする

```bash
git clone https://github.com/u7chan/workstation-config.git
cd workstation-config
./bootstrap
```

引数なしでは`personal`プロファイルを適用します。個人用Roleを含めない場合は`./bootstrap base`を明示してください。

```bash
./bootstrap base
```

## 5. sudo-rs対応済みbootstrapを確認する

Ubuntu 26.04では`sudo-rs`が標準の`sudo`になっている場合があります。`sudo-rs`はAnsibleのbecomeパスワードプロンプトと相性が悪いため、bootstrapは`/usr/bin/sudo.ws`が存在する環境ではAnsibleに`ANSIBLE_BECOME_EXE=/usr/bin/sudo.ws`を渡します。

clone後、bootstrap実行前に次で確認できます。

```bash
grep -n 'SUDO_EXE\|sudo.ws\|ANSIBLE_BECOME_EXE\|ANSIBLE_BECOME_ASK_PASS\|env \\' bootstrap
sudo --version | head -1
test -x /usr/bin/sudo.ws && echo 'sudo.ws exists'
```

`sudo --version | head -1`が`sudo-rs ...`で、`sudo.ws exists`も表示される場合は、`bootstrap`内に`sudo.ws`と`ANSIBLE_BECOME_EXE`が含まれている必要があります。含まれていない場合は古いcheckoutや手動コピーの可能性があるため、最新の`main`を取り直してください。
