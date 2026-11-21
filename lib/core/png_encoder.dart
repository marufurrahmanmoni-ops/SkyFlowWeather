import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// Minimal PNG encoder for RGBA8888 pixels.
///
/// Pure Dart (uses dart:io zlib), so it can run inside a background isolate
/// where dart:ui image encoding is not available.
class PngEncoder {
  PngEncoder._();

  static final Uint32List _crcTable = _makeCrcTable();

  static Uint32List _makeCrcTable() {
    final table = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc(Uint8List bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List encodeRgba(Uint8List rgba, int width, int height) {
    // Filter type 0 (none) for each scanline.
    final stride = width * 4;
    final raw = Uint8List((stride + 1) * height);
    for (var y = 0; y < height; y++) {
      final o = y * (stride + 1);
      raw[o] = 0;
      raw.setRange(o + 1, o + 1 + stride, rgba, y * stride);
    }
    final compressed = Uint8List.fromList(ZLibCodec(level: 6).encode(raw));

    final out = BytesBuilder(copy: false);
    out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    final ihdr = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 6) // colour type RGBA
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);
    _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
    _chunk(out, 'IDAT', compressed);
    _chunk(out, 'IEND', Uint8List(0));
    return out.takeBytes();
  }

  static void _chunk(BytesBuilder out, String type, Uint8List data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final typeAndData = Uint8List(4 + data.length)
      ..setRange(0, 4, type.codeUnits)
      ..setRange(4, 4 + data.length, data);
    out.add(typeAndData);
    final crc = ByteData(4)..setUint32(0, _crc(typeAndData));
    out.add(crc.buffer.asUint8List());
  }
}
