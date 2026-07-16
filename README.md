# VNDB App

[English](./readme-en.md)

## 部分代码由 AI 生成。

一款用于 [VNDB](https://vndb.org/)（Visual Novel Database，视觉小说数据库）的 Flutter 客户端，采用现代 Material Design 3 界面复刻网站功能。

## 功能特性

- **首页** - 最新发布、随机视觉小说和最近变更
- **视觉小说详情** - 完整信息，包括开发商、发行商、标签、角色、制作人员、截图和发行版本
- **制作商** - 点击开发商/发行商查看其详情页面
- **制作人员分类** - 按职位查看制作人员（剧本、美术、作曲、配音等）
- **可折叠区域** - 制作人员和发行版本区域可展开/折叠
- **制作人员作品** - 查看某位制作人员参与过的所有视觉小说
- **用户列表** - 通过全部/评分/愿望单标签管理你的视觉小说收藏
- **搜索** - 在用户列表内搜索
- **M3 设计** - 采用 Material Design 3，支持自定义强调色
- **语言切换** - 支持简体中文和英文
- **深色模式** - 自动跟随系统主题

## 技术栈

- **框架**：Flutter 3.x
- **状态管理**：Riverpod 2
- **路由**：Go Router
- **网络请求**：Dio
- **图片缓存**：Cached Network Image
- **本地化**：Flutter Localizations
- **安全存储**：Flutter Secure Storage
- **应用内浏览器**：Flutter InAppWebView

## 开始使用

### 环境要求

- Flutter SDK >= 3.0.0
- Android SDK（用于 Android 开发）
- VNDB 账号（用于需要登录的功能）

### 安装

```bash
# 克隆仓库
git clone https://github.com/sunxibing114514/VNclient.git
cd vndb_app

# 安装依赖
flutter pub get

# 构建应用
flutter build apk --release --split-per-abi
```

### 运行

```bash
# 开发模式
flutter run

# 发布模式（Android）
flutter run --release
```

## API 使用

本应用使用 [VNDB Kana API](https://api.vndb.org/kana) 获取数据。认证通过存储在设备上的 API 密钥完成。

## 项目结构

```
lib/
├── core/                  # 核心功能
│   ├── api/               # VNDB API 客户端和接口
│   ├── models/            # 数据模型
│   ├── providers/         # Riverpod 状态提供者
│   ├── router/            # Go Router 路由配置
│   ├── theme/             # 应用主题配置
│   └── l10n/              # 本地化字符串
├── features/              # 功能模块
│   ├── home/              # 首页
│   ├── vn_detail/         # 视觉小说详情页
│   ├── lists/             # 用户列表页
│   ├── staff/             # 制作人员页面
│   ├── producers/         # 制作商页面
│   ├── characters/        # 角色页面
│   ├── tags/              # 标签页面
│   ├── search/            # 搜索页面
│   ├── settings/          # 设置页面
│   └── login/             # 登录页面
├── widgets/               # 可复用组件
├── app.dart               # 根应用组件
└── main.dart              # 入口文件
```

## 特别感谢

- 界面设计灵感来自 [daniel-c-j/vndb-lite](https://github.com/daniel-c-j/vndb-lite)
- 感谢 [VNDB Kana API](https://api.vndb.org/kana) 提供的 API 文档

## 许可证

Apache-2.0 license
