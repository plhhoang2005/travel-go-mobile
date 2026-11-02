import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/local_ai_models.dart';
import '../../services/local_ai_service.dart';
import '../widgets/local_ai_chat_tab.dart';
import '../widgets/local_ai_search_tab.dart';
import '../widgets/local_ai_recommend_tab.dart';

/// Màn hình Trung tâm Trợ lý AI Du lịch 3-in-1
/// - Tab 1: Trò chuyện hỏi đáp tự do (Ollama local AI)
/// - Tab 2: Tra cứu thông tin Hybrid RAG (CSDL + Tìm kiếm Internet)
/// - Tab 3: Gợi ý địa điểm thông minh dựa trên đánh giá thực tế >= 4.5 sao
class LocalAiAssistantScreen extends StatefulWidget {
  final LocalAiService? service;
  final List<Map<String, dynamic>> localCataloguePlaces;
  final List<Map<String, dynamic>> ratedPlaces;

  const LocalAiAssistantScreen({
    super.key,
    this.service,
    this.localCataloguePlaces = const [],
    this.ratedPlaces = const [],
  });

  @override
  State<LocalAiAssistantScreen> createState() => _LocalAiAssistantScreenState();
}

class _LocalAiAssistantScreenState extends State<LocalAiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final LocalAiService _service;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LocalAiService(dio: Dio());
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trợ Lý AI TravelGO',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Hỏi đáp du lịch, tra cứu thông tin & gợi ý thông minh',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Trò Chuyện 💬'),
            Tab(text: 'Tra Cứu 🔍'),
            Tab(text: 'Gợi Ý 💡'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LocalAiChatTab(service: _service),
          LocalAiSearchTab(
            service: _service,
            localCataloguePlaces: widget.localCataloguePlaces,
          ),
          LocalAiRecommendTab(
            service: _service,
            ratedPlaces: widget.ratedPlaces,
          ),
        ],
      ),
    );
  }
}
