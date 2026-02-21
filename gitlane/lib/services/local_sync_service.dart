import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:network_info_plus/network_info_plus.dart';
import 'git_service.dart';
import 'package:path_provider/path_provider.dart';

class LocalSyncService {
  static final LocalSyncService _instance = LocalSyncService._internal();
  factory LocalSyncService() => _instance;
  LocalSyncService._internal();

  HttpServer? _server;
  String? _servingRepoPath;
  String? _servingRepoName;

  bool get isRunning => _server != null;
  String? get currentRepo => _servingRepoName;

  Future<String?> getLocalIP() async {
    return await NetworkInfo().getWifiIP();
  }

  Future<int> startHub(String repoPath, String repoName) async {
    if (_server != null) return _server!.port;

    _servingRepoPath = repoPath;
    _servingRepoName = repoName;

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    _server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
    return _server!.port;
  }

  Future<void> stopHub() async {
    await _server?.close();
    _server = null;
    _servingRepoPath = null;
    _servingRepoName = null;
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    if (path == 'info') {
      return Response.ok(
        '{"repoName": "$_servingRepoName", "timestamp": "${DateTime.now().toIso8601String()}"}',
        headers: {'content-type': 'application/json'},
      );
    }

    if (path == 'sync') {
      if (_servingRepoPath == null) {
        return Response.notFound('No repository being served');
      }

      try {
        final tempDir = await getTemporaryDirectory();
        final zipPath = '${tempDir.path}/sync_temp.zip';
        
        // Ensure old temp file is gone
        final tempFile = File(zipPath);
        if (tempFile.existsSync()) tempFile.deleteSync();

        final result = await GitService.createBundle(_servingRepoPath!, zipPath);
        
        if (result == 0) {
          final bytes = await tempFile.readAsBytes();
          return Response.ok(
            bytes,
            headers: {
              'content-type': 'application/zip',
              'content-disposition': 'attachment; filename="$_servingRepoName.zip"',
            },
          );
        } else {
          return Response.internalServerError(body: 'Git Export failed: $result');
        }
      } catch (e) {
        return Response.internalServerError(body: 'Sync error: $e');
      }
    }

    return Response.notFound('Not Found');
  }
}
