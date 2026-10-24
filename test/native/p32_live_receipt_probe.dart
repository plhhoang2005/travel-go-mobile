// Explicit staging-only native transport probe. Installs separately from main.
// Uses main's SDK/lifecycle authorization; never reads credential storage itself.
// Only creates the named synthetic fixture, never updates/deletes existing trips.
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/main.dart' as app;

const _title = 'P32LOSTREPLY_1810_01';
const _request = '00000000-0000-4000-8000-000000001810';

void _require(bool condition, String code) {
  if (!condition) {
    debugPrint('[P32 live receipt] assertion=$code');
    throw StateError(code);
  }
}

class _DropCommittedReply implements HttpClientAdapter {
  final HttpClientAdapter _delegate = IOHttpClientAdapter();
  bool dropped = false;
  int creates = 0, lookups = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _require(options.uri.host == 'bkocylxbuyvdgxccpixx.supabase.co', 'origin');
    final create = options.uri.path.endsWith('/create_editable_trip_v2');
    if (create) creates++;
    if (options.uri.path.endsWith('/get_editable_mutation_v2')) lookups++;
    final response = await _delegate.fetch(
      options,
      requestStream,
      cancelFuture,
    );
    if (create && !dropped && response.statusCode == 200) {
      // Fully receive a real successful response BEFORE making it unavailable
      // to the real service/repository. No request bytes/headers are logged.
      await response.stream.drain<void>();
      dropped = true;
      debugPrint('[P32 live receipt] committed_response_dropped=true');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return response;
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}

BuildContext? _context() {
  BuildContext? found;
  void visit(Element element) {
    if (found != null) return;
    try {
      element.read<AuthProvider>();
      element.read<app.ManualPlannerRuntime>();
      found = element;
    } on ProviderNotFoundException {
      element.visitChildren(visit);
    }
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

Future<void> _probe(BuildContext context) async {
  _require(SupabaseConstants.isStaging, 'staging_required');
  final auth = context.read<AuthProvider>();
  final runtime = context.read<app.ManualPlannerRuntime>();
  await auth.initialization;
  _require(
    auth.isAuthenticated && !auth.isDemoSession,
    'real_account_required',
  );
  final bundle = await runtime.getResources();
  final original = bundle.repository;
  // Require the exact previously authorized Account A test fixture as an anchor.
  final page = await original.listOwned();
  final anchors = page.items.where(
    (row) => row.title == 'P32CONFLICT_WIN_1810',
  );
  _require(anchors.length == 1, 'synthetic_A_anchor_required');
  final recovering = page.items.any((row) => row.title == _title);
  final view = await original.readTrip(
    anchors.single.tripId,
    allowCached: false,
  );
  final head = view.head;
  _require(head != null, 'online_anchor_required');
  final source = head!.document;
  final candidate = EditableTripDocumentV2.fromJson({
    ...source.toJson(),
    'input': {...source.input.toJson(), 'title': _title},
    'source': SourceReference(
      kind: 'new',
      sourceId: null,
      sourceDigest: null,
    ).toJson(),
  });
  final adapter = _DropCommittedReply();
  final service = EditableTripService(
    projectUrl: SupabaseConstants.projectUrl,
    publicKey: SupabaseConstants.publishableKey,
    isCurrentProof: original.lifecycle.isCurrentProof,
    adapter: adapter,
  );
  try {
    final repository = EditableTripRepository(
      store: original.store,
      lifecycle: original.lifecycle,
      service: service,
    );
    if (!recovering) {
      var uncertain = false;
      try {
        await repository.saveAccount(
          document: candidate,
          commands: [],
          requestId: _request,
        );
      } on EditableRemoteException catch (error) {
        uncertain = error.kind == EditableRemoteFailure.uncertain;
      }
      _require(
        uncertain && adapter.dropped,
        'real_committed_reply_loss_required',
      );
    } else {
      debugPrint('[P32 live receipt] recovering_prior_dropped_reply=true');
    }
    final handle = original.lifecycle.handle;
    _require(handle != null, 'authority_still_required');
    final outbox = await original.store.listEditableAttempts(handle: handle!);
    final pending = outbox.where((row) => row.attempt.requestId == _request);
    _require(pending.length <= 1, 'one_frozen_attempt_required');
    EditableMutationReply retry;
    if (pending.isNotEmpty) {
      retry = await repository.retryPending(_request);
      debugPrint('[P32 live receipt] pending_retry_acknowledged=true');
    } else {
      _require(recovering, 'pending_frozen_attempt_required');
      final committed = await original.store.rawDb.query(
        'editable_mutation_outbox',
        columns: ['state'],
        where: 'owner_id=? AND request_id=?',
        whereArgs: [original.lifecycle.captureProof().ownerId, _request],
      );
      _require(
        committed.length == 1 && committed.single['state'] == 'committed',
        'prior_local_ack_required',
      );
      retry = await service.lookup(
        proof: original.lifecycle.captureProof(),
        requestId: _request,
      );
      debugPrint(
        '[P32 live receipt] prior_pending_retry_locally_committed=true',
      );
    }
    // retryPending intentionally excludes committed rows. After acknowledgement,
    // inspect the same server receipt rather than retrying a nonexistent pending row.
    final again = await service.lookup(
      proof: original.lifecycle.captureProof(),
      requestId: _request,
    );
    _require(
      retry.status == EditableMutationStatus.committed &&
          again.status == EditableMutationStatus.committed &&
          retry.receipt?.tripId == again.receipt?.tripId &&
          retry.receipt?.resultVersion == 1 &&
          again.receipt?.resultVersion == 1,
      'same_receipt_version_required',
    );
    _require(
      adapter.creates == (recovering ? 0 : 1) && adapter.lookups >= 2,
      'no_duplicate_create_required',
    );
    final readback = await original.readTrip(
      retry.receipt!.tripId,
      allowCached: false,
    );
    _require(
      readback.head?.version == 1 &&
          readback.head?.document.input.title == _title,
      'server_readback_required',
    );
    final after = await original.listOwned();
    _require(
      after.items.where((row) => row.title == _title).length == 1,
      'one_new_synthetic_row',
    );
    debugPrint(
      '[P32 live receipt] retry_same_receipt=true version=1 synthetic_row_count=1',
    );
    debugPrint(
      '[P32 live receipt] PASS_NATIVE_REAL_SERVER_NOT_MAIN_UI recovery=$recovering new_creates=${adapter.creates}',
    );
  } finally {
    service.close();
  }
}

Future<void> main() async {
  await app.main();
  for (var attempt = 0; attempt < 60; attempt++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final context = _context();
    if (context == null) continue;
    if (!context.mounted) continue;
    try {
      await _probe(context);
    } on Object catch (error) {
      // Do not log exception objects: transport errors can carry credentials.
      debugPrint('[P32 live receipt] FAIL_SAFE_TYPE=${error.runtimeType}');
    }
    return;
  }
  debugPrint('[P32 live receipt] FAIL_NO_CONTEXT');
}
