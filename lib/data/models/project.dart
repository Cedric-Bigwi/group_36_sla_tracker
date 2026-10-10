class Project {
  const Project({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'start_date': startDate.millisecondsSinceEpoch,
    'end_date': endDate?.millisecondsSinceEpoch,
  };

  factory Project.fromMap(Map<String, Object?> map) => Project(
    id: map['id']! as String,
    name: map['name']! as String,
    description: map['description'] as String?,
    startDate: DateTime.fromMillisecondsSinceEpoch(
      map['start_date']! as int,
      isUtc: true,
    ),
    endDate: map['end_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            map['end_date']! as int,
            isUtc: true,
          ),
  );

  Project copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) => Project(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(id, name, description, startDate, endDate);
}
