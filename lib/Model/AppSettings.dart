class AppSettings {
  final bool success;
  final String message;
  final AppSettingsData data;

  AppSettings({
    required this.success,
    required this.message,
    required this.data,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: AppSettingsData.fromJson(json['data'] ?? {}),
    );
  }
}

class AppSettingsData {
  final int appVersion;
  final String? playStoreUrl;

  AppSettingsData({
    required this.appVersion,
    this.playStoreUrl,
  });

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    return AppSettingsData(
      appVersion: json['app_version'] ?? 0,
      playStoreUrl: json['play_store_url'],
    );
  }
}
