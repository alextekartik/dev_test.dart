import 'dart:async';

import 'package:dev_build/src/import.dart';
import 'package:dev_build/src/mixin/package.dart';
import 'package:dev_build/src/pub_io.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:process_run/stdio.dart';

/// false if symlink
bool isDirectoryNotLinkSynk(String path) =>
    FileSystemEntity.isDirectorySync(path) &&
    !FileSystemEntity.isLinkSync(path);

/// Normalize path using posix style
/// Not valid if current path contains a part containing a backslash (not recommended)
String posixNormalize(String path) {
  return posix.normalize(path.replaceAll('\\', '/'));
}

bool _isToBeIgnored(String baseName) {
  var posixName = posixNormalize(baseName);
  // Don't ignore the current directory
  if (posixName == '.') {
    return false;
  }
  // Don't ignore the parent directory
  if (posixName == '..') {
    return false;
  }

  // Don't ignore relative path in parents
  if (posix.normalize(baseName).startsWith('../')) {
    return false;
  }
  // Ignore blacklisted targets
  if (_blackListedTargets.contains(baseName)) {
    return true;
  }

  // Ignore typically hidden folder
  return baseName.startsWith('.');
}

final List<String> _blackListedTargets = [
  '.',
  '..',
  'build',
  'deploy',
  'node_modules'
];

/// True if the dir should be handled
Future<bool> _handleDir(String dir,
    {List<String>? dependencies,
    FilterDartProjectOptions? filterDartProjectOptions}) async {
  // Ignore folder starting with .
  // don't event go below
  if (!_isToBeIgnored(basename(dir))) {
    if (await isPubPackageRoot(dir,
        filterDartProjectOptions: filterDartProjectOptions)) {
      if (dependencies is List && dependencies!.isNotEmpty) {
        final yaml = await pathGetPubspecYamlMap(dir);
        if (pubspecYamlHasAnyDependencies(yaml, dependencies)) {
          return true;
        }
      } else {
        // add package path
        return true;
      }
    }
  }
  return false;
}

/// if [forceRecursive] is true, we folder going deeper even if the current
/// path is a dart project
Future<List<String>> filterPubPath(List<String> dirs,
    {List<String>? dependencies,
    FilterDartProjectOptions? filterDartProjectOptions}) async {
  var list = <String>[];

  for (final dir in dirs) {
    if (isDirectoryNotLinkSynk(dir)) {
      final handled = await _handleDir(dir,
          dependencies: dependencies,
          filterDartProjectOptions: filterDartProjectOptions);
      if (handled) {
        list.add(dir);
      }
    } else {
      throw '$dir not a directory';
    }
  }
  return list;
}

/// if [forceRecursive] is true, we folder going deeper even if the current
/// path is a dart project
///
/// if [ignoreSdkConstraints] is true, it lists the project even if not compatible.
///
/// if [dependencies] is specified, it will only list the project that contains
/// such dependency, use either dependency like `path`, or 'direct:path', 'dev:path' or 'override:path'.
/// Returns the list of valid pub folder, including me
Future<List<String>> recursivePubPath(List<String> dirs,
    {List<String>? dependencies,
    FilterDartProjectOptions? filterDartProjectOptions}) async {
  var pubDirs = await filterPubPath(dirs,
      dependencies: dependencies,
      filterDartProjectOptions: filterDartProjectOptions);

  Future<List<String>> getSubDirs(String dir) async {
    if (!_isToBeIgnored(basename(dir))) {
      // devPrint('testing: $dir');
      final sub = <String>[];
      final futures = <Future>[];
      await Directory(dir).list().listen((FileSystemEntity fse) {
        var subDir = fse.path;
        // Make sure it is not added even if it is a package root
        if (!_isToBeIgnored(basename(subDir))) {
          if (isDirectoryNotLinkSynk(subDir)) {
            futures.add(() async {
              var subPubDirs = await filterPubPath([subDir],
                  dependencies: dependencies,
                  filterDartProjectOptions: filterDartProjectOptions);
              /*
              if (await isPubPackageRoot(subDir,
                  filterDartProjectOptions: filterDartProjectOptions)) {
                sub.add(subDir);
              }*/
              sub.addAll(subPubDirs);
              sub.addAll(await getSubDirs(subDir));
            }());
          }
        }
      }).asFuture<void>();
      await Future.wait(futures);
      return sub;
    }
    return <String>[];
  }

  for (final dir in dirs) {
    if (isDirectoryNotLinkSynk(dir)) {
      pubDirs.addAll(await getSubDirs(dir));
    } else {
      throw '$dir not a directory';
    }
  }

  return removeDuplicates(pubDirs)..sort();
}

/// Remove duplicates.
List<String> removeDuplicates(List<String> dirs) {
  // remove duplicates
  var absolutes = <String>{};
  // devPrint(pubDirs);
  var list = <String>[];
  for (var dir in dirs) {
    var absolutePath = normalize(absolute(dir));
    if (!absolutes.contains(absolutePath)) {
      absolutes.add(absolutePath);
      list.add(dir);
    }
  }
  return list;
}

/// Each path is tested
///
/// [poolSize] default to 4
Future<void> recursivePackagesRun(List<String> paths,
        {required FutureOr<dynamic> Function(String package) action,
        bool? verbose,
        int? poolSize,
        List<String>? dependencies,
        FilterDartProjectOptions? filterDartProjectOptions}) =>
    recursiveActions(paths,
        action: action,
        verbose: verbose,
        poolSize: poolSize,
        dependencies: dependencies,
        filterDartProjectOptions: filterDartProjectOptions);

/// Each path is tested
///
/// [poolSize] default to 4
Future<void> recursiveActions(List<String> paths,
    {required FutureOr<dynamic> Function(String package) action,
    bool? verbose,
    int? poolSize,
    List<String>? dependencies,
    FilterDartProjectOptions? filterDartProjectOptions}) async {
  poolSize ??= 4;
  verbose ??= false;
// filter what could be packages in the paths list
  var dirsOrFiles = paths;
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }

  final packagePool = Pool(poolSize);

  var packages = await recursivePubPath(paths,
      dependencies: dependencies,
      filterDartProjectOptions: filterDartProjectOptions);

  var futures = <Future>[];
  for (final pkg in packages) {
    futures.add(packagePool.withResource(() async {
      try {
        await action(pkg);
      } catch (e) {
        stderr.writeln('ERROR $e in $pkg');
        rethrow;
      }
    }));
  }
  await Future.wait(futures);
}
