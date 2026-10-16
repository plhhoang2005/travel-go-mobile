import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/saved_trips_provider.dart';
import 'editable_trip_detail_screen.dart';

/// Displays only the validated snapshot already published by the account cache.
class SavedTripSnapshotScreen extends StatelessWidget {
  final String tripId;
  final String expectedOwnerId;

  const SavedTripSnapshotScreen({
    super.key,
    required this.tripId,
    required this.expectedOwnerId,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<SavedTripsProvider>();
    final ownerIsCurrent =
        auth.isAuthenticated &&
        !auth.isDemoSession &&
        auth.currentUser?.id == expectedOwnerId &&
        trips.currentUserId == expectedOwnerId &&
        trips.cacheState != AccountCacheState.blocked;
    final matches = ownerIsCurrent
        ? trips.accountSnapshots.where(
            (item) => item.ownerId == expectedOwnerId && item.tripId == tripId,
          )
        : const Iterable<Never>.empty();
    final snapshot = matches.isEmpty ? null : matches.first;
    final plan = snapshot?.cachedPayload.plan;
    final request = snapshot?.cachedPayload.request;
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch trình đã lưu')),
      body: snapshot == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không có bản lưu trên máy khả dụng cho tài khoản này.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              key: const ValueKey('saved.v1'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  snapshot.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Điểm đến: ${snapshot.destinationName}'),
                if (snapshot.startDate != null || snapshot.endDate != null)
                  Text(
                    'Ngày đi: ${snapshot.startDate ?? 'chưa rõ'} – ${snapshot.endDate ?? 'chưa rõ'}',
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bản chỉ đọc trên máy'),
                        Text(
                          trips.cacheState == AccountCacheState.offline
                              ? 'Ngoại tuyến · chưa kiểm tra lại với server'
                              : trips.cacheState == AccountCacheState.online
                              ? 'Đã kiểm tra với server'
                              : 'Chưa thể kiểm tra lại với server',
                        ),
                        Text(
                          'Lấy lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(snapshot.fetchedAt.toLocal())}',
                        ),
                        Text(
                          snapshot.remoteVersion == null
                              ? 'Phiên bản server: chưa có'
                              : 'Phiên bản server: ${snapshot.remoteVersion}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (request != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Thông tin chuyến đi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Xuất phát: ${request.origin}'),
                  Text('${request.numDays} ngày · ${request.numPeople} người'),
                  Text('Ngân sách: ${currency.format(request.budgetVnd)}'),
                ],
                if (plan == null) ...[
                  const SizedBox(height: 20),
                  const Text('Chỉ có thông tin đầu vào, chưa có lịch trình.'),
                ] else ...[
                  if (plan.isFallback) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '[Dữ liệu ngoại tuyến] Kết quả dự phòng',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Lịch trình',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (plan.itineraryDays.isEmpty)
                    const Text('Bản lưu chưa có lịch trình theo ngày.'),
                  for (final day in plan.itineraryDays)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày ${day.day}: ${day.title}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            for (final activity in day.activities)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${activity.time} · ${activity.title} · ${currency.format(activity.costVnd)}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (plan.transportOptions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Phương tiện',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final option in plan.transportOptions)
                      Text(
                        '${option.displayName}: ${currency.format(option.priceTotalVnd)}',
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegacyTripCopyScreen(snapshot: snapshot),
                    ),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Tạo bản sao để chỉnh sửa'),
                ),
              ],
            ),
    );
  }
}
