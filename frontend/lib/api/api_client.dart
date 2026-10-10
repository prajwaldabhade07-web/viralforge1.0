import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;

import '../models.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  const ApiException(this.status, this.code, this.message);

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Thin typed wrapper over the versioned REST API (see docs/API.md).
class ApiClient {
  final Dio _dio;
  final Future<String?> Function() _token;
  final void Function()? _onUnauthorized;

  ApiClient({
    required String baseUrl,
    required Future<String?> Function() token,
    void Function()? onUnauthorized,
    Dio? dio,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            )),
        _token = token,
        _onUnauthorized = onUnauthorized;

  Future<T> _run<T>(Future<Response<dynamic>> Function(Options auth) call, T Function(dynamic data) parse) async {
    final token = await _token();
    final options = Options(headers: {if (token != null) 'Authorization': 'Bearer $token'});
    try {
      final res = await call(options);
      return parse(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  ApiException _toException(DioException e) {
    if (e.type == DioExceptionType.cancel) return const ApiException(0, 'cancelled', 'Upload cancelled.');
    final res = e.response;
    if (res == null) {
      return const ApiException(
          0, 'network_error', 'Cannot reach the ViralForge server. Check that the backend is running and try again.');
    }
    final data = res.data;
    var code = 'http_error';
    var message = 'Something went wrong (HTTP ${res.statusCode}).';
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = (err['code'] as String?) ?? code;
      message = (err['message'] as String?) ?? message;
      final details = err['details'];
      if (code == 'validation_error' && details is List && details.isNotEmpty && details.first is Map) {
        final d = details.first as Map;
        message = '${d['field'] ?? 'Input'}: ${d['message']}';
      }
    }
    final status = res.statusCode ?? 0;
    if (status == 401) _onUnauthorized?.call();
    return ApiException(status, code, message);
  }

  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);

  // ---- public config / health
  Future<PublicConfig> getConfig() => _run((o) => _dio.get('/config', options: o), (d) => PublicConfig.fromJson(_map(d)));

  // ---- projects
  Future<Paged<Project>> listProjects({int limit = 50, int offset = 0}) => _run(
      (o) => _dio.get('/projects', queryParameters: {'limit': limit, 'offset': offset}, options: o),
      (d) => Paged.parse(_map(d), Project.fromJson));

  Future<Project> getProject(String id) =>
      _run((o) => _dio.get('/projects/$id', options: o), (d) => Project.fromJson(_map(d)));

  Future<Project> createProject(Map<String, dynamic> body) =>
      _run((o) => _dio.post('/projects', data: body, options: o), (d) => Project.fromJson(_map(d)));

  Future<Project> updateProject(String id, Map<String, dynamic> body) =>
      _run((o) => _dio.patch('/projects/$id', data: body, options: o), (d) => Project.fromJson(_map(d)));

  Future<void> deleteProject(String id) => _run((o) => _dio.delete('/projects/$id', options: o), (_) {});

  // ---- videos
  Future<Paged<VideoItem>> listVideos(String projectId, {int limit = 50, int offset = 0}) => _run(
      (o) => _dio.get('/projects/$projectId/videos', queryParameters: {'limit': limit, 'offset': offset}, options: o),
      (d) => Paged.parse(_map(d), VideoItem.fromJson));

  Future<VideoItem> uploadVideo(
    String projectId,
    Uint8List bytes,
    String filename, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = await _token();
    final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)});
    try {
      final res = await _dio.post(
        '/projects/$projectId/videos',
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      return VideoItem.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> deleteVideo(String id) => _run((o) => _dio.delete('/videos/$id', options: o), (_) {});

  // ---- analyses
  Future<Job> createAnalysis(String projectId, Map<String, dynamic> body) => _run(
      (o) => _dio.post('/projects/$projectId/analyses', data: body, options: o), (d) => Job.fromJson(_map(d)));

  Future<JobDetail> getAnalysis(String id) =>
      _run((o) => _dio.get('/analyses/$id', options: o), (d) => JobDetail.fromJson(_map(d)));

  Future<Job> retryAnalysis(String id) =>
      _run((o) => _dio.post('/analyses/$id/retry', options: o), (d) => Job.fromJson(_map(d)));

  Future<void> deleteAnalysis(String id) => _run((o) => _dio.delete('/analyses/$id', options: o), (_) {});

  Future<Paged<Job>> projectAnalyses(String projectId, {int limit = 50, int offset = 0}) => _run(
      (o) => _dio.get('/projects/$projectId/analyses', queryParameters: {'limit': limit, 'offset': offset}, options: o),
      (d) => Paged.parse(_map(d), Job.fromJson));

  Future<Paged<Job>> history({int limit = 20, int offset = 0}) => _run(
      (o) => _dio.get('/history', queryParameters: {'limit': limit, 'offset': offset}, options: o),
      (d) => Paged.parse(_map(d), Job.fromJson));
}

/// A video chosen by the user (picker or drag-and-drop), held in memory until uploaded.
class PickedVideo {
  final String name;
  final Uint8List bytes;
  const PickedVideo(this.name, this.bytes);
  int get size => bytes.length;

  factory PickedVideo.fromPlatformFile(PlatformFile f) => PickedVideo(f.name, f.bytes ?? Uint8List(0));
}
