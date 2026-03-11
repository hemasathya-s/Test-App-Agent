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
      // Parsing app_version as int. It might be a string in the JSON "0"
      appVersion: int.tryParse(json['partner_app_version'].toString()) ?? 0,
      playStoreUrl: json['partner_app_play_store_url'],
    );
  }
}
