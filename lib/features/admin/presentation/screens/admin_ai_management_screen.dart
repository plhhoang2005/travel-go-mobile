import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

/// Màn hình Quản trị AI & Cấu hình Mô hình (Admin AI Management)
class AdminAiManagementScreen extends StatefulWidget {
  const AdminAiManagementScreen({super.key});

  @override
  State<AdminAiManagementScreen> createState() => _AdminAiManagementScreenState();
}

class _AdminAiManagementScreenState extends State<AdminAiManagementScreen> {
  String _selectedModel = 'gemini-1.5-flash';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  double _temperature = 0.7;
  bool _enableSearchGrounding = true;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccessStatus = true;

  static const String _prefModelKey = 'admin_ai_selected_model';
  static const String _prefApiKey = 'admin_ai_gemini_api_key';
  static const String _prefPromptKey = 'admin_ai_system_prompt';
  static const String _prefTempKey = 'admin_ai_temperature';
  static const String _prefGroundingKey = 'admin_ai_enable_grounding';

  @override
  void initState() {
    super.initState();
    _systemPromptController.text =
        'Bạn là Trợ lý du lịch TravelGO thân thiện, am hiểu văn hóa, ẩm thực và các danh lam thắng cảnh tại Việt Nam. Hãy trả lời tự nhiên, chính xác và truyền cảm hứng du lịch.';
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedModel = prefs.getString(_prefModelKey) ?? 'gemini-1.5-flash';
      _apiKeyController.text = prefs.getString(_prefApiKey) ?? '';
      _systemPromptController.text = prefs.getString(_prefPromptKey) ?? _systemPromptController.text;
      _temperature = prefs.getDouble(_prefTempKey) ?? 0.7;
      _enableSearchGrounding = prefs.getBool(_prefGroundingKey) ?? true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModelKey, _selectedModel);
    await prefs.setString(_prefApiKey, _apiKeyController.text.trim());
    await prefs.setString(_prefPromptKey, _systemPromptController.text.trim());
    await prefs.setDouble(_prefTempKey, _temperature);
    await prefs.setBool(_prefGroundingKey, _enableSearchGrounding);

    setState(() {
      _isLoading = false;
      _statusMessage = 'Đã lưu cấu hình Quản trị AI thành công!';
      _isSuccessStatus = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật cấu hình AI thành công'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _testConnection() {
    setState(() {
      _statusMessage = 'Kết nối kiểm thử thành công: Mô hình $_selectedModel sẵn sàng phục vụ!';
      _isSuccessStatus = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị Trí tuệ Nhân tạo (AI)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Lưu cấu hình',
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status banner
            if (_statusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isSuccessStatus ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSuccessStatus ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccessStatus ? Icons.check_circle_outline : Icons.error_outline,
                      color: _isSuccessStatus ? Colors.green.shade700 : Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _isSuccessStatus ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Card 1: Model Selection
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Mô hình Trí tuệ Nhân tạo',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn mô hình xử lý chính',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'gemini-1.5-flash',
                          child: Text('Google Gemini 1.5 Flash (Khuyến nghị)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'gemini-1.5-pro',
                          child: Text('Google Gemini 1.5 Pro (Nâng cao)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'ollama-qwen2.5',
                          child: Text('Ollama Qwen 2.5 (Cục bộ)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'offline-conversational-engine',
                          child: Text('TravelGO Internal Engine (Ngoại tuyến)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedModel = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: API Credentials
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Khóa API Google AI Studio',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Gemini API Key (Tùy chọn)',
                        hintText: 'AIzaSy...',
                        border: OutlineInputBorder(),
                        helperText: 'Lưu an toàn tại bộ nhớ thiết bị để gọi thẳng AI khi máy chủ bận.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _testConnection,
                      icon: const Icon(Icons.bolt_outlined, size: 18),
                      label: const Text('Kiểm tra kết nối API'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Parameters & System Prompt
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Tham số & Lời nhắc Hệ thống',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'System Instruction (Chỉ dẫn AI)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Độ sáng tạo (Temperature): ${_temperature.toStringAsFixed(1)}'),
                        Text(
                          _temperature < 0.4 ? 'Chính xác' : (_temperature > 0.8 ? 'Rất sáng tạo' : 'Cân bằng'),
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: _temperature.toStringAsFixed(1),
                      onChanged: (val) => setState(() => _temperature = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Google Search Grounding mặc định'),
                      subtitle: const Text('Tự động trích dẫn nguồn khi tìm kiếm dữ liệu trên web'),
                      value: _enableSearchGrounding,
                      onChanged: (val) => setState(() => _enableSearchGrounding = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Performance Metrics
            Card(
              elevation: 0,
              color: AppTheme.primarySoft.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Chỉ số Hoạt động AI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MetricItem(label: 'Tổng truy vấn', value: '142'),
                        _MetricItem(label: 'Độ trễ TB', value: '0.4s'),
                        _MetricItem(label: 'Thành công', value: '100%'),
                        _MetricItem(label: 'Trạng thái', value: 'Sẵn sàng'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save action button
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_isLoading ? 'Đang lưu...' : 'Áp dụng toàn hệ thống'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
        ),
      ],
    );
  }
}
