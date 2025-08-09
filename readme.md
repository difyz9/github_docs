# 如何通过脚本发布压缩包到GitHub Release

本指南介绍了几种通过脚本将本地压缩包发布到GitHub Release的方法。

## 方法一：使用GitHub CLI (推荐)

### 1. 安装GitHub CLI

在macOS上：
```bash
brew install gh
```

### 2. 认证
```bash
gh auth login
```

### 3. 创建Release并上传文件的脚本

创建 `release.sh` 脚本：

```bash
#!/bin/bash

# 配置变量
REPO="username/repository"  # 替换为您的仓库
VERSION="v1.0.0"           # 替换为您的版本号
ARCHIVE_PATH="./dist.zip"   # 替换为您的压缩包路径
RELEASE_TITLE="Release $VERSION"
RELEASE_NOTES="Release notes for $VERSION"

# 创建Release并上传文件
gh release create "$VERSION" "$ARCHIVE_PATH" \
  --repo "$REPO" \
  --title "$RELEASE_TITLE" \
  --notes "$RELEASE_NOTES"

echo "Release created successfully!"
```

### 4. 使用方法
```bash
chmod +x release.sh
./release.sh
```

## 方法二：使用curl和GitHub API

### 1. 获取GitHub Personal Access Token

1. 访问 GitHub Settings > Developer settings > Personal access tokens
2. 创建新token，授予 `repo` 权限

### 2. 创建API脚本

创建 `release-api.sh` 脚本：

```bash
#!/bin/bash

# 配置变量
GITHUB_TOKEN="your_token_here"  # 替换为您的token
REPO_OWNER="username"           # 替换为仓库所有者
REPO_NAME="repository"          # 替换为仓库名
VERSION="v1.0.0"               # 替换为版本号
ARCHIVE_PATH="./dist.zip"      # 替换为压缩包路径
RELEASE_NAME="Release $VERSION"
RELEASE_BODY="Release notes for $VERSION"

# 1. 创建Release
RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
  -d "{
    \"tag_name\": \"$VERSION\",
    \"name\": \"$RELEASE_NAME\",
    \"body\": \"$RELEASE_BODY\",
    \"draft\": false,
    \"prerelease\": false
  }")

# 2. 获取Upload URL
UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')
RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id": [0-9]*' | head -1 | cut -d' ' -f2)

echo "Release created with ID: $RELEASE_ID"

# 3. 上传文件
FILENAME=$(basename "$ARCHIVE_PATH")
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @"$ARCHIVE_PATH" \
  "$UPLOAD_URL?name=$FILENAME"

echo "File uploaded successfully!"
```

## 方法三：使用GitHub Actions (自动化)

### 1. 创建GitHub Actions工作流

创建 `.github/workflows/release.yml`：

```yaml
name: Create Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build and create archive
      run: |
        # 您的构建命令
        zip -r dist.zip ./dist
    
    - name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        files: dist.zip
        name: Release ${{ github.ref_name }}
        body: |
          Release notes for ${{ github.ref_name }}
        draft: false
        prerelease: false
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 2. 触发Release
```bash
git tag v1.0.0
git push origin v1.0.0
```

## 方法四：完整的自动化脚本示例

创建 `auto-release.sh`：

```bash
#!/bin/bash

set -e  # 遇到错误时退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
REPO="username/repository"
ARCHIVE_NAME="release.zip"
ARCHIVE_PATH="./$ARCHIVE_NAME"

# 函数：打印彩色消息
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要工具
check_requirements() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first."
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        exit 1
    fi
}

# 创建压缩包
create_archive() {
    print_message "Creating archive..."
    
    # 这里添加您的文件打包逻辑
    # 例如：
    # zip -r "$ARCHIVE_PATH" ./dist
    # 或者：
    # tar -czf "release.tar.gz" ./dist
    
    if [ ! -f "$ARCHIVE_PATH" ]; then
        print_error "Archive creation failed or file not found: $ARCHIVE_PATH"
        exit 1
    fi
    
    print_message "Archive created: $ARCHIVE_PATH"
}

# 获取版本号
get_version() {
    # 方法1：从git tag获取
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -z "$VERSION" ]; then
        # 方法2：手动输入
        read -p "Enter version (e.g., v1.0.0): " VERSION
    fi
    
    if [ -z "$VERSION" ]; then
        print_error "Version is required"
        exit 1
    fi
    
    print_message "Using version: $VERSION"
}

# 创建Release
create_release() {
    print_message "Creating GitHub Release..."
    
    RELEASE_NOTES="Release $VERSION

## Changes
- Add your release notes here

## Download
- Download the archive from the assets below"
    
    if gh release create "$VERSION" "$ARCHIVE_PATH" \
        --repo "$REPO" \
        --title "Release $VERSION" \
        --notes "$RELEASE_NOTES"; then
        print_message "Release created successfully!"
        print_message "View at: https://github.com/$REPO/releases/tag/$VERSION"
    else
        print_error "Failed to create release"
        exit 1
    fi
}

# 主函数
main() {
    print_message "Starting release process..."
    
    check_requirements
    get_version
    create_archive
    create_release
    
    print_message "Release process completed!"
}

# 执行主函数
main "$@"
```

## 使用建议

1. **推荐使用GitHub CLI**：最简单、最可靠的方法
2. **设置环境变量**：将敏感信息（如token）存储在环境变量中
3. **版本管理**：使用git tags来管理版本号
4. **自动化**：考虑使用GitHub Actions进行完全自动化

## 注意事项

- 确保有仓库的写权限
- Token需要适当的权限范围
- 压缩包路径要正确
- 版本号要唯一，不能重复

选择适合您需求的方法，根据具体情况调整脚本中的配置变量。