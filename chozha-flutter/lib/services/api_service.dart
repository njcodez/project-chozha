import 'dart:io';
import 'package:dio/dio.dart';
import '../models/job.dart';
import '../models/job_list_item.dart';

class ApiService {
  final Dio _dio;

  ApiService(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  // ── Health ──────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get('/health');
      return res.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ── Username ────────────────────────────────────────────
  Future<bool> isUsernameTaken(String username) async {
    final res = await _dio.get('/usernames/check',
        queryParameters: {'username': username});
    return res.data['taken'] as bool;
  }

  // ── Jobs list ───────────────────────────────────────────
  Future<List<JobListItem>> getJobs({String? username}) async {
    final res = await _dio.get(
      '/jobs',
      queryParameters: username != null ? {'username': username} : null,
    );
    final items = res.data['items'] as List<dynamic>;
    return items
        .map((e) => JobListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Job detail ──────────────────────────────────────────
  Future<Job> getJob(String jobId) async {
    final res = await _dio.get('/jobs/$jobId');
    return Job.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Create job ──────────────────────────────────────────
  Future<String> createJob({
    required File image,
    required String username,
    bool isPublic = true,
    String? title,
    String? description,
  }) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path),
      'username': username,
      'is_public': isPublic ? 'true' : 'false',
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
    final res = await _dio.post('/jobs', data: form);
    return res.data['job_id'] as String;
  }

  // ── Update job ──────────────────────────────────────────
  Future<Job> updateJob(
    String jobId, {
    String? title,
    String? description,
    bool? isPublic,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (isPublic != null) body['is_public'] = isPublic;
    final res = await _dio.patch('/jobs/$jobId', data: body);
    return Job.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Delete job ──────────────────────────────────────────
  Future<void> deleteJob(String jobId, String masterPassword) async {
    await _dio.delete(
      '/jobs/$jobId',
      data: {'master_password': masterPassword},
    );
  }

  // ── Image URLs (resolved, not fetched) ──────────────────
  String inputImageUrl(String baseUrl, String jobId) =>
      '$baseUrl/jobs/$jobId/input';
  String outputImageUrl(String baseUrl, String jobId) =>
      '$baseUrl/jobs/$jobId/output';

  // ── Binary download (for save to gallery) ───────────────
  Future<String> downloadOutputImage(String jobId, String savePath) async {
    await _dio.download('/jobs/$jobId/output', savePath);
    return savePath;
  }
}
