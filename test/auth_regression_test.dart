import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/app.dart';
import 'package:school_bus_app/core/models/app_mode.dart';
import 'package:school_bus_app/core/models/booking_model.dart';
import 'package:school_bus_app/core/models/user_model.dart';
import 'package:school_bus_app/core/persistence/demo_persistence.dart';
import 'package:school_bus_app/core/providers/app_mode_provider.dart';
import 'package:school_bus_app/core/providers/auth_provider.dart';
import 'package:school_bus_app/core/router/app_router.dart';
import 'package:school_bus_app/features/auth/data/mock_auth_repository.dart';
import 'package:school_bus_app/features/passenger/booking/providers/passenger_booking_provider.dart';

void main() {
  for (final target in AppMode.values) {
    testWidgets(
      'one quick account click switches to ${target.value} and retains credentials',
      (tester) async {
        final initial = target == AppMode.admin
            ? AppMode.passenger
            : AppMode.admin;
        final container = await _mountApp(tester, initial);
        final credential = MockAuthRepository.credentials.singleWhere(
          (item) => item.mode == target,
        );

        await tester.ensureVisible(
          find.byKey(Key('quick_${target.value}_login')),
        );
        await tester.tap(find.byKey(Key('quick_${target.value}_login')));
        await tester.pumpAndSettle();

        expect(container.read(appModeControllerProvider), target);
        expect(find.text('${target.title}登录'), findsOneWidget);
        final fields = tester.widgetList<TextFormField>(
          find.byType(TextFormField),
        );
        expect(fields.map((field) => field.controller!.text), [
          credential.user.phone,
          credential.password,
        ]);

        await tester.ensureVisible(find.byKey(const Key('login_submit')));
        await tester.tap(find.byKey(const Key('login_submit')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('${target.title}工作台'), findsOneWidget);
        expect(container.read(authControllerProvider).user?.role, target.role);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );
  }

  testWidgets('router survives credit updates and enforces changed entrance', (
    tester,
  ) async {
    final container = await _mountApp(tester, AppMode.passenger);
    final router = container.read(appRouterProvider);
    final authentication = container
        .read(authControllerProvider.notifier)
        .login(
          phone: '13800000001',
          password: '123456',
          mode: AppMode.passenger,
        );
    await tester.pump(const Duration(milliseconds: 600));
    expect(await authentication, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('普通用户端工作台'), findsOneWidget);

    container.read(authControllerProvider.notifier).adjustCreditScore(-5);
    await tester.pumpAndSettle();
    expect(identical(container.read(appRouterProvider), router), isTrue);
    expect(find.text('普通用户端工作台'), findsOneWidget);
    expect(find.textContaining('信用分 91'), findsWidgets);

    container.read(appModeControllerProvider.notifier).switchTo(AppMode.driver);
    await tester.pumpAndSettle();
    expect(identical(container.read(appRouterProvider), router), isTrue);
    expect(find.text('司机端登录'), findsOneWidget);

    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('司机端登录'), findsOneWidget);
    expect(find.text('后台管理端工作台'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  test('cancellation credit penalty survives logout and relogin', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final auth = container.read(authControllerProvider.notifier);
    expect(await _loginPassenger(auth), isTrue);
    expect(container.read(authControllerProvider).user!.creditScore, 96);
    final bookings = container.read(passengerBookingProvider.notifier);
    final created = await bookings.createBooking(
      userId: 'u-passenger-001',
      tripId: 'trip-001',
      seatNo: 19,
    );
    expect(created.success, isTrue);
    expect((await bookings.cancelBooking(created.booking!.id)).success, isTrue);
    expect(container.read(authControllerProvider).user!.creditScore, 91);

    auth.logout();
    expect(await _loginPassenger(auth), isTrue);
    expect(container.read(authControllerProvider).user!.creditScore, 91);
    final booking = container
        .read(passengerBookingProvider)
        .bookings
        .singleWhere((item) => item.id == created.booking!.id);
    expect(booking.status, BookingStatus.cancelled);
    expect(booking.creditPenalty, 5);
  });

  test(
    'logout prevents an unfinished login from authenticating again',
    () async {
      final repository = _DelayedAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final auth = container.read(authControllerProvider.notifier);
      final login = _loginPassenger(auth);
      expect(container.read(authControllerProvider).isLoading, isTrue);

      auth.logout();
      repository.result.complete(MockAuthRepository.credentials.first.user);
      expect(await login, isFalse);
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(container.read(authControllerProvider).errorMessage, isNull);
    },
  );

  test(
    'scores restore without sessions and follow external storage changes',
    () async {
      final store = MemoryDemoPersistence();
      addTearDown(store.dispose);
      final first = ProviderContainer(
        overrides: [demoPersistenceProvider.overrideWithValue(store)],
      );
      final second = ProviderContainer(
        overrides: [demoPersistenceProvider.overrideWithValue(store)],
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final firstAuth = first.read(authControllerProvider.notifier);
      expect(await _loginPassenger(firstAuth), isTrue);
      firstAuth.adjustCreditScore(-5);

      expect(second.read(authControllerProvider).isAuthenticated, isFalse);
      expect(
        await _loginPassenger(second.read(authControllerProvider.notifier)),
        isTrue,
      );
      expect(second.read(authControllerProvider).user!.creditScore, 91);
      expect(store.read('scores'), {'u-passenger-001': 91});

      store.receiveExternal('scores', {
        'u-passenger-001': 77,
        'u-driver-001': 88,
      });
      expect(first.read(authControllerProvider).user!.creditScore, 77);
      expect(second.read(authControllerProvider).user!.creditScore, 77);
      firstAuth.adjustCreditScore(-2);
      expect(store.read('scores'), {'u-passenger-001': 75, 'u-driver-001': 88});

      store.clear();
      expect(first.read(authControllerProvider).isAuthenticated, isFalse);
      expect(second.read(authControllerProvider).isAuthenticated, isFalse);
      expect(await _loginPassenger(firstAuth), isTrue);
      expect(first.read(authControllerProvider).user!.creditScore, 96);
    },
  );

  testWidgets('reset demo data requires confirmation and can be cancelled', (
    tester,
  ) async {
    final container = await _mountApp(tester, AppMode.passenger);
    final store = container.read(demoPersistenceProvider);
    store.write('scores', {'u-passenger-001': 80});
    expect(find.text('当前环境的演示数据仅保存在本次会话。'), findsOneWidget);

    final reset = find.byKey(const Key('reset_demo_data'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('重置演示数据？'), findsOneWidget);
    expect(store.read('scores'), {'u-passenger-001': 80});
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(store.read('scores'), {'u-passenger-001': 80});

    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_reset_demo_data')));
    await tester.pumpAndSettle();
    expect(store.read('scores'), isNull);
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(find.text('演示数据已重置'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}

Future<ProviderContainer> _mountApp(WidgetTester tester, AppMode mode) async {
  final container = ProviderContainer(
    overrides: [initialAppModeProvider.overrideWithValue(mode)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppRoot()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<bool> _loginPassenger(AuthController auth) {
  return auth.login(
    phone: '13800000001',
    password: '123456',
    mode: AppMode.passenger,
  );
}

class _DelayedAuthRepository extends MockAuthRepository {
  final result = Completer<UserModel>();

  @override
  Future<UserModel> login({
    required String phone,
    required String password,
    required AppMode mode,
  }) {
    return result.future;
  }
}
