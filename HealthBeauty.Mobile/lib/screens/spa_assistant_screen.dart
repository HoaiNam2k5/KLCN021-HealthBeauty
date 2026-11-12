import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../providers/catalog_provider.dart';
import 'booking_screen.dart';
import 'service_packages_screen.dart';

class _ChatMessage {
  const _ChatMessage(
    this.text, {
    this.customer = false,
    this.serviceIds = const [],
    this.comboIds = const [],
    this.packageIds = const [],
  });
  final String text;
  final bool customer;
  final List<int> serviceIds;
  final List<int> comboIds;
  final List<int> packageIds;
}

class SpaAssistantScreen extends StatefulWidget {
  const SpaAssistantScreen({super.key, this.dio});
  final Dio? dio;
  @override
  State<SpaAssistantScreen> createState() => _SpaAssistantScreenState();
}

class _SpaAssistantScreenState extends State<SpaAssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      'Xin chào! Em là trợ lý của HealthBeauty. Em có thể giúp anh/chị tìm hiểu dịch vụ, giá và gói chăm sóc hiện có.',
    ),
  ];
  bool _sending = false;
  String? _error;
  String? _retryMessage;
  static const _suggestions = [
    'Tư vấn chăm sóc da khô',
    'Tư vấn dịch vụ cho da mụn',
    'Các gói chăm sóc da',
    'Tôi muốn đặt lịch làm đẹp',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send(String value, {bool retry = false}) async {
    final message = value.trim();
    if (_sending || message.isEmpty || message.length > 1000) return;
    final history = _messages.skip(1).toList();
    if (retry &&
        history.isNotEmpty &&
        history.last.customer &&
        history.last.text == message) {
      history.removeLast();
    }
    setState(() {
      _sending = true;
      _error = null;
      _retryMessage = null;
      if (!retry) _messages.add(_ChatMessage(message, customer: true));
    });
    _input.clear();
    _scrollToEnd();
    try {
      final res = await (widget.dio ?? ApiClient().dio).post(
        '/assistant/chat',
        data: {
          'message': message,
          'history': history.reversed
              .take(6)
              .toList()
              .reversed
              .map(
                (m) => {
                  'role': m.customer ? 'user' : 'assistant',
                  'text': m.text.length > 500
                      ? m.text.substring(0, 500)
                      : m.text,
                },
              )
              .toList(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      final data = res.data;
      if (data is! Map ||
          data['reply'] is! String ||
          (data['reply'] as String).trim().isEmpty ||
          data['serviceIds'] is! List) {
        throw const FormatException('Invalid response');
      }
      final ids = (data['serviceIds'] as List)
          .whereType<int>()
          .toSet()
          .take(5)
          .toList();
      final comboIds =
          (data['comboIds'] is List ? data['comboIds'] as List : const [])
              .whereType<int>()
              .toSet()
              .take(5)
              .toList();
      final packageIds =
          (data['packageIds'] is List ? data['packageIds'] as List : const [])
              .whereType<int>()
              .toSet()
              .take(5)
              .toList();
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            (data['reply'] as String).trim(),
            serviceIds: ids,
            comboIds: comboIds,
            packageIds: packageIds,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Chưa thể kết nối trợ lý. Anh/chị có thể thử lại hoặc gọi hotline.';
        _retryMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final services = catalog.services;
    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý spa')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Tin nhắn được gửi tới Gemini. Không chia sẻ thông tin cá nhân nhạy cảm; tư vấn không thay thế ý kiến y tế.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final message in _messages)
                    Align(
                      alignment: message.customer
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: message.customer
                              ? AppColors.roseContainer
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.outline.withValues(alpha: .5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.text),
                            for (final service in services.where(
                              (s) => message.serviceIds.contains(s.id),
                            )) ...[
                              const SizedBox(height: 8),
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookingScreen(initialService: service),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_month),
                                label: const Text('Đặt lịch dịch vụ này'),
                              ),
                            ],
                            for (final combo in catalog.combos.where(
                              (c) => message.comboIds.contains(c.id),
                            )) ...[
                              const SizedBox(height: 8),
                              Text(
                                combo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookingScreen(initialCombo: combo),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_month),
                                label: const Text('Đặt lịch combo này'),
                              ),
                            ],
                            if (message.packageIds.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ServicePackagesScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.card_membership),
                                label: const Text('Xem các gói dịch vụ'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_sending)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Đang chuẩn bị câu trả lời...'),
                    ),
                  if (_error != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => _send(_retryMessage!, retry: true),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (_messages.length == 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final question in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(question),
                          onPressed: _sending ? null : () => _send(question),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hỏi...',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi câu hỏi',
                    onPressed: _sending ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send_rounded, color: AppColors.rose),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
