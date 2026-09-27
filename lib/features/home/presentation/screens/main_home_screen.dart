import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../favorites/models/favorite_item_model.dart';
import '../../../favorites/presentation/widgets/guest_login_bottom_sheet.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../providers/home_catalog_provider.dart';
import '../../../map/presentation/screens/trip_map_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  static const String photoDaNang =
      'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=900&q=85';
  static const String photoResort =
      'https://images.unsplash.com/photo-1549294413-26f195200c16?auto=format&fit=crop&w=900&q=85';
  static const String photoHoiAn =
      'https://images.unsplash.com/photo-1618165220283-e85246c4171c?auto=format&fit=crop&w=900&q=85';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isGuest = auth.isGuest || user == null;
    final displayName = isGuest ? 'Quý khách' : user.fullName.split(' ').last;
    final catalog = context.watch<HomeCatalogProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Curving Gradient Header (Direct from Figma Prototype)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF034B46),
                    Color(0xFF086C61),
                    Color(0xFF198879),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 16,
                18,
                24,
              ),
              child: Column(
                children: [
                  // User Top Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isGuest
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              }
                            : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isGuest
                                ? Colors.white.withValues(alpha: 0.18)
                                : const Color(0xFFF6C8A7),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isGuest
                                ? const Icon(
                                    Icons.person_outline_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Color(0xFF74442C),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Xin chào, $displayName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isGuest) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Vãng lai',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Bạn muốn đi đâu hôm nay?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isGuest) ...[
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.login_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Không có thông báo mới nào'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // White Floating Search Box with Shadow
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExploreScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF112F2B).withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Color(0xFF65726F), size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tìm điểm đến, khách sạn, tour...',
                              style: TextStyle(
                                color: Color(0xFF65726F),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Service Grid (5 items matching prototype exactly)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildServiceItem('Khách sạn', Icons.hotel_rounded, const Color(0xFFE2F1FF), const Color(0xFF2774AB)),
                      _buildServiceItem('Máy bay', Icons.flight_takeoff_rounded, const Color(0xFFEDE9FD), const Color(0xFF624CBD)),
                      _buildServiceItem('Xe khách', Icons.directions_bus_rounded, const Color(0xFFFFF0DF), const Color(0xFFC8771F)),
                      _buildServiceItem('Tours', Icons.explore_rounded, const Color(0xFFE5F5E9), const Color(0xFF3A8656)),
                      _buildServiceItem('Combo', Icons.confirmation_number_rounded, const Color(0xFFFDEBED), const Color(0xFFC95766)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // AI Travel Planner Banner (Figma Prototype Gradient: #322281 -> #5A46C8 -> #8774EE)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF322281), Color(0xFF5A46C8), Color(0xFF8774EE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4834AA).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Decorative orbit circle
                        Positioned(
                          right: -24,
                          top: -10,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            ),
                            child: const Center(
                              child: Icon(Icons.auto_awesome, color: Colors.white54, size: 28),
                            ),
                          ),
                        ),
                        // Copy & CTA
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.auto_awesome, color: Color(0xFFD8D1FF), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'TRAVEL-GO AI',
                                  style: TextStyle(
                                    color: Color(0xFFD8D1FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chưa biết đi đâu?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Lịch trình phù hợp ngân sách, chỉ trong vài phút.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const HomePlannerScreen(),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Lên kế hoạch',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // OpenStreetMap & Group Member Radar Quick Access Card
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TripMapScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF086C61).withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF086C61).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF086C61).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.map_rounded, color: Color(0xFF086C61), size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bản Đồ Lộ Trình & Radar Nhóm',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'OpenStreetMap OSRM & Định vị đồng đội',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF086C61),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Mở Map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section: Điểm đến nổi bật
                  _buildSectionHeader('Điểm đến nổi bật', 'Xem tất cả', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExploreScreen()),
                    );
                  }),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 178,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: catalog.destinations.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final dest = catalog.destinations[index];
                        final weather = catalog.getWeather(dest.id);
                        final temp = weather != null
                            ? '${weather.temperature.toStringAsFixed(0)}°C'
                            : '${dest.weatherCachedTemp.toStringAsFixed(0)}°C';
                        final subtitle = '$temp · ${dest.region}';
                        return _buildDestinationCard(
                          dest.name,
                          subtitle,
                          dest.imageUrl ?? photoDaNang,
                          weatherIcon: weather?.weatherIcon,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section: Ở đâu tại Đà Nẵng / Resort nổi bật
                  _buildSectionHeader('Chỗ nghỉ nổi bật', 'Xem tất cả'),
                  const SizedBox(height: 12),

                  // Featured Hotel Card
                  Builder(
                    builder: (context) {
                      final featuredHotel = catalog.featuredHotels.isNotEmpty
                          ? catalog.featuredHotels.first
                          : null;
                      final hotelId = featuredHotel?.id ?? 'furama-resort-da-nang';
                      final isFav = favorites.isFavorite(hotelId);
                      final hotelTitle = featuredHotel?.title ?? 'Furama Resort Đà Nẵng';
                      final hotelLocation = featuredHotel?.location ?? 'Võ Nguyên Giáp, Ngũ Hành Sơn, Đà Nẵng';
                      final hotelPrice = featuredHotel != null
                          ? currencyFmt.format(featuredHotel.basePrice)
                          : '2.200.000₫';
                      final hotelRating = featuredHotel?.rating.toStringAsFixed(1) ?? '4.8';
                      final hotelReviews = '${featuredHotel?.reviewCount ?? 128} đánh giá';
                      final hotelImage = featuredHotel?.primaryImage ?? photoResort;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF112F2B).withValues(alpha: 0.07),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              hotelImage,
                              height: 178,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 178,
                                color: const Color(0xFF086C61).withValues(alpha: 0.1),
                                child: const Center(
                                  child: Icon(Icons.hotel, size: 48, color: Color(0xFF086C61)),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hotelTitle,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF172422),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF65726F)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    hotelLocation,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF65726F)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (isGuest) {
                                            GuestLoginBottomSheet.show(context);
                                          } else {
                                            favorites.toggleFavorite(FavoriteItem(
                                              id: '',
                                              userId: user.id,
                                              itemId: hotelId,
                                              itemType: 'hotel',
                                              title: hotelTitle,
                                              location: hotelLocation,
                                              imageUrl: hotelImage,
                                              price: featuredHotel?.basePrice ?? 2200000,
                                              rating: featuredHotel?.rating ?? 4.8,
                                              createdAt: DateTime.now(),
                                            ));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isFav
                                                      ? 'Đã bỏ lưu khỏi danh sách yêu thích'
                                                      : 'Đã lưu $hotelTitle vào danh sách yêu thích!',
                                                ),
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 18,
                                            color: isFav ? const Color(0xFFEF4444) : const Color(0xFF172422),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3DC),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, size: 12, color: Color(0xFFA65B0B)),
                                            const SizedBox(width: 3),
                                            Text(
                                              hotelRating,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFA65B0B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        hotelReviews,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF65726F)),
                                      ),
                                      const Spacer(),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          const Text('Từ ', style: TextStyle(fontSize: 11, color: Color(0xFF65726F))),
                                          Text(
                                            hotelPrice,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF172422),
                                            ),
                                          ),
                                          const Text('/đêm', style: TextStyle(fontSize: 10, color: Color(0xFF65726F))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Promo Banner (Live from Supabase vouchers)
                  Builder(
                    builder: (context) {
                      final voucher = catalog.vouchers.isNotEmpty ? catalog.vouchers.first : null;
                      final voucherCode = voucher?.id ?? 'HELLO25';
                      final voucherTitle = voucher?.title ?? 'Ưu đãi chào bạn mới mừng năm 2026';
                      final voucherDiscount = voucher?.discountDisplay ?? '200.000₫';

                      return InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: voucherCode));
                          if (!isGuest) {
                            catalog.claimVoucher(userId: user.id, voucherId: voucherCode);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã sao chép mã ưu đãi $voucherCode (Giảm $voucherDiscount)!'),
                              backgroundColor: const Color(0xFF086C61),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF6ED), Color(0xFFFFE8D6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFD4B8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MÃ ƯU ĐÃI ĐỘC QUYỀN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF7657),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Giảm ngay $voucherDiscount',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF172422),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      voucherTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF65726F)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7657),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  voucherCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Section: Trải nghiệm được yêu thích
                  _buildSectionHeader('Trải nghiệm được yêu thích', 'Khám phá', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExploreScreen()),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Mini tour card
                  Builder(
                    builder: (context) {
                      final tour = catalog.popularTours.isNotEmpty
                          ? catalog.popularTours.first
                          : null;
                      final tourId = tour?.id ?? 'tour-bana-hills-01';
                      final tourTitle = tour?.title ?? 'Tour Bà Nà Hills - Cầu Vàng 1 Ngày';
                      final tourPrice = tour != null ? currencyFmt.format(tour.basePrice) : '1.150.000₫';
                      final tourRating = tour?.rating.toStringAsFixed(1) ?? '4.9';
                      final tourReviews = '${tour?.reviewCount ?? 840} lượt đặt';
                      final tourImage = tour?.primaryImage ?? photoHoiAn;
                      final isFav = favorites.isFavorite(tourId);

                      return InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$tourTitle: $tourPrice · Chi tiết lịch trình có trong Đợt 2!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDFE6E4)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  tourImage,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFF086C61).withValues(alpha: 0.1),
                                    child: const Icon(Icons.tour, color: Color(0xFF086C61)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOUR NỔI BẬT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF3A8656),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tourTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF172422),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$tourRating · $tourReviews',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF65726F)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tourPrice,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF086C61),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: isFav ? const Color(0xFFEF4444) : const Color(0xFF65726F),
                                ),
                                onPressed: () {
                                  if (isGuest) {
                                    GuestLoginBottomSheet.show(context);
                                  } else {
                                    favorites.toggleFavorite(FavoriteItem(
                                      id: '',
                                      userId: user.id,
                                      itemId: tourId,
                                      itemType: 'tour',
                                      title: tourTitle,
                                      location: tour?.location ?? 'Việt Nam',
                                      imageUrl: tourImage,
                                      price: tour?.basePrice ?? 1150000,
                                      rating: tour?.rating ?? 4.9,
                                      createdAt: DateTime.now(),
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isFav
                                              ? 'Đã bỏ lưu khỏi danh sách yêu thích'
                                              : 'Đã lưu $tourTitle vào danh sách yêu thích!',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172422),
          ),
        ),
        InkWell(
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                );
              },
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF086C61),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem(String name, IconData icon, Color bg, Color fg) {
    return InkWell(
      onTap: () {
        if (name == 'Khách sạn' || name == 'Tours') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExploreScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dịch vụ $name đang được hoàn thiện trong Đợt 2!'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(17),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172422),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(String name, String price, String photo, {IconData? weatherIcon}) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExploreScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 148,
        height: 178,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF112F2B).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF086C61),
              child: Center(
                child: Text(name, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF071816).withValues(alpha: 0.75),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 13,
            right: 13,
            bottom: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    if (weatherIcon != null) ...[
                      Icon(weatherIcon, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        price,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
