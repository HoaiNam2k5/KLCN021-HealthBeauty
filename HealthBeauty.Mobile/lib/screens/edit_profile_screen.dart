import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/customer_avatar.dart';
import '../core/avatar_image.dart';

class EditProfileScreen extends StatefulWidget {
  final Customer customer;

  const EditProfileScreen({super.key, required this.customer});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  // Giới tính chỉ nhận 'Nam' hoặc 'Nữ' (không có icon)
  late String _gender;
  String? _errorMessage;
  bool _choosingAvatar = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.fullName);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');

    // Chuẩn hóa giới tính về Nam hoặc Nữ, mặc định là Nữ nếu chưa thiết lập
    final currentGender = widget.customer.gender?.trim();
    if (currentGender == 'Nam') {
      _gender = 'Nam';
    } else {
      _gender = 'Nữ';
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _recoverInterruptedSelection(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_choosingAvatar) return;
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profile = context.read<ProfileProvider>();
    final success = await profile.update(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      gender: _gender,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: AppColors.ok,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage =
            profile.error ?? 'Không thể cập nhật hồ sơ. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _recoverInterruptedSelection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final lost = await _imagePicker.retrieveLostData();
      if (mounted && !lost.isEmpty) {
        setState(
          () => _errorMessage = 'Lần chọn ảnh trước bị gián đoạn. Vui lòng chọn lại ảnh đại diện.',
        );
      }
    } catch (_) {
      // Optional recovery must not prevent editing the profile.
    }
  }

  Future<void> _pickAvatar() async {
    final profile = context.read<ProfileProvider>();
    if (_choosingAvatar || profile.saving || profile.avatarSaving) return;
    final accountId = context.read<AuthProvider>().account?.id;
    setState(() {
      _choosingAvatar = true;
      _errorMessage = null;
    });
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      if (await image.length() > maximumAvatarBytes) {
        if (mounted) {
          setState(
            () =>
                _errorMessage = 'Ảnh vượt quá 5 MB. Vui lòng chọn ảnh nhỏ hơn.',
          );
        }
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted || context.read<AuthProvider>().account?.id != accountId) {
        return;
      }
      final success = await profile.updateAvatar(bytes: bytes);
      if (!mounted) return;
      if (!success) {
        setState(
          () => _errorMessage =
              profile.error ?? 'Không cập nhật được ảnh đại diện.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện')),
        );
      }
    } on MissingPluginException {
      _showAvatarError('Bộ chọn ảnh chưa được cập nhật trong ứng dụng. Vui lòng tắt app và chạy lại bản mới.');
    } on PlatformException catch (exception) {
      _showAvatarError(switch (exception.code) {
        'channel-error' => 'Bộ chọn ảnh chưa sẵn sàng. Vui lòng tắt app và chạy lại bản mới.',
        'photo_access_denied' || 'photo_access_restricted' || 'read_external_storage_denied' =>
          'Ứng dụng chưa được phép truy cập ảnh. Vui lòng kiểm tra quyền ảnh trong Cài đặt.',
        'already_active' => 'Một cửa sổ chọn ảnh đang mở. Vui lòng hoàn tất hoặc đóng cửa sổ đó.',
        _ => 'Không mở được thư viện ảnh. Vui lòng thử lại.',
      });
    } catch (_) {
      _showAvatarError('Không mở hoặc đọc được ảnh. Vui lòng chọn lại.');
    } finally {
      if (mounted) setState(() => _choosingAvatar = false);
    }
  }

  void _showAvatarError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeAvatar() async {
    final profile = context.read<ProfileProvider>();
    if (_choosingAvatar || profile.saving || profile.avatarSaving) return;
    setState(() => _errorMessage = null);
    final success = await profile.updateAvatar(remove: true);
    if (mounted && !success) {
      setState(
        () => _errorMessage = profile.error ?? 'Không xóa được ảnh đại diện.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final email = auth.account?.email ?? '';

    final nameText = _nameController.text.trim();
    final initial = nameText.isNotEmpty ? nameText[0].toUpperCase() : '?';
    final avatarUrl = profile.customer?.avatarUrl;
    final busy = profile.saving || profile.avatarSaving || _choosingAvatar;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Avatar
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.rose.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: CustomerAvatar(
                                radius: 46,
                                url: avatarUrl,
                                initial: initial,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: busy ? null : _pickAvatar,
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                              label: const Text('Đổi ảnh đại diện'),
                            ),
                            const Text(
                              'JPG, PNG hoặc WebP · tối đa 5 MB',
                              style: TextStyle(fontSize: 12),
                            ),
                            if (avatarUrl?.isNotEmpty == true)
                              TextButton(
                                onPressed: busy ? null : _removeAvatar,
                                child: const Text('Xóa ảnh đại diện'),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              nameText.isNotEmpty
                                  ? nameText
                                  : 'Hồ sơ khách hàng',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mã khách hàng: #HB-${widget.customer.id.toString().padLeft(5, '0')}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Thông báo lỗi nếu có
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Mục Email (Chỉ đọc)
                      const Text(
                        'Email đăng nhập',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                email.isNotEmpty ? email : 'Chưa cập nhật',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: AppColors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email được dùng để định danh và nhận thông tin lịch hẹn, không thể thay đổi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mục Họ và tên
                      const Text(
                        'Họ và tên *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Nhập họ và tên đầy đủ',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.rose,
                              width: 1.6,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          if (v.length < 2) {
                            return 'Họ tên quá ngắn';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      // Mục Số điện thoại
                      const Text(
                        'Số điện thoại',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: 0912345678',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.rose,
                              width: 1.6,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isNotEmpty) {
                            if (!RegExp(r'^0[3|5|7|8|9][0-9]{8}$')
                                .hasMatch(v)) {
                              return 'Số điện thoại không đúng định dạng (10 số, bắt đầu bằng 0)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Mục Giới tính (Chỉ Nam hoặc Nữ, không dùng icon)
                      const Text(
                        'Giới tính',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderOption(
                              label: 'Nữ',
                              selected: _gender == 'Nữ',
                              onTap: () {
                                setState(() => _gender = 'Nữ');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GenderOption(
                              label: 'Nam',
                              selected: _gender == 'Nam',
                              onTap: () {
                                setState(() => _gender = 'Nam');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Nút Lưu thay đổi cố định dưới cùng
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : _handleSave,
                  child: profile.saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ lựa chọn giới tính (Chỉ hiển thị chữ Nam hoặc Nữ, không icon)
class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.roseContainer.withValues(alpha: 0.35)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.outline,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.onRoseContainer : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
