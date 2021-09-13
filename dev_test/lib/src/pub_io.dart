import 'dart:async';
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';

import 'mixin/package.dart';

final String _pubspecYaml = 'pubspec.yaml';

/// return true if root package

/// Check whether the package contains a supported version
Future<bool> isPubPackageRoot(String dirPath) async {
  var pubspecYamlPath = join(dirPath, _pubspecYaml);
  // ignore: avoid_slow_async_io
  if (await io.FileSystemEntity.isFile(pubspecYamlPath)) {
    var map = await pathGetPubspecYamlMap(dirPath);
    var boundaries = pubspecYamlGetSdkBoundaries(map);
    if (boundaries != null) {
      return boundaries.match(dartVersion);
    }
  }
  return false;
}

/// @Deprecated('Use isPubPackageRoot')
bool isPubPackageRootSync(String dirPath) {
  var pubspecYamlPath = join(dirPath, _pubspecYaml);
  return io.FileSystemEntity.isFileSync(pubspecYamlPath);
}

/// Also test if the the sdk matches
Future<bool> isFlutterPackageRoot(String dirPath) async {
  try {
    var map = await pathGetPubspecYamlMap(dirPath);
    return pubspecYamlSupportsFlutter(map);
  } catch (_) {
    return false;
  }
}

/// throws if no project found
Future<String> getPubPackageRoot(String resolverPath) async {
  var dirPath = normalize(absolute(resolverPath));

  while (true) {
    // Find the project root path
    if (await isPubPackageRoot(dirPath)) {
      return dirPath;
    }
    var parentDirPath = dirname(dirPath);

    if (parentDirPath == dirPath) {
      throw Exception("No project found for path '$resolverPath");
    }
    dirPath = parentDirPath;
  }
}

String getPubPackageRootSync(String resolverPath) {
  var dirPath = normalize(absolute(resolverPath));

  while (true) {
    // Find the project root path
    if (isPubPackageRootSync(dirPath)) {
      return dirPath;
    }
    var parentDirPath = dirname(dirPath);

    if (parentDirPath == dirPath) {
      throw Exception("No project found for path '$resolverPath");
    }
    dirPath = parentDirPath;
  }
}
