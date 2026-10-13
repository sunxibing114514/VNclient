#!/usr/bin/env python3
"""Lossless PNG re-optimizer (pure Python, no dependencies).

Equivalent to a single `optipng -o2` pass:
  * parses every IDAT chunk,
  * re-selects the best PNG scanline filter per row (None/Sub/Up/Average/Paeth)
  * recompresses with zlib level 9 + several strategies,
  * writes the file back only when strictly smaller.

The decoded pixels are guaranteed byte-identical (lossless): PNG filtering
is a reversible transform and we verify by re-decoding the result.
"""
import binascii
import os
import struct
import sys
import zlib


def parse_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    pos = 8
    chunks = []
    while pos + 8 <= len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        cdata = data[pos + 8:pos + 8 + length]
        chunks.append((ctype, cdata))
        pos += 12 + length  # length + type + data + crc
    return chunks


def build_png(chunks):
    out = [b'\x89PNG\r\n\x1a\n']
    for ctype, cdata in chunks:
        out.append(struct.pack('>I', len(cdata)))
        out.append(ctype)
        out.append(cdata)
        out.append(struct.pack('>I', binascii.crc32(ctype + cdata) & 0xffffffff))
    return b''.join(out)


def ihdr_info(chunks):
    for ctype, cdata in chunks:
        if ctype == b'IHDR':
            w, h, depth, color = struct.unpack('>IIBB', cdata[:10])
            return w, h, depth, color
    raise ValueError('missing IHDR')


CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def unfilter(raw, w, h, depth, color):
    """Decode PNG scanlines back into raw pixel bytes."""
    bpp = CHANNELS[color] * (depth // 8 if depth >= 8 else 1)
    stride = (w * CHANNELS[color] * depth + 7) // 8
    out = bytearray(h * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 0:
            pass
        elif ftype == 1:  # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ftype == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                if pa <= pb and pa <= pc:
                    pred = a
                elif pb <= pc:
                    pred = b
                else:
                    pred = c
                line[i] = (line[i] + pred) & 0xFF
        else:
            raise ValueError(f'bad filter {ftype}')
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return bytes(out), bpp, stride


def apply_filter(ftype, pixels, prev, bpp, stride):
    """Apply one filter type to a whole scanline, returning filtered bytes."""
    line = pixels[:stride]
    if ftype == 0:
        return line
    out = bytearray(stride)
    if ftype == 1:
        for i in range(stride - 1, bpp - 1, -1):
            out[i] = (line[i] - line[i - bpp]) & 0xFF
        for i in range(min(bpp, stride)):
            out[i] = line[i]
    elif ftype == 2:
        for i in range(stride):
            out[i] = (line[i] - prev[i]) & 0xFF
    elif ftype == 3:
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            out[i] = (line[i] - ((left + prev[i]) >> 1)) & 0xFF
    elif ftype == 4:
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            if pa <= pb and pa <= pc:
                pred = a
            elif pb <= pc:
                pred = b
            else:
                pred = c
            out[i] = (line[i] - pred) & 0xFF
    return bytes(out)


def optimize(path):
    original = os.path.getsize(path)
    chunks = parse_png(path)
    w, h, depth, color = ihdr_info(chunks)
    if depth not in (8, 16):
        # Palette/low-bit depths: keep the pixels untouched; only try
        # recompressing the existing filtered stream.
        idat = b''.join(c for t, c in chunks if t == b'IDAT')
        plain = zlib.decompress(idat)
        best = zlib.compress(plain, 9)
        if len(best) >= len(idat):
            return 0
        new_chunks = [(t, c) for t, c in chunks if t != b'IDAT']
        insert_at = next(i for i, (t, _) in enumerate(new_chunks) if t == b'IEND')
        new_chunks.insert(insert_at, (b'IDAT', best))
        data = build_png(new_chunks)
        with open(path, 'wb') as f:
            f.write(data)
        return original - len(data)

    raw = zlib.decompress(b''.join(c for t, c in chunks if t == b'IDAT'))
    pixels, bpp, stride = unfilter(raw, w, h, depth, color)

    # Re-filter each scanline with the locally-best filter, like optipng.
    prev = bytearray(stride)
    filtered = bytearray()
    for y in range(h):
        line = pixels[y * stride:(y + 1) * stride]
        best_type, best_enc = 0, None
        best_size = 1 << 60
        for ftype in range(5):
            enc = apply_filter(ftype, line, prev, bpp, stride)
            # Cheap heuristic: sum of absolute bytes (zlib loves zeros).
            cost = sum(enc)
            if cost < best_size:
                best_size = cost
                best_type, best_enc = ftype, enc
        filtered.append(best_type)
        filtered += best_enc
        prev = bytearray(line)

    # Try a few zlib strategies/levels and keep the smallest. The
    # original (already filtered) stream is also repacked as a candidate —
    # sometimes the shipped filters were fine and only the compression
    # level was weak (e.g. bgTouhou).
    def _compress(data, strategy=zlib.Z_DEFAULT_STRATEGY):
        co = zlib.compressobj(9, zlib.DEFLATED, zlib.MAX_WBITS, 9, strategy)
        return co.compress(data) + co.flush()

    refiltered = bytes(filtered)
    candidates = [
        zlib.compress(refiltered, 9),
        _compress(refiltered, zlib.Z_RLE),
        _compress(refiltered, zlib.Z_FILTERED),
        # Original filter stream, recompressed:
        zlib.compress(raw, 9),
        _compress(raw, zlib.Z_RLE),
    ]
    best = min(candidates, key=len)
    best_is_original = best in candidates[3:]
    if best_is_original:
        # Verification: the original stream decodes to the same pixels by
        # construction, but double-check anyway.
        check = zlib.decompress(best)
        if unfilter(check, w, h, depth, color)[0] != pixels:
            raise ValueError('original-stream verification failed')
    idat = b''.join(c for t, c in chunks if t == b'IDAT')
    if len(best) >= len(idat):
        return 0

    new_chunks = [(t, c) for t, c in chunks if t != b'IDAT']
    insert_at = next(i for i, (t, _) in enumerate(new_chunks) if t == b'IEND')
    new_chunks.insert(insert_at, (b'IDAT', best))
    data = build_png(new_chunks)

    # Safety: verify the new file decodes to identical pixels.
    vchunks = parse_png_path(data)
    vraw = zlib.decompress(b''.join(c for t, c in vchunks if t == b'IDAT'))
    if not best_is_original:
        vpixels, _, _ = unfilter(vraw, w, h, depth, color)
        if vpixels != pixels:
            raise ValueError('verification failed; keeping original')

    with open(path, 'wb') as f:
        f.write(data)
    return original - len(data)


def parse_png_path(data):
    pos = 8
    chunks = []
    while pos + 8 <= len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        cdata = data[pos + 8:pos + 8 + length]
        chunks.append((ctype, cdata))
        pos += 12 + length
    return chunks


if __name__ == '__main__':
    total_before = total_saved = 0
    for arg in sys.argv[1:]:
        if not os.path.isfile(arg):
            continue
        before = os.path.getsize(arg)
        try:
            saved = optimize(arg)
        except Exception as e:
            print(f'  SKIP {arg}: {e}')
            continue
        after = os.path.getsize(arg)
        total_before += before
        total_saved += saved
        pct = 100.0 * saved / before if before else 0
        print(f'  {arg}: {before/1024:8.1f} KB -> {after/1024:8.1f} KB  '
              f'(-{pct:.1f}%)')
    print(f'TOTAL: {total_before/1024:.1f} KB -> '
          f'{(total_before - total_saved)/1024:.1f} KB '
          f'(saved {total_saved/1024:.1f} KB)')
