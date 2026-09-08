<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Git 常用操作与安全实践

> 本文中的用户名、邮箱、仓库名、路径和提交 ID 均为占位符。请将 `<github-user>`、`<repo>`、`<email>`、`<branch>` 和 `<commit>` 替换为实际值。

## 快速导航

- [先记住这几条](#先记住这几条)
- [工作区、暂存区与仓库](#工作区暂存区与仓库)
- [初始化与克隆](#初始化与克隆)
- [日常开发流程](#日常开发流程)
- [撤销与恢复](#撤销与恢复)
- [远程仓库与认证](#远程仓库与认证)
- [忽略文件与换行符](#忽略文件与换行符)
- [排查常见错误](#排查常见错误)
- [标签与发布](#标签与发布)

## 先记住这几条

1. 执行删除、重置、变基或强制推送前，先运行 `git status`，必要时运行 `git diff` 和 `git log`。
2. 开发在功能分支上进行，`main` 用于稳定代码和发布。团队策略若不同，以团队规范为准。
3. `git clean`、`git reset --hard`、`git rebase` 和强制推送都有数据丢失或历史改写风险。
4. 清理未跟踪文件前，始终先用 `git clean -n` 预览；确需删除时再使用 `git clean -f`。
5. 变基或 amend 已推送提交后，只在确认没有覆盖他人工作的情况下使用 `git push --force-with-lease`，尽量不要使用 `--force`。
6. 远程仓库已经有协作者时，优先使用 Pull Request，不要直接改写共享分支历史。

## 工作区、暂存区与仓库

Git 可以简单理解为三层：

| 区域 | 含义 | 常用操作 |
| --- | --- | --- |
| 工作区 | 磁盘上的实际文件 | 编辑、`git restore` |
| 暂存区 | 下次提交准备包含的内容 | `git add`、`git restore --staged` |
| 本地仓库 | 已提交的历史记录 | `git commit`、`git log` |

`git status` 查看三者状态，`git diff` 查看工作区与暂存区的差异，`git diff --staged` 查看暂存区与最近一次提交的差异。

### 常用命令速查

| 目的 | 命令 |
| --- | --- |
| 查看状态 | `git status` |
| 暂存指定文件 | `git add <file>` |
| 暂存所有变化 | `git add -A` |
| 只暂存已跟踪文件的修改和删除 | `git add -u` |
| 取消暂存 | `git restore --staged <file>` |
| 丢弃工作区修改 | `git restore <file>` |
| 提交暂存内容 | `git commit -m "<message>"` |
| 查看简洁历史 | `git log --oneline --graph --decorate --all` |
| 查看某个提交 | `git show <commit>` |
| 查看引用移动记录 | `git reflog` |

## 初始化与克隆

### 从本地目录创建仓库

```bash
mkdir <project>
cd <project>
git init -b main
git add -A
git commit -m "Initial commit"
git remote add origin git@github.com:<github-user>/<repo>.git
git push -u origin main
```

如果远程仓库已经由 GitHub 创建了 README、License 等初始提交，本地和远程可能没有共同祖先。此时先明确选择一种策略：

```bash
# 保留两边历史，并创建合并提交
git fetch origin
git merge origin/main --allow-unrelated-histories

# 解决冲突后
git add <resolved-file>
git commit
git push -u origin main
```

如果远程仓库是空的，则不需要 `--allow-unrelated-histories`。不要把它当作普通同步命令使用。

### 克隆已有仓库

```bash
git clone git@github.com:<github-user>/<repo>.git
cd <repo>
```

克隆已经包含 `.git` 目录，不需要再次执行 `git init`。

### 修改远程地址

```bash
git remote -v
git remote set-url origin git@github.com:<github-user>/<repo>.git
```

## 日常开发流程

### 创建功能分支

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/<short-name>
```

旧版 Git 可使用 `git checkout -b feature/<short-name>`，但新版本更推荐 `switch`。

### 提交与推送

```bash
git status
git diff
git add -p                 # 按块选择要提交的内容
git commit -m "Add <feature>"
git push -u origin feature/<short-name>
```

首次推送使用 `-u` 设置上游分支，之后可以直接使用 `git push` 和 `git pull`。

### 同步主分支

个人功能分支可以使用变基保持线性历史：

```bash
git fetch origin
git rebase origin/main
```

发生冲突时：

```bash
# 编辑冲突文件，删除 <<<<<<<、=======、>>>>>>> 标记
git add <resolved-file>
git rebase --continue

# 想放弃本次变基
git rebase --abort
```

变基会改写本地提交 ID。若该分支已经推送，需要确认没有其他人基于旧历史开发，再执行：

```bash
git push --force-with-lease origin feature/<short-name>
```

多人共享分支不要随意变基，通常使用合并：

```bash
git fetch origin
git merge origin/main
```

### 合并功能分支

```bash
git switch main
git pull --ff-only origin main
git merge --no-ff feature/<short-name>
git push origin main
git branch -d feature/<short-name>
git push origin --delete feature/<short-name>
```

如果团队使用 GitHub Pull Request，应推送功能分支后在网页上审查和合并，不必直接在本地合并到 `main`。

## 撤销与恢复

### 工作区和暂存区

```bash
# 丢弃工作区中某个文件的未暂存修改
git restore <file>

# 取消暂存，但保留文件内容
git restore --staged <file>
```

这些操作会丢弃相应状态中的内容，执行前先检查 `git diff`。

### 撤销提交

| 需求 | 命令 | 结果 |
| --- | --- | --- |
| 修改最近一次提交 | `git commit --amend` | 替换最近提交，改变提交 ID |
| 撤销提交但保留暂存 | `git reset --soft HEAD~1` | 提交消失，内容仍在暂存区 |
| 撤销提交但保留工作区 | `git reset --mixed HEAD~1` | 默认模式，内容回到工作区 |
| 放弃本地提交和文件修改 | `git reset --hard HEAD~1` | 高风险，可能永久丢失内容 |
| 已推送提交的安全撤销 | `git revert <commit>` | 新建一个反向提交，不改写历史 |

已推送或共享的提交，通常选择 `git revert`；`reset` 适合只影响自己的本地历史。

### `git reset --hard` 前的检查

```bash
git status
git diff
git branch backup/<name>
git reset --hard <commit>
```

同步本地分支到远程状态时也会丢弃本地修改：

```bash
git fetch origin
git reset --hard origin/main
```

只有在确认本地提交和未提交修改都不需要时才执行。

### 交互式变基

只整理尚未共享的提交：

```bash
git rebase -i HEAD~3
```

常用指令：

| 指令 | 作用 |
| --- | --- |
| `pick` | 保留提交 |
| `reword` | 保留内容并修改提交信息 |
| `squash` | 合并提交并重新编辑信息 |
| `fixup` | 合并提交并丢弃当前提交信息 |
| `drop` | 删除提交及其修改 |

## 远程仓库与认证

### HTTPS 与 SSH

SSH 适合日常推送，HTTPS 适合临时环境或已有凭据管理工具的环境。GitHub 已不再支持用账户密码进行 Git 操作；HTTPS 应使用 Personal Access Token（PAT）或 Git Credential Manager。

SSH 基本流程：

```bash
ssh-keygen -t ed25519 -C "<email>"
cat ~/.ssh/id_ed25519.pub
ssh -T git@github.com
git remote set-url origin git@github.com:<github-user>/<repo>.git
```

只公开 `.pub` 公钥，不要公开私钥、PAT 或包含凭据的远程 URL。

### 多个 GitHub 账户

在 `~/.ssh/config` 中为不同账户设置别名：

```sshconfig
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
```

对应的远程地址：

```bash
git remote set-url origin git@github-personal:<github-user>/<repo>.git
```

项目级提交身份：

```bash
git config user.name "<author-name>"
git config user.email "<email>"
```

### 常用配置

```bash
git config --global init.defaultBranch main
git config --global core.quotepath false
git config --global user.name "<author-name>"
git config --global user.email "<email>"

git config --global --list
git config --list --show-origin
```

不要为了网络缓慢盲目设置 `http.postBuffer`，它通常不能解决网络或服务器问题。应先检查代理、网络、远程地址和认证方式。

## 忽略文件与换行符

### `.gitignore`

项目相关的忽略规则应放在仓库根目录的 `.gitignore`，例如：

```gitignore
# 编辑器和系统文件
.vscode/
.idea/
.DS_Store
Thumbs.db

# 构建和缓存
build/
dist/
target/
*.o
*.pyc

# 本地配置和敏感信息
.env
*.local
```

个人环境规则可以放在全局忽略文件：

```bash
git config --global core.excludesfile ~/.gitignore_global
```

已经被 Git 跟踪的文件不会因新增忽略规则而自动停止跟踪：

```bash
git rm --cached <file>
git commit -m "Stop tracking local file"
```

`git rm --cached` 保留本地文件；`git rm` 会同时删除工作区文件并将删除记录放入暂存区。

### `.gitattributes`

跨平台项目可以在根目录添加：

```gitattributes
* text=auto
*.sh text eol=lf
*.bash text eol=lf
*.py text eol=lf
*.c text eol=lf
*.h text eol=lf
*.md text
*.json text
*.png binary
*.jpg binary
*.pdf binary
```

新增 `.gitattributes` 后，是否刷新整个索引应结合仓库规模和团队协作安排，避免直接复制会造成大范围无关 diff 的命令。

## 排查常见错误

### `src refspec <branch> does not match any`

通常表示本地分支名写错，或仓库还没有提交：

```bash
git branch --show-current
git status
git log --oneline -1
git push -u origin <branch>
```

### `non-fast-forward`

远程分支比本地更新，先获取并整合远程提交：

```bash
git fetch origin
git rebase origin/<branch>
git push origin <branch>
```

共享分支不适合变基时改用 `git merge origin/<branch>`。不要仅为了绕过报错就强制推送。

### `Authentication failed` 或 `403`

依次检查：

```bash
git remote -v
ssh -T git@github.com
git config --get credential.helper
```

确认仓库地址和账户权限正确。HTTPS 使用 PAT，SSH 使用已添加到 GitHub 的公钥；不要把 Token 写进命令行参数或远程 URL。

### `refusing to merge unrelated histories`

这表示本地和远程是两个没有共同祖先的仓库。确认两边确实属于同一个项目后，再使用：

```bash
git fetch origin
git merge origin/main --allow-unrelated-histories
```

### 合并或变基进行中

```bash
# 合并中止
git merge --abort

# 变基中止
git rebase --abort

# 查看当前状态
git status
```

如果冲突已经解决，合并使用 `git add <file>` 后执行 `git commit`；变基使用 `git add <file>` 后执行 `git rebase --continue`。

### 清理未跟踪文件

```bash
git clean -n       # 只预览文件
git clean -nd      # 预览文件和目录
git clean -i       # 交互式选择
git clean -fd      # 确认无误后删除文件和目录
```

`git clean` 不删除已跟踪文件，但删除的未跟踪内容通常无法通过 Git 恢复。

## 标签与发布

标签用于标记某个提交，Release 是托管平台提供的发布页面，二者不是同一个对象：

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

git fetch --tags
git tag --list
git show v1.0.0
```

需要发布说明和二进制附件时，再在 GitHub Release 页面基于该标签创建 Release。不要为了发布版本改写 `main` 的历史；版本修复应使用新提交和新标签。

## 附录：常见概念对照

| 命令 | 核心作用 |
| --- | --- |
| `git fetch` | 获取远程对象和引用，不自动修改当前分支 |
| `git pull` | 获取远程更新并进行合并或变基，行为取决于配置和参数 |
| `git merge` | 保留双方历史，创建合并结果 |
| `git rebase` | 将提交重新应用到新的基点，改写提交 ID |
| `git switch` | 切换或创建分支 |
| `git restore` | 恢复工作区或取消暂存 |
| `git revert` | 用新提交抵消已有提交 |
| `git reset` | 移动当前分支指针，并按模式调整暂存区/工作区 |
| `git clean` | 删除未跟踪的工作区内容 |
