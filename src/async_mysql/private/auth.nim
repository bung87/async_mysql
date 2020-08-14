import std/sha1, nimcrypto
import math # used by scramble323
const Sha1DigestSize = 20

proc `xor`(a: Sha1Digest, b: Sha1Digest): string =
  result = newStringOfCap(Sha1DigestSize)
  for i in 0..<Sha1DigestSize:
    let c = ord(a[i]) xor ord(b[i])
    add(result, chr(c))

proc `xor`(a: MDigest[256], b: MDigest[256]): string =
  result = newStringOfCap(32)
  for i in 0..<32:
    let c = ord(a.data[i]) xor ord(b.data[i])
    add(result, chr(c))

proc toString(h: sha1.SecureHash | Sha1Digest): string =
  ## convert sha1.SecureHash,Sha1Digest to limited length string(Sha1DigestSize:20)
  var bytes = cast[array[0 .. Sha1DigestSize-1, uint8]](h)
  result = newString(Sha1DigestSize)
  copyMem(result[0].addr, bytes[0].addr, bytes.len)

proc scramble_native_password*(scrambleBuff: string, password: string): string =
  let stage1 = sha1.secureHash(password)
  let stage2 = sha1.secureHash( stage1.toString )
  var ss = newSha1State()
  ss.update(scrambleBuff[0..<Sha1DigestSize])
  ss.update(stage2.toString)
  let stage3 = ss.finalize
  result = stage3 xor stage1.Sha1Digest

proc scramble_caching_sha2*(scrambleBuff: string, password: string): string =
  let p1 = sha256.digest(password)
  let p2 = sha256.digest($p1)
  let p3 = sha256.digest($p2 & scrambleBuff)
  result = p1 xor p3

proc hash323(s: string): tuple[a: uint32, b: uint32] =
  var nr = 0x50305735'u32
  var add = 7'u32
  var nr2 = 0x12345671'u32
  var tmp: uint32
  for c in s:
    case c
    of '\x09', '\x20':
      continue
    else:
      tmp = uint32(0xFF and ord(c))
      nr = nr xor ((((nr and 63) + add) * tmp) + (nr shl 8))
      nr2 = nr2 + ((nr2 shl 8) xor nr)
      add = add + tmp
  result.a = nr and 0x7FFFFFFF
  result.b = (nr2 and 0x7FFFFFFF)

proc scramble323*(seed: string, password: string): string =
  assert password.len == 0
  if password.len == 0:
    return ""
  var pw = hash323(seed)
  var msg = hash323(password)
  const max = 0x3FFFFFFF'u32
  var seed1 = (pw.a xor msg.a) mod max
  var seed2 = (pw.b xor msg.b) mod max
  var b: uint32
  result = newString(seed.len)
  for i in 0..<seed.len:
    seed1 = ((seed1 * 3) + seed2) mod max
    seed2 = (seed1 + seed2 + 33) mod max
    b = floor((seed1.int / max.int * 31) + 64).uint32
    result[i] = chr(b)
  seed1 = ((seed1 * 3) + seed2) mod max
  seed2 = (seed1 + seed2 + 33) mod max
  b = floor(seed1.int / max.int * 31).uint32
  for i in 0..<seed.len:
    result[i] = chr(ord(result[i]) xor b.int)