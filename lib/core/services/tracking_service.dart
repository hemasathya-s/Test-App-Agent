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
  Uri _buildWsUri() {
    final base = ApiService.wsBaseUrl.replaceAll(RegExp(r'/$'), '');
    final token = ApiService.accessToken.trim();
    return Uri.parse('$base/ws/api/tracking/log/?token=$token');
  }

  /// CONNECT WEBSOCKET
  void _connectWebSocket() {
    if (_channel != null ||
        ApiService.accessToken.isEmpty ||
        !_isOnline ||
        _isConnecting) return;

    _isConnecting = true;

    final uri = _buildWsUri();
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
      const Duration(seconds: 60),
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

      final Map<String, dynamic> data = {
        "latitude": position.latitude.toString(),
        "longitude": position.longitude.toString(),
        "accuracy": position.accuracy.toStringAsFixed(2),
        "speed": position.speed.toStringAsFixed(2),
        "heading": position.heading.toStringAsFixed(2),
        "battery_level": 100,
        "is_mock_location": position.isMocked,
      };
      print ("latitude: ${position.latitude.toString()}longitude: ${position.longitude.toString()},accuracy: ${position.accuracy.toStringAsFixed(2)},speed: ${position.speed.toStringAsFixed(2)},heading: ${position.heading.toStringAsFixed(2)},battery_level: 100,is_mock_location: ${position.isMocked},");

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
        debugPrint("[TRACKING] SYNCED: ${position.latitude}, ${position.longitude}");
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
