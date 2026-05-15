import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';

/// Provider class that manages audio streaming state and UDP communication
class AudioProvider extends ChangeNotifier {
  static const EventChannel _audioChannel = EventChannel('com.mymic/audio_stream');
  
  String _ipAddress = '192.168.1.100';
  String _status = 'ready'; // ready, streaming, error
  String? _errorMessage;
  bool _isStreaming = false;
  
  RawDatagramSocket? _socket;
  StreamSubscription<dynamic>? _audioSubscription;
  
  // Audio configuration
  static const int sampleRate = 48000;
  static const int bitDepth = 16;
  static const int channels = 1;
  static const int port = 55555;
  static const int chunkSize = 4800; // ~100ms of audio
  
  String get ipAddress => _ipAddress;
  String get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isStreaming => _isStreaming;
  
  void setIpAddress(String ip) {
    _ipAddress = ip;
    notifyListeners();
  }
  
  /// Initialize and start audio streaming
  Future<void> startStreaming() async {
    try {
      _setStatus('streaming');
      _errorMessage = null;
      notifyListeners();
      
      // Create UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      // Listen to native audio stream
      _audioSubscription = _audioChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Uint8List && _socket != null && _isStreaming) {
            _sendAudioData(event);
          }
        },
        onError: (error) {
          _setError('Audio stream error: $error');
        },
        onDone: () {
          if (_isStreaming) {
            _setError('Audio stream ended unexpectedly');
          }
        },
      );
      
      _isStreaming = true;
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to start streaming: $e');
    }
  }
  
  /// Stop audio streaming and cleanup resources
  Future<void> stopStreaming() async {
    _isStreaming = false;
    
    // Cancel audio subscription
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    
    // Close socket
    _socket?.close();
    _socket = null;
    
    _setStatus('ready');
    notifyListeners();
  }
  
  /// Send audio data via UDP
  void _sendAudioData(Uint8List data) {
    if (_socket == null || !_isStreaming) return;
    
    try {
      final address = InternetAddress(_ipAddress);
      _socket!.send(data, address, port);
    } catch (e) {
      // Silently ignore send errors to avoid spam during network issues
      // The error will be caught if connection is completely lost
    }
  }
  
  void _setStatus(String status) {
    _status = status;
    if (status != 'error') {
      _errorMessage = null;
    }
  }
  
  void _setError(String message) {
    _status = 'error';
    _errorMessage = message;
    _isStreaming = false;
  }
  
  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
