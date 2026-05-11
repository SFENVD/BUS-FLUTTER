# Supabase MVP 接入计划

## 当前阶段

本分支 `feature/supabase-mvp` 已完成 Supabase MVP 前三步：认证层、普通用户车次/预约/支付，以及后台车辆、司机、调度和位置数据具备 Supabase 接入能力，未配置 Supabase 环境变量时继续走 Mock，避免影响课程演示和自动化测试。

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `BACKEND` | `auto`、`mock`、`supabase`，默认 `auto` |
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_ANON_KEY` | Supabase anon public key |

启动 Supabase 后端示例：

```bash
flutter run \
  --dart-define=BACKEND=supabase \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_MODE=passenger
```

未设置 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 时，`BACKEND=auto` 会自动回退到 Mock。

## 数据库初始化

1. 在 Supabase 控制台创建项目。
2. 在 Authentication 中创建三个演示用户：
   - `13800000001@school-bus.local` / `123456`
   - `13800000002@school-bus.local` / `123456`
   - `13800000003@school-bus.local` / `123456`
3. 在 SQL Editor 执行 `supabase/migrations/202605110001_initial_schema.sql`。
4. 在 SQL Editor 执行 `supabase/seed/202605110001_seed_demo_data.sql`。

## 分阶段替换计划

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| M1 | Supabase 配置、初始化、认证 Repository 可切换 | 已完成 |
| M2 | 普通用户车次、预约、取消、支付流水切 Supabase | 已完成 |
| M3 | 后台车辆、司机、调度、位置切 Supabase | 已完成 |
| M3.5 | 后台历史分析由真实数据聚合 | 待做 |
| M4 | 司机任务和位置上报切 Supabase | 已完成 |
| M4.5 | 司机和后台位置使用 Supabase Realtime 订阅 | 待做 |
| M5 | 支付沙箱后台确认、通知持久化、权限细化 | 待做 |

## 当前保留 Mock 的原因

当前仓库没有 Supabase 项目 URL 和 anon key，CI 环境也不能依赖外部私有项目。因此第一步使用 `BACKEND=auto` 策略，保证：

- 本地未配置 Supabase 时仍可运行和测试。
- 配置 Supabase 后认证和普通用户预约支付流程优先走真实后端。
- 后续业务模块可以逐个从 Mock Repository 切到 Supabase Repository。

## 已切换 Supabase 的模块

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 认证 | 已接入 | `SupabaseAuthRepository` 使用手机号派生邮箱登录，并读取 `profiles` 角色和信用分 |
| 车次列表 | 已接入 | `SupabasePassengerRepository.fetchSnapshot` 从 `trips` 读取车次 |
| 我的预约 | 已接入 | 从 `bookings` 读取当前用户预约，从 `payments` 读取支付流水 |
| 创建预约 | 已接入 | 写入 `bookings`，由数据库索引防止同一车次座位重复和同一用户重复预约 |
| 取消预约 | 已接入 | 更新 `bookings` 状态、扣分和 `profiles.credit_score` |
| 支付沙箱 | 已接入 | 写入 `payments`，先 `processing` 后模拟确认 `paid` |
| 后台基础数据 | 已接入 | 从 `vehicles`、`drivers`、`dispatch_demands`、`dispatch_plans`、`vehicle_locations` 加载数据 |
| 车辆管理 | 已接入 | 新增、编辑、删除会后台持久化到 `vehicles` |
| 司机管理 | 已接入 | 新增、编辑、删除会后台持久化到 `drivers` |
| AI 调度 | 已接入 | 生成的 AI 推荐方案会写入 `dispatch_plans` |
| 人工调度 | 已接入 | 人工调度方案会写入 `dispatch_plans` |
| 调度确认 | 已接入 | 确认后更新 `dispatch_plans`、`dispatch_demands`、`vehicles`、`drivers` 并写入 `vehicle_locations` |
| 位置刷新 | 已接入 | 后台 Mock 位置刷新会追加写入 `vehicle_locations` |
| 司机任务 | 已接入 | 司机端按 `drivers.profile_id` 读取 `trips` 和关联预约乘客名单 |
| 司机任务状态 | 已接入 | 开始任务和完成任务会更新 `trips.status` |
| 司机位置上报 | 已接入 | 司机端位置上报会写入 `vehicle_locations` |

## 下一步重点

| 优先级 | 内容 |
| --- | --- |
| 高 | 使用 Supabase Realtime 订阅车辆位置，替代手动刷新 |
| 中 | 将通知中心持久化到 `notifications` |
| 中 | 将后台历史分析改为由真实预约和支付数据聚合 |
