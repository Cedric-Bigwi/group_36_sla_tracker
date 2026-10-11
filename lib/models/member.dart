class Member {
  final String username, password, name, team;
  final bool isCaptain;
  const Member({
    required this.username, required this.password, required this.name,
    required this.team, this.isCaptain = false,
  });
}
