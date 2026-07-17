/// An image reference as returned by the API (covers, screenshots, etc.).
class ImageRef {
  const ImageRef({
    this.id,
    this.url,
    this.dims,
    this.sexual,
    this.violence,
    this.votecount,
    this.thumbnail,
    this.thumbnailDims,
  });

  final String? id;
  final String? url;
  final List<int>? dims;
  final num? sexual;
  final num? violence;
  final int? votecount;
  final String? thumbnail;
  final List<int>? thumbnailDims;

  factory ImageRef.fromJson(Map<String, dynamic> json) {
    return ImageRef(
      id: json['id'] as String?,
      url: json['url'] as String?,
      dims: (json['dims'] as List?)?.map((e) => e as int).toList(),
      sexual: json['sexual'] as num?,
      violence: json['violence'] as num?,
      votecount: json['votecount'] as int?,
      thumbnail: json['thumbnail'] as String?,
      thumbnailDims:
          (json['thumbnail_dims'] as List?)?.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (url != null) 'url': url,
        if (dims != null) 'dims': dims,
        if (sexual != null) 'sexual': sexual,
        if (violence != null) 'violence': violence,
        if (votecount != null) 'votecount': votecount,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (thumbnailDims != null) 'thumbnail_dims': thumbnailDims,
      };

  String get displayUrl => thumbnail ?? url ?? '';
}
