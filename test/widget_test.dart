import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_bus_app/app.dart';
import 'package:school_bus_app/core/models/app_mode.dart';
import 'package:school_bus_app/core/providers/app_mode_provider.dart';

void main() {
  testWidgets('passenger mock login opens passenger workspace', (tester) async {
    await _pumpPassengerApp(tester);
    await _loginAsPassenger(tester);

    expect(find.text('普通用户端工作台'), findsOneWidget);
    expect(find.text('预约车次'), findsOneWidget);
    expect(find.text('我的预约'), findsOneWidget);
  });

  testWidgets('passenger can book a seat and cancel with credit penalty', (
    tester,
  ) async {
    await _pumpPassengerApp(tester);
    await _loginAsPassenger(tester);

    await tester.ensureVisible(find.byKey(const Key('book_trip_trip-001')));
    await tester.tap(find.byKey(const Key('book_trip_trip-001')));
    await tester.pumpAndSettle();

    expect(find.text('选择座位 · 大学城早班线'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seat_trip-001_19')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_booking')));
    await tester.pumpAndSettle();

    expect(find.text('座位 19'), findsOneWidget);
    expect(find.text('预约成功，订单已生成'), findsOneWidget);

    await tester.ensureVisible(find.text('取消预约'));
    await tester.tap(find.text('取消预约'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_cancel_booking')));
    await tester.pumpAndSettle();

    expect(find.text('已扣减信用分 5 分'), findsOneWidget);
    expect(find.textContaining('信用分 91'), findsWidgets);
  });

  testWidgets('passenger can pay booking and receive notification', (
    tester,
  ) async {
    await _pumpPassengerApp(tester);
    await _loginAsPassenger(tester);

    expect(find.text('信用等级'), findsOneWidget);
    expect(find.text('推送通知'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('book_trip_trip-001')));
    await tester.tap(find.byKey(const Key('book_trip_trip-001')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seat_trip-001_19')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_booking')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('立即支付'));
    await tester.tap(find.text('立即支付'));
    await tester.pumpAndSettle();

    expect(find.text('支付车费'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_payment')));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(find.text('已支付'), findsWidgets);
    expect(find.text('支付成功'), findsWidgets);
  });

  testWidgets('driver can start task and report mock location', (tester) async {
    await _pumpApp(tester, AppMode.driver);
    await _loginWithMockCredential(
      tester,
      mode: AppMode.driver,
      loginTitle: '司机端登录',
    );

    expect(find.text('司机端工作台'), findsOneWidget);
    expect(find.text('统计看板'), findsOneWidget);
    expect(find.text('实时位置共享'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
    await tester.tap(find.byKey(const Key('start_task_task-001')));
    await tester.pumpAndSettle();

    expect(find.text('行程中'), findsOneWidget);
    expect(find.text('上报次数：1'), findsOneWidget);
    expect(find.text('纬度：31.23040'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('simulate_location_report')),
    );
    await tester.tap(find.byKey(const Key('simulate_location_report')));
    await tester.pumpAndSettle();

    expect(find.text('上报次数：2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete_active_task')));
    await tester.pumpAndSettle();

    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('未开启'), findsOneWidget);
  });

  testWidgets('admin can manage vehicles drivers and tracking', (tester) async {
    await _pumpApp(tester, AppMode.admin);
    await _loginWithMockCredential(
      tester,
      mode: AppMode.admin,
      loginTitle: '后台管理端登录',
    );

    expect(find.text('后台管理端工作台'), findsOneWidget);
    expect(find.text('车辆管理'), findsOneWidget);
    expect(find.text('司机管理'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('edit_vehicle_bus-002')));
    await tester.tap(find.byKey(const Key('edit_vehicle_bus-002')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('vehicle_plate_field')),
      '校A·2040',
    );
    await tester.tap(find.byKey(const Key('save_vehicle')));
    await tester.pumpAndSettle();

    expect(find.text('校A·2040'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('add_vehicle')));
    await tester.tap(find.byKey(const Key('add_vehicle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('vehicle_plate_field')),
      '校A·5098',
    );
    await tester.enterText(
      find.byKey(const Key('vehicle_model_field')),
      '测试车型 T1',
    );
    await tester.tap(find.byKey(const Key('save_vehicle')));
    await tester.pumpAndSettle();

    expect(find.text('校A·5098'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add_driver')));
    await tester.tap(find.byKey(const Key('add_driver')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('driver_name_field')), '孙师傅');
    await tester.enterText(
      find.byKey(const Key('driver_phone_field')),
      '13800009001',
    );
    await tester.enterText(
      find.byKey(const Key('driver_license_field')),
      'A1-TEST-9001',
    );
    await tester.tap(find.byKey(const Key('save_driver')));
    await tester.pumpAndSettle();

    expect(find.text('孙师傅'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('generate_ai_dispatch')));
    await tester.tap(find.byKey(const Key('generate_ai_dispatch')));
    await tester.pumpAndSettle();

    expect(find.text('AI 推荐'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('confirm_first_dispatch_plan')),
    );
    await tester.tap(find.byKey(const Key('confirm_first_dispatch_plan')));
    await tester.pumpAndSettle();

    expect(find.text('已确认'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('map_marker_bus-003')));
    await tester.tap(find.byKey(const Key('map_marker_bus-003')));
    await tester.pumpAndSettle();

    expect(find.text('校A·3099'), findsWidgets);
    expect(find.text('钱师傅'), findsWidgets);

    await tester.ensureVisible(find.text('预约客户 ETA'));
    expect(find.text('预约客户 ETA'), findsOneWidget);
    expect(find.textContaining('预计 8 分钟'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('simulate_admin_location_tick')),
    );
    await tester.tap(find.byKey(const Key('simulate_admin_location_tick')));
    await tester.pumpAndSettle();

    expect(find.text('实时位置监控'), findsOneWidget);

    await tester.ensureVisible(find.text('历史数据分析'));
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.text('1298'), findsOneWidget);
    expect(find.text('路线热度排行'), findsOneWidget);
  });
}

Future<void> _pumpPassengerApp(WidgetTester tester) async {
  await _pumpApp(tester, AppMode.passenger);
}

Future<void> _loginAsPassenger(WidgetTester tester) async {
  await _loginWithMockCredential(
    tester,
    mode: AppMode.passenger,
    loginTitle: '普通用户端登录',
  );
}

Future<void> _pumpApp(WidgetTester tester, AppMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [initialAppModeProvider.overrideWithValue(mode)],
      child: const AppRoot(),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _loginWithMockCredential(
  WidgetTester tester, {
  required AppMode mode,
  required String loginTitle,
}) async {
  expect(find.text('校车管理系统'), findsOneWidget);
  expect(find.text(loginTitle), findsOneWidget);

  await tester.tap(find.byKey(Key('quick_${mode.value}_login')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('login_submit')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}
