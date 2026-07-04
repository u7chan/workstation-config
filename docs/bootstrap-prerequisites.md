# Bootstrap前の初期セットアップ

この手順は、Windowsホストから新しいUbuntu 26.04 WSL2を作成し、`workstation-config`をcloneするまでの人間操作を記録したものです。bootstrapはここに記載するユーザー作成や認証を自動化しません。

## 1. Ubuntu 26.04 WSL2を作成する

PowerShellで実行します。

```powershell
wsl --install Ubuntu-26.04
wsl -d Ubuntu-26.04
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
