enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled;

  bool get isActive => this == downloading;
  bool get isCompleted => this == completed;
  bool get isFailed => this == failed;
  bool get isPaused => this == paused;
  bool get isCancelled => this == cancelled;
  bool get canResume => this == paused || this == failed;
  bool get canPause => this == downloading || this == queued;
  bool get canRetry => this == failed || this == cancelled;
}

enum DownloadPriority {
  low,
  medium,
  high;

  int get value {
    switch (this) {
      case low:
        return 0;
      case medium:
        return 1;
      case high:
        return 2;
    }
  }
}
