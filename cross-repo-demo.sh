#!/bin/bash

# 跨仓库发布测试脚本
# 这个脚本演示了如何手动执行跨仓库发布流程

set -e

# 配置变量
SOURCE_REPO="difyz9/github_docs"      # 源仓库
TARGET_REPO="difyz9/release-repo"     # 目标仓库 - 需要修改为实际仓库
VERSION="v1.0.0"                      # 版本号
GITHUB_TOKEN="${GITHUB_TOKEN}"        # 从环境变量读取token

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查必要工具和配置
check_requirements() {
    print_step "Checking requirements..."
    
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GITHUB_TOKEN environment variable is required"
        echo "Please set it with: export GITHUB_TOKEN=your_token_here"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is required but not installed"
        echo "Install with: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    
    print_info "All requirements satisfied"
}

# 模拟项目构建
simulate_build() {
    print_step "Simulating project build..."
    
    # 创建模拟的构建输出
    mkdir -p dist
    
    # 创建一些示例文件
    cat > dist/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Cross-Repo Release Demo</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Cross-Repository Release Demo</h1>
    <p>This is a demo of cross-repository release process.</p>
    <p>Built on: <span id="build-date"></span></p>
    <script>
        document.getElementById('build-date').textContent = new Date().toISOString();
    </script>
</body>
</html>
EOF

    cat > dist/app.js << 'EOF'
// Demo application
console.log('Cross-repo release demo loaded');

function showBuildInfo() {
    fetch('./build-info.json')
        .then(response => response.json())
        .then(data => {
            console.log('Build Info:', data);
        })
        .catch(error => {
            console.error('Error loading build info:', error);
        });
}

// Auto-load build info
document.addEventListener('DOMContentLoaded', showBuildInfo);
EOF

    cat > dist/styles.css << 'EOF'
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    line-height: 1.6;
    color: #333;
}

h1 {
    color: #0366d6;
    border-bottom: 1px solid #e1e4e8;
    padding-bottom: 10px;
}

p {
    margin: 15px 0;
}

#build-date {
    font-family: 'Monaco', 'Menlo', monospace;
    background: #f6f8fa;
    padding: 2px 4px;
    border-radius: 3px;
}
EOF

    # 创建README
    cat > dist/README.md << EOF
# Cross-Repository Release Demo

This package was built from the source repository and published to a separate release repository.

## Package Information
- **Version**: $VERSION
- **Build Date**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- **Source**: $SOURCE_REPO

