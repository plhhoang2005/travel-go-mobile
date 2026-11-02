import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/local_ai_models.dart';
import '../../services/local_ai_service.dart';

class LocalAiSearchTab extends StatefulWidget {
  final LocalAiService service;
  final List<Map<String, dynamic>> localCataloguePlaces;

  const LocalAiSearchTab({
    super.key,
    required this.service,
    this.localCataloguePlaces = const [],
  });

  @override
  State<LocalAiSearchTab> createState() => _LocalAiSearchTabState();
}

class _LocalAiSearchTabState extends State<LocalAiSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  PlaceInfoResult? _result;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    final res = await widget.service.searchPlaceInfoHybrid(
      query,
      localCataloguePlaces: widget.localCataloguePlaces,
    );

    if (mounted) {
      setState(() {
        _result = res;
        _isSearching = false;
      });
    }
  }

  Future<void> _openSourceUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên địa danh cần tra cứu...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _performSearch,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tra cứu'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_result != null) ...[
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _result!.placeName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_result!.isFromWeb)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.language_rounded, size: 14, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Từ Internet',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'CSDL Đã Kiểm Duyệt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _result!.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.payments_outlined,
                      'Giá vé tham khảo',
                      _result!.priceInfo,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.schedule_outlined,
                      'Giờ mở cửa',
                      _result!.openingHours,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.lightbulb_outline_rounded,
                      'Mẹo du lịch',
                      _result!.tips,
                    ),
                    if (_result!.isFromWeb && _result!.sourceUrl != null) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _openSourceUrl(_result!.sourceUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Xem bài viết nguồn trích dẫn'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.travel_explore_rounded, size: 56, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Tra cứu thông tin bất kỳ địa điểm du lịch nào',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ưu tiên CSDL nội bộ • Tự động tìm kiếm Internet nếu chưa có',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: content),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
