import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import 'auth/auth_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  int _step = 0; // 0: nhập email, 1: nhập OTP và mật khẩu mới
  String? _emailErr;
  String? _otpErr;
  String? _passErr;
  String? _confirmPassErr;
  String? _serverError;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _email.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _otp.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  void _sendOtp({bool isResend = false}) async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading || _resendSeconds > 0) return;
    final emailText = _email.text.trim();
    if (emailText.isEmpty || !emailText.contains('@')) {
      setState(() => _emailErr = 'Vui lòng nhập email hợp lệ');
      return;
    }

    setState(() {
      _emailErr = null;
      _serverError = null;
    });

    final data = await auth.forgotPassword(emailText);

    if (!mounted) return;

    if (data != null) {
      setState(() {
        _step = 1;
        _otp.clear();
        _resendSeconds = 60;
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _resendSeconds--);
        if (_resendSeconds <= 0) timer.cancel();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message']?.toString() ?? 'Mã xác thực đã được gửi đến email.',
          ),
          backgroundColor: AppColors.ok,
        ),
      );
    } else {
      setState(() {
        _serverError =
            auth.error ?? 'Không thể gửi mã xác thực. Vui lòng thử lại.';
      });
    }
  }

  void _submitReset() async {
    if (context.read<AuthProvider>().isLoading) return;
    setState(() {
      _otpErr = !RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())
          ? 'Mã xác thực gồm 6 chữ số'
          : null;
      _passErr =
          _newPass.text.trim().isEmpty ||
              _newPass.text.length < 8 ||
              _newPass.text.length > 128
          ? 'Mật khẩu từ 8 đến 128 ký tự, không chỉ gồm khoảng trắng'
          : null;
      _confirmPassErr = _newPass.text != _confirmPass.text
          ? 'Mật khẩu xác nhận không khớp'
          : null;
      _serverError = null;
    });

    if (_otpErr != null || _passErr != null || _confirmPassErr != null) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(
      email: _email.text.trim(),
      otp: _otp.text.trim(),
      newPassword: _newPass.text,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, _email.text.trim());
    } else {
      setState(() {
        _serverError =
            auth.error ?? 'Đặt lại mật khẩu thất bại. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: _step == 0 ? 'Quên mật khẩu' : 'Đặt lại mật khẩu',
      subtitle: _step == 0
          ? 'Nhập email đã đăng ký để nhận mã xác thực đặt lại mật khẩu'
          : 'Nhập mã xác thực (OTP) và mật khẩu mới cho ${_email.text.trim()}',
      onBack: () {
        if (auth.isLoading) return;
        if (_step == 1) {
          setState(() {
            _step = 0;
            _serverError = null;
          });
        } else {
          Navigator.pop(context);
        }
      },
      children: [
        if (_serverError != null) ErrorBanner(message: _serverError!),
        if (_step == 0) ...[
          AuthTextField(
            controller: _email,
            label: 'Email',
            icon: Icons.email_outlined,
            error: _emailErr,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _emailErr = null;
              _serverError = null;
            }),
            onSubmitted: () => _sendOtp(),
          ),
          const SizedBox(height: 6),
          AuthButton(
            text: _resendSeconds > 0
                ? 'Gửi lại sau ${_resendSeconds}s'
                : 'Gửi mã xác nhận',
            loading: auth.isLoading,
            onPressed: () => _sendOtp(),
          ),
        ] else ...[
          AuthTextField(
            controller: _otp,
            label: 'Mã xác nhận (OTP gồm 6 số)',
            icon: Icons.pin_outlined,
            error: _otpErr,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {
              _otpErr = null;
              _serverError = null;
            }),
          ),

          AuthTextField(
            controller: _newPass,
            label: 'Mật khẩu mới',
            icon: Icons.lock_outline,
            error: _passErr,
            isPassword: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {
              _passErr = null;
              _serverError = null;
            }),
          ),
          AuthTextField(
            controller: _confirmPass,
            label: 'Xác nhận mật khẩu mới',
            icon: Icons.lock_reset_outlined,
            error: _confirmPassErr,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _confirmPassErr = null;
              _serverError = null;
            }),
            onSubmitted: _submitReset,
          ),
          const SizedBox(height: 6),
          AuthButton(
            text: 'Xác nhận đặt lại mật khẩu',
            loading: auth.isLoading,
            onPressed: _submitReset,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () => setState(() {
                        _step = 0;
                        _serverError = null;
                      }),
                child: const Text('Đổi email khác'),
              ),
              TextButton(
                onPressed: auth.isLoading || _resendSeconds > 0
                    ? null
                    : () => _sendOtp(isResend: true),
                child: Text(
                  _resendSeconds > 0
                      ? 'Gửi lại (${_resendSeconds}s)'
                      : 'Gửi lại mã OTP',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
