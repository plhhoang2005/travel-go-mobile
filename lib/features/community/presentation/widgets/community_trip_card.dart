import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/community_trip.dart';

/// Thẻ hiển thị tóm tắt chuyến đi công khai trong Bảng tin Cộng đồng (Community Feed).
/// Bao gồm: Ảnh đại diện điểm đến, Tiêu đề, Điểm đến, Thời lượng, Dự toán chi phí,
/// Tác giả, Điểm đánh giá ⭐ và Thống kê lượt thích ❤️.
class CommunityTripCard extends StatefulWidget {
  final CommunityTrip trip;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onPrint;
  final bool isLiked;

  const CommunityTripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onLike,
    this.onPrint,
    this.isLiked = false,
  });

  static TravelMediaReference? resolveDestinationMedia(String destination) {
    final clean = destination.trim().toLowerCase();
    if (clean.contains('đà nẵng') || clean.contains('da nang') || clean.contains('da-nang')) {
      return TravelMediaCatalog.forDestination('da-nang');
    }
    if (clean.contains('hà nội') || clean.contains('ha noi') || clean.contains('ha-noi')) {
      return TravelMediaCatalog.forDestination('ha-noi');
    }
    if (clean.contains('hạ long') || clean.contains('ha long') || clean.contains('ha-long')) {
      return TravelMediaCatalog.forDestination('ha-long');
    }
    if (clean.contains('sa pa') || clean.contains('sapa') || clean.contains('sa-pa')) {
      return TravelMediaCatalog.forDestination('sa-pa');
    }
    if (clean.contains('ninh bình') || clean.contains('ninh binh') || clean.contains('ninh-binh')) {
      return TravelMediaCatalog.forDestination('ninh-binh');
    }
    if (clean.contains('huế') || clean.contains('hue')) {
      return TravelMediaCatalog.forDestination('hue');
    }
    if (clean.contains('hội an') || clean.contains('hoi an') || clean.contains('hoi-an')) {
      return TravelMediaCatalog.forDestination('hoi-an');
    }
    if (clean.contains('nha trang') || clean.contains('nha-trang')) {
      return TravelMediaCatalog.forDestination('nha-trang');
    }
    if (clean.contains('đà lạt') || clean.contains('da lat') || clean.contains('da-lat')) {
      return TravelMediaCatalog.forDestination('da-lat');
    }
    if (clean.contains('hồ chí minh') || clean.contains('sài gòn') || clean.contains('ho chi minh') || clean.contains('ho-chi-minh')) {
      return TravelMediaCatalog.forDestination('ho-chi-minh');
    }
    if (clean.contains('phú quốc') || clean.contains('phu quoc') || clean.contains('phu-quoc')) {
      return TravelMediaCatalog.forDestination('phu-quoc');
    }
    if (clean.contains('cần thơ') || clean.contains('can tho') || clean.contains('can-tho')) {
      return TravelMediaCatalog.forDestination('can-tho');
    }
    return TravelMediaCatalog.forDestination(destination);
  }

  @override
  State<CommunityTripCard> createState() => _CommunityTripCardState();
}

class _CommunityTripCardState extends State<CommunityTripCard> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.isLiked;
    _likeCount = widget.trip.likeCount;
  }

  @override
  void didUpdateWidget(CommunityTripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) {
      _liked = widget.isLiked;
    }
    if (oldWidget.trip.likeCount != widget.trip.likeCount) {
      _likeCount = widget.trip.likeCount;
    }
  }

  void _handleLikeToggle() {
    setState(() {
      _liked = !_liked;
      _likeCount = _liked ? _likeCount + 1 : (_likeCount > 0 ? _likeCount - 1 : 0);
    });
    if (widget.onLike != null) {
      widget.onLike!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_liked ? 'Đã thích chuyến đi!' : 'Đã bỏ thích chuyến đi.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _handlePrint() {
    if (widget.onPrint != null) {
      widget.onPrint!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chuẩn bị in lịch trình: ${widget.trip.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final trip = widget.trip;
    final destination = trip.destination.trim().isNotEmpty
        ? trip.destination.trim()
        : 'Việt Nam';

    final days = trip.daysCount ?? 1;
    final budget = trip.estimatedCostVnd?.toInt();
    final author = trip.authorName?.trim().isNotEmpty == true
        ? trip.authorName!.trim()
        : 'Thành viên TravelGO';

    final ratingText = trip.averageRating > 0
        ? trip.averageRating.toStringAsFixed(1)
        : 'Mới';

    final media = CommunityTripCard.resolveDestinationMedia(destination);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ảnh đại diện điểm đến (nếu có trong Media Catalog)
            if (media != null)
              TravelImage(
                media: media,
                semanticLabel: media.caption,
                height: 140,
              )
            else
              Container(
                height: 80,
                color: AppTheme.primarySoft,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      destination,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng trên: Chip Điểm đến + Đánh giá sao ⭐
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.ratingBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ratingText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ratingText,
                              ),
                            ),
                            if (trip.reviewCount > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                '(${trip.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.ratingText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tiêu đề chuyến đi
                  Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tác giả chuyến đi
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppTheme.slate200,
                        child: Text(
                          author.isNotEmpty ? author[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bởi $author',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.slate100),

                  // Hàng dưới: Thời lượng, Dự toán ngân sách & Lượt thích (read-only stats)
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppTheme.slate500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$days ngày',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wallet_outlined,
                              size: 14,
                              color: AppTheme.slate500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                budget != null
                                    ? currencyFmt.format(budget)
                                    : 'Chưa có dự toán',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slate800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nút In (Print Icon Button)
                      IconButton(
                        onPressed: _handlePrint,
                        icon: const Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: AppTheme.slate600,
                        ),
                        tooltip: 'In lịch trình',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      // Biểu tượng Thả tim tương tác (Interactive Like Button)
                      InkWell(
                        onTap: _handleLikeToggle,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (_liked || _likeCount > 0)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 16,
                                color: (_liked || _likeCount > 0)
                                    ? const Color(0xFFEF4444)
                                    : AppTheme.slate500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (_liked || _likeCount > 0)
                                      ? const Color(0xFFEF4444)
                                      : AppTheme.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
