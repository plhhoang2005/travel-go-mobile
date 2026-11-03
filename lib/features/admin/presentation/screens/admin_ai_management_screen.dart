import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ai_chat/providers/ai_chat_provider.dart';
import '../../../ai_chat/services/local_ai_settings_store.dart';
import '../../../trip_planner/models/local_ai_models.dart';
import '../../../trip_planner/models/local_ai_settings.dart';
import '../../../trip_planner/services/local_ai_service.dart';

class AdminAiManagementScreen extends StatefulWidget {
  final LocalAiSettingsStore? settingsStore;
  final LocalAiService? service;
  const AdminAiManagementScreen({super.key, this.settingsStore, this.service});
  @override
  State<AdminAiManagementScreen> createState() =>
      _AdminAiManagementScreenState();
}

class _AdminAiManagementScreenState extends State<AdminAiManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _model = TextEditingController();
  final _prompt = TextEditingController();
  final _dailyQuota = TextEditingController();
  late final LocalAiSettingsStore _store;
  late final LocalAiService _service;
  double _temperature = 0.7;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _success = false;
  int _revision = 0;
  String? _status;
  CancelToken? _probeToken;

  @override
  void initState() {
    super.initState();
    _store = widget.settingsStore ?? LocalAiSettingsStore();
    _service = widget.service ?? LocalAiService(dio: Dio());
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _store.load();
      if (!mounted) return;
      _host.text = settings.baseUrl;
      _model.text = settings.modelName;
      _prompt.text = settings.systemPrompt;
      _temperature = settings.temperature;
      _dailyQuota.text = settings.dailyQuota.toString();
      _status = _store.loadWarning;
    } catch (_) {
      if (!mounted) return;
      _host.text = LocalAiSettings().baseUrl;
      _model.text = LocalAiSettings().modelName;
      _prompt.text = LocalAiSettings.defaultPrompt;
      _dailyQuota.text = LocalAiSettings().dailyQuota.toString();
      _status = 'Không đọc được cấu hình đã lưu. Hãy kiểm tra và lưu lại.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    _revision++;
    _probeToken?.cancel();
    _probeToken = null;
    setState(() {
      _testing = false;
      _status = null;
      _success = false;
    });
  }

  LocalAiSettings _settings() => LocalAiSettings(
    baseUrl: _host.text,
    modelName: _model.text,
    systemPrompt: _prompt.text,
    temperature: _temperature,
    dailyQuota: int.tryParse(_dailyQuota.text.trim()) ?? 10,
  );

  Future<void> _save() async {
    if (_saving || _testing || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _status = null;
      _success = false;
    });
    var saved = false;
    final chat = context.read<AiChatProvider?>();
    try {
      await _store.save(_settings());
      saved = true;
      await chat?.reloadAiSettings();
      if (!mounted) return;
      setState(() {
        _success = true;
        _status = 'Đã lưu cấu hình trên thiết bị. Cấu hình áp dụng cho yêu cầu tiếp theo; chưa xác nhận kết nối.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Đã lưu cấu hình, nhưng chatbot chưa nạp lại được. Hãy mở lại ứng dụng trước khi gửi.'
            : 'Không lưu được cấu hình. Nội dung đang nhập vẫn được giữ nguyên.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (_saving || _testing || !_formKey.currentState!.validate()) return;
    final revision = _revision;
    final token = CancelToken();
    _probeToken = token;
    setState(() {
      _testing = true;
      _status = null;
      _success = false;
    });
    try {
      final result = await _service.checkConnection(
        _settings(),
        cancelToken: token,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _success = true;
        _status =
            'Kết nối Ollama thành công: ${result.modelName}, ${result.elapsed.inMilliseconds} ms. Cấu hình đang thử chưa được tự động lưu.';
      });
    } on LocalAiFailure catch (failure) {
      if (mounted && revision == _revision) {
        setState(() => _status = failure.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _status = 'Không kiểm tra được Ollama. Vui lòng kiểm tra cấu hình rồi thử lại.',
        );
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() {
          _testing = false;
          _probeToken = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    _probeToken?.cancel();
    _host.dispose();
    _model.dispose();
    _prompt.dispose();
    _dailyQuota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị AI local')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cấu hình AI trên thiết bị này',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ollama chạy trên máy tính của bạn. Cấu hình này không tự đồng bộ sang thiết bị khác.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('ollama_host_field'),
                      controller: _host,
                      enabled: !_saving,
                      onChanged: (_) => _changed(),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ Ollama',
                        helperText: 'USB: http://127.0.0.1:11434\nEmulator: http://10.0.2.2:11434',
                        helperMaxLines: 4,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        try {
                          LocalAiSettings(baseUrl: value ?? '');
                          return null;
                        } on FormatException catch (e) {
                          return e.message;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ollama_model_field'),
                      controller: _model,
                      enabled: !_saving,
                      onChanged: (_) => _changed(),
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Model trên máy tính',
                        hintText: 'qwen3:4b-instruct-2507-q4_K_M',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Nhập tên model đã tải.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ollama_prompt_field'),
                      controller: _prompt,
                      enabled: !_saving,
                      onChanged: (_) => _changed(),
                      minLines: 3,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Chỉ dẫn trả lời',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Nhập chỉ dẫn cho trợ lý.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ollama_quota_field'),
                      controller: _dailyQuota,
                      enabled: !_saving,
                      onChanged: (_) => _changed(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hạn mức lượt hỏi/ngày (User)',
                        helperText: 'Số lượt hỏi tối đa mỗi ngày của tài khoản thường. Admin luôn không giới hạn.',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0 || parsed > 1000) {
                          return 'Nhập số nguyên từ 1 đến 1000.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Độ sáng tạo: ${_temperature.toStringAsFixed(1)}'),
                    Slider(
                      value: _temperature,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: _temperature.toStringAsFixed(1),
                      onChanged: _saving
                          ? null
                          : (value) {
                              _temperature = value;
                              _changed();
                            },
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _status!,
                            style: TextStyle(
                              color: _success ? colors.primary : colors.error,
                            ),
                          ),
                        ),
                      ),
                    if (_saving || _testing) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        _saving
                            ? 'Đang lưu cấu hình…'
                            : 'Đang kiểm tra model và phản hồi Ollama…',
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          onPressed: _saving || _testing ? null : _save,
                          child: const Text('Lưu cấu hình'),
                        ),
                        OutlinedButton(
                          onPressed: _saving || _testing ? null : _test,
                          child: const Text('Kiểm tra kết nối'),
                        ),
                        if (_testing)
                          TextButton(
                            onPressed: _changed,
                            child: const Text('Hủy kiểm tra'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
