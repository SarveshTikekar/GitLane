import 'dart:convert';
import 'package:http/http.dart' as http;
import 'git_service.dart';

enum GitHost { github, gitlab, bitbucket, unknown }

class PullRequest {
  final int number;
  final String title;
  final String author;
  final String state;
  final String url;
  final List<String> labels;
  final DateTime createdAt;

  PullRequest({
    required this.number,
    required this.title,
    required this.author,
    required this.state,
    required this.url,
    required this.labels,
    required this.createdAt,
  });

  factory PullRequest.fromGitHub(Map<String, dynamic> json) {
    return PullRequest(
      number: json['number'],
      title: json['title'],
      author: json['user']['login'],
      state: json['state'],
      url: json['html_url'],
      labels: (json['labels'] as List).map((l) => l['name'] as String).toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Issue {
  final int number;
  final String title;
  final String author;
  final String state;
  final String url;
  final List<String> labels;
  final DateTime createdAt;

  Issue({
    required this.number,
    required this.title,
    required this.author,
    required this.state,
    required this.url,
    required this.labels,
    required this.createdAt,
  });

  factory Issue.fromGitHub(Map<String, dynamic> json) {
    return Issue(
      number: json['number'],
      title: json['title'],
      author: json['user']['login'],
      state: json['state'],
      url: json['html_url'],
      labels: (json['labels'] as List).map((l) => l['name'] as String).toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class CollaborationService {
  static GitHost detectHost(String url) {
    if (url.contains('github.com')) return GitHost.github;
    if (url.contains('gitlab.com')) return GitHost.gitlab;
    if (url.contains('bitbucket.org')) return GitHost.bitbucket;
    return GitHost.unknown;
  }

  static String? extractRepoSlug(String url) {
    // Basic regex to extract 'owner/repo' from git URLs
    final regex = RegExp(r'(?:github\.com|gitlab\.com)[:/](.+?)(?:\.git|$)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  static Future<List<PullRequest>> fetchPullRequests(String repoPath) async {
    final remoteUrl = await GitService.getRemoteUrl(repoPath);
    if (remoteUrl.isEmpty) return [];

    final host = detectHost(remoteUrl);
    final slug = extractRepoSlug(remoteUrl);

    if (host == GitHost.github && slug != null) {
      final response = await http.get(Uri.parse('https://api.github.com/repos/$slug/pulls'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((pr) => PullRequest.fromGitHub(pr)).toList();
      }
    }
    // GitLab/Bitbucket implementation TBD
    return [];
  }

  static Future<List<Issue>> fetchIssues(String repoPath) async {
    final remoteUrl = await GitService.getRemoteUrl(repoPath);
    if (remoteUrl.isEmpty) return [];

    final host = detectHost(remoteUrl);
    final slug = extractRepoSlug(remoteUrl);

    if (host == GitHost.github && slug != null) {
      final response = await http.get(Uri.parse('https://api.github.com/repos/$slug/issues?state=open'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        // GitHub API returns PRs as issues too, filter them out
        return data.where((i) => i['pull_request'] == null)
                   .map((i) => Issue.fromGitHub(i)).toList();
      }
    }
    return [];
  }
}
