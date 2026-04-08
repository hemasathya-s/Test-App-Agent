import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryWebSocketService {
  static const String _wsUrl = 'wss://api.itfixer199.com/ws/movements/';
  
  WebSocketChannel? _channel;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        _isConnecting = false;
        return;
      }

      final uri = Uri.parse('$_wsUrl?token=$token');

      _channel = WebSocketChannel.connect(uri);

      // Wait for the first message or error to confirm connection
      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0;
          _isConnecting = false;
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
          }
        },
        onError: (error) {
          _isConnecting = false;
          _reconnect();
        },
        onDone: () {
          _isConnecting = false;
          _reconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      _reconnect();
    }
  }

  void _reconnect() {
    if (_reconnectAttempts > 5) {
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: (2 * _reconnectAttempts).clamp(5, 30));
    

    Future.delayed(delay, () {
      if (_channel == null || _isConnecting == false) {
        connect();
      }
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
