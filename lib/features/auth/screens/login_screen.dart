import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await AuthService.instance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = await AuthService.instance.getCurrentUserModel(
        throwOnError: true,
      );
      if (!mounted) return;

      if (user == null) {
        final currentAuthUser = AuthService.instance.currentUser;
        final uid = currentAuthUser?.uid ?? 'unknown';
        
        // Auto-heal: Nếu tài khoản Auth tồn tại nhưng không có trong Firestore (do lỗi ngắt quãng trước đây), 
        // xoá luôn tài khoản Auth đó để Chủ rừng có thể tạo lại một cách liền mạch.
        if (currentAuthUser != null) {
          try {
            await currentAuthUser.delete();
          } catch (_) {
            // Ignore error if delete fails
          }
        }
        
        await AuthService.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tài khoản bị lỗi đồng bộ (ID: $uid) đã được dọn dẹp. Vui lòng nhờ Chủ rừng tạo lại.',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      if (user.status == UserStatus.locked ||
          user.status == UserStatus.inactive) {
        await AuthService.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản đã bị khóa hoặc chưa hoạt động.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      switch (user.role) {
        case UserRole.platformAdmin:
          context.go(AppRoutes.dashboardAdmin);
          break;
        case UserRole.forestOwner:
          context.go(AppRoutes.dashboardOwner);
          break;
        case UserRole.forestWorker:
          context.go(AppRoutes.dashboardWorker);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().split('\n').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không đăng nhập được: $message'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 0 : AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / Header
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.forest,
                        color: AppColors.onPrimary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.appName,
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quản lý dữ liệu rừng phục vụ dự án carbon',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppStrings.login,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: AppStrings.email,
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return AppStrings.fieldRequired;
                            }
                            if (!v.contains('@')) {
                              return AppStrings.invalidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: AppStrings.password,
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return AppStrings.fieldRequired;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              context.push(AppRoutes.otpLogin);
                            },
                            child: Text(
                              AppStrings.forgotPassword,
                              style: TextStyle(color: AppColors.tertiary),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Login button
                        AppPrimaryButton(
                          label: AppStrings.login,
                          onPressed: _onLogin,
                          isLoading: _isLoading,
                          width: double.infinity,
                        ),
                      ],
                    ),
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
