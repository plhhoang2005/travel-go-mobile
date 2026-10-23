// Wire models for TravelGO Administration (contract: travelgo.admin.v1).
// Strict JSON parsing; unknown enums or missing fields fail closed.

import 'package:flutter/foundation.dart';

@immutable
class AdminAccess {
  final String subjectId;
  final String role;
  final int accountRevision;
  final bool allowed;

  const AdminAccess({
    required this.subjectId,
    required this.role,
    required this.accountRevision,
    required this.allowed,
  });

  factory AdminAccess.fromJson(Map<String, dynamic> json) {
    final subjectId = json['subjectId'];
    final role = json['role'];
    final accountRevision = json['accountRevision'];
    final allowed = json['allowed'];

    if (subjectId is! String || subjectId.trim().isEmpty) {
      throw const FormatException('AdminAccess missing or invalid subjectId');
    }
    if (role is! String || role != 'admin') {
      throw const FormatException('AdminAccess role must be admin');
    }
    if (accountRevision is! int || accountRevision < 1) {
      throw const FormatException('AdminAccess invalid accountRevision');
    }
    if (allowed is! bool || allowed != true) {
      throw const FormatException('AdminAccess allowed must be true');
    }

    return AdminAccess(
      subjectId: subjectId,
      role: role,
      accountRevision: accountRevision,
      allowed: allowed,
    );
  }
}

@immutable
class UserSummary {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String state;
  final int revision;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final bool authSynced;

  const UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.state,
    required this.revision,
    required this.createdAt,
    this.lastSignInAt,
    required this.authSynced,
  });

  bool get isAdmin => role == 'admin';
  bool get isLocked => state == 'locked';
  bool get isUnlocking => state == 'unlocking';
  bool get isEnabled => state == 'enabled';

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final fullName = json['fullName'];
    final email = json['email'];
    final role = json['role'];
    final state = json['state'];
    final revision = json['revision'];
    final createdAtRaw = json['createdAt'];
    final lastSignInAtRaw = json['lastSignInAt'];
    final authSynced = json['authSynced'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('UserSummary invalid id');
    }
    if (fullName is! String) {
      throw const FormatException('UserSummary invalid fullName');
    }
    if (email is! String) {
      throw const FormatException('UserSummary invalid email');
    }
    if (role is! String || (role != 'customer' && role != 'admin')) {
      throw const FormatException('UserSummary unknown role');
    }
    if (state is! String ||
        (state != 'enabled' && state != 'locked' && state != 'unlocking')) {
      throw const FormatException('UserSummary unknown state');
    }
    if (revision is! int || revision < 1) {
      throw const FormatException('UserSummary invalid revision');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('UserSummary invalid createdAt');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('UserSummary invalid createdAt format');
    }

    DateTime? lastSignInAt;
    if (lastSignInAtRaw != null) {
      if (lastSignInAtRaw is! String) {
        throw const FormatException('UserSummary invalid lastSignInAt');
      }
      lastSignInAt = DateTime.tryParse(lastSignInAtRaw);
      if (lastSignInAt == null) {
        throw const FormatException('UserSummary invalid lastSignInAt format');
      }
    }

    if (authSynced is! bool) {
      throw const FormatException('UserSummary invalid authSynced');
    }

    return UserSummary(
      id: id,
      fullName: fullName,
      email: email,
      role: role,
      state: state,
      revision: revision,
      createdAt: createdAt,
      lastSignInAt: lastSignInAt,
      authSynced: authSynced,
    );
  }
}

@immutable
class AuditEvent {
  final String id;
  final String? operationId;
  final String actorId;
  final String targetId;
  final String eventKind;
  final String reason;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    this.operationId,
    required this.actorId,
    required this.targetId,
    required this.eventKind,
    required this.reason,
    required this.createdAt,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final operationId = json['operationId'];
    final actorId = json['actorId'];
    final targetId = json['targetId'];
    final eventKind = json['eventKind'];
    final reason = json['reason'];
    final createdAtRaw = json['createdAt'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('AuditEvent invalid id');
    }
    if (operationId != null && operationId is! String) {
      throw const FormatException('AuditEvent invalid operationId');
    }
    if (actorId is! String || actorId.isEmpty) {
      throw const FormatException('AuditEvent invalid actorId');
    }
    if (targetId is! String || targetId.isEmpty) {
      throw const FormatException('AuditEvent invalid targetId');
    }
    if (eventKind is! String || eventKind.isEmpty) {
      throw const FormatException('AuditEvent invalid eventKind');
    }
    if (reason is! String) {
      throw const FormatException('AuditEvent invalid reason');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('AuditEvent invalid createdAt');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('AuditEvent invalid createdAt format');
    }

