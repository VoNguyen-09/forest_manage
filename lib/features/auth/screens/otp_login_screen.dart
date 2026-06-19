import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/config/theme.dart';
import 'package:forest_carbon_platform/core/models/user_model.dart';
import 'package:forest_carbon_platform/core/services/auth_service.dart';
import 'package:forest_carbon_platform/core/services/demo_otp_email_service.dart';
import 'package:forest_carbon_platform/shared/widgets/app_button.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  static const String _demoDefaultPassword = '123456';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  String? _generatedOtp;
  DateTime? _otpExpiresAt;
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final otp = DemoOtpEmailService.instance.generateOtp();
      await DemoOtpEmailService.instance.sendOtp(
        email: _emailController.text,
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        _generatedOtp = otp;
        _otpExpiresAt = DateTime.now().add(DemoOtpEmailService.otpLifetime);
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi mã OTP tới email đã đăng ký.')),
      );
    } catch (e) {
      _showError('Không gửi được OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otpController.text.trim().length != 6) {
      _showError('Mã OTP gồm 6 chữ số.');
      return;
    }
    if (_generatedOtp == null || _otpExpiresAt == null) {
      _showError('Bạn cần gửi mã OTP trước.');
      return;
    }
    if (DateTime.now().isAfter(_otpExpiresAt!)) {
      _showError('Mã OTP đã hết hạn. Vui lòng gửi mã mới.');
      return;
    }
    if (_otpController.text.trim() != _generatedOtp) {
      _showError('Mã OTP không đúng.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signIn(
        email: _emailController.text,
        password: _demoDefaultPassword,
      );

      final user = await AuthService.instance.getCurrentUserModel(
        throwOnError: true,
      );
      if (!mounted) return;

      if (user == null) {
        final uid = AuthService.instance.currentUser?.uid ?? 'unknown';
        await AuthService.instance.signOut();
        _showError(
          'Tài khoản chưa có hồ sơ phân quyền trong Firestore users/$uid.',
        );
        return;
      }

      if (user.status == UserStatus.locked ||
          user.status == UserStatus.inactive) {
        await AuthService.instance.signOut();
        _showError('Tài khoản đã bị khóa hoặc chưa hoạt động.');
        return;
      }

      _goToDashboard(user.role);
    } catch (e) {
      _showError(
        'OTP đúng nhưng không đăng nhập được. Tài khoản cần dùng mật khẩu mặc định $_demoDefaultPassword. Chi tiết: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToDashboard(UserRole role) {
    switch (role) {
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
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= AppBreakpoints.web;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text(AppStrings.otpLogin),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 0 : AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
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
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.otpLogin,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpSent
                          ? 'Nhập mã OTP gồm 6 chữ số vừa được gửi tới email.'
                          : 'Nhập email đã đăng ký để nhận mã OTP đăng nhập.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_otpSent && !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return AppStrings.fieldRequired;
                        if (!email.contains('@'))
                          return AppStrings.invalidEmail;
                        return null;
                      },
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _otpController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Mã OTP',
                          counterText: '',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        validator: (value) {
                          final otp = value?.trim() ?? '';
                          if (otp.isEmpty) return AppStrings.fieldRequired;
                          if (otp.length != 6) return 'OTP gồm 6 chữ số';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: _otpSent ? 'Đăng nhập' : 'Gửi mã OTP',
                      onPressed: _otpSent ? _verifyOtp : _requestOtp,
                      isLoading: _isLoading,
                      width: double.infinity,
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                _otpController.clear();
                                _requestOtp();
                              },
                        child: const Text('Gửi lại mã OTP'),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _otpSent = false;
                                  _generatedOtp = null;
                                  _otpExpiresAt = null;
                                  _otpController.clear();
                                });
                              },
                        child: const Text('Đổi email'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
