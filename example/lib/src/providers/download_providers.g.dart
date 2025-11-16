// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DownloadList)
const downloadListProvider = DownloadListProvider._();

final class DownloadListProvider
    extends $AsyncNotifierProvider<DownloadList, List<DownloadTask>> {
  const DownloadListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadListHash();

  @$internal
  @override
  DownloadList create() => DownloadList();
}

String _$downloadListHash() => r'8e68ab7d747a71338977324ccbfd66adcff0c92e';

abstract class _$DownloadList extends $AsyncNotifier<List<DownloadTask>> {
  FutureOr<List<DownloadTask>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<DownloadTask>>, List<DownloadTask>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DownloadTask>>, List<DownloadTask>>,
              AsyncValue<List<DownloadTask>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(downloadProgress)
const downloadProgressProvider = DownloadProgressFamily._();

final class DownloadProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadProgress>,
          DownloadProgress,
          Stream<DownloadProgress>
        >
    with $FutureModifier<DownloadProgress>, $StreamProvider<DownloadProgress> {
  const DownloadProgressProvider._({
    required DownloadProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'downloadProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadProgressHash();

  @override
  String toString() {
    return r'downloadProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<DownloadProgress> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DownloadProgress> create(Ref ref) {
    final argument = this.argument as String;
    return downloadProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadProgressHash() => r'3f63ef793b33f63246e5b1cb0b589b4bf8aa725f';

final class DownloadProgressFamily extends $Family
    with $FunctionalFamilyOverride<Stream<DownloadProgress>, String> {
  const DownloadProgressFamily._()
    : super(
        retry: null,
        name: r'downloadProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DownloadProgressProvider call(String downloadId) =>
      DownloadProgressProvider._(argument: downloadId, from: this);

  @override
  String toString() => r'downloadProgressProvider';
}

@ProviderFor(ActiveDownloads)
const activeDownloadsProvider = ActiveDownloadsProvider._();

final class ActiveDownloadsProvider
    extends $AsyncNotifierProvider<ActiveDownloads, List<DownloadTask>> {
  const ActiveDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeDownloadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeDownloadsHash();

  @$internal
  @override
  ActiveDownloads create() => ActiveDownloads();
}

String _$activeDownloadsHash() => r'dbf840b2397c1d1f7be76827dedb48a4e9247d7b';

abstract class _$ActiveDownloads extends $AsyncNotifier<List<DownloadTask>> {
  FutureOr<List<DownloadTask>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<DownloadTask>>, List<DownloadTask>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DownloadTask>>, List<DownloadTask>>,
              AsyncValue<List<DownloadTask>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CompletedDownloads)
const completedDownloadsProvider = CompletedDownloadsProvider._();

final class CompletedDownloadsProvider
    extends $AsyncNotifierProvider<CompletedDownloads, List<DownloadTask>> {
  const CompletedDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completedDownloadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completedDownloadsHash();

  @$internal
  @override
  CompletedDownloads create() => CompletedDownloads();
}

String _$completedDownloadsHash() =>
    r'a80f28346abbcef9607aab36b5d0523aefdfe2a7';

abstract class _$CompletedDownloads extends $AsyncNotifier<List<DownloadTask>> {
  FutureOr<List<DownloadTask>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<DownloadTask>>, List<DownloadTask>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DownloadTask>>, List<DownloadTask>>,
              AsyncValue<List<DownloadTask>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
