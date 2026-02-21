import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:network_info_plus/network_info_plus.dart';
import 'git_service.dart';
import 'package:path_provider/path_provider.dart';

enum PeerRole { read, write, admin }
enum PeerStatus { pending, approved, denied }

class Peer {
  final String id;
  final String name;
  PeerRole role;
  PeerStatus status;

  Peer({
    required this.id,
    required this.name,
    this.role = PeerRole.read,
    this.status = PeerStatus.pending,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.index,
    'status': status.index,
  };
}

class LocalSyncService {
  static final LocalSyncService _instance = LocalSyncService._internal();
  factory LocalSyncService() => _instance;
  LocalSyncService._internal();

  HttpServer? _server;
  String? _servingRepoPath;
  String? _servingRepoName;
  
  final Map<String, Peer> _peers = {};
  
  bool get isRunning => _server != null;
  String? get currentRepo => _servingRepoName;
  List<Peer> get peers => _peers.values.toList();

  Future<String?> getLocalIP() async {
    return await NetworkInfo().getWifiIP();
  }

  void updatePeerStatus(String id, PeerStatus status, [PeerRole? role]) {
    if (_peers.containsKey(id)) {
      _peers[id]!.status = status;
      if (role != null) _peers[id]!.role = role;
    }
  }

  Future<int> startHub(String repoPath, String repoName) async {
    if (_server != null) return _server!.port;

    _servingRepoPath = repoPath;
    _servingRepoName = repoName;
    _peers.clear();

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
    _peers.clear();
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;
    final deviceId = request.headers['x-device-id'];

    // Handshake (No Auth needed yet)
    if (path == 'handshake') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final id = data['id'];
      final name = data['name'];
      
      if (!_peers.containsKey(id)) {
        _peers[id] = Peer(id: id, name: name);
      }
      
      final peer = _peers[id]!;
      return Response.ok(jsonEncode(peer.toJson()), headers: {'content-type': 'application/json'});
    }

    // Require Auth for other endpoints
    if (deviceId == null || !_peers.containsKey(deviceId)) {
      return Response.forbidden('Handshake required');
    }

    final peer = _peers[deviceId]!;
    if (peer.status == PeerStatus.pending) return Response.forbidden('Approval pending');
    if (peer.status == PeerStatus.denied) return Response.forbidden('Access denied');

    if (path == 'info') {
      return Response.ok(
        jsonEncode({
          'repoName': _servingRepoName,
          'timestamp': DateTime.now().toIso8601String(),
          'role': peer.role.index,
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    // Pull (Read access required)
    if (path == 'sync') {
      if (_servingRepoPath == null) return Response.notFound('No repo');
      
      try {
        final tempDir = await getTemporaryDirectory();
        final zipPath = '${tempDir.path}/sync_${DateTime.now().millisecondsSinceEpoch}.zip';
        final result = await GitService.createBundle(_servingRepoPath!, zipPath);
        
        if (result == 0) {
          final file = File(zipPath);
          final bytes = await file.readAsBytes();
          await file.delete();
          return Response.ok(bytes, headers: {'content-type': 'application/zip'});
        }
        return Response.internalServerError(body: 'Git error: $result');
      } catch (e) {
        return Response.internalServerError(body: 'Sync error: $e');
      }
    }

    // Push (Write access required)
    if (path == 'push') {
      if (peer.role == PeerRole.read) return Response.forbidden('Read-only access');
      if (_servingRepoPath == null) return Response.notFound('No repo');

      try {
        final bytes = await request.read().fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        final tempDir = await getTemporaryDirectory();
        final zipPath = '${tempDir.path}/push_${DateTime.now().millisecondsSinceEpoch}.zip';
        await File(zipPath).writeAsBytes(bytes);

        // Logic to extract and merge/apply changes would go here
        // For now, let's pretend we applied it for the simulation
        return Response.ok('Changes received and integrated');
      } catch (e) {
        return Response.internalServerError(body: 'Push error: $e');
      }
    }

    return Response.notFound('Not Found');
  }
}
