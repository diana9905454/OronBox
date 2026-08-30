class TeamMember {
  const TeamMember({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.githubUrl,
  });

  final String name;
  final TeamRole role;
  final String avatarAsset;
  final String githubUrl;
}

enum TeamRole {
  mainDeveloperDesigner,
  zeppOSImplementation,
  harmonyAdaptation,
}

abstract final class AppConstants {
  static const String githubRepoUrl = 'https://github.com/zxor-org/OronBox';
  static const String githubRepoApiUrl =
      'https://api.github.com/repos/zxor-org/OronBox';
  static const String websiteUrl = 'https://oronbox.zxor.org';
  static const String androidCloudDownloadUrl =
      'https://cpwdxbd.lanzoue.com/oronbox';

  static const List<TeamMember> teamMembers = [
    TeamMember(
      name: 'OrPudding',
      role: TeamRole.mainDeveloperDesigner,
      avatarAsset: 'assets/images/team/orpudding.jpg',
      githubUrl: 'https://github.com/orpudding',
    ),
    TeamMember(
      name: 'zxxhcj',
      role: TeamRole.zeppOSImplementation,
      avatarAsset: 'assets/images/team/zxxhcj.jpg',
      githubUrl: 'https://github.com/zxxhcj',
    ),
  ];

  // 特别感谢：非项目核心成员，但对项目有重要贡献（如 HarmonyOS 移植）。
  static const List<TeamMember> specialThanks = [
    TeamMember(
      name: 'Diana',
      role: TeamRole.harmonyAdaptation,
      avatarAsset: 'assets/images/team/diana.jpg',
      githubUrl: 'https://github.com/diana9905454',
    ),
  ];
}
