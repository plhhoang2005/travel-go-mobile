import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'travel_media.dart';

class TravelImage extends StatelessWidget {
  final TravelMediaReference? media;
  final String semanticLabel;
  final double height;
  const TravelImage({
    super.key,
    required this.media,
    required this.semanticLabel,
    required this.height,
  }) : assert(height > 0);

  @override
  Widget build(BuildContext context) {
    final reference = media;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Semantics(
              image: true,
              label: semanticLabel,
              child: ExcludeSemantics(
                child: reference == null
                    ? const _PhotoState(label: 'Chưa có ảnh phù hợp')
                    : Image.network(
                        reference.imageUrl,
                        headers: const {
                          kIsWeb ? 'Api-User-Agent' : 'User-Agent': 'TravelGO/1.0 (https://github.com/plhhoang2005/travel-go-mobile)',
                        },
                        fit: BoxFit.cover,
                        frameBuilder: (_, child, frame, synchronous) =>
                            synchronous || frame != null
                            ? child
                            : const _PhotoState(label: 'Đang tải ảnh'),
                        errorBuilder: (_, error, trace) {
                          assert(() {
                            debugPrint('travel.image load_failed: $error');
                            return true;
                          }());
                          return const _PhotoState(label: 'Ảnh chưa tải được');
                        },
                      ),
              ),
            ),
          ),
          if (reference != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Nguồn ảnh',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => _showSource(context, reference),
                  icon: const Icon(Icons.info_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSource(BuildContext context, TravelMediaReference reference) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nguồn ảnh', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(reference.caption),
            const SizedBox(height: 8),
            Text('Ảnh: ${reference.author}'),
            const SizedBox(height: 8),
            Text('Giấy phép: ${reference.license}'),
            const SizedBox(height: 8),
            SelectableText(reference.sourceUrl),
            if (reference.declaredPermission != null) ...[
              const SizedBox(height: 8),
              Text('Quyền công bố: ${reference.declaredPermission}'),
            ],
            if (reference.licenseUrl != null && reference.licenseUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(reference.licenseUrl!),
            ],
            const SizedBox(height: 16),
            const Text('Ảnh được cắt để vừa khung hiển thị.'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoState extends StatelessWidget {
  final String label;
  const _PhotoState({required this.label});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ),
  );
}
