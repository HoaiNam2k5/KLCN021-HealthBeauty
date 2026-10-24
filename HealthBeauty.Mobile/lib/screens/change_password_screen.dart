import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/password_change.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final validation = validatePasswordChange(_current.text, _next.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (success) {
      _current.clear();
      _next.clear();
      _confirm.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(
        () =>
            _error = auth.error ?? 'Không đổi được mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Nhập mật khẩu hiện tại và mật khẩu mới. Sau khi đổi, bạn cần đăng nhập lại trên các thiết bị.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                enabled: !auth.isLoading,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Vui lòng nhập mật khẩu hiện tại'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                enabled: !auth.isLoading,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: 'Từ 8 đến 128 ký tự',
                ),
                validator: (value) =>
                    value == null || value.length < 8 || value.length > 128
                    ? 'Mật khẩu mới phải từ 8 đến 128 ký tự'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                enabled: !auth.isLoading,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu mới',
                ),
                validator: (value) =>
                    value != _next.text ? 'Mật khẩu xác nhận không khớp' : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hiện mật khẩu'),
                value: !_obscure,
                onChanged: auth.isLoading
                    ? null
                    : (value) => setState(() => _obscure = !(value ?? false)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: auth.isLoading ? null : _save,
                child: auth.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Đổi mật khẩu'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nếu đăng nhập bằng Google và chưa biết mật khẩu, hãy dùng “Quên mật khẩu” tại màn hình đăng nhập để đặt mật khẩu trước.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
