class Paged<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  const Paged(this.items, this.total, this.limit, this.offset);

  bool get hasMore => offset + items.length < total;

  static Paged<T> parse<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) {
    final items = ((j['items'] as List?) ?? const []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    return Paged<T>(items, (j['total'] as num?)?.toInt() ?? items.length, (j['limit'] as num?)?.toInt() ?? 20,
        (j['offset'] as num?)?.toInt() ?? 0);
  }
}

class PublicConfig {
  final int maxUploadMb;
  final double minVideoSeconds;
  final double maxVideoSeconds;
  final List<String> allowedExtensions;
  const PublicConfig({
    this.maxUploadMb = 50,
    this.minVideoSeconds = 1,
    this.maxVideoSeconds = 90,
    this.allowedExtensions = const ['mp4', 'webm', 'mov'],
  });

  factory PublicConfig.fromJson(Map<String, dynamic> j) => PublicConfig(
        maxUploadMb: (j['max_upload_mb'] as num).toInt(),
        minVideoSeconds: (j['min_video_seconds'] as num).toDouble(),
        maxVideoSeconds: (j['max_video_seconds'] as num).toDouble(),
        allowedExtensions: ((j['allowed_extensions'] as List).map((e) => e.toString())).toList(),
      );
}

class Project {
  final String id;
  final String name;
  final String? description;
  final String? platform;
  final String? niche;
  final String? targetAudience;
  final int analysisCount;
  final String createdAt;
  final String updatedAt;
  const Project({
    required this.id,
    required this.name,
    this.description,
    this.platform,
    this.niche,
    this.targetAudience,
    this.analysisCount = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        platform: j['platform'] as String?,
        niche: j['niche'] as String?,
        targetAudience: j['target_audience'] as String?,
        analysisCount: (j['analysis_count'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] as String?) ?? '',
        updatedAt: (j['updated_at'] as String?) ?? '',
      );
}

class VideoItem {
  final String id;
  final String projectId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final double? durationSeconds;
  final String createdAt;
  const VideoItem({
    required this.id,
    required this.projectId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.durationSeconds,
    this.createdAt = '',
  });

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: j['id'] as String,
        projectId: j['project_id'] as String,
        filename: j['original_filename'] as String,
        mimeType: j['mime_type'] as String,
        sizeBytes: (j['size_bytes'] as num).toInt(),
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble(),
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

class Job {
  final String id;
  final String projectId;
  final String? projectName;
  final String? videoId;
  final String inputType;
  final String platform;
  final String niche;
  final String targetAudience;
  final String? caption;
  final String status; // queued | processing | completed | failed
  final String stage;
  final int progress;
  final int attempts;
  final int maxAttempts;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;
  final Map<String, int>? scores;
  final String createdAt;
  final String? completedAt;

  const Job({
    required this.id,
    required this.projectId,
    this.projectName,
    this.videoId,
    this.inputType = 'video',
    this.platform = 'tiktok',
    this.niche = '',
    this.targetAudience = '',
    this.caption,
    required this.status,
    this.stage = '',
    this.progress = 0,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
    this.scores,
    this.createdAt = '',
    this.completedAt,
  });

  bool get isActive => status == 'queued' || status == 'processing';
  bool get isBlocked => errorCode == 'content_blocked';
  int? get overall => scores?['overall'];

  factory Job.fromJson(Map<String, dynamic> j) {
    final s = j['scores'];
    return Job(
      id: j['id'] as String,
      projectId: j['project_id'] as String,
      projectName: j['project_name'] as String?,
      videoId: j['video_id'] as String?,
      inputType: (j['input_type'] as String?) ?? 'video',
      platform: (j['platform'] as String?) ?? 'tiktok',
      niche: (j['niche'] as String?) ?? '',
      targetAudience: (j['target_audience'] as String?) ?? '',
      caption: j['caption'] as String?,
      status: j['status'] as String,
      stage: (j['stage'] as String?) ?? '',
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (j['max_attempts'] as num?)?.toInt() ?? 3,
      errorCode: j['error_code'] as String?,
      errorMessage: j['error_message'] as String?,
      retryable: (j['retryable'] as bool?) ?? false,
      scores: s is Map ? s.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) : null,
      createdAt: (j['created_at'] as String?) ?? '',
      completedAt: j['completed_at'] as String?,
    );
  }
}

class JobDetail {
  final Job job;
  final Report? report;
  const JobDetail(this.job, this.report);

  factory JobDetail.fromJson(Map<String, dynamic> j) {
    final r = j['report'];
    return JobDetail(Job.fromJson(j), r is Map ? Report(Map<String, dynamic>.from(r)) : null);
  }
}

List<Map<String, dynamic>> _maps(dynamic v) =>
    ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// Typed accessors over the report JSON produced by the backend (see docs/API.md).
class Report {
  final Map<String, dynamic> raw;
  const Report(this.raw);

  Map<String, int> get scores =>
      ((raw['scores'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  int get overall => scores['overall'] ?? 0;
  String get verdict => (raw['verdict'] as String?) ?? '';
  String get platform => (raw['platform'] as String?) ?? '';
  String get niche => (raw['niche'] as String?) ?? '';
  String get summary => (raw['content_summary'] as String?) ?? '';
  String get confidence => (raw['confidence'] as String?) ?? '';
  String get confidenceNote => (raw['confidence_note'] as String?) ?? '';
  String get disclaimer => (raw['disclaimer'] as String?) ?? '';
  String get model => (raw['model'] as String?) ?? '';
  String get generatedAt => (raw['generated_at'] as String?) ?? '';
  String get inputType => (raw['input_type'] as String?) ?? 'video';

  List<String> get strengths => ((raw['strengths'] as List?) ?? const []).map((e) => e.toString()).toList();
  List<String> get weaknesses => ((raw['weaknesses'] as List?) ?? const []).map((e) => e.toString()).toList();
  List<Map<String, dynamic>> get dimensions => _maps(raw['dimensions']);
  List<Map<String, dynamic>> get recommendations => _maps(raw['recommendations']);
  List<Map<String, dynamic>> get observations => _maps(raw['observations']);

  Map<String, dynamic> get rubric => Map<String, dynamic>.from((raw['rubric'] as Map?) ?? const {});
  Map<String, String> get formulas =>
      ((rubric['formulas'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString()));

  Personas get personas => Personas(Map<String, dynamic>.from((raw['personas'] as Map?) ?? const {}));
}

class Personas {
  final Map<String, dynamic> raw;
  const Personas(this.raw);
  String get status => (raw['status'] as String?) ?? 'failed'; // complete | partial | failed
  int get expected => (raw['expected'] as num?)?.toInt() ?? 10;
  int get received => (raw['received'] as num?)?.toInt() ?? 0;
  String? get note => raw['note'] as String?;
  String get label => (raw['label'] as String?) ?? 'AI-simulated reactions. Not real audience research.';
  List<Map<String, dynamic>> get items => _maps(raw['items']);
}
