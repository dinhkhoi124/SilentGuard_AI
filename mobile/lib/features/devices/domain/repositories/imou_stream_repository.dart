abstract interface class ImouStreamRepository {
  Future<String> getStreamUrl(String deviceSn);

  Future<void> releaseStreamSession(String deviceSn);
}
