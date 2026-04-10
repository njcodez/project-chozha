class Job {
  final String jobId;
  final String username;
  final String? title;
  final String? description;
  final String status;
  final String? errorMessage;
  final bool isPublic;
  final String createdAt;
  final String updatedAt;
  final String inputImageUrl;
  final String? outputImageUrl;

  const Job({
    required this.jobId,
    required this.username,
    this.title,
    this.description,
    required this.status,
    this.errorMessage,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    required this.inputImageUrl,
    this.outputImageUrl,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isTerminal => isDone || isFailed;

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        jobId: j['job_id'] as String,
        username: j['username'] as String,
        title: j['title'] as String?,
        description: j['description'] as String?,
        status: j['status'] as String,
        errorMessage: j['error_message'] as String?,
        isPublic: j['is_public'] as bool? ?? true,
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String,
        inputImageUrl: j['input_image_url'] as String,
        outputImageUrl: j['output_image_url'] as String?,
      );

  Job copyWith({
    String? title,
    String? description,
    String? status,
    String? outputImageUrl,
    bool? isPublic,
  }) =>
      Job(
        jobId: jobId,
        username: username,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        errorMessage: errorMessage,
        isPublic: isPublic ?? this.isPublic,
        createdAt: createdAt,
        updatedAt: updatedAt,
        inputImageUrl: inputImageUrl,
        outputImageUrl: outputImageUrl ?? this.outputImageUrl,
      );
}
