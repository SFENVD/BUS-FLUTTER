# 校车管理系统

Flutter 校车管理系统 P0 骨架，覆盖普通用户端、司机端和后台管理端。

## 已完成

- 项目初始化：Flutter 3.x 工程与模块化 `lib/` 目录。
- 状态管理：使用 `flutter_riverpod` 管理入口模式与登录态。
- 路由：使用 `go_router` 配置登录鉴权和三端首页骨架。
- 三端入口：通过 `APP_MODE` 环境变量初始化，也可在 P0 页面内切换 Mock 入口。
- 登录页：内置普通用户、司机、管理员三组 Mock 账号。
- P1 用户端：可预约车次列表、选座确认、生成预约订单、我的预约筛选、取消预约扣信用分。
- P2 司机端：今日派车任务、乘客名单/上车点、日/周/月统计看板、Mock 实时位置共享。
- P3 后台端：车辆 CRUD、司机 CRUD/绑定车辆、Mock 实时位置监控地图。
- P4 后台端：预约需求汇总、人工调度、AI 辅助调度建议、预约客户 ETA、历史数据分析。
- P5 用户端：Mock 微信/支付宝支付、信用等级/失信记录、Mock 推送通知中心、UI 收口。
- P6 CI/CD：GitHub Actions 自动执行格式检查、静态分析、测试、Web 构建和 Pages 部署。
- P7 Supabase MVP：已接入可切换后端配置、Supabase 认证、普通用户车次/预约/取消/支付流水、后台车辆/司机数据，未配置时自动回退 Mock。

## 启动方式

```bash
flutter pub get

# 普通用户端
flutter run --dart-define=APP_MODE=passenger

# 司机端
flutter run --dart-define=APP_MODE=driver

# 后台管理端（Web）
flutter run -d chrome --dart-define=APP_MODE=admin
```

## 后端模式

默认 `BACKEND=auto`。未配置 Supabase 时自动使用 Mock；配置 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 后可连接 Supabase。

```bash
# 强制 Mock
flutter run --dart-define=BACKEND=mock --dart-define=APP_MODE=passenger

# 使用 Supabase
flutter run \
  --dart-define=BACKEND=supabase \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_MODE=passenger
```

Supabase 数据库脚本位于：

- `supabase/migrations/202605110001_initial_schema.sql`
- `supabase/seed/202605110001_seed_demo_data.sql`

详细接入步骤见 `docs/08_Supabase_MVP接入计划.md`。

## CI/CD

- GitHub Actions 配置位于 `.github/workflows/flutter-ci-cd.yml`。
- 推送到 `main` 或创建指向 `main` 的 PR 时，会执行 `flutter pub get`、`dart format --set-exit-if-changed lib test`、`flutter analyze`、`flutter test` 和 `flutter build web`。
- `main` 分支推送验证通过后，会把后台管理端 Web 构建产物部署到 GitHub Pages。
- CI 构建默认使用 `BACKEND=mock`，避免公开仓库依赖私有 Supabase 配置。
- 如需启用 Pages 部署，在 GitHub 仓库 `Settings > Pages > Build and deployment` 中选择 `GitHub Actions`。

## Mock 账号

| 入口 | 手机号 | 密码 |
| --- | --- | --- |
| 普通用户端 | `13800000001` | `123456` |
| 司机端 | `13800000002` | `123456` |
| 后台管理端 | `13800000003` | `123456` |

账号角色必须与当前入口一致。点击登录页的 Mock 账号会自动切换入口并填入账号。

## P1 取消规则

- 距发车时间小于等于 2 小时：扣减信用分 `5` 分。
- 距发车时间大于 2 小时：扣减信用分 `2` 分。
- 只有 `待发车` 预约可以取消。

## P2 司机端 Mock 说明

- 点击任务卡片的 `开始任务并共享位置` 后，任务状态变为 `行程中`。
- 系统会立即生成一次位置上报，并每 `5` 秒模拟追加一条经纬度和速度记录。
- 点击 `模拟上报一次` 可手动追加位置记录，便于开发阶段验证 UI。
- 点击 `到站完成` 后，任务状态变为 `已完成`，位置共享停止。

## P3 后台端 Mock 说明

- 车辆管理支持新增、编辑、删除；运行中车辆不可删除。
- 司机管理支持新增、编辑、删除；车辆绑定保持一车一司机。
- 实时位置监控使用 Flutter 组件绘制 Mock 地图标记，点击车辆标记可查看车次、司机、速度和坐标，并展示预约客户距离和预计到达时间。
- 位置监控每 `5` 秒自动模拟更新一次，也可点击 `刷新位置` 手动更新。

## P4 调度与分析 Mock 说明

- `AI 生成方案` 会按待调度人数降序匹配空闲且已绑定司机的车辆。
- `人工调度` 可手动为单个需求选择车辆和司机，车辆座位数不足会被拦截。
- `确认生效` 后需求变为已调度，车辆变为运行中，并进入实时位置监控。
- 历史数据分析支持日/周/月切换，展示人次趋势、路线热度、收入和车辆利用率。

## 项目报告

- `docs/00_项目报告总览.md`：报告索引和完成情况总览。
- `docs/01_项目计划.md`：项目计划、WBS、里程碑和甘特图。
- `docs/02_项目需求.md`：需求说明、业务规则和用例。
- `docs/03_项目设计.md`：架构设计、模块设计、数据模型和 UML。
- `docs/04_项目源码说明.md`：源码结构、运行方式和功能映射。
- `docs/05_项目测试.md`：测试计划、测试用例和测试报告。
- `docs/06_配置管理.md`：Git、依赖、基线和交付配置管理。
- `docs/07_课程工具使用标识.md`：课程工具使用痕迹汇总。

## P5 支付、信用和推送 Mock 说明

- 用户端待支付预约可点击 `立即支付`，选择 `微信支付` 或 `支付宝`。
- 支付流程会先进入 `支付中`，约 `500ms` 后变为 `已支付`，并写入 Mock 支付流水。
- 预约创建、支付成功、取消扣分都会写入 Mock 推送通知中心。
- 信用等级按信用分划分：`优秀 >= 90`、`良好 >= 80`、`一般 >= 60`、`受限 < 60`。
