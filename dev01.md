# 跨仓库发布：从仓库A构建并发布到仓库B的Release

本文档介绍如何在GitHub Actions中实现从仓库A构建项目，然后将打包后的文件发布到仓库B的Release中。

## 方案概述

- **仓库A（源码仓库）**：存放源代码，配置GitHub Actions工作流
- **仓库B（发布仓库）**：接收构建产物，作为Release分发

## 准备工作

### 1. 创建GitHub Personal Access Token

1. 访问 GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 点击 "Generate new token (classic)"
3. 设置以下权限：
   - `repo` (完整仓库权限)
   - `write:packages` (如果需要)
4. 复制生成的token

### 2. 配置仓库A的Secrets

在仓库A中添加以下Secrets（Settings → Secrets and variables → Actions）：

- `RELEASE_TOKEN`: 上面创建的Personal Access Token
- `TARGET_REPO`: 目标仓库名（格式：owner/repo-name）

## 实现方案

### 方案一：基础版本

创建 `.github/workflows/cross-repo-release.yml`：

```yaml
name: Build and Release to Target Repo

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., v1.0.0)'
        required: true
        type: string
      target_repo:
        description: 'Target repository (owner/repo)'
        required: false
        type: string

jobs:
  build-and-release:
    runs-on: ubuntu-latest
    
    steps:
    # 1. 检出源码
    - name: Checkout source code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    # 2. 设置Node.js环境（根据项目类型调整）
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
      if: hashFiles('package.json') != ''
    
    # 3. 安装依赖
    - name: Install dependencies
      run: npm ci
      if: hashFiles('package.json') != ''
    
    # 4. 构建项目
    - name: Build project
      run: npm run build
      if: hashFiles('package.json') != ''
    
    # 5. 创建发布包
    - name: Create release package
      run: |
        # 确定版本号
        if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
          VERSION="${{ github.event.inputs.version }}"
        else
          VERSION=${GITHUB_REF#refs/tags/}
        fi
        echo "VERSION=$VERSION" >> $GITHUB_ENV
        
        # 创建发布目录
        mkdir -p release-package
        
        # 复制构建产物（根据实际项目调整路径）
        if [ -d "dist" ]; then
          cp -r dist/* release-package/
        elif [ -d "build" ]; then
          cp -r build/* release-package/
        elif [ -d "out" ]; then
          cp -r out/* release-package/
        else
          echo "No build output found!"
          exit 1
        fi
        
        # 添加版本信息文件
        echo "{\"version\":\"$VERSION\",\"build_date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"commit\":\"$GITHUB_SHA\"}" > release-package/build-info.json
        
        # 创建压缩包
        cd release-package
        zip -r ../release.zip .
        tar -czf ../release.tar.gz .
        cd ..
        
        # 输出文件信息
        echo "Release package contents:"
        ls -la release-package/
        echo "Archive files:"
        ls -lh release.zip release.tar.gz
    
    # 6. 发布到目标仓库
    - name: Create release in target repository
      env:
        GITHUB_TOKEN: ${{ secrets.RELEASE_TOKEN }}
        TARGET_REPO: ${{ secrets.TARGET_REPO || github.event.inputs.target_repo }}
      run: |
        # 验证目标仓库配置
        if [ -z "$TARGET_REPO" ]; then
          echo "Error: TARGET_REPO not configured"
          exit 1
        fi
        
        echo "Creating release in repository: $TARGET_REPO"
        
        # 生成发布说明
        RELEASE_NOTES="## Release $VERSION

### 📦 Build Information
- **Source Repository**: ${{ github.repository }}
- **Source Commit**: [${{ github.sha }}](https://github.com/${{ github.repository }}/commit/${{ github.sha }})
- **Build Date**: $(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)
- **Workflow**: [${{ github.run_id }}](https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }})

### 📥 Downloads
- **release.zip**: Universal zip archive
- **release.tar.gz**: Unix/Linux tar.gz archive

### ✨ What's Included
- Built and optimized production files
- Build metadata (build-info.json)

---
*This release was automatically created from [${{ github.repository }}](https://github.com/${{ github.repository }}) by GitHub Actions.*"
        
        # 使用GitHub CLI创建release
        gh release create "$VERSION" \
          --repo "$TARGET_REPO" \
          --title "Release $VERSION" \
          --notes "$RELEASE_NOTES" \
          release.zip \
          release.tar.gz
        
        echo "✅ Release created successfully!"
        echo "🔗 View at: https://github.com/$TARGET_REPO/releases/tag/$VERSION"
```

