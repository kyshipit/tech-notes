**English** | [简体中文](../../tools/Git常用操作与安全实践.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Common Git Operations and Security Practices

> The username, email, repository name, path, and commit ID in this document are placeholders. Please replace `<github-user>` `, `<repo>` `, `<email>` , `<branch>` , and `<commit>` with their actual values.

## Quick Navigation

- [1. Key Points to Remember](#1-key-points-to-remember)
- [2. Working Directory, Staging Area & Repository](#2-working-directory-staging-area--repository)
- [3. Initialization and Cloning](#3-initialization-and-cloning)
- [4. Daily Development Workflow](#4-daily-development-workflow)
- [5. Undo and Restore](#5-undo-and-restore)
- [6. Remote Repository and Authentication](#6-remote-repository-and-authentication)
- [7. Ignore Files and Line Endings](#7-ignore-files-and-line-endings)
- [8. Troubleshooting Common Errors](#8-troubleshooting-common-errors)
- [9. Tags and Releases](#9-tags-and-releases)



## 1. Key Points to Remember

1. Before performing deletion, reset, rebase, or forced push, run `git status` , and if necessary, run `git diff` and `git log` .
2. Development takes place on feature branches, while `main` is used for stabilizing code and releasing. If team strategies differ, the team's established guidelines will prevail.
3. `git clean` , `git reset --hard` , `git rebase` , and forced push all carry the risk of data loss or historical data rewriting.
4. Always preview files using `git clean -n` before cleaning them up; only use `git clean -f` if you absolutely need to delete them.
5. After a rebase or amend has been pushed, use `git push --force-with-lease` only if you are sure you are not overwriting someone else's work. Try to avoid using `--force` .
6. When there are already collaborators in the remote repository, prioritize using Pull Requests and avoid directly rewriting the shared branch history.

## 2. Working Directory, Staging Area & Repository

Git can be simply understood as having three layers:

area | meaning | Common Operations
--- | --- | ---
work area | Actual files on the disk | Edit, `git restore`
Temporary storage area | The next submission will include the following content. | `git add` , `git restore --staged`
local repository | Submitted history | `git commit` , `git log`

`git status` checks the status of the working directory, staging area, and working directory; `git diff` shows the differences between the working directory and staging area; `git diff --staged` shows the differences between the staging area and the most recent commit.

### Quick Reference for Common Commands

Purpose | Order
--- | ---
Check status | `git status`
Temporarily save specified files | `git add <file>`
Save all changes | `git add -A`
Temporarily store only the modifications and deletions of tracked files. | `git add -u`
Cancel temporary storage | `git restore --staged <file>`
Discard workspace modifications | `git restore <file>`
Submit temporary content | `git commit -m "<message>"`
View brief history | `git log --oneline --graph --decorate --all`
View a specific submission | `git show <commit>`
View reference movement history | `git reflog`

## 3. Initialization and Cloning

### Create a repository from the local directory

```bash
mkdir <project>
cd <project>
git init -b main
git add -A
git commit -m "Initial commit"
git remote add origin git@github.com:<github-user>/<repo>.git
git push -u origin main
```

If the remote repository has already had its initial commits (README, License, etc.) created by GitHub, the local and remote repositories may not share a common ancestor. In this case, first explicitly choose a strategy:

```bash
# 保留两边历史，并创建合并提交
git fetch origin
git merge origin/main --allow-unrelated-histories

# 解决冲突后
git add <resolved-file>
git commit
git push -u origin main
```

If the remote repository is empty, then `--allow-unrelated-histories` is not needed. Do not use it as a regular synchronization command.

### Cloning an existing repository

```bash
git clone git@github.com:<github-user>/<repo>.git
cd <repo>
```

The clone already includes the `.git` directory, so there is no need to run `git init` again.

### Modify remote address

```bash
git remote -v
git remote set-url origin git@github.com:<github-user>/<repo>.git
```

## 4. Daily Development Workflow

### Create feature branches

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/<short-name>
```

Older versions of Git can use `git checkout -b feature/<short-name>` , but newer versions recommend using `switch` .

### Submission and Push

```bash
git status
git diff
git add -p                 # 按块选择要提交的内容
git commit -m "Add <feature>"
git push -u origin feature/<short-name>
```

The first push uses `-u` option to set the upstream branch; afterwards, you can directly use `git push` and `git pull` .

### Synchronize main branch

Individual feature branches can use rebasing to maintain a linear history:

```bash
git fetch origin
git rebase origin/main
```

When a conflict occurs:

```bash
# 编辑冲突文件，删除 <<<<<<<、=======、>>>>>>> 标记
git add <resolved-file>
git rebase --continue

# 想放弃本次变基
git rebase --abort
```

Rebasing will rewrite the local commit ID. If the branch has already been pushed, you need to confirm that no one else is developing based on the old history before executing this command:

```bash
git push --force-with-lease origin feature/<short-name>
```

Do not rebase shared branches arbitrarily; merging is the usual method.

```bash
git fetch origin
git merge origin/main
```

### Merge feature branches

```bash
git switch main
git pull --ff-only origin main
git merge --no-ff feature/<short-name>
git push origin main
git branch -d feature/<short-name>
git push origin --delete feature/<short-name>
```

If the team uses GitHub Pull Requests, they should push the feature branch and then review and merge it on the webpage, rather than merging it directly into `main` locally.

## 5. Undo and Restore

### Work area and temporary storage area

```bash
# 丢弃工作区中某个文件的未暂存修改
git restore <file>

# 取消暂存，但保留文件内容
git restore --staged <file>
```

These operations will discard the contents of the corresponding state, and will check `git diff` before execution.

### Cancel Submission

need | Order | result
--- | --- | ---
Modify the most recent commit | `git commit --amend` | Replace the most recent commit, change the commit ID
Cancel submission but retain temporary files | `git reset --soft HEAD~1` | Submissions disappear, but content remains in the staging area.
Cancel the submission but retain the workspace | `git reset --mixed HEAD~1` | In default mode, the content returns to the workspace.
Discard local commits and file modifications | `git reset --hard HEAD~1` | High risk, content may be permanently lost.
Security revocation already submitted | `git revert <commit>` | Create a new reverse commit without rewriting the history.

For commits that have already been pushed or shared, `git revert` is usually the better choice; `reset` is suitable for only affecting your local history.

### Checks before `git reset --hard`

```bash
git status
git diff
git branch backup/<name>
git reset --hard <commit>
```

Local changes are also discarded when syncing local branches to the remote state:

```bash
git fetch origin
git reset --hard origin/main
```

Only execute this action if it is confirmed that neither local commits nor uncommitted changes are needed.

### Interactive bases

Only organize commits that have not yet been shared:

```bash
git rebase -i HEAD~3
```

Common commands:

instruction | effect
--- | ---
`pick` | Reserved submission
`reword` | Keep the content and modify the submission information
`squash` | Merge submissions and re-edit information
`fixup` | Merge commits and discard current commit information
`drop` | Delete submissions and their modifications

## 6. Remote Repository and Authentication

### HTTPS and SSH

SSH is suitable for daily pushes, while HTTPS is suitable for temporary environments or environments with existing credential management tools. GitHub no longer supports Git operations using account passwords; HTTPS should use Personal Access Token (PAT) or Git Credential Manager.

SSH basic process:

```bash
ssh-keygen -t ed25519 -C "<email>"
cat ~/.ssh/id_ed25519.pub
ssh -T git@github.com
git remote set-url origin git@github.com:<github-user>/<repo>.git
```

Only expose the `.pub` public key; do not expose the private key, PAT file, or remote URL containing credentials.

### Multiple GitHub accounts

Set aliases for different accounts in `~/.ssh/config` :

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

Corresponding remote address:

```bash
git remote set-url origin git@github-personal:<github-user>/<repo>.git
```

Project-level submission identity:

```bash
git config user.name "<author-name>"
git config user.email "<email>"
```

### Common configurations

```bash
git config --global init.defaultBranch main
git config --global core.quotepath false
git config --global user.name "<author-name>"
git config --global user.email "<email>"

git config --global --list
git config --list --show-origin
```

Do not blindly set `http.postBuffer` just because of slow network speeds; it usually does not solve network or server problems. You should first check your proxy, network, remote address, and authentication method.

## 7. Ignore Files and Line Endings

### `.gitignore`

Project-related ignore rules should be placed in the `.gitignore` file in the repository root directory, for example:

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

Personal environment rules can be placed in a global ignore file:

```bash
git config --global core.excludesfile ~/.gitignore_global
```

Files already tracked by Git will not be automatically stopped from being tracked by adding ignore rules:

```bash
git rm --cached <file>
git commit -m "Stop tracking local file"
```

`git rm --cached` preserves local files; `git rm` also deletes files in the working directory and places the deletion records in the staging area.

### `.gitattributes`

Cross-platform projects can be added to the root directory:

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

After adding `.gitattributes` file, whether to refresh the entire index should be considered in conjunction with the size of the repository and team collaboration arrangements to avoid direct copying commands that could cause large-scale irrelevant diffs.

## 8. Troubleshooting Common Errors

### `src refspec <branch> does not match any`

This usually indicates that the local branch name is misspelled, or that the repository has not yet been committed.

```bash
git branch --show-current
git status
git log --oneline -1
git push -u origin <branch>
```

### `non-fast-forward`

If the remote branch is more up-to-date than the local branch, fetch and integrate the remote commits first.

```bash
git fetch origin
git rebase origin/<branch>
git push origin <branch>
```

If a shared branch is not suitable for rebasing, use `git merge origin/<branch>` instead. Do not force a push simply to bypass errors.

### `Authentication failed` or `403`

Check in sequence:

```bash
git remote -v
ssh -T git@github.com
git config --get credential.helper
```

Verify that the repository address and account permissions are correct. Use PAT for HTTPS and the public key that has been added to GitHub for SSH; do not write the token in the command-line arguments or remote URL.

### `refusing to merge unrelated histories`

This means the local and remote repositories are two repositories that do not share a common ancestor. Only use this after confirming that both belong to the same project:

```bash
git fetch origin
git merge origin/main --allow-unrelated-histories
```

### Merging or rebasing in progress

```bash
# 合并中止
git merge --abort

# 变基中止
git rebase --abort

# 查看当前状态
git status
```

If the conflict has been resolved, merge using `git add <file>` followed by `git commit` ; rebase using `git add <file>` followed by `git rebase --continue` .

### Clean up untracked files

```bash
git clean -n       # 只预览文件
git clean -nd      # 预览文件和目录
git clean -i       # 交互式选择
git clean -fd      # 确认无误后删除文件和目录
```

`git clean` does not delete tracked files, but deleted untracked content is usually unrecoverable via Git.

## 9. Tags and Releases

The `&lt;sub&gt;` tag is used to mark a submission, while `Release` is the release page provided by the hosting platform; the two are not the same object.

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

git fetch --tags
git tag --list
git show v1.0.0
```

Only create a Release on the GitHub Release page with that tag when you need to add release notes and binary attachments. Do not rewrite `main` history for releases; version fixes should be done with new commits and new tags.

## Appendix: Comparison of Common Concepts

Order | core role
--- | ---
`git fetch` | Retrieve remote objects and references without automatically modifying the current branch.
`git pull` | Retrieve remote updates and perform merges or rebases; the behavior depends on configuration and parameters.
`git merge` | Preserve the history of both parties and create a merge result.
`git rebase` | Reapply the commit to the new base point and rewrite the commit ID.
`git switch` | Switching or creating a branch
`git restore` | Restore workspace or cancel temporary storage
`git revert` | Use the new commit to offset the existing commit.
`git reset` | Move the current branch pointer and adjust the staging area/working area according to the pattern.
`git clean` | Delete untracked workspace content
