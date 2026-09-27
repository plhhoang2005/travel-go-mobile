import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/destination_model.dart';
import '../models/service_model.dart';
import '../models/voucher_model.dart';

class HomeCatalogService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<DestinationModel>> fetchDestinations() async {
    final client = _client;
    if (client == null) return DestinationModel.presetFallbackList();

    try {
      final response = await client
          .from('destinations')
          .select()
          .order('name');

      final list = (response as List<dynamic>)
          .map((item) => DestinationModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : DestinationModel.presetFallbackList();
    } catch (e) {
      debugPrint('Error fetching destinations from Supabase: $e');
      return DestinationModel.presetFallbackList();
    }
  }

  Future<List<ServiceModel>> fetchFeaturedHotels() async {
    final client = _client;
    if (client == null) return ServiceModel.presetHotelsFallback();

    try {
      final response = await client
          .from('services')
          .select()
          .eq('service_type', 'hotel')
          .eq('is_active', true)
          .order('rating', ascending: false)
          .limit(8);

      final list = (response as List<dynamic>)
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : ServiceModel.presetHotelsFallback();
    } catch (e) {
      debugPrint('Error fetching hotels from Supabase: $e');
      return ServiceModel.presetHotelsFallback();
    }
  }

  Future<List<ServiceModel>> fetchPopularTours() async {
    final client = _client;
    if (client == null) return ServiceModel.presetToursFallback();

    try {
      final response = await client
          .from('services')
          .select()
          .eq('service_type', 'tour')
          .eq('is_active', true)
          .order('rating', ascending: false)
          .limit(6);

      final list = (response as List<dynamic>)
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : ServiceModel.presetToursFallback();
    } catch (e) {
      debugPrint('Error fetching tours from Supabase: $e');
      return ServiceModel.presetToursFallback();
    }
  }

  Future<List<VoucherModel>> fetchActiveVouchers() async {
    final client = _client;
    if (client == null) return VoucherModel.presetFallbackList();

    try {
      final response = await client
          .from('vouchers')
          .select()
          .eq('is_active', true)
          .order('discount_amount', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => VoucherModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : VoucherModel.presetFallbackList();
    } catch (e) {
      debugPrint('Error fetching vouchers from Supabase: $e');
      return VoucherModel.presetFallbackList();
    }
  }

  Future<bool> claimVoucher({
    required String userId,
    required String voucherId,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('user_vouchers').upsert(
        {
          'user_id': userId,
          'voucher_id': voucherId,
          'status': 'available',
        },
        onConflict: 'user_id,voucher_id',
      );
      return true;
    } catch (e) {
      debugPrint('Error claiming voucher in Supabase: $e');
      return false;
    }
  }
}