### 方案二：高级版本（支持多种项目类型）

创建 `.github/workflows/advanced-cross-repo-release.yml`：

```yaml
name: Advanced Cross-Repo Release

on:
  push:
    tags:
      - 'v*'
      - 'release-*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version'
        required: true
        type: string
      target_repo:
        description: 'Target repository'
        required: false
        type: string
      build_type:
        description: 'Build type'
        required: false
        default: 'auto'
        type: choice
        options:
          - auto
          - nodejs
          - python
          - go
          - rust
          - static
      include_source:
        description: 'Include source code'
        required: false
        default: false
        type: boolean

env:
  TARGET_REPO: ${{ secrets.TARGET_REPO || github.event.inputs.target_repo }}

jobs:
  detect-project:
    runs-on: ubuntu-latest
    outputs:
      project_type: ${{ steps.detect.outputs.project_type }}
      build_command: ${{ steps.detect.outputs.build_command }}
      output_dir: ${{ steps.detect.outputs.output_dir }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Detect project type
      id: detect
      run: |
        BUILD_TYPE="${{ github.event.inputs.build_type || 'auto' }}"
        
        if [ "$BUILD_TYPE" = "auto" ]; then
          if [ -f "package.json" ]; then
            PROJECT_TYPE="nodejs"
            BUILD_CMD="npm run build"
            OUTPUT_DIR="dist"
          elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
            PROJECT_TYPE="python"
            BUILD_CMD="python -m build"
            OUTPUT_DIR="dist"
          elif [ -f "go.mod" ]; then
            PROJECT_TYPE="go"
            BUILD_CMD="go build -o build/ ./..."
            OUTPUT_DIR="build"
          elif [ -f "Cargo.toml" ]; then
            PROJECT_TYPE="rust"
            BUILD_CMD="cargo build --release"
            OUTPUT_DIR="target/release"
          else
            PROJECT_TYPE="static"
            BUILD_CMD="echo 'No build required'"
            OUTPUT_DIR="."
          fi
        else
          PROJECT_TYPE="$BUILD_TYPE"
          case "$BUILD_TYPE" in
            nodejs) BUILD_CMD="npm run build"; OUTPUT_DIR="dist" ;;
            python) BUILD_CMD="python -m build"; OUTPUT_DIR="dist" ;;
            go) BUILD_CMD="go build -o build/ ./..."; OUTPUT_DIR="build" ;;
            rust) BUILD_CMD="cargo build --release"; OUTPUT_DIR="target/release" ;;
            static) BUILD_CMD="echo 'No build required'"; OUTPUT_DIR="." ;;
          esac
        fi
        
        echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
        echo "build_command=$BUILD_CMD" >> $GITHUB_OUTPUT
        echo "output_dir=$OUTPUT_DIR" >> $GITHUB_OUTPUT
        
        echo "Detected project type: $PROJECT_TYPE"
        echo "Build command: $BUILD_CMD"
        echo "Output directory: $OUTPUT_DIR"

  build-and-release:
    needs: detect-project
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout source code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    # 设置各种环境
    - name: Setup Node.js
      if: needs.detect-project.outputs.project_type == 'nodejs'
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Setup Python
      if: needs.detect-project.outputs.project_type == 'python'
      uses: actions/setup-python@v4
      with:
        python-version: '3.x'
    
    - name: Setup Go
      if: needs.detect-project.outputs.project_type == 'go'
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'
    
    - name: Setup Rust
      if: needs.detect-project.outputs.project_type == 'rust'
      uses: dtolnay/rust-toolchain@stable
    
    # 安装依赖
    - name: Install dependencies (Node.js)
      if: needs.detect-project.outputs.project_type == 'nodejs'
      run: npm ci
    
    - name: Install dependencies (Python)
      if: needs.detect-project.outputs.project_type == 'python'
      run: |
        python -m pip install --upgrade pip
        python -m pip install build wheel
        if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
        if [ -f setup.py ]; then pip install -e .; fi
    
    # 执行构建
    - name: Build project
      run: ${{ needs.detect-project.outputs.build_command }}
    
    # 准备发布包
    - name: Prepare release package
      run: |
        # 获取版本号
        if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
          VERSION="${{ github.event.inputs.version }}"
        else
          VERSION=${GITHUB_REF#refs/tags/}
        fi
        echo "VERSION=$VERSION" >> $GITHUB_ENV
        
        # 创建发布目录
        mkdir -p release-package
        
        # 复制构建产物
        OUTPUT_DIR="${{ needs.detect-project.outputs.output_dir }}"
        
        if [ "$OUTPUT_DIR" = "." ]; then
          # 静态文件项目，复制所有文件但排除开发文件
          rsync -av --exclude='.git' --exclude='node_modules' --exclude='__pycache__' \
                    --exclude='.pytest_cache' --exclude='target' --exclude='.env' \
                    --exclude='*.log' ./ release-package/
        else
          if [ -d "$OUTPUT_DIR" ]; then
            cp -r "$OUTPUT_DIR"/* release-package/ 2>/dev/null || cp -r "$OUTPUT_DIR"/. release-package/
          else
            echo "Build output directory not found: $OUTPUT_DIR"
            ls -la
            exit 1
          fi
        fi
        
        # 添加元数据
        cat > release-package/release-info.json << EOF
        {
          "version": "$VERSION",
          "source_repository": "${{ github.repository }}",
          "source_commit": "${{ github.sha }}",
          "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "project_type": "${{ needs.detect-project.outputs.project_type }}",
          "workflow_run": "${{ github.run_id }}",
          "build_command": "${{ needs.detect-project.outputs.build_command }}"
        }
        EOF
        
        # 如果选择包含源码
        if [ "${{ github.event.inputs.include_source }}" = "true" ]; then
          mkdir -p release-package/source
          git archive HEAD | tar -x -C release-package/source
        fi
        
        # 创建压缩包
        cd release-package
        
        # 创建多种格式的压缩包
        zip -r ../release-$VERSION.zip .
        tar -czf ../release-$VERSION.tar.gz .
        
        # 如果是特定项目类型，创建专用包
        case "${{ needs.detect-project.outputs.project_type }}" in
          nodejs)
            # 创建npm包结构
            tar -czf ../release-$VERSION-npm.tgz .
            ;;
          python)
            # 创建Python wheel包（如果存在）
            if [ -f "../dist/*.whl" ]; then
              cp ../dist/*.whl ../
            fi
            ;;
        esac
        
        cd ..
        
        # 输出信息
        echo "Release package contents:"
        find release-package -type f | head -20
        echo "Archive files:"
        ls -lh release-*.{zip,tar.gz,tgz,whl} 2>/dev/null || ls -lh release-*
    
    # 创建Release
    - name: Create cross-repository release
      env:
        GITHUB_TOKEN: ${{ secrets.RELEASE_TOKEN }}
      run: |
        if [ -z "$TARGET_REPO" ]; then
          echo "❌ TARGET_REPO not configured in secrets or inputs"
          exit 1
        fi
        
        echo "🎯 Target repository: $TARGET_REPO"
        echo "📦 Creating release: $VERSION"
        
        # 生成详细的发布说明
        RELEASE_NOTES="## 🚀 Release $VERSION

### 📊 Build Information
| Field | Value |
|-------|-------|
| **Source Repository** | [\`${{ github.repository }}\`](https://github.com/${{ github.repository }}) |
| **Source Commit** | [\`${{ github.sha }}\`](https://github.com/${{ github.repository }}/commit/${{ github.sha }}) |
| **Project Type** | \`${{ needs.detect-project.outputs.project_type }}\` |
| **Build Date** | \`$(date -u '+%Y-%m-%d %H:%M:%S UTC')\` |
| **Workflow Run** | [#${{ github.run_id }}](https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}) |

### 📥 Available Downloads
| File | Description |
|------|-------------|
| \`release-$VERSION.zip\` | Universal ZIP archive |
| \`release-$VERSION.tar.gz\` | Unix/Linux TAR.GZ archive |"

        # 添加项目特定信息
        case "${{ needs.detect-project.outputs.project_type }}" in
          nodejs)
            RELEASE_NOTES="$RELEASE_NOTES
| \`release-$VERSION-npm.tgz\` | npm package format |"
            ;;
          python)
            if ls release-*.whl 2>/dev/null; then
              RELEASE_NOTES="$RELEASE_NOTES
| \`*.whl\` | Python wheel packages |"
            fi
            ;;
        esac

        RELEASE_NOTES="$RELEASE_NOTES

### ✨ Package Contents
- 🏗️ Built and optimized production files
- 📋 Release metadata (\`release-info.json\`)$([ '${{ github.event.inputs.include_source }}' = 'true' ] && echo '
- 📂 Source code (\`source/\` directory)')

### 🔧 Build Details
- **Build Command**: \`${{ needs.detect-project.outputs.build_command }}\`
- **Output Directory**: \`${{ needs.detect-project.outputs.output_dir }}\`

---
*This release was automatically built and published from [\`${{ github.repository }}\`](https://github.com/${{ github.repository }}) using GitHub Actions.*"
        
        # 收集所有要上传的文件
        UPLOAD_FILES=()
        for file in release-$VERSION.zip release-$VERSION.tar.gz release-$VERSION-npm.tgz release-*.whl; do
          if [ -f "$file" ]; then
            UPLOAD_FILES+=("$file")
          fi
        done
        
        # 创建release
        gh release create "$VERSION" \
          --repo "$TARGET_REPO" \
          --title "🚀 Release $VERSION" \
          --notes "$RELEASE_NOTES" \
          --latest \
          "${UPLOAD_FILES[@]}"
        
        echo "✅ Release created successfully!"
        echo "🔗 View at: https://github.com/$TARGET_REPO/releases/tag/$VERSION"
        
        # 输出摘要
        echo "📊 Release Summary:" >> $GITHUB_STEP_SUMMARY
        echo "- **Target Repository**: [\`$TARGET_REPO\`](https://github.com/$TARGET_REPO)" >> $GITHUB_STEP_SUMMARY
        echo "- **Release Version**: \`$VERSION\`" >> $GITHUB_STEP_SUMMARY
        echo "- **Files Uploaded**: ${#UPLOAD_FILES[@]}" >> $GITHUB_STEP_SUMMARY
        echo "- **Release URL**: https://github.com/$TARGET_REPO/releases/tag/$VERSION" >> $GITHUB_STEP_SUMMARY
```

