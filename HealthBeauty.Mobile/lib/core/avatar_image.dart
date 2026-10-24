/// Match the backend's allowed formats by signature, not an untrusted extension.
String? avatarImageContentType(List<int> bytes) {
  if (bytes.length >= 8 &&
      List.generate(8, (i) => bytes[i]).join(',') ==
          '137,80,78,71,13,10,26,10') {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

const maximumAvatarBytes = 5 * 1024 * 1024;
