class JobListItem {
  final String jobId;
  final String username;
  final String? title;
  final String status;
  final String createdAt;
  final String inputImageUrl;

  const JobListItem({
    required this.jobId,
    required this.username,
    this.title,
    required this.status,
    required this.createdAt,
    required this.inputImageUrl,
  });

  factory JobListItem.fromJson(Map<String, dynamic> j) => JobListItem(
        jobId: j['job_id'] as String,
        username: j['username'] as String,
        title: j['title'] as String?,
        status: j['status'] as String,
        createdAt: j['created_at'] as String,
        inputImageUrl: j['input_image_url'] as String,
      );
}