## 使用方法

### 1. 自动触发（推荐）

在仓库A中创建tag并推送：

```bash
# 创建并推送tag
git tag v1.0.0
git push origin v1.0.0

# 或者使用带消息的标签
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 2. 手动触发

1. 在仓库A的Actions页面找到工作流
2. 点击"Run workflow"
3. 填写必要信息：
   - Version: 发布版本号
   - Target repo: 目标仓库（可选，如果已在Secrets中配置）
   - Build type: 构建类型（可选）
   - Include source: 是否包含源码

## 配置示例

### 仓库A的Secrets配置

```
RELEASE_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
TARGET_REPO=difyz9/release-repo
```

### 支持的项目类型

- **Node.js**: 自动检测 `package.json`，运行 `npm run build`
- **Python**: 自动检测 `setup.py` 或 `pyproject.toml`，运行 `python -m build`
- **Go**: 自动检测 `go.mod`，运行 `go build`
- **Rust**: 自动检测 `Cargo.toml`，运行 `cargo build --release`
- **Static**: 静态文件项目，直接打包

## 注意事项

1. **权限要求**: Personal Access Token 需要对目标仓库有写权限
2. **文件大小**: GitHub Release 单个文件限制为 2GB
3. **版本管理**: 确保版本号唯一，避免冲突
4. **安全性**: 妥善保管 Personal Access Token，定期更新

## 故障排除

### 常见问题

1. **Token权限不足**: 检查token是否有目标仓库的写权限
2. **构建失败**: 检查构建命令和依赖配置
3. **文件未找到**: 检查构建输出目录配置
4. **版本冲突**: 确保版本号唯一或删除已存在的release

### 调试方法

在工作流中添加调试步骤：

```yaml
- name: Debug information
  run: |
    echo "Current directory: $(pwd)"
    echo "Files in current directory:"
    ls -la
    echo "Build output directory:"
    ls -la ${{ needs.detect-project.outputs.output_dir }} || echo "Output directory not found"
```

这个解决方案提供了完整的跨仓库发布功能，支持多种项目类型的自动检测和构建，并提供了丰富的配置选项。