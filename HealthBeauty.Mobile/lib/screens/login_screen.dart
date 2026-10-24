import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'auth/auth_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _otp = TextEditingController();
  String? _emailErr;
  String? _passErr;
  String? _otpErr;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().clearError();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() {
      _hasSubmitted = true;
      _emailErr = _email.text.isEmpty || !_email.text.contains('@') ? 'Email không hợp lệ' : null;
      _passErr = _pass.text.length < 8 ? 'Mật khẩu tối thiểu 8 ký tự' : null;
    });
    if (_emailErr != null || _passErr != null) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (auth.requiresTwoFactor) {
      _otp.clear();
      _otpErr = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã xác thực đăng nhập (OTP) đã được gửi đến email của bạn.'),
          backgroundColor: AppColors.ok,
        ),
      );
    } else if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Lỗi')));
    } else if (ok && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  void _submitOtp() async {
    setState(() {
      _otpErr = _otp.text.trim().length != 6 ? 'Mã xác thực gồm 6 chữ số' : null;
    });
    if (_otpErr != null) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyTwoFactor(_otp.text.trim());
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Mã xác thực không hợp lệ')));
    } else if (ok && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  void _resendOtp() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendTwoFactor();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã xác thực mới đã được gửi đến email của bạn.'),
          backgroundColor: AppColors.ok,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Không thể gửi lại mã')),
      );
    }
  }

  void _loginWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithGoogle();
    if (!mounted) return;
    if (!ok) {
      if (auth.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(auth.error!)));
      }
    } else if (ok && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    if (auth.requiresTwoFactor) {
      return AuthScaffold(
        title: 'Xác thực đăng nhập',
        subtitle: 'Nhập mã xác thực gồm 6 số đã được gửi đến ${auth.twoFactorEmail ?? _email.text.trim()}',
        onBack: () {
          auth.cancelTwoFactor();
          _otp.clear();
        },
        children: [
          if (auth.error != null) ErrorBanner(message: auth.error!),
          AuthTextField(
            controller: _otp,
            label: 'Mã xác thực (OTP gồm 6 số)',
            icon: Icons.pin_outlined,
            error: _otpErr,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _otpErr = null;
              auth.clearError();
            }),
            onSubmitted: _submitOtp,
          ),
          const SizedBox(height: 6),
          AuthButton(
            text: 'Xác nhận đăng nhập',
            loading: auth.isLoading,
            onPressed: _submitOtp,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  auth.cancelTwoFactor();
                  _otp.clear();
                },
                child: const Text('Quay lại đăng nhập'),
              ),
              TextButton(
                onPressed: auth.isLoading ? null : _resendOtp,
                child: const Text('Gửi lại mã OTP'),
              ),
            ],
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Chào mừng trở lại',
      subtitle: 'Đăng nhập để đặt lịch và nhận ưu đãi',
      onBack: Navigator.canPop(context) ? () => Navigator.pop(context, false) : null,
      children: [
        if (_hasSubmitted && auth.error != null) ErrorBanner(message: auth.error!),
        AuthTextField(
          controller: _email,
          label: 'Email',
          icon: Icons.email_outlined,
          error: _emailErr,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {
            _emailErr = null;
            _hasSubmitted = false;
            auth.clearError();
          }),
        ),
        AuthTextField(
          controller: _pass,
          label: 'Mật khẩu',
          icon: Icons.lock_outline,
          error: _passErr,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {
            _passErr = null;
            _hasSubmitted = false;
            auth.clearError();
          }),
          onSubmitted: _submit,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await Navigator.push<String?>(
                context,
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(
                    initialEmail: _email.text.trim(),
                  ),
                ),
              );
              if (!mounted) return;
              if (result != null && result.isNotEmpty) {
                _email.text = result;
                _pass.clear();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Đặt lại mật khẩu thành công. Vui lòng đăng nhập với mật khẩu mới.'),
                    backgroundColor: AppColors.ok,
                  ),
                );
              }
            },
            child: const Text('Quên mật khẩu?', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        AuthButton(
          text: 'Đăng nhập',
          loading: auth.isLoading,
          onPressed: _submit,
        ),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('hoặc', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: auth.isLoading || auth.googleLoading ? null : _loginWithGoogle,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (auth.googleLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 18)),
                const SizedBox(width: 10),
                Text(auth.googleLoading ? 'Đang đăng nhập Google...' : 'Tiếp tục với Google'),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Chưa có tài khoản?'),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
                if (context.mounted &&
                    context.read<AuthProvider>().isLoggedIn &&
                    Navigator.canPop(context)) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
