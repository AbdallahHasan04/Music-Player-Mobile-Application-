class Song {
  final String songName;
  final String artistName;
  final String albumArtImagePath; // asset path OR network URL
  final String audioPath;         // asset path OR network URL
  final bool isNetworkSource;     // true = use NetworkSource / Image.network

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.audioPath,
    this.isNetworkSource = false,
  });

  Map<String, dynamic> toMap() => {
        'songName': songName,
        'artistName': artistName,
        'albumArtImagePath': albumArtImagePath,
        'audioPath': audioPath,
        'isNetworkSource': isNetworkSource,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        songName: map['songName'] ?? '',
        artistName: map['artistName'] ?? '',
        albumArtImagePath: map['albumArtImagePath'] ?? '',
        audioPath: map['audioPath'] ?? '',
        isNetworkSource: map['isNetworkSource'] ?? false,
      );
}
