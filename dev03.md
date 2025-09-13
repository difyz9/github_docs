# 如何通过脚本把打包的文件提交到Gitee的Release

## 概述

本文档介绍如何使用脚本自动化将打包的文件提交到Gitee的Release。我们提供了两种方法：

1. **使用Gitee API（推荐）** - 直接调用Gitee的REST API
2. **使用curl命令行工具** - 更通用的方法

## 方法一：使用Gitee API脚本

### 前置要求

1. **Gitee Access Token**: 在Gitee个人设置中生成访问令牌
   - 登录Gitee → 设置 → 私人令牌 → 生成新令牌
   - 需要的权限：`projects`、`pull_requests`、`issues`

2. **必要工具**:
   - `curl` - 用于API调用
   - `jq` - JSON处理工具（可选，但推荐）

### 脚本配置

在使用脚本前，需要配置以下参数：

```bash
# 必须配置的参数
GITEE_TOKEN="your_gitee_access_token"  # Gitee访问令牌
REPO_OWNER="your_username"             # 仓库所有者
REPO_NAME="your_repository"            # 仓库名称
ARCHIVE_PATH="./your_package.zip"      # 打包文件路径
```

### 使用步骤

1. **设置环境变量**:
   ```bash
   export GITEE_TOKEN="your_access_token"
   ```

2. **运行脚本**:
   ```bash
   chmod +x gitee-release.sh
   ./gitee-release.sh
   ```

3. **按提示操作**:
   - 输入版本号
   - 确认发布信息
   - 脚本会自动创建release并上传文件

## 方法二：手动使用curl命令

### 1. 创建Release

```bash
curl -X POST \
  "https://gitee.com/api/v5/repos/{owner}/{repo}/releases" \
  -H "Content-Type: application/json" \
  -H "Authorization: token {your_token}" \
  -d '{
    "tag_name": "v1.0.0",
    "name": "Release v1.0.0",
    "body": "Release description",
    "target_commitish": "master"
  }'
```

### 2. 上传文件到Release

```bash
curl -X POST \
  "https://gitee.com/api/v5/repos/{owner}/{repo}/releases/{release_id}/attach_files" \
  -H "Authorization: token {your_token}" \
  -F "file=@your_package.zip"
```

## 脚本功能特性

我们提供的Gitee release脚本包含以下功能：

- ✅ **自动版本管理** - 自动获取和递增版本号
- ✅ **文件验证** - 检查打包文件是否存在
- ✅ **错误处理** - 完善的错误检查和提示
- ✅ **进度显示** - 彩色输出和进度提示
- ✅ **交互确认** - 发布前的确认步骤
- ✅ **Release Notes** - 自动生成发布说明
- ✅ **重复检查** - 检查版本是否已存在

## 常见问题

### Q: 如何获取Gitee Access Token？
A: 
1. 登录Gitee，进入个人设置
2. 点击"私人令牌"
3. 点击"生成新令牌"
4. 选择必要的权限范围
5. 复制生成的令牌

### Q: 支持哪些文件格式？
A: 支持常见的压缩格式：
- `.zip` - ZIP压缩包
- `.tar.gz` / `.tgz` - tar.gz压缩包
- `.tar` - tar归档文件
- 其他二进制文件

### Q: 如何自定义Release Notes？
A: 编辑脚本中的 `create_release_notes()` 函数，可以：
- 从CHANGELOG.md读取
- 从git commit生成
- 使用模板文件

### Q: 脚本执行失败怎么办？
A: 检查以下几点：
1. Gitee Token是否有效
2. 仓库路径是否正确
3. 网络连接是否正常
4. 文件路径是否存在

## 最佳实践

1. **版本管理**: 使用语义化版本号（如v1.0.0）
2. **文件命名**: 使用有意义的文件名包含版本信息
3. **发布说明**: 提供详细的变更日志
4. **测试**: 在正式发布前先测试脚本
5. **备份**: 保留重要版本的备份

## 示例配置文件

创建 `.env` 文件存储配置：

```bash
# Gitee配置
GITEE_TOKEN=your_access_token_here
REPO_OWNER=your_username
REPO_NAME=your_repository

# 文件配置
ARCHIVE_PATH=./dist/app-v1.0.0.zip
DEFAULT_VERSION=v1.0.0

# 可选配置
RELEASE_BRANCH=master
PRERELEASE=false
```

然后在脚本中加载：
```bash
source .env
```