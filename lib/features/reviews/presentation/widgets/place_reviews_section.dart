import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/place_review.dart';
import '../../providers/place_reviews_provider.dart';
import '../../services/place_reviews_service.dart';
import '../screens/place_reviews_screen.dart';
import 'place_review_tile.dart';
import 'rating_stars_widget.dart';

class PlaceReviewsSection extends StatefulWidget {
  final String placeId;
  final String placeName;
  final PlaceReviewsRepository? repository;
  const PlaceReviewsSection({
    super.key,
    required this.placeId,
    required this.placeName,
    this.repository,
  });

  @override
  State<PlaceReviewsSection> createState() => _PlaceReviewsSectionState();
}

class _PlaceReviewsSectionState extends State<PlaceReviewsSection> {
  late final PlaceReviewsProvider provider;

  @override
  void initState() {
    super.initState();
    provider = PlaceReviewsProvider(
      repository: widget.repository ?? _defaultRepository(),
      placeId: widget.placeId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(provider.load());
    });
  }

  PlaceReviewsRepository _defaultRepository() {
    try {
      return SupabasePlaceReviewsService(Supabase.instance.client);
    } catch (_) {
      return const _UnavailableReviewsRepository();
    }
  }

  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {}
    final canReview =
        auth?.isAuthenticated == true &&
        auth?.isDemoSession != true &&
        auth?.isRecovering != true;
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final summary = provider.summary;
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text('Đánh giá', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (provider.isLoading && provider.reviews.isEmpty)
                const LinearProgressIndicator(
                  semanticsLabel: 'Đang tải đánh giá',
                )
              else if (provider.errorCode != null && provider.reviews.isEmpty)
                Row(
                  children: [
                    const Expanded(child: Text('Chưa tải được đánh giá.')),
                    TextButton(
                      onPressed: provider.load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    RatingStarsWidget(rating: summary.average),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary.count == 0
                            ? 'Chưa có đánh giá'
                            : '${summary.average.toStringAsFixed(1)} · ${summary.count} đánh giá',
                      ),
                    ),
                  ],
                ),
                if (provider.reviews.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final review in provider.reviews.take(2)) ...[
                    PlaceReviewTile(review: review),
                    const Divider(height: 1),
                  ],
                ],
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _writeReview(auth, canReview),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Viết đánh giá'),
                  ),
                  OutlinedButton(
                    onPressed: provider.isLoading && provider.reviews.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlaceReviewsScreen(
                                placeName: widget.placeName,
                                provider: provider,
                              ),
                            ),
                          ),
                    child: const Text('Xem tất cả đánh giá'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _writeReview(AuthProvider? auth, bool canReview) async {
    if (!canReview || auth == null) {
      final login = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Cần đăng nhập'),
          content: const Text(
            'Bạn cần đăng nhập bằng tài khoản thật để gửi đánh giá.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
      if (login == true && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      }
      return;
    }
    final epoch = auth.authEpoch;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _ReviewForm(
        placeName: widget.placeName,
        provider: provider,
        authEpoch: epoch,
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final String placeName;
  final PlaceReviewsProvider provider;
  final int authEpoch;
  const _ReviewForm({
    required this.placeName,
    required this.provider,
    required this.authEpoch,
  });

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final controller = TextEditingController();
  int rating = 0;
  String? ratingError;
  String? contentError;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = controller.text.trim();
    setState(() {
      ratingError = rating == 0 ? 'Hãy chọn từ 1 đến 5 sao.' : null;
      contentError = content.isEmpty
          ? 'Hãy nhập nội dung đánh giá.'
          : content.length > 1000
          ? 'Nội dung tối đa 1000 ký tự.'
          : null;
    });
    if (ratingError != null || contentError != null) return;
    final success = await widget.provider.submit(
      rating: rating,
      content: content,
    );
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.authEpoch != widget.authEpoch) {
      Navigator.pop(context);
      return;
    }
    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Đã gửi đánh giá.')));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đánh giá ${widget.placeName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('Số sao'),
              RatingStarsWidget(
                rating: rating.toDouble(),
                onRatingChanged: (value) => setState(() {
                  rating = value;
                  ratingError = null;
                }),
              ),
              if (ratingError != null)
                Text(
                  ratingError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('review-content'),
                controller: controller,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Nội dung đánh giá',
                  alignLabelWithHint: true,
                  errorText: contentError,
                ),
              ),
              if (widget.provider.errorCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _messageFor(widget.provider.errorCode!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.provider.isSubmitting ? null : _submit,
                  child: Text(
                    widget.provider.isSubmitting ? 'Đang gửi…' : 'Gửi đánh giá',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _messageFor(String code) => switch (code) {
    'already_reviewed' => 'Bạn đã đánh giá địa điểm này.',
    'authentication_required' => 'Phiên đăng nhập không còn hợp lệ.',
    _ => 'Chưa gửi được đánh giá. Nội dung của bạn vẫn được giữ lại.',
  };
}

class _UnavailableReviewsRepository implements PlaceReviewsRepository {
  const _UnavailableReviewsRepository();
  @override
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  }) => throw const PlaceReviewFailure('service_unavailable');

  @override
  Future<List<PlaceReview>> fetchForPlace(String placeId) =>
      throw const PlaceReviewFailure('service_unavailable');
}
