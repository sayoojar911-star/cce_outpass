import 'dart:math';

/// In-memory mock backend that implements the CCE Outpass state machine,
/// allowing the full student -> tutor -> HOD -> guard core loop to run
/// standalone without external PostgreSQL or Firebase dependencies.
class MockBackend {
  static final MockBackend instance = MockBackend._internal();
  MockBackend._internal() {
    _initSeed();
  }

  // Current session
  String? currentUserId;
  final Map<String, String> _registeredDeviceKeys = {}; // userId -> pem

  // Data stores
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _outpasses = [];
  final List<Map<String, dynamic>> _gateEvents = [];
  final List<Map<String, dynamic>> _notifications = [];
  int _outpassCounter = 100;

  void resetForTesting() {
    currentUserId = null;
    _registeredDeviceKeys.clear();
    _users.clear();
    _outpasses.clear();
    _gateEvents.clear();
    _notifications.clear();
    _outpassCounter = 100;
    _initSeed();
  }

  void _initSeed() {
    _users.addAll([
      {
        'id': 'u-student-demo',
        'name': 'Demo Student',
        'role': 'STUDENT',
        'mobile': '9074121510',
        'department': 'CSE',
        'registerNo': 'CCE25CS100',
        'semester': 3,
        'tutorId': 'u-tutor-1',
      },
      {
        'id': 'u-student-1',
        'name': 'Ananya S',
        'role': 'STUDENT',
        'mobile': '9000000010',
        'department': 'CSE',
        'registerNo': 'CCE25CS001',
        'semester': 3,
        'tutorId': 'u-tutor-1',
      },
      {
        'id': 'u-student-2',
        'name': 'Arjun R',
        'role': 'STUDENT',
        'mobile': '9000000011',
        'department': 'CSE',
        'registerNo': 'CCE25CS002',
        'semester': 3,
        'tutorId': 'u-tutor-1',
      },
      {
        'id': 'u-tutor-1',
        'name': 'Dr. Anand Kumar',
        'role': 'TUTOR',
        'mobile': '9000000001',
        'department': 'CSE',
      },
      {
        'id': 'u-hod-1',
        'name': 'Dr. Priya Menon',
        'role': 'HOD',
        'mobile': '9000000002',
        'department': 'CSE',
      },
      {
        'id': 'u-guard-1',
        'name': 'Suresh (Security)',
        'role': 'GUARD',
        'mobile': '9000000090',
      },
    ]);

    // Seed one sample approved pass for Ananya S so gate scanning can also be tested immediately
    final now = DateTime.now();
    _outpasses.add({
      'id': 'outpass-seeded-1',
      'displayId': 'OUT-2026-0099',
      'studentId': 'u-student-1',
      'student': {
        'name': 'Ananya S',
        'registerNo': 'CCE25CS001',
        'department': 'CSE',
        'semester': 3,
      },
      'type': 'NORMAL',
      'status': 'APPROVED',
      'requestedExitAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      'expectedReturnAt': now.add(const Duration(hours: 2)).toIso8601String(),
      'destination': 'Town Center',
      'purposeCategory': 'Medical',
      'purposeText': 'Dental checkup',
      'validFrom': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      'validUntil': now.add(const Duration(hours: 2)).toIso8601String(),
      'lastTokenTs': 0,
      'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
    });
  }

  List<Map<String, dynamic>> get seedAccounts => List.unmodifiable(_users);

