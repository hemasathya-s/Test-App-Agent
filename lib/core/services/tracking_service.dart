import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'apiservices.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  Timer? _timer;
  bool _isOnline = false;
  WebSocketChannel? _channel;

  double? _destLat;
  double? _destLng;

  bool _isConnecting = false;
  bool _reconnectScheduled = false;

  /// SET AGENT ONLINE / OFFLINE
  Future<void> setOnlineStatus(bool online) async {
    if (_isOnline == online) return;

    _isOnline = online;
    debugPrint("[TRACKING] Agent status: ${online ? 'ONLINE' : 'OFFLINE'}");

    if (online) {
      _startTracking();
    } else {
      _stopTracking();
    }
  }

  /// UPDATE DESTINATION
  void updateDestination(double lat, double lng) {
    _destLat = lat;
    _destLng = lng;
    debugPrint("[TRACKING] Destination updated: $lat , $lng");
  }

  /// BUILD WEBSOCKET URI
  /// Using Uri.parse() on a plain string avoids the Dart Uri() constructor
  /// injecting port :0 for an unknown scheme (wss has no default in Dart).
  Future<Uri> _buildWsUri() async {
    final base = ApiService.wsBaseUrl.replaceAll(RegExp(r'/$'), '');
    final token = await ApiService.getAccessToken(); // await the Future
    return Uri.parse('$base/ws/api/tracking/log/?token=$token');
  }

  /// CONNECT WEBSOCKET
  Future<void> _connectWebSocket() async {
    final token = await ApiService.getAccessToken();
    if (_channel != null ||
        token == null ||
        !_isOnline ||
        _isConnecting) return;

    _isConnecting = true;

    final uri = await _buildWsUri();
    debugPrint("[TRACKING] Connecting to WS: $uri");

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          debugPrint("[TRACKING] WS MESSAGE: $message");
        },
        onError: (error) {
          debugPrint("[TRACKING] WS ERROR in tracking: $error");
          _handleDisconnect();
        },
        onDone: () {
          debugPrint("[TRACKING] WS CLOSED by server");
          _handleDisconnect();
        },
        // false so the subscription is not auto-cancelled on error;
        // onError callback already handles cleanup.
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("[TRACKING] WS CONNECTION EXCEPTION: $e");
      _channel = null;
      _scheduleReconnect();
    } finally {
      // Always clear the connecting flag once setup attempt completes.
      _isConnecting = false;
    }
  }

  /// HANDLE DISCONNECT + AUTO RECONNECT
  void _handleDisconnect() {
    _closeWebSocket();
    if (!_isOnline) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectScheduled || !_isOnline) return;
    _reconnectScheduled = true;
    debugPrint("[TRACKING] Reconnecting WS in 10 seconds...");
    Future.delayed(const Duration(seconds: 10), () {
      _reconnectScheduled = false;
      if (_isOnline) {
        _connectWebSocket();
      }
    });
  }

  /// CLOSE WEBSOCKET
  void _closeWebSocket() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnecting = false;
  }

  /// START PERIODIC TRACKING
  void _startTracking() {
    if (_timer != null) return; // already running

    debugPrint("[TRACKING] Tracking started (60s interval)");
    _connectWebSocket();

    // Immediate first send, then every 60 seconds
    _sendLocationUpdate();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendLocationUpdate(),
    );
  }

  /// STOP TRACKING
  void _stopTracking() {
    _timer?.cancel();
    _timer = null;
    _reconnectScheduled = false;
    _closeWebSocket();
    debugPrint("[TRACKING] Tracking stopped");
  }

  /// SEND LOCATION UPDATE
  Future<void> _sendLocationUpdate() async {
    if (!_isOnline) return;

    // If channel is gone and no reconnect in progress, kick one off
    if (_channel == null && !_isConnecting && !_reconnectScheduled) {
      _connectWebSocket();
    }

    // Don't try to send while still connecting or channel is null
    if (_channel == null || _isConnecting) {
      debugPrint("[TRACKING] Skipping send — WS not ready.");
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("[TRACKING] Location services are disabled.");
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint("[TRACKING] getCurrentPosition failed, trying last known: $e");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint("[TRACKING] No position available.");
        return;
      }

      // Helper to ensure values fit in backend DecimalField(max_digits=5, decimal_places=2)
      // and satisfies "no more than 3 digits before the decimal point" (max_whole_digits=3)
      String formatForBackend(double value) {
        double absValue = value.abs();
        if (absValue >= 1000) {
          // Cap at 999.99 to satisfy max_whole_digits=3 and max_digits=5
          return "999.99";
        } else if (absValue >= 100) {
          // e.g. 123.45 -> satisfies max_whole_digits=3 and max_digits=5
          return value.toStringAsFixed(2);
        } else {
          // e.g. 12.34
          return value.toStringAsFixed(2);
        }
      }

      final Map<String, dynamic> data = {
        "latitude": position.latitude.toString(),
        "longitude": position.longitude.toString(),
        "accuracy": formatForBackend(position.accuracy),
        "speed": formatForBackend(position.speed),
        "heading": formatForBackend(position.heading),
        "battery_level": 100,
        "is_mock_location": position.isMocked,
      };

      debugPrint ("latitude: ${position.latitude} longitude: ${position.longitude}, accuracy: ${data['accuracy']}, speed: ${data['speed']}, heading: ${data['heading']}");

      if (_destLat != null && _destLng != null) {
        data["destination_latitude"] = _destLat.toString();
        data["destination_longitude"] = _destLng.toString();
      }

      // Guard: channel might have dropped while we were getting position
      if (_channel == null) {
        debugPrint("[TRACKING] Channel lost before send — will retry next tick.");
        return;
      }

      final payload = jsonEncode(data);
      try {
        _channel!.sink.add(payload);
       // debugPrint("[TRACKING] SYNCED: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        debugPrint("[TRACKING] Sink send failed: $e");
        _handleDisconnect();
      }
    } catch (e) {
      debugPrint("[TRACKING] LOCATION ERROR: $e");
    }
  }

  Future<void> sendLocationFromBackground() async {
    await _sendLocationUpdate();
  }
}
