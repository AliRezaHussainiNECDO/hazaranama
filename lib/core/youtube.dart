/// شناسه‌ی ویدیوی یوتیوب از لینک‌های رایج (watch، youtu.be، shorts، embed)؛ اگر یوتیوب نباشد null.
String? youtubeId(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.hasScheme) return null;
  final host = u.host.replaceFirst('www.', '').replaceFirst('m.', '');
  String? id;
  if (host == 'youtu.be') {
    id = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
  } else if (host == 'youtube.com' || host == 'music.youtube.com' || host == 'youtube-nocookie.com') {
    if (u.path == '/watch') {
      id = u.queryParameters['v'];
    } else if (u.pathSegments.length >= 2 && const ['shorts', 'embed', 'live', 'v'].contains(u.pathSegments.first)) {
      id = u.pathSegments[1];
    }
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(id)) return null;
  return id;
}

String youtubeThumb(String id) => 'https://img.youtube.com/vi/$id/hqdefault.jpg';
