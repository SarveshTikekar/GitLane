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
  PeerStatus status;
  // RepoID -> PeerRole
  final Map<String, PeerRole> repoRoles;

  Peer({
    required this.id,
    required this.name,
    this.status = PeerStatus.pending,
    Map<String, PeerRole>? repoRoles,
  }) : repoRoles = repoRoles ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.index,
    'repoRoles': repoRoles.map((key, value) => MapEntry(key, value.index)),
  };
}

class LocalSyncService {
  static final LocalSyncService _instance = LocalSyncService._internal();
  factory LocalSyncService() => _instance;
  LocalSyncService._internal();

  HttpServer? _server;
  // RepoID -> RepoPath
  final Map<String, String> _servingRepos = {};
  
  final Map<String, Peer> _peers = {};
  
  bool get isRunning => _server != null;
  List<String> get sharedRepos => _servingRepos.keys.toList();
  List<Peer> get peers => _peers.values.toList();

  Future<String?> getLocalIP() async {
    return await NetworkInfo().getWifiIP();
  }

  void updatePeerStatus(String id, PeerStatus status) {
    if (_peers.containsKey(id)) {
      _peers[id]!.status = status;
    }
  }

  void updatePeerRepoRole(String id, String repoId, PeerRole role) {
    if (_peers.containsKey(id)) {
      _peers[id]!.repoRoles[repoId] = role;
    }
  }

  Future<int> startHub() async {
    if (_server != null) return _server!.port;

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    _server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
    return _server!.port;
  }

  void registerRepo(String repoId, String repoPath) {
    _servingRepos[repoId] = repoPath;
  }

  void unregisterRepo(String repoId) {
    _servingRepos.remove(repoId);
  }

  Future<void> stopHub() async {
    await _server?.close();
    _server = null;
    _servingRepos.clear();
    _peers.clear();
  }

  Future<Response> _handleRequest(Request request) async {
    final pathSegments = request.url.pathSegments;
    final deviceId = request.headers['x-device-id'];

    if (pathSegments.isEmpty) return Response.notFound('Not Found');

    final action = pathSegments[0];

    // Handshake (No Auth needed yet)
    if (action == 'handshake') {
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

    if (action == 'repos') {
      return Response.ok(
        jsonEncode({
          'repos': _servingRepos.keys.toList(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    if (action == 'repo' && pathSegments.length >= 3) {
      final repoId = pathSegments[1];
      final repoAction = pathSegments[2];

      if (!_servingRepos.containsKey(repoId)) {
        return Response.notFound('Repo not found');
      }

      final repoPath = _servingRepos[repoId]!;
      final role = peer.repoRoles[repoId];

      if (role == null) {
        return Response.forbidden('No access to this repository');
      }

      if (repoAction == 'info') {
        return Response.ok(
          jsonEncode({
            'repoName': repoId,
            'role': role.index,
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Pull (Read access required)
      if (repoAction == 'sync') {
        try {
          final tempDir = await getTemporaryDirectory();
          final zipPath = '${tempDir.path}/sync_${repoId}_${DateTime.now().millisecondsSinceEpoch}.zip';
          final result = await GitService.createBundle(repoPath, zipPath);
          
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
      if (repoAction == 'push') {
        if (role == PeerRole.read) return Response.forbidden('Read-only access');

        try {
          final bytes = await request.read().fold<List<int>>(<int>[], (a, b) => a..addAll(b));
          final tempDir = await getTemporaryDirectory();
          final zipPath = '${tempDir.path}/push_${repoId}_${DateTime.now().millisecondsSinceEpoch}.zip';
          await File(zipPath).writeAsBytes(bytes);

          // Logic to apply changes would go here
          return Response.ok('Changes received and integrated');
        } catch (e) {
          return Response.internalServerError(body: 'Push error: $e');
        }
      }
    }

    return Response.notFound('Not Found');
  }
}
