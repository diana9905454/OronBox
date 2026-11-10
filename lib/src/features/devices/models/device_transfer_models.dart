import 'dart:typed_data';

class DeviceLogPullResult {
  const DeviceLogPullResult({
    required this.fileName,
    required this.data,
    this.currentLog,
  });

  final String fileName;
  final Uint8List data;
  final Uint8List? currentLog;
}

class DeviceLogPullProgress {
  const DeviceLogPullProgress({
    required this.progress,
    required this.fileName,
    required this.channel,
    required this.currentPart,
    required this.totalParts,
  });

  final double progress;
  final String fileName;
  final int channel;
  final int currentPart;
  final int totalParts;
}

class DeviceRecordingPullProgress {
  const DeviceRecordingPullProgress({
    required this.progress,
    required this.currentIndex,
    required this.totalFiles,
    required this.fileName,
    required this.currentPart,
    required this.totalParts,
    this.bytesDone,
    this.bytesTotal,
  });

  final double progress;
  final int currentIndex;
  final int totalFiles;
  final String fileName;
  final int currentPart;
  final int totalParts;
  final int? bytesDone;
  final int? bytesTotal;
}

class DeviceMusicSong {
  const DeviceMusicSong({
    required this.id,
    required this.name,
    required this.size,
    required this.duration,
    required this.album,
    required this.artist,
    this.playlistIds = const [],
  });

  final List<int> id;
  final String name;
  final int size;
  final int duration;
  final String album;
  final String artist;
  final List<int> playlistIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'duration': duration,
    'album': album,
    'artist': artist,
    'playlistIds': playlistIds,
  };

  factory DeviceMusicSong.fromJson(Map<String, Object?> json) =>
      DeviceMusicSong(
        id: (json['id'] as List).cast<num>().map((e) => e.toInt()).toList(),
        name: json['name']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        album: json['album']?.toString() ?? '',
        artist: json['artist']?.toString() ?? '',
        playlistIds: (json['playlistIds'] as List? ?? const [])
            .cast<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

class DeviceMusicPlaylist {
  const DeviceMusicPlaylist({
    required this.id,
    required this.name,
    required this.songCount,
  });

  final int id;
  final String name;
  final int songCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'songCount': songCount,
  };

  factory DeviceMusicPlaylist.fromJson(Map<String, Object?> json) =>
      DeviceMusicPlaylist(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      );
}

class DeviceMusicLibrary {
  const DeviceMusicLibrary({
    required this.songs,
    required this.playlists,
    required this.playlistLimit,
  });

  final List<DeviceMusicSong> songs;
  final List<DeviceMusicPlaylist> playlists;
  final int playlistLimit;

  Map<String, Object?> toJson() => {
    'songs': songs.map((e) => e.toJson()).toList(),
    'playlists': playlists.map((e) => e.toJson()).toList(),
    'playlistLimit': playlistLimit,
  };

  factory DeviceMusicLibrary.fromJson(Map<String, Object?> json) =>
      DeviceMusicLibrary(
        songs: (json['songs'] as List? ?? const [])
            .map((e) => DeviceMusicSong.fromJson((e as Map).cast()))
            .toList(),
        playlists: (json['playlists'] as List? ?? const [])
            .map((e) => DeviceMusicPlaylist.fromJson((e as Map).cast()))
            .toList(),
        playlistLimit: (json['playlistLimit'] as num?)?.toInt() ?? 0,
      );
}

class DeviceRecording {
  const DeviceRecording({
    required this.fileName,
    required this.data,
    this.durationSeconds,
    this.createdAt,
  });

  final String fileName;
  final Uint8List data;
  final int? durationSeconds;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'data': data.toList(growable: false),
    'durationSeconds': durationSeconds,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };

  factory DeviceRecording.fromJson(Map<String, Object?> json) =>
      DeviceRecording(
        fileName: json['fileName']?.toString() ?? 'recording.opus',
        data: Uint8List.fromList(
          (json['data'] as List? ?? const [])
              .map((value) => (value as num).toInt())
              .toList(),
        ),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['createdAt'] as num).toInt(),
              ),
      );
}
