import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_error.dart';
import '../core/invoice_navigation.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../widgets/common.dart';
import 'invoice_detail_screen.dart';
import 'invoices_screen.dart';

class InvoiceNotificationScreen extends StatefulWidget {
  const InvoiceNotificationScreen({super.key, required this.target});
  final InvoiceNotificationTarget target;

  @override
  State<InvoiceNotificationScreen> createState() =>
      _InvoiceNotificationScreenState();
}

class _InvoiceNotificationScreenState extends State<InvoiceNotificationScreen> {
  int? _invoiceId, _accountVersion;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.target.invoiceId == null &&
        widget.target.appointmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    final provider = context.read<InvoiceProvider>();
    _accountVersion ??= provider.accountVersion;
    if (!context.read<AuthProvider>().isLoggedIn ||
        _accountVersion != provider.accountVersion) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoice = await provider.findForAppointment(
        widget.target.appointmentId!,
      );
      if (!mounted || _accountVersion != provider.accountVersion) return;
      setState(() {
        _invoiceId = invoice?.id;
        _error = invoice == null
            ? 'Chưa tìm thấy hóa đơn của lịch hẹn. Vui lòng thử lại.'
            : null;
      });
    } on DioException catch (e) {
      if (mounted && _accountVersion == provider.accountVersion) {
        setState(() => _error = ApiError.message(e));
      }
    } catch (_) {
      if (mounted && _accountVersion == provider.accountVersion) {
        setState(() => _error = 'Không mở được hóa đơn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && _accountVersion == provider.accountVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final auth = context.watch<AuthProvider>();
    final target = widget.target;
    if (target.invoiceId != null) {
      return InvoiceDetailScreen(invoiceId: target.invoiceId!);
    }
    if (target.appointmentId == null) return const InvoicesScreen();
    if (!auth.isLoggedIn ||
        (_accountVersion != null &&
            _accountVersion != provider.accountVersion)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hóa đơn')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại hóa đơn.',
        ),
      );
    }
    if (_invoiceId != null) return InvoiceDetailScreen(invoiceId: _invoiceId!);
    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ErrorState(
              message: _error ?? 'Không tìm thấy hóa đơn.',
              onRetry: _resolve,
            ),
    );
  }
}