    return AuditEvent(
      id: id,
      operationId: operationId,
      actorId: actorId,
      targetId: targetId,
      eventKind: eventKind,
      reason: reason,
      createdAt: createdAt,
    );
  }
}

@immutable
class UserDetail {
  final UserSummary summary;
  final List<AuditEvent> audit;

  const UserDetail({
    required this.summary,
    required this.audit,
  });

  String get id => summary.id;
  String get fullName => summary.fullName;
  String get email => summary.email;
  String get role => summary.role;
  String get state => summary.state;
  int get revision => summary.revision;
  DateTime get createdAt => summary.createdAt;
  DateTime? get lastSignInAt => summary.lastSignInAt;
  bool get authSynced => summary.authSynced;

  bool get isAdmin => summary.isAdmin;
  bool get isLocked => summary.isLocked;
  bool get isEnabled => summary.isEnabled;
  bool get isUnlocking => summary.isUnlocking;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    final summary = UserSummary.fromJson(json);
    final auditRaw = json['audit'];
    if (auditRaw is! List) {
      throw const FormatException('UserDetail invalid audit list');
    }
    final audit = auditRaw
        .map((e) => AuditEvent.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    return UserDetail(
      summary: summary,
      audit: audit,
    );
  }
}

@immutable
class UserCursor {
  final String createdAt;
  final String id;

  const UserCursor({
    required this.createdAt,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt,
        'id': id,
      };

  factory UserCursor.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    final id = json['id'];
    if (createdAt is! String || id is! String) {
      throw const FormatException('UserCursor invalid fields');
    }
    return UserCursor(createdAt: createdAt, id: id);
  }
}

@immutable
class UserPage {
  final List<UserSummary> items;
  final UserCursor? nextCursor;

  const UserPage({
    required this.items,
    this.nextCursor,
  });

  factory UserPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    if (itemsRaw is! List) {
      throw const FormatException('UserPage invalid items list');
    }
    final items = itemsRaw
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    UserCursor? nextCursor;
    if (json['nextCursor'] != null) {
      nextCursor =
          UserCursor.fromJson(json['nextCursor'] as Map<String, dynamic>);
    }

    return UserPage(
      items: items,
      nextCursor: nextCursor,
    );
  }
}

@immutable
class AccountOperation {
  final String id;
  final String targetId;
  final String action;
  final String state;
  final int targetRevision;
  final bool authSynced;

  const AccountOperation({
    required this.id,
    required this.targetId,
    required this.action,
    required this.state,
    required this.targetRevision,
    required this.authSynced,
  });

  bool get isPending => state == 'pending';
  bool get isCompleted => state == 'completed';
  bool get needsRetry => state == 'needs_retry';

  factory AccountOperation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final targetId = json['targetId'];
    final action = json['action'];
    final state = json['state'];
    final targetRevision = json['targetRevision'];
    final authSynced = json['authSynced'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('AccountOperation invalid id');
    }
    if (targetId is! String || targetId.isEmpty) {
      throw const FormatException('AccountOperation invalid targetId');
    }
    if (action is! String ||
        (action != 'lock' &&
            action != 'unlock' &&
            action != 'promote' &&
            action != 'demote' &&
            action != 'reconcile')) {
      throw const FormatException('AccountOperation unknown action');
    }
    if (state is! String ||
        (state != 'pending' &&
            state != 'completed' &&
            state != 'needs_retry')) {
      throw const FormatException('AccountOperation unknown state');
    }
    if (targetRevision is! int || targetRevision < 1) {
      throw const FormatException('AccountOperation invalid targetRevision');
    }
    if (authSynced is! bool) {
      throw const FormatException('AccountOperation invalid authSynced');
    }

    return AccountOperation(
      id: id,
      targetId: targetId,
      action: action,
      state: state,
      targetRevision: targetRevision,
      authSynced: authSynced,
    );
  }
}

@immutable
class RegistrationDayPoint {
  final String date;
  final int count;

  const RegistrationDayPoint({
    required this.date,
    required this.count,
  });

  factory RegistrationDayPoint.fromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final count = json['count'];
    if (date is! String || count is! int || count < 0) {
      throw const FormatException('RegistrationDayPoint invalid fields');
    }
    return RegistrationDayPoint(date: date, count: count);
  }
}

@immutable
class DraftCatalogueStats {
  final int revision;
  final int activeDestinations;
  final int hiddenDestinations;
  final int activePlaces;
  final int hiddenPlaces;

  const DraftCatalogueStats({
    required this.revision,
    required this.activeDestinations,
    required this.hiddenDestinations,
    required this.activePlaces,
    required this.hiddenPlaces,
  });

