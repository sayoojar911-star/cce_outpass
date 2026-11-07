class OutpassStatus {
  static const String pendingTutor = 'PENDING_TUTOR';
  static const String pendingHod = 'PENDING_HOD';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
  static const String cancelled = 'CANCELLED';
  static const String exited = 'EXITED';
  static const String returned = 'RETURNED';
  static const String completed = 'COMPLETED';
  static const String expired = 'EXPIRED';
  static const String overdue = 'OVERDUE';

  static bool isPending(String? status) {
    if (status == null) return false;
    final s = status.toUpperCase();
    return s == 'PENDING' || s.startsWith('PENDING_');
  }
}

class OutpassTypeId {
  static const String normal = 'normal';
  static const String emergency = 'emergency';
}

class StageRoleId {
  static const String tutor = 'tutor';
  static const String hod = 'hod';
}
