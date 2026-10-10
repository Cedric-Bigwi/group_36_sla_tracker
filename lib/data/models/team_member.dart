import 'enums.dart';

class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.jobTitle,
    required this.role,
    required this.pinHash,
    required this.avatarColor,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String jobTitle;
  final MemberRole role;
  final String pinHash;

  /// ARGB int, used for the initials avatar.
  final int avatarColor;
  final DateTime createdAt;

  bool get isManager => role == MemberRole.manager;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// Up to two initials, e.g. "Brenda Mukasa" -> "BM".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    final first = list.first[0];
    final last = list.length > 1 ? list.last[0] : '';
    return (first + last).toUpperCase();
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'job_title': jobTitle,
    'role': role.name,
    'pin_hash': pinHash,
    'avatar_color': avatarColor,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory TeamMember.fromMap(Map<String, Object?> map) => TeamMember(
    id: map['id']! as String,
    name: map['name']! as String,
    email: map['email']! as String,
    jobTitle: map['job_title']! as String,
    role: MemberRole.parse(map['role'] as String?),
    pinHash: map['pin_hash']! as String,
    avatarColor: map['avatar_color']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['created_at']! as int,
      isUtc: true,
    ),
  );

  TeamMember copyWith({
    String? name,
    String? email,
    String? jobTitle,
    MemberRole? role,
    String? pinHash,
    int? avatarColor,
  }) => TeamMember(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    jobTitle: jobTitle ?? this.jobTitle,
    role: role ?? this.role,
    pinHash: pinHash ?? this.pinHash,
    avatarColor: avatarColor ?? this.avatarColor,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          jobTitle == other.jobTitle &&
          role == other.role &&
          pinHash == other.pinHash &&
          avatarColor == other.avatarColor &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    jobTitle,
    role,
    pinHash,
    avatarColor,
    createdAt,
  );
}