  factory DraftCatalogueStats.fromJson(Map<String, dynamic> json) {
    final revision = json['revision'];
    final activeDestinations = json['activeDestinations'];
    final hiddenDestinations = json['hiddenDestinations'];
    final activePlaces = json['activePlaces'];
    final hiddenPlaces = json['hiddenPlaces'];

    if (revision is! int ||
        activeDestinations is! int ||
        hiddenDestinations is! int ||
        activePlaces is! int ||
        hiddenPlaces is! int) {
      throw const FormatException('DraftCatalogueStats invalid fields');
    }

    return DraftCatalogueStats(
      revision: revision,
      activeDestinations: activeDestinations,
      hiddenDestinations: hiddenDestinations,
      activePlaces: activePlaces,
      hiddenPlaces: hiddenPlaces,
    );
  }
}

@immutable
class PublishedCatalogueStats {
  final String version;
  final int sourceRevision;
  final int activeDestinations;
  final int activePlaces;

  const PublishedCatalogueStats({
    required this.version,
    required this.sourceRevision,
    required this.activeDestinations,
    required this.activePlaces,
  });

  factory PublishedCatalogueStats.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final sourceRevision = json['sourceRevision'];
    final activeDestinations = json['activeDestinations'];
    final activePlaces = json['activePlaces'];

    if (version is! String ||
        sourceRevision is! int ||
        activeDestinations is! int ||
        activePlaces is! int) {
      throw const FormatException('PublishedCatalogueStats invalid fields');
    }

    return PublishedCatalogueStats(
      version: version,
      sourceRevision: sourceRevision,
      activeDestinations: activeDestinations,
      activePlaces: activePlaces,
    );
  }
}

@immutable
class DashboardSnapshot {
  final DateTime asOf;
  final int days;
  final int totalUsers;
  final int lockedUsers;
  final int activeAdmins;
  final List<RegistrationDayPoint> registrations;
  final DraftCatalogueStats draft;
  final PublishedCatalogueStats? published;

  const DashboardSnapshot({
    required this.asOf,
    required this.days,
    required this.totalUsers,
    required this.lockedUsers,
    required this.activeAdmins,
    required this.registrations,
    required this.draft,
    this.published,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final asOfRaw = json['asOf'];
    final days = json['days'];
    final totalUsers = json['totalUsers'];
    final lockedUsers = json['lockedUsers'];
    final activeAdmins = json['activeAdmins'];
    final registrationsRaw = json['registrations'];
    final draftRaw = json['draft'];
    final publishedRaw = json['published'];

    if (asOfRaw is! String) {
      throw const FormatException('DashboardSnapshot invalid asOf');
    }
    final asOf = DateTime.tryParse(asOfRaw);
    if (asOf == null) {
      throw const FormatException('DashboardSnapshot invalid asOf date format');
    }
    if (days is! int || (days != 7 && days != 30)) {
      throw const FormatException('DashboardSnapshot days must be 7 or 30');
    }
    if (totalUsers is! int || totalUsers < 0) {
      throw const FormatException('DashboardSnapshot invalid totalUsers');
    }
    if (lockedUsers is! int || lockedUsers < 0) {
      throw const FormatException('DashboardSnapshot invalid lockedUsers');
    }
    if (activeAdmins is! int || activeAdmins < 0) {
      throw const FormatException('DashboardSnapshot invalid activeAdmins');
    }
    if (registrationsRaw is! List) {
      throw const FormatException('DashboardSnapshot invalid registrations');
    }
    final registrations = registrationsRaw
        .map((e) => RegistrationDayPoint.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    if (draftRaw is! Map<String, dynamic>) {
      throw const FormatException('DashboardSnapshot invalid draft');
    }
    final draft = DraftCatalogueStats.fromJson(draftRaw);

    PublishedCatalogueStats? published;
    if (publishedRaw != null) {
      published = PublishedCatalogueStats.fromJson(
          publishedRaw as Map<String, dynamic>);
    }

    return DashboardSnapshot(
      asOf: asOf,
      days: days,
      totalUsers: totalUsers,
      lockedUsers: lockedUsers,
      activeAdmins: activeAdmins,
      registrations: registrations,
      draft: draft,
      published: published,
    );
  }
}

@immutable
class AdminFailure implements Exception {
  final String code;
  final String? field;
  final bool outcomeUncertain;
  final String message;

  const AdminFailure({
    required this.code,
    this.field,
    this.outcomeUncertain = false,
    required this.message,
  });

  @override
  String toString() => 'AdminFailure(code: $code, field: $field, uncertain: $outcomeUncertain)';
}
