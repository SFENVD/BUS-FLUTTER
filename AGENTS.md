# 仓库工作约定

## 当前实现边界
- 这是单一 Flutter 应用，不是三端独立包。`lib/main.dart` 读取编译期 `APP_MODE`，通过 `initialAppModeProvider` 注入入口；默认 `passenger`，另有 `driver`、`admin`。
- `lib/app.dart` 使用 `appRouterProvider`；路由实例稳定，通过监听身份/角色和入口变化刷新重定向，并在 Provider 销毁时 dispose。不要因信用分、loading 等变化重建 GoRouter。Widget 测试直接挂载 `AppRoot`，必须用 `ProviderScope` override `initialAppModeProvider`，不能依赖 `main()` 的 dart-define。
- 实际依赖为 Riverpod **3**、GoRouter **17**，Dart 约束 `^3.11.5`；不要套用旧技术方案中的 Riverpod 2、旧路由 API 或代码生成命令。当前没有 build_runner/freezed/json_serializable。
- 各业务域仍由 `mock_*_repository.dart` 提供初始样例，操作位于 Notifier。`main.dart` 注入 `DemoPersistence`：网页使用 localStorage 保存业务快照并通过 storage 事件同步同浏览器同源标签页；原生和默认测试容器使用独立内存。它不是服务端数据库，不提供跨设备/跨浏览器同步或事务保证；角色业务域仍彼此独立。
- 认证会话、密码不持久化；信用分以 `scores` 保存，退出重登不恢复初始分。登录页提供保存范围提示和带确认的“重置演示数据”，清除后恢复初始样例并登出。新增状态字段需同步维护对应 state codec；监听持久化变化需处理业务 key 和 `'*'` 重置，并释放订阅。
- 支付是 500ms 延迟模拟，通知是本地 Provider，位置是 5 秒 Timer 模拟；后台地图是自绘网格，客户 ETA 是固定示例，“AI 调度”是本地贪心匹配。不要声称已接入支付 SDK、GPS、WebSocket、地图服务或 OpenAI。
- `supabase/` 只有预备 SQL，Flutter 没有 Supabase 客户端，也不读取 `BACKEND`/`SUPABASE_*`。若专门验证 SQL：先建表，再创建种子文件头部指定的三个 Auth 用户，再运行 seed；这不是当前 App/测试的启动前置条件。

## 运行与验证
- 安装依赖：`flutter pub get`。锁文件使用 `https://pub.flutter-io.cn`；新 Flutter SDK 可能自动改写 `pubspec.lock`、`analysis_options.yaml`，与任务无关的工具迁移不要混入提交。
- 乘客/司机：`flutter run --dart-define=APP_MODE=passenger` / `flutter run --dart-define=APP_MODE=driver`；后台：`flutter run -d chrome --dart-define=APP_MODE=admin`。
- 演示手机号分别为 `13800000001` / `13800000002` / `13800000003`，密码均为 `123456`；账号必须与入口匹配。
- 本地非改写检查顺序：`dart format --output=none --set-exit-if-changed lib test` → `flutter analyze` → `flutter test`。CI 固定 Flutter 3.47.9，使用相同严格格式门禁，并运行 `python3 tools/build_overleaf.py --check`。
- 聚焦回归：`flutter test test/business_rule_test.dart`；司机：`flutter test test/driver_test.dart`；单例：`flutter test test/widget_test.dart --plain-name 'passenger can pay booking and receive notification'`。
- Pages 构建必须保留子路径和后台入口：`flutter build web --release --base-href /BUS-FLUTTER/ --dart-define=APP_MODE=admin`。工作流只在 push 到 `main` 后发布 `build/web`，PR 仅验证。
- Android Java/Kotlin 目标为 17；`android/app/build.gradle.kts` 的 release 仍使用 debug 签名和示例 applicationId，不是生产发布配置。Windows/Linux runner 的可执行名由各平台顶层 CMake 的 `BINARY_NAME` 控制。
- Provider 单测用独立 `ProviderContainer` 并 `addTearDown(container.dispose)`；司机和后台有周期 Timer，需释放容器/组件。延迟登录、支付和定时回调用 `tester.pump(Duration(...))` 推进；滚动外按钮先 `ensureVisible`，快捷登录 Key 为 `quick_${mode.value}_login`。

## 容易改错的业务语义
- `BookingStatus` 与 `BookingPaymentStatus` 是两个独立状态；支付成功仍是 `BookingStatus.pending`，不能新增或假设 `BookingStatus.paid`。
- 支付处理中重复提交应拒绝；支付中取消将流水置 failed、预约支付状态恢复 unpaid，已支付取消需同时把预约和流水置 refunded。延迟回调必须检查 Provider 未销毁及当前支付尝试仍有效，不能覆盖取消或其他标签页的新状态。
- 余座扣减同时包含 `TripModel.bookedSeats` 的预占座位和新建 active bookings；不要再次把 active bookings 累加进 `bookedSeats`。取消在距发车整数分钟数 ≤120 时扣 5 分，否则扣 2 分。
- 智能调度只选空闲且已绑定司机的车辆，每批建议不重复用车/司机；创建和确认时共用容量、司机占用、双向绑定、需求状态与时间校验，确认需重验建议快照。建议需 `confirmDispatchPlan` 后才改车辆和需求状态；它不会创建乘客端车次或司机端任务。
- 司机退出登录或切换角色后停止定位 Timer；重登司机后可恢复进行中任务的模拟上报。位置历史与通知最多保留 200 条，避免恢复无限增长的演示记录。

## 唯一文档与 Overleaf 交付
- 用户要求合并项目文档：完整正文唯一来源是根目录 `main.tex`，交付包是 `overleaf.zip`；`README.md` 只保留入口，`AGENTS.md` 只放代理约定。保留用户后来上传的 `docs/` 历史资料，不在其中新建或维护平行正文、独立技术方案或测试报告。
- `report-assets/` 只存正文图片和原始建模/计划证据，不新增平行正文。原有报告中的 Supabase 切换、JUnit、生产能力、测试数字等不能当作当前事实；历史截图不等于本次验证。
- 修改正文/素材后运行 `python3 tools/build_overleaf.py` 重建压缩包，运行 `python3 tools/build_overleaf.py --check` 检查文件内容是否同步；脚本仅用 Python 标准库，不依赖旧文档。
- Overleaf 主文件为 `main.tex`，编译器选 **XeLaTeX**；使用 `ctexrep` 的 Fandol 字体，无需系统中文字体、minted 或 shell-escape。本地可用 `latexmk -xelatex -outdir=build/report main.tex` 验证。