## Contents
- \`index.html\` - Demo web page
- \`app.js\` - JavaScript application
- \`styles.css\` - Stylesheet
- \`build-info.json\` - Build metadata

## Usage
Open \`index.html\` in a web browser to see the demo.
EOF

    print_info "Build simulation completed"
    print_info "Generated files:"
    ls -la dist/
}

# 创建发布包
create_release_package() {
    print_step "Creating release package..."
    
    # 清理旧的发布包
    rm -rf release-package
    mkdir -p release-package
    
    # 复制构建产物
    cp -r dist/* release-package/
    
    # 添加构建元数据
    cat > release-package/build-info.json << EOF
{
    "version": "$VERSION",
    "source_repository": "$SOURCE_REPO",
    "target_repository": "$TARGET_REPO",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_type": "demo",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "builder": "cross-repo-demo.sh"
}
EOF
    
    # 创建压缩包
    cd release-package
    zip -r ../release-$VERSION.zip .
    tar -czf ../release-$VERSION.tar.gz .
    cd ..
    
    print_info "Release package created:"
    ls -lh release-$VERSION.{zip,tar.gz}
}

# 创建GitHub Release
create_github_release() {
    print_step "Creating GitHub Release..."
    
    # 检查目标仓库是否存在
    if ! gh repo view "$TARGET_REPO" &>/dev/null; then
        print_error "Target repository '$TARGET_REPO' not found or no access"
        print_info "Please check:"
        print_info "1. Repository name is correct"
        print_info "2. Repository exists"
        print_info "3. You have access to the repository"
        print_info "4. Token has appropriate permissions"
        exit 1
    fi
    
    # 检查release是否已存在
    if gh release view "$VERSION" --repo "$TARGET_REPO" &>/dev/null; then
        print_warning "Release $VERSION already exists in $TARGET_REPO"
        read -p "Do you want to delete and recreate it? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Deleting existing release..."
            gh release delete "$VERSION" --repo "$TARGET_REPO" --yes
        else
            print_info "Cancelled"
            exit 0
        fi
    fi
    
    # 生成发布说明
    RELEASE_NOTES="## 🚀 Cross-Repository Release Demo $VERSION

### 📦 Package Information
This release demonstrates the cross-repository release process where:
- **Source Repository**: [\`$SOURCE_REPO\`](https://github.com/$SOURCE_REPO)
- **Target Repository**: [\`$TARGET_REPO\`](https://github.com/$TARGET_REPO)
- **Build Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

### 📥 Available Downloads
| File | Description | Size |
|------|-------------|------|
| \`release-$VERSION.zip\` | Universal ZIP archive | $(du -h release-$VERSION.zip | cut -f1) |
| \`release-$VERSION.tar.gz\` | Unix/Linux TAR.GZ archive | $(du -h release-$VERSION.tar.gz | cut -f1) |

### 📂 Package Contents
- **Web Demo**: \`index.html\`, \`app.js\`, \`styles.css\`
- **Documentation**: \`README.md\`
- **Metadata**: \`build-info.json\`

### 🎯 Demo Features
- ✅ Cross-repository release workflow
- ✅ Automated build packaging
- ✅ Multiple archive formats
- ✅ Rich release documentation
- ✅ Build metadata tracking

### 🔧 Technical Details
- **Build Tool**: cross-repo-demo.sh
- **Package Format**: Static web files
- **Compression**: ZIP + TAR.GZ

---
*This is a demonstration release created by the cross-repository release demo script.*"

    # 创建release
    print_info "Creating release in $TARGET_REPO..."
    
    if gh release create "$VERSION" \
        --repo "$TARGET_REPO" \
        --title "🚀 Demo Release $VERSION" \
        --notes "$RELEASE_NOTES" \
        --latest \
        release-$VERSION.zip \
        release-$VERSION.tar.gz; then
        
        print_info "✅ Release created successfully!"
        print_info "🔗 View at: https://github.com/$TARGET_REPO/releases/tag/$VERSION"
        
        # 显示下载链接
        echo ""
        print_info "📥 Direct download links:"
        echo "   ZIP: https://github.com/$TARGET_REPO/releases/download/$VERSION/release-$VERSION.zip"
        echo "   TAR.GZ: https://github.com/$TARGET_REPO/releases/download/$VERSION/release-$VERSION.tar.gz"
        
    else
        print_error "❌ Failed to create release"
        exit 1
    fi
}

# 清理临时文件
cleanup() {
    print_step "Cleaning up..."
    rm -rf release-package
    rm -f release-$VERSION.zip release-$VERSION.tar.gz
    rm -rf dist
    print_info "Cleanup completed"
}

# 显示帮助信息
show_help() {
    echo "Cross-Repository Release Demo Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Set release version (default: $VERSION)"
    echo "  -t, --target REPO        Set target repository (default: $TARGET_REPO)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GITHUB_TOKEN            GitHub Personal Access Token (required)"
    echo ""
    echo "Example:"
    echo "  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx"
    echo "  $0 --version v2.0.0 --target username/my-releases"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_REPO="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    echo "🚀 Cross-Repository Release Demo"
    echo "================================="
    echo ""
    
    parse_args "$@"
    
    print_info "Configuration:"
    print_info "  Source Repository: $SOURCE_REPO"
    print_info "  Target Repository: $TARGET_REPO"
    print_info "  Release Version: $VERSION"
    echo ""
    
    # 确认执行
    read -p "Do you want to proceed with the demo release? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Demo cancelled"
        exit 0
    fi
    
    check_requirements
    simulate_build
    create_release_package
    create_github_release
    
    echo ""
    print_info "🎉 Cross-repository release demo completed successfully!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Visit the release page to see the result"
    print_info "2. Download and test the packages"
    print_info "3. Adapt the GitHub Actions workflows for your real projects"
    
    # 询问是否清理
    echo ""
    read -p "Do you want to clean up temporary files? [Y/n]: " cleanup_confirm
    if [[ ! "$cleanup_confirm" =~ ^[Nn]$ ]]; then
        cleanup
    fi
}

# 设置trap来在脚本中断时清理
trap 'print_error "Script interrupted"; cleanup; exit 1' INT TERM

# 执行主函数
main "$@"
