/// Pseudo exports.
///
/// Used internally.
library;

export 'package:dev_build/src/package/filter_dart_project_options.dart'
    show FilterDartProjectOptions, FilterDartProjectOptionsExt;
export 'package:dev_build/src/package/package.dart'
    show
        pubspecYamlHasAnyDependencies,
        pubspecYamlSupportsFlutter,
        pubspecYamlSupportsNode,
        pubspecYamlSupportsWeb,
        pubspecYamlGetVersion,
        pubspecYamlSupportsTest,
        pubspecYamlGetSdkBoundaries,
        VersionBoundaries,
        VersionBoundary,
        analysisOptionsSupportsNnbdExperiment,
        packageConfigGetPackages;

/// Pseudo exports.
///
/// Used internally.
export 'package:dev_build/src/package/universal/package_universal.dart'
    show
        pathGetPubspecYamlMap,
        pathGetPackageConfigMap,
        pathGetAnalysisOptionsYamlMap;
