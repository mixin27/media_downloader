import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class NetworkUtils {
  static final NetworkUtils instance = NetworkUtils._init();
  final Connectivity _connectivity = Connectivity();

  StreamController<ConnectivityResult>? _connectivityController;
  Stream<ConnectivityResult>? _connectivityStream;

  NetworkUtils._init();

  Stream<ConnectivityResult> get connectivityStream {
    _connectivityController ??=
        StreamController<ConnectivityResult>.broadcast();
    _connectivityStream ??= _connectivity.onConnectivityChanged
        .map(
          (results) =>
              results.isNotEmpty ? results.first : ConnectivityResult.none,
        )
        .distinct();

    _connectivityStream!.listen((result) {
      _connectivityController!.add(result);
    });

    return _connectivityController!.stream;
  }

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.first != ConnectivityResult.none;
  }

  Future<bool> isWifiConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.first == ConnectivityResult.wifi;
  }

  Future<bool> isMobileConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.first == ConnectivityResult.mobile;
  }

  Future<ConnectivityResult> getConnectionType() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty ? results.first : ConnectivityResult.none;
  }

  Future<int?> getFileSize(String url, {Map<String, String>? headers}) async {
    try {
      final response = await http.head(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        return contentLength != null ? int.parse(contentLength) : null;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  void dispose() {
    _connectivityController?.close();
  }
}

class SpeedCalculator {
  DateTime? _startTime;
  int _previousBytes = 0;
  final List<double> _speedSamples = [];
  static const int _maxSamples = 10;

  void start() {
    _startTime = DateTime.now();
    _previousBytes = 0;
    _speedSamples.clear();
  }

  double calculateSpeed(int currentBytes) {
    if (_startTime == null) {
      start();
      return 0.0;
    }

    final now = DateTime.now();
    final duration = now.difference(_startTime!);

    if (duration.inMilliseconds < 100) {
      return _speedSamples.isNotEmpty ? _speedSamples.last : 0.0;
    }

    final bytesDownloaded = currentBytes - _previousBytes;
    final speed = bytesDownloaded / (duration.inMilliseconds / 1000);

    _speedSamples.add(speed);
    if (_speedSamples.length > _maxSamples) {
      _speedSamples.removeAt(0);
    }

    _previousBytes = currentBytes;
    _startTime = now;

    return _getAverageSpeed();
  }

  double _getAverageSpeed() {
    if (_speedSamples.isEmpty) return 0.0;
    return _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;
  }

  Duration? estimateTimeRemaining(
    int currentBytes,
    int totalBytes,
    double speed,
  ) {
    if (speed <= 0 || currentBytes >= totalBytes) return null;

    final remainingBytes = totalBytes - currentBytes;
    final secondsRemaining = remainingBytes / speed;

    return Duration(seconds: secondsRemaining.round());
  }

  void reset() {
    _startTime = null;
    _previousBytes = 0;
    _speedSamples.clear();
  }
}
