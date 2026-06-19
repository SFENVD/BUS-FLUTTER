import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_mode_switcher.dart';
import '../data/mock_auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppMode mode) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          phone: _phoneController.text,
          password: _passwordController.text,
          mode: mode,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go(mode.homeLocation);
      return;
    }

    final message = ref.read(authControllerProvider).errorMessage ?? '登录失败';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _fillCredential(MockCredential credential) {
    final mode = credential.mode;
    ref.read(authControllerProvider.notifier).logout();
    ref.read(appModeControllerProvider.notifier).switchTo(mode);
    _phoneController.text = credential.user.phone;
    _passwordController.text = credential.password;
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final credentials = ref.watch(mockCredentialsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.64),
              colorScheme.surface,
              colorScheme.secondaryContainer.withValues(alpha: 0.46),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final form = _LoginForm(
                      formKey: _formKey,
                      mode: mode,
                      isLoading: authState.isLoading,
                      phoneController: _phoneController,
                      passwordController: _passwordController,
                      onSubmit: () => _submit(mode),
                    );
                    final intro = _LoginIntro(
                      mode: mode,
                      credentials: credentials,
                      onCredentialTap: _fillCredential,
                    );

                    if (!isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [intro, const SizedBox(height: 18), form],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: intro),
                        const SizedBox(width: 22),
                        Expanded(child: form),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro({
    required this.mode,
    required this.credentials,
    required this.onCredentialTap,
  });

  final AppMode mode;
  final List<MockCredential> credentials;
  final ValueChanged<MockCredential> onCredentialTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '在线服务',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '校车管理系统',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '当前入口：${mode.title}。可在下方切换不同角色入口，体验预约、调度和司机任务协同流程。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        const AppModeSwitcher(),
        const SizedBox(height: 22),
        Text(
          '快捷登录账号',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: credentials.map((credential) {
            return _CredentialChip(
              credential: credential,
              isSelected: credential.mode == mode,
              onTap: () => onCredentialTap(credential),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CredentialChip extends StatelessWidget {
  const _CredentialChip({
    required this.credential,
    required this.isSelected,
    required this.onTap,
  });

  final MockCredential credential;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      key: Key('quick_${credential.mode.value}_login'),
      avatar: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.onPrimary
            : colorScheme.primaryContainer,
        child: Text(
          credential.user.name.characters.first,
          style: TextStyle(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      label: Text('${credential.mode.shortLabel} · ${credential.user.phone}'),
      backgroundColor: isSelected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHigh,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      onPressed: onTap,
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.mode,
    required this.isLoading,
    required this.phoneController,
    required this.passwordController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final AppMode mode;
  final bool isLoading;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${mode.title}登录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mode.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: phoneController,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入手机号';
                    }
                    if (value.trim().length != 11) {
                      return '请输入 11 位手机号';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 6) {
                      return '密码至少 6 位';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      onSubmit();
                    }
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('login_submit'),
                  onPressed: isLoading ? null : onSubmit,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(isLoading ? '登录中...' : '登录'),
                ),
                const SizedBox(height: 14),
                Text(
                  '默认密码：123456。账号角色必须与当前入口一致。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
