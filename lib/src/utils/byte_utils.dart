import 'dart:convert';
import 'dart:typed_data';

class ByteParser {
  final Uint8List bytes;
  int offset = 0;

  ByteParser(this.bytes);

  Uint8List view([int? size]) {
    return Uint8List.sublistView(
      bytes,
      offset,
      size == null ? null : offset + size,
    );
  }

  Uint8List take(int length) {
    final result = view(length);
    offset += length;
    return result;
  }

  Uint8List takeUntil(String delimiter) {
    final delimiterBytes = ascii.encode(delimiter);
    return takeUntilBytes(delimiterBytes);
  }

  Uint8List takeUntilBytes(Uint8List delimiterBytes) {
    int index = ByteUtils.indexOf(view(), delimiterBytes);
    if (index == -1) {
      throw Exception("Delimiter not found");
    }
    final result = view(index);
    offset += index + delimiterBytes.length;
    return result;
  }

  Uint8List takeWhile(bool Function(int) predicate) {
    final index = view().indexWhere((b) => !predicate(b));
    final result = view(index);
    offset += index;
    return result;
  }

  void tag(String tag) {
    final i = view(offset);
    final tagBytes = ascii.encode(tag);
    final tagLength = tagBytes.length;
    if (i.length < tagLength) {
      throw Exception("Tag not found");
    }
    for (var i = 0; i < tagLength; i++) {
      if (bytes[offset + i] != tagBytes[i]) {
        throw Exception("Tag not found");
      }
    }
    offset += tagLength;
  }
}

class ByteUtils {
  static int indexOf(Uint8List bytes, Uint8List delimiter) {
    int i = 0;
    while (i < bytes.length) {
      int d = 0;
      while (bytes[i + d] == delimiter[d++]) {
        if (d == delimiter.length) return i;
      }
      i += d;
    }
    return -1;
  }

  static List<Uint8List> splitBytes(Uint8List bytes, int delimiter) {
    final result = <Uint8List>[];
    int previous = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == delimiter) {
        result.add(Uint8List.sublistView(bytes, previous, i));
        previous = i + 1;
      }
    }
    result.add(Uint8List.sublistView(bytes, previous));
    return result;
  }

  static bool isAlphanumeric(int b) {
    return (b >= 65 && b <= 90) ||
        (b >= 97 && b <= 122) ||
        (b >= 48 && b <= 57);
  }
}