  Map<String, dynamic>? findUserByMobile(String mobile) {
    final clean = mobile.replaceAll(RegExp(r'\D+'), '');
    final norm = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
    return _users.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u?['mobile'] == norm,
          orElse: () => null,
        );
  }

  Map<String, dynamic> loginUser(String mobileOrToken) {
    // If passed mock-token:mobile or raw mobile
    String mobile = mobileOrToken;
    if (mobile.contains(':')) {
      mobile = mobile.split(':').last;
    }
    final user = findUserByMobile(mobile) ?? _users.first;
    currentUserId = user['id'] as String;
    return {
      'accessToken': 'mock-access-token-${user['id']}',
      'user': {
        'id': user['id'],
        'name': user['name'],
        'role': user['role'],
        'mobile': user['mobile'],
        'department': user['department'],
      },
    };
  }

  void registerDevice(String publicKeyPem) {
    if (currentUserId != null) {
      _registeredDeviceKeys[currentUserId!] = publicKeyPem;
    }
  }

  List<dynamic> myOutpasses() {
    if (currentUserId == null) return [];
    return _outpasses.where((o) => o['studentId'] == currentUserId).toList();
  }

  static const List<String> _activeStatuses = [
    'PENDING_TUTOR',
    'PENDING_HOD',
    'APPROVED',
    'EXITED',
    'OVERDUE',
  ];

  Map<String, dynamic> createOutpass({
    required String requestedExitAt,
    required String expectedReturnAt,
    required String destination,
    required String purposeCategory,
    String? purposeText,
    String type = 'NORMAL',
  }) {
    final user = _users.firstWhere((u) => u['id'] == currentUserId);

    // Rule 2: Concurrent active-outpass restriction (mirrors outpass.service.ts:48-54)
    final hasActive = _outpasses.any(
      (o) => o['studentId'] == currentUserId && _activeStatuses.contains(o['status']),
    );
    if (hasActive) {
      throw Exception('You already have an active outpass request');
    }

    _outpassCounter++;
    final id = 'outpass-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final displayId = 'OUT-2026-0$_outpassCounter';

    final outpass = {
      'id': id,
      'displayId': displayId,
      'studentId': currentUserId,
      'student': {
        'name': user['name'],
        'registerNo': user['registerNo'] ?? 'CCE25CS100',
        'department': user['department'] ?? 'CSE',
        'semester': user['semester'] ?? 3,
      },
      'type': type,
      'status': 'PENDING_TUTOR',
      'requestedExitAt': requestedExitAt,
      'expectedReturnAt': expectedReturnAt,
      'destination': destination,
      'purposeCategory': purposeCategory,
      'purposeText': purposeText,
      'validFrom': null,
      'validUntil': null,
      'exitAt': null,
      'entryAt': null,
      'lastTokenTs': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    _outpasses.insert(0, outpass);

    // Rule 4: Emergency approval notifications (FR-APR-04: notifies tutor and HOD simultaneously)
    final tutorId = user['tutorId'] ?? 'u-tutor-1';
    _notifications.insert(0, {
      'id': 'notif-${DateTime.now().millisecondsSinceEpoch}-1',
      'userId': tutorId,
      'title': '${type == "EMERGENCY" ? "EMERGENCY outpass request — " : "New outpass request — "}${user['name']}',
      'body': '$purposeCategory · $destination',
      'readAt': null,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (type == 'EMERGENCY') {
      final dept = user['department'] ?? 'CSE';
      final hod = _users.firstWhere(
        (u) => u['role'] == 'HOD' && u['department'] == dept,
        orElse: () => _users.firstWhere((u) => u['role'] == 'HOD'),
      );
      _notifications.insert(0, {
        'id': 'notif-${DateTime.now().millisecondsSinceEpoch}-2',
        'userId': hod['id'],
        'title': 'EMERGENCY outpass request — ${user['name']}',
        'body': '$purposeCategory · $destination',
        'readAt': null,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    return outpass;
  }

  void cancelOutpass(String id) {
    final index = _outpasses.indexWhere((o) => o['id'] == id);
    if (index != -1) {
      final o = _outpasses[index];
      if (['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED'].contains(o['status'])) {
        o['status'] = 'CANCELLED';
      }
    }
  }

  List<dynamic> pendingApprovals() {
    final user = _users.firstWhere(
      (u) => u['id'] == currentUserId,
      orElse: () => {'role': 'TUTOR'},
    );
    final role = user['role'] as String;
    if (role == 'TUTOR') {
      return _outpasses.where((o) => o['status'] == 'PENDING_TUTOR').toList();
    } else if (role == 'HOD') {
      // Emergency requests first (FR-HOD-07)
      final hodRequests = _outpasses.where((o) => o['status'] == 'PENDING_HOD').toList();
      hodRequests.sort((a, b) => (a['type'] == b['type'] ? 0 : a['type'] == 'EMERGENCY' ? -1 : 1));
      return hodRequests;
    }
    return [];
  }

  Map<String, dynamic> decide(String outpassId, String decision, {String? comment}) {
    final o = _outpasses.firstWhere((item) => item['id'] == outpassId);
    final currentStatus = o['status'] as String;

    if (decision == 'APPROVED') {
      if (currentStatus == 'PENDING_TUTOR') {
        o['status'] = 'PENDING_HOD';
      } else if (currentStatus == 'PENDING_HOD') {
        o['status'] = 'APPROVED';
        final now = DateTime.now();
        o['validFrom'] = o['requestedExitAt'] ?? now.toIso8601String();
        o['validUntil'] = o['expectedReturnAt'] ??
            now.add(const Duration(hours: 2)).toIso8601String();
      }
    } else if (decision == 'REJECTED') {
      o['status'] = 'REJECTED';
      o['rejectionReason'] = comment ?? 'Rejected by staff';
    }
    return o;
  }

  void startShift(String gateId) {
    // bookkeeping
  }

  static const int minDwellSeconds = 10 * 60; // §6.9 minimum 10-minute return dwell

  Map<String, dynamic> scan({
    required String token,
    required String direction,
    required String gateId,
    required String clientScanId,
  }) {
    // token format: v1.<outpassId>.<tsSec>.<signature>
    final parts = token.split('.');
    if (parts.length != 4 || parts[0] != 'v1') {
      return {'result': 'QR_INVALID', 'outpass': null};
    }

    final outpassId = parts[1];
    final tsStr = parts[2];
    final ts = int.tryParse(tsStr);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Rule 3: QR window validation (±75s window)
    if (ts == null || (nowSec - ts).abs() > 75) {
      final o = _outpasses.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id'] == outpassId,
            orElse: () => null,
          );
      return {'result': 'QR_STALE', 'outpass': o};
    }

    final outpass = _outpasses.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id'] == outpassId,
          orElse: () => null,
        );

    if (outpass == null) {
      return {'result': 'NOT_FOUND', 'outpass': null};
    }

    final status = outpass['status'] as String;
    final lastTokenTs = (outpass['lastTokenTs'] as num?)?.toInt() ?? 0;

    if (direction == 'EXIT') {
      if (status == 'APPROVED') {
        // Rule 3: Monotonic replay guard (lastTokenTs < ts)
        if (lastTokenTs >= ts) {
          return {'result': 'QR_STALE', 'outpass': outpass};
        }

        outpass['status'] = 'EXITED';
        outpass['exitAt'] = DateTime.now().toIso8601String();
        outpass['exitGateId'] = gateId;
        outpass['lastTokenTs'] = ts;

        _gateEvents.insert(0, {
          'direction': 'EXIT',
          'resultCode': 'OK_EXIT',
          'scannedAt': DateTime.now().toIso8601String(),
          'gateId': gateId,
          'outpassId': outpassId,
        });

        return {
          'result': 'OK_EXIT',
          'outpass': outpass,
        };
      } else if (status == 'EXITED') {
        return {'result': 'ALREADY_USED', 'outpass': outpass};
      } else {
        return {'result': 'NOT_APPROVED ($status)', 'outpass': outpass};
      }
    } else {
      // ENTRY direction
      if (status == 'EXITED' || status == 'OVERDUE') {
        // Rule 1: Minimum return dwell enforcement (10 minutes, PRD §6.9)
        final exitAtStr = outpass['exitAt'] as String?;
        if (exitAtStr != null) {
          final exitAt = DateTime.tryParse(exitAtStr);
          if (exitAt != null) {
            final elapsed = DateTime.now().difference(exitAt).inSeconds;
            if (elapsed < minDwellSeconds) {
              return {'result': 'MIN_DWELL', 'outpass': outpass};
            }
          }
        }

        // Rule 3: Monotonic replay guard on entry (lastTokenTs < ts)
        if (lastTokenTs >= ts) {
          return {'result': 'QR_STALE', 'outpass': outpass};
        }

        outpass['status'] = 'RETURNED';
        outpass['entryAt'] = DateTime.now().toIso8601String();
        outpass['entryGateId'] = gateId;
        outpass['lastTokenTs'] = ts;

        _gateEvents.insert(0, {
          'direction': 'ENTRY',
          'resultCode': 'OK_ENTRY',
          'scannedAt': DateTime.now().toIso8601String(),
          'gateId': gateId,
          'outpassId': outpassId,
        });

        return {
          'result': 'OK_ENTRY',
          'outpass': outpass,
        };
      } else {
        return {'result': 'NOT_EXITED ($status)', 'outpass': outpass};
      }
    }
  }

  List<dynamic> guardScans() {
    return _gateEvents;
  }

  List<Map<String, dynamic>> notificationsFor(String userId) {
    return _notifications.where((n) => n['userId'] == userId).toList();
  }
}
