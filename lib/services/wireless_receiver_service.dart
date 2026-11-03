import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class WirelessReceiverService {
  static final WirelessReceiverService _instance =
      WirelessReceiverService._internal();
  factory WirelessReceiverService() => _instance;
  WirelessReceiverService._internal();

  HttpServer? _server;
  bool _isRunning = false;
  String _serverIp = '';
  int _port = 8080;

  bool get isRunning => _isRunning;
  String get serverUrl => _isRunning ? 'http://$_serverIp:$_port' : '';
  String get serverIp => _serverIp;
  int get port => _port;

  Function(String filePath, String fileName)? onAudioFileReceived;
  Function(String youtubeUrl)? onYouTubeUrlReceived;

  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _serverIp = await getLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      _server?.listen((HttpRequest request) async {
        try {
          await _handleRequest(request);
        } catch (e) {
          debugPrint('Error handling request: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('Error: $e');
            await request.response.close();
          } catch (_) {}
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error starting WirelessReceiverService: $e');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _isRunning = false;
  }

  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prefer Wi-Fi or Hotspot interfaces
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('ap') || name.contains('eth')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_buildWebPageHtml());
      await request.response.close();
    } else if (request.method == 'GET' && path == '/api/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'online',
        'app': 'Karaoke FX',
        'receiverActive': true,
      }));
      await request.response.close();
    } else if (request.method == 'POST' && path == '/api/upload') {
      await _handleFileUpload(request);
    } else if (request.method == 'POST' && path == '/api/youtube') {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final url = data['url']?.toString() ?? '';
      if (url.isNotEmpty && onYouTubeUrlReceived != null) {
        onYouTubeUrlReceived!(url);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'message': 'Memutar YouTube...'}));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
    }
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
    try {
      String fileName = 'lagu_terima_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final headerFileName = request.headers.value('x-file-name');
      if (headerFileName != null && headerFileName.isNotEmpty) {
        fileName = Uri.decodeComponent(headerFileName);
      }

      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$fileName');
      final sink = targetFile.openWrite();
      await for (final chunk in request) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      if (onAudioFileReceived != null) {
        onAudioFileReceived!(targetFile.path, fileName);
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'fileName': fileName,
        'message': 'Musik berhasil dikirim ke HP Karaoke!',
      }));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': false, 'error': e.toString()}));
      await request.response.close();
    }
  }

  String _buildWebPageHtml() {
    return '''<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Karaoke FX — Remote Music Transmitter</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: linear-gradient(135deg, #0b0f19 0%, #161b2e 100%);
      color: #e2e8f0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }
    .card {
      width: 100%;
      max-width: 520px;
      background: #1a2238;
      border: 1px solid #2d3748;
      border-radius: 20px;
      padding: 24px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
    .badge {
      display: inline-block;
      padding: 4px 10px;
      background: #00f2fe;
      color: #0b0f19;
      font-weight: 800;
      font-size: 11px;
      border-radius: 6px;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    h1 { font-size: 20px; font-weight: 700; color: #fff; margin-bottom: 6px; }
    p.sub { font-size: 13px; color: #94a3b8; margin-bottom: 20px; line-height: 1.4; }
    .status-box {
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.4);
      border-radius: 12px;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      margin-bottom: 24px;
      font-size: 13px;
      color: #34d399;
      font-weight: 600;
    }
    .dot {
      width: 10px; height: 10px;
      background: #10b981;
      border-radius: 50%;
      margin-right: 10px;
      box-shadow: 0 0 10px #10b981;
    }
    .section-title {
      font-size: 13px;
      font-weight: 700;
      color: #38bdf8;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 10px;
    }
    .upload-zone {
      border: 2px dashed #3b82f6;
      background: rgba(59, 130, 246, 0.05);
      border-radius: 14px;
      padding: 28px 16px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s ease;
      margin-bottom: 20px;
    }
    .upload-zone:hover {
      background: rgba(59, 130, 246, 0.12);
      border-color: #60a5fa;
    }
    .upload-icon { font-size: 36px; margin-bottom: 8px; }
    .upload-text { font-size: 14px; font-weight: 600; color: #fff; margin-bottom: 4px; }
    .upload-hint { font-size: 12px; color: #94a3b8; }
    input[type="file"] { display: none; }
    .divider { height: 1px; background: #2d3748; margin: 24px 0; }
    .input-group { display: flex; gap: 8px; margin-bottom: 12px; }
    input[type="text"] {
      flex: 1;
      padding: 12px 14px;
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 10px;
      color: #fff;
      font-size: 13px;
      outline: none;
    }
    input[type="text"]:focus { border-color: #38bdf8; }
    button {
      padding: 12px 18px;
      background: linear-gradient(135deg, #38bdf8, #2563eb);
      color: #fff;
      border: none;
      border-radius: 10px;
      font-weight: 700;
      font-size: 13px;
      cursor: pointer;
      transition: transform 0.1s ease;
    }
    button:active { transform: scale(0.97); }
    #msg {
      margin-top: 14px;
      padding: 12px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      display: none;
    }
    .msg-success { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #10b981; }
    .msg-error { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #ef4444; }
    .footer { margin-top: 24px; font-size: 12px; color: #64748b; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Wireless Audio Transmitter</div>
    <h1>Kirim Musik ke Karaoke FX</h1>
    <p class="sub">Pilih file lagu atau masukkan link YouTube dari HP/Laptop ini. Musik akan langsung berbunyi di HP Karaoke dan diolah oleh Equalizer Sistem!</p>

    <div class="status-box">
      <div class="dot"></div>
      <span>Terhubung ke Karaoke FX</span>
    </div>

    <div class="section-title">📁 1. Kirim File Lagu (MP3 / WAV / M4A)</div>
    <div class="upload-zone" onclick="document.getElementById('fileInput').click()">
      <div class="upload-icon">🎵</div>
      <div class="upload-text">Klik untuk Pilih Lagu dari Perangkat Ini</div>
      <div class="upload-hint">Format MP3, M4A, FLAC, atau WAV didukung</div>
      <input type="file" id="fileInput" accept="audio/*">
    </div>

    <div class="divider"></div>

    <div class="section-title">📺 2. Kirim Link YouTube Karaoke</div>
    <div class="input-group">
      <input type="text" id="ytUrl" placeholder="Tempel link YouTube karaoke di sini...">
      <button onclick="sendYoutube()">Kirim</button>
    </div>

    <div id="msg"></div>
  </div>

  <div class="footer">
    Karaoke FX Nirkabel &bull; Kualitas Suara Lossless Hi-Fi Stereo
  </div>

  <script>
    const fileInput = document.getElementById('fileInput');
    const msg = document.getElementById('msg');

    function showMsg(text, isError) {
      msg.style.display = 'block';
      msg.className = isError ? 'msg-error' : 'msg-success';
      msg.textContent = text;
    }

    fileInput.addEventListener('change', async (e) => {
      const file = e.target.files[0];
      if (!file) return;

      showMsg('Sedang mengunggah: ' + file.name + '...', false);

      try {
        const res = await fetch('/api/upload', {
          method: 'POST',
          headers: {
            'Content-Type': file.type || 'audio/mpeg',
            'x-file-name': encodeURIComponent(file.name)
          },
          body: file
        });

        const data = await res.json();
        if (data.success) {
          showMsg('✅ Berhasil! Lagu "' + file.name + '" sedang diputar di HP Karaoke!', false);
        } else {
          showMsg('❌ Gagal: ' + (data.error || 'Terjadi kesalahan'), true);
        }
      } catch (err) {
        showMsg('❌ Gagal mengirim file: ' + err.message, true);
      }
    });

    async function sendYoutube() {
      const url = document.getElementById('ytUrl').value.trim();
      if (!url) {
        showMsg('Mohon masukkan URL YouTube terlebih dahulu', true);
        return;
      }

      showMsg('Mengirim link YouTube ke HP Karaoke...', false);

      try {
        const res = await fetch('/api/youtube', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url: url })
        });
        const data = await res.json();
        if (data.success) {
          showMsg('✅ Lagu YouTube sedang dimuat di HP Karaoke!', false);
          document.getElementById('ytUrl').value = '';
        } else {
          showMsg('❌ Gagal memuat YouTube', true);
        }
      } catch (err) {
        showMsg('❌ Gagal terhubung: ' + err.message, true);
      }
    }
  </script>
</body>
</html>''';
  }
}
