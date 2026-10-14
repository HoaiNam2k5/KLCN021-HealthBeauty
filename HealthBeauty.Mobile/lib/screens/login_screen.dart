import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
  String? _emailErr;
  String? _passErr;

  void _submit() async {
    setState(() {
      _emailErr = _email.text.isEmpty || !_email.text.contains('@') ? 'Email không hợp lệ' : null;
      _passErr = _pass.text.length < 8 ? 'Mật khẩu tối thiểu 8 ký tự' : null;
    });
    if (_emailErr != null || _passErr != null) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text.trim(), _pass.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Lỗi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Chào mừng trở lại',
      subtitle: 'Đăng nhập để đặt lịch và nhận ưu đãi',
      children: [
        if (auth.error != null) ErrorBanner(message: auth.error!),
        AuthTextField(
          controller: _email,
          label: 'Email',
          icon: Icons.email_outlined,
          error: _emailErr,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() { _emailErr = null; auth.clearError(); }),
        ),
        AuthTextField(
          controller: _pass,
          label: 'Mật khẩu',
          icon: Icons.lock_outline,
          error: _passErr,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() { _passErr = null; auth.clearError(); }),
          onSubmitted: _submit,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () { /* TODO Forgot Password */ },
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đăng nhập Google sẽ được bổ sung khi tích hợp OAuth2.'))
              );
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 18)),
                const SizedBox(width: 10),
                const Text('Tiếp tục với Google'),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Chưa có tài khoản?'),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
