import 'package:flutter/material.dart';

import '../../data/models/team_member.dart';

/// Initials avatar on a member-specific color.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initials,
    required this.color,
    this.size = 40,
    this.semanticLabel,
  });

  /// Unassigned placeholder.
  const AvatarCircle.unassigned({super.key, this.size = 40})
    : initials = '?',
      color = 0xFF94A3B8,
      semanticLabel = 'Unassigned';

  AvatarCircle.member(TeamMember member, {super.key, this.size = 40})
    : initials = member.initials,
      color = member.avatarColor,
      semanticLabel = member.name;

  final String initials;
  final int color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
        child: Text(
          initials,
          // Avatar text should not blow up with the system text scale.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
