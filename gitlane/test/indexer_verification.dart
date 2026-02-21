import 'dart:io';
import '../lib/services/indexer_service.dart';

void main() async {
  print("--- IndexerService Verification ---");
  
  final repoPath = Directory.current.path;
  print("Indexing repository at: $repoPath");
  
  await IndexerService.indexRepository(repoPath);
  
  // Test 1: Dart Class lookup
  final gitService = IndexerService.findSymbol('GitService');
  if (gitService != null) {
    print("✅ Found GitService at: ${gitService.path}:${gitService.line}");
  } else {
    print("❌ GitService not found");
  }

  // Test 1.5: Dart Method lookup & Docs
  final initRepo = IndexerService.findSymbol('initRepository');
  if (initRepo != null) {
    print("✅ Found initRepository at: ${initRepo.path}:${initRepo.line}");
    if (initRepo.documentation != null) {
      print("✅ Found documentation for initRepository: ${initRepo.documentation}");
    } else {
      print("❌ Documentation missing for initRepository");
    }
  } else {
    print("❌ initRepository not found");
  }

  // Test 2: Native C Function lookup
  final applyPatch = IndexerService.findSymbol('applyPatchToIndex');
  if (applyPatch != null) {
    print("✅ Found applyPatchToIndex at: ${applyPatch.path}:${applyPatch.line}");
  } else {
    print("❌ applyPatchToIndex not found");
  }

  // Test 3: Documentation extraction
  if (gitService?.documentation != null) {
    print("✅ Found GitService documentation:\n${gitService!.documentation}");
  } else {
    print("❌ Documentation missing for GitService");
  }

  // Test 4: Symbol at offset
  final line = "  final res = await GitService.applyPatchToIndex(path, patch);";
  final symbol = IndexerService.getSymbolAt(line, 25); // Offset 25 is 'G' in GitService
  print("Symbol at offset 25: $symbol");
  if (symbol == "GitService") {
    print("✅ Symbol detection at offset correct");
  } else {
    print("❌ Symbol detection at offset failed");
  }

  print("Verification complete.");
  exit(0);
}
