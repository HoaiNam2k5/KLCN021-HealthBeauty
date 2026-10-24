import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/auth_components.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;

  final Map<String, String> _errors = {};

  void _clear(String key) {
    setState(() {
      _errors.remove(key);
    });
    context.read<AuthProvider>().clearError();
  }

  void _submit() async {
    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Bắt buộc nhập họ tên';
      if (_phone.text.trim().isEmpty) _errors['phone'] = 'Bắt buộc nhập số điện thoại';
      if (_email.text.trim().isEmpty || !_email.text.contains('@')) _errors['email'] = 'Email không hợp lệ';
      if (_pass.text.length < 8) _errors['pw'] = 'Mật khẩu phải từ 8 ký tự trở lên';
      if (_pass.text != _confirm.text) _errors['confirm'] = 'Mật khẩu không khớp';
      if (!_agreed) _errors['terms'] = 'Bạn cần đồng ý với điều khoản để tiếp tục';
    });

    if (_errors.isNotEmpty) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _name.text.trim(),
      _email.text.trim(),
      _phone.text.trim(),
      _pass.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Lỗi')));
    } else if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  int _strength(String pw) {
    if (pw.isEmpty) return 0;
    if (pw.length < 8) return 1;
    if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[0-9]').hasMatch(pw)) return 3;
    return 2;
  }

  Widget _buildPasswordStrength(String pw) {
    final s = _strength(pw);
    final labels = ['Quá yếu', 'Yếu', 'Trung bình', 'Mạnh'];
    final colors = [
      const Color(0xFFD64545),
      const Color(0xFFD64545),
      const Color(0xFFE9A23B),
      const Color(0xFF4CAF7D),
    ];
    final c = colors[s];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (s / 3).clamp(0.08, 1.0),
          color: c,
          backgroundColor: c.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 4),
        Text(
          'Độ mạnh mật khẩu: ${labels[s]}',
          style: TextStyle(fontSize: 12, color: c),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Tạo tài khoản',
      subtitle: 'Chỉ mất một phút để bắt đầu làm đẹp cùng Health Beauty',
      onBack: () => Navigator.pop(context),
      children: [
        if (auth.error != null) ErrorBanner(message: auth.error!),
        AuthTextField(
          controller: _name,
          label: 'Họ và tên',
          icon: Icons.person_outline,
          error: _errors['name'],
          onChanged: (_) => _clear('name'),
        ),
        AuthTextField(
          controller: _phone,
          label: 'Số điện thoại',
          icon: Icons.phone_outlined,
          error: _errors['phone'],
          keyboardType: TextInputType.phone,
          onChanged: (_) => _clear('phone'),
        ),
        AuthTextField(
          controller: _email,
          label: 'Email',
          icon: Icons.email_outlined,
          error: _errors['email'],
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _clear('email'),
        ),
        AuthTextField(
          controller: _pass,
          label: 'Mật khẩu',
          icon: Icons.lock_outline,
          error: _errors['pw'],
          isPassword: true,
          onChanged: (v) {
            _clear('pw');
            setState(() {});
          },
        ),
        if (_pass.text.isNotEmpty) _buildPasswordStrength(_pass.text),
        AuthTextField(
          controller: _confirm,
          label: 'Nhập lại mật khẩu',
          icon: Icons.lock_outline,
          error: _errors['confirm'],
          isPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clear('confirm'),
          onSubmitted: _submit,
        ),
        Row(
          children: [
            Checkbox(
              value: _agreed,
              onChanged: (v) {
                setState(() => _agreed = v ?? false);
                _clear('terms');
              },
            ),
            Expanded(
              child: Text(
                'Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật',
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
            ),
          ],
        ),
        if (_errors['terms'] != null)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4),
            child: Text(
              _errors['terms']!,
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ),
        AuthButton(
          text: 'Đăng ký',
          loading: auth.isLoading,
          onPressed: _submit,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Đã có tài khoản?'),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
