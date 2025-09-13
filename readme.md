# 自动化Release发布脚本工具集

本仓库提供了完整的自动化Release发布解决方案，支持GitHub和Gitee两大平台。包含多种实现方法，从简单的命令行脚本到复杂的API调用，满足不同场景的需求。

## 📦 工具概览

### GitHub Release 工具
- `release.sh` - 使用GitHub CLI的完整发布脚本
- `release-api.sh` - 使用GitHub API的发布脚本

### Gitee Release 工具 ⭐
- `gitee-release.sh` - 功能完整的Gitee发布脚本
- `gitee-release-simple.sh` - 简化版快速发布脚本
- `gitee-mcp-demo.sh` - MCP工具使用演示

### 配置和文档
- `.env.gitee.example` - Gitee配置文件模板
- `dev03.md` - Gitee发布详细教程
- `SETUP-GUIDE.md` - 项目设置指南

## 🚀 快速开始

### GitHub Release
```bash
# 使用GitHub CLI
./release.sh

# 使用API
./release-api.sh
```

### Gitee Release
```bash
# 完整版本
./gitee-release.sh -o username -r repository -f ./app.zip -v v1.0.0

# 简化版本
./gitee-release-simple.sh
```

## 🔧 Gitee Release 详细说明

### 特性对比

| 功能 | gitee-release.sh | gitee-release-simple.sh |
|------|-----------------|------------------------|
| 参数验证 | ✅ 完整 | ✅ 基础 |
| 错误处理 | ✅ 详细 | ✅ 基础 |
| 彩色输出 | ✅ 完整 | ✅ 简化 |
| 交互确认 | ✅ 是 | ✅ 是 |
| 版本检查 | ✅ 是 | ❌ 否 |
| 命令行参数 | ✅ 支持 | ❌ 不支持 |
| 帮助文档 | ✅ 详细 | ❌ 无 |

### 使用前准备

1. **获取Gitee访问令牌**
   - 访问 [Gitee个人令牌](https://gitee.com/profile/personal_access_tokens)
   - 创建新令牌，选择 `projects` 权限
   - 复制生成的令牌

2. **配置环境**
   ```bash
   # 方法1：环境变量
   export GITEE_TOKEN="your_gitee_token"
   
   # 方法2：配置文件
   cp .env.gitee.example .env
   # 编辑.env文件设置您的配置
   ```

3. **准备发布文件**
   ```bash
   # 确保您的打包文件存在
   ls -la ./your-package.zip
   ```

### 详细使用指南

参见 [`dev03.md`](dev03.md) 获取完整的使用教程和最佳实践。

## 📋 GitHub Release 方法

### 方法一：使用GitHub CLI (推荐)

#### 1. 安装GitHub CLI

在macOS上：
```bash
brew install gh
```

#### 2. 认证
```bash
gh auth login
```

#### 3. 创建Release并上传文件的脚本

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

#### 4. 使用方法
```bash
chmod +x release.sh
./release.sh
```

### 方法二：使用curl和GitHub API

#### 1. 获取GitHub Personal Access Token

1. 访问 GitHub Settings > Developer settings > Personal access tokens
2. 创建新token，授予 `repo` 权限

#### 2. 创建API脚本

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

### 方法三：使用GitHub Actions (自动化)

#### 1. 创建GitHub Actions工作流

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

#### 2. 触发Release
```bash
git tag v1.0.0
git push origin v1.0.0
```

## 💡 最佳实践和建议

### 通用建议
1. **版本管理**：使用语义化版本号（如v1.0.0）
2. **安全性**：将敏感信息（Token）存储在环境变量中
3. **文档化**：提供详细的Release Notes
4. **测试**：在正式发布前先测试脚本
5. **备份**：保留重要版本的备份

### GitHub vs Gitee 选择指南

| 特性 | GitHub | Gitee |
|------|--------|-------|
| 国际化 | ✅ 全球访问 | ❌ 主要面向中国 |
| 访问速度(中国) | ❌ 较慢 | ✅ 快速 |
| 开源生态 | ✅ 丰富 | ⭐ 成长中 |
| 企业支持 | ✅ 完善 | ✅ 本土化 |
| API文档 | ✅ 详细 | ✅ 中文文档 |

## 🔍 故障排除

### 常见问题

1. **Token权限不足**
   - GitHub: 确保Token有`repo`权限
   - Gitee: 确保Token有`projects`权限

2. **文件上传失败**
   - 检查文件路径是否正确
   - 确认文件大小限制
   - 验证网络连接

3. **版本冲突**
   - 检查版本号是否已存在
   - 使用脚本的版本检查功能

### 调试技巧

```bash
# 启用详细输出
set -x

# 检查API响应
curl -v -H "Authorization: token $TOKEN" "https://api.github.com/user"
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这些脚本！

### 开发环境设置
```bash
git clone https://github.com/your-username/github_docs
cd github_docs
chmod +x *.sh
```

### 测试
```bash
# 测试GitHub脚本
./release.sh --help

# 测试Gitee脚本  
./gitee-release.sh --help
```

## 📚 相关资源

- [GitHub API文档](https://docs.github.com/en/rest)
- [Gitee API文档](https://gitee.com/api/v5/swagger)
- [GitHub CLI文档](https://cli.github.com/)
- [语义化版本规范](https://semver.org/)

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## ⭐ 如果这个项目对您有帮助，请给个Star！