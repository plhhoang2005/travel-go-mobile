import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/catalogue_map_marker.dart';

class PlaceMapPreviewCard extends StatelessWidget {
  final CatalogueMapMarker marker;
  final VoidCallback? onDetailsPressed;
  final VoidCallback? onClosePressed;
  final bool isAdmin;
  final bool isPlaceHidden;
  final VoidCallback? onAdminToggleHide;

  const PlaceMapPreviewCard({
    super.key,
    required this.marker,
    this.onDetailsPressed,
    this.onClosePressed,
    this.isAdmin = false,
    this.isPlaceHidden = false,
    this.onAdminToggleHide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: marker.isTopRated
              ? Colors.amber.shade300
              : AppTheme.border.withValues(alpha: 0.8),
          width: marker.isTopRated ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon, Title, Subtitle, Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: marker.markerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      marker.iconData,
                      color: marker.markerColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (marker.subtitle != null && marker.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          marker.subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onClosePressed != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.slate400),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onClosePressed,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Badges & Action CTA Button
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (marker.type == MarkerType.place) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                              const SizedBox(width: 3),
                              Text(
                                marker.averageRating > 0
                                    ? marker.averageRating.toStringAsFixed(1)
                                    : 'Mới',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              if (marker.reviewCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${marker.reviewCount} đánh giá)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (marker.isTopRated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: const Text(
                              '⭐ Nổi Bật',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ] else if (marker.type == MarkerType.destination) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Điểm đến du lịch',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Lãnh thổ Việt Nam',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onDetailsPressed,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: Text(
                    marker.type == MarkerType.destination ? 'Xem các điểm' : 'Xem chi tiết',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: marker.isTopRated ? const Color(0xFFD97706) : AppTheme.tealPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            if (isAdmin && marker.type == MarkerType.place) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.6)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlaceHidden
                      ? Colors.red.withValues(alpha: 0.06)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPlaceHidden
                        ? Colors.red.shade200
                        : AppTheme.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPlaceHidden
                          ? Icons.visibility_off_rounded
                          : Icons.admin_panel_settings_outlined,
                      size: 16,
                      color: isPlaceHidden
                          ? Colors.red.shade700
                          : AppTheme.tealPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPlaceHidden
                                ? 'Đang ẩn với khách'
                                : 'Quản trị địa điểm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPlaceHidden
                                  ? Colors.red.shade800
                                  : AppTheme.slate800,
                            ),
                          ),
                          Text(
                            isPlaceHidden
                                ? 'Khách không nhìn thấy trên bản đồ'
                                : 'Đang hiển thị công khai',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      key: const ValueKey('admin-toggle-place-visibility-btn'),
                      onPressed: onAdminToggleHide,
                      icon: Icon(
                        isPlaceHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 15,
                      ),
                      label: Text(
                        isPlaceHidden ? 'Hiện lại' : 'Ẩn địa điểm',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isPlaceHidden
                            ? AppTheme.tealPrimary
                            : Colors.deepOrange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
