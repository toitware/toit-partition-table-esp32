// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io
import io show LITTLE-ENDIAN
import crypto.md5

class PartitionTable:
  static MAGIC-BYTES-MD5 ::= #[0xeb, 0xeb]

  /**
  An application partition.
  */
  static PARTITION-TYPE-APP ::= 0x00
  /**
  A data partition.
  */
  static PARTITION-TYPE-DATA ::= 0x01

  /**
  The default app partition.

  The bootloader execute the factory app unless there is a partition of type
    data/ota.
  */
  static PARTITION-SUBTYPE-APP-FACTORY ::= 0x00
  /**
  The subpartition type for the OTA partition (an app partition).

  Additional OTA partitions are following this one, incrementing the subtype.

  For example, 'ota_1' has the subtype `PARTITION-SUBTYPE-OTA-0_ + 1`.
  */
  static PARTITION-SUBTYPE-APP-OTA-0 ::= 0x10
  /**
  Reserved for factory test procedures. It's used if no other valid app
    partition is found. It is also possible to configure the bootloader to
    read a GPIO input during each boot, and boot this partition if the GPIO
    is held low.
  */
  static PARTITION-SUBTYPE-APP-TEST ::= 0x20

  /**
  The OTA data partition.

  Stores information about the currently selected OTA app slot.
  */
  static PARTITION-SUBTYPE-DATA-OTA ::= 0x00
  /**
  PHY initialization data.

  By default PHY initialization data is compiled into the app itself. To
    use the partition, the `CONFIG_ESP_PHY_INIT_DATA_IN_PARTITION` option
    must be set.
  */
  static PARTITION-SUBTYPE-DATA-PHY ::= 0x01
  /**
  The NVS partition.

  Stores non-volatile data, such as WiFi credentials.
  */
  static PARTITION-SUBTYPE-DATA-NVS ::= 0x02
  /**
  A partition to store core dumps.
  */
  static PARTITION-SUBTYPE-DATA-COREDUMP ::= 0x03
  /**
  The NVS key partition.
  */
  static PARTITION-SUBTYPE-DATA-NVS-KEYS ::= 0x04
  /**
  A partition for emulating eFuse bits using virtual efuses.
  */
  static PARTITION-SUBTYPE-DATA-EFUSE ::= 0x05
  /**
  Unspecified data partition.
  */
  static PARTITION-SUBTYPE-DATA-UNDEFINED ::= 0x06
  /**
  A FAT filesystem partition.
  */
  static PARTITION-SUBTYPE-DATA-FAT ::= 0x81
  /**
  A SPIFFS filesystem partition.
  */
  static PARTITION-SUBTYPE-DATA-SPIFFS ::= 0x82
  /**
  A LittleFS filesystem partition.
  */
  static PARTITION-SUBTYPE-DATA-LITTLEFS ::= 0x83

  static PARTITION-SUBTYPES-APP ::= {
    "factory": PARTITION-SUBTYPE-APP-FACTORY,
    "ota_0": PARTITION-SUBTYPE-APP-OTA-0,
    "ota_1": PARTITION-SUBTYPE-APP-OTA-0 + 1,
    "ota_2": PARTITION-SUBTYPE-APP-OTA-0 + 2,
    "ota_3": PARTITION-SUBTYPE-APP-OTA-0 + 3,
    "ota_4": PARTITION-SUBTYPE-APP-OTA-0 + 4,
    "ota_5": PARTITION-SUBTYPE-APP-OTA-0 + 5,
    "ota_6": PARTITION-SUBTYPE-APP-OTA-0 + 6,
    "ota_7": PARTITION-SUBTYPE-APP-OTA-0 + 7,
    "ota_8": PARTITION-SUBTYPE-APP-OTA-0 + 8,
    "ota_9": PARTITION-SUBTYPE-APP-OTA-0 + 9,
    "ota_10": PARTITION-SUBTYPE-APP-OTA-0 + 10,
    "ota_11": PARTITION-SUBTYPE-APP-OTA-0 + 11,
    "ota_12": PARTITION-SUBTYPE-APP-OTA-0 + 12,
    "ota_13": PARTITION-SUBTYPE-APP-OTA-0 + 13,
    "ota_14": PARTITION-SUBTYPE-APP-OTA-0 + 14,
    "ota_15": PARTITION-SUBTYPE-APP-OTA-0 + 15,
    "test": PARTITION-SUBTYPE-APP-TEST,
  }

  static PARTITION-SUBTYPES-DATA ::= {
    "ota": PARTITION-SUBTYPE-DATA-OTA,
    "phy": PARTITION-SUBTYPE-DATA-PHY,
    "nvs": PARTITION-SUBTYPE-DATA-NVS,
    "coredump": PARTITION-SUBTYPE-DATA-COREDUMP,
    "nvs_keys": PARTITION-SUBTYPE-DATA-NVS-KEYS,
    "efuse": PARTITION-SUBTYPE-DATA-EFUSE,
    "undefined": PARTITION-SUBTYPE-DATA-UNDEFINED,
    "fat": PARTITION-SUBTYPE-DATA-FAT,
    "spiffs": PARTITION-SUBTYPE-DATA-SPIFFS,
    "littlefs": PARTITION-SUBTYPE-DATA-LITTLEFS,
  }

  /**
  Flag to signal that a data partition should be encrypted.

  App partitions are always encrypted.
  */
  static FLAG-ENCRYPTED ::= 1 << 0

  /**
  Flag to signal that a data partition should be read-only.

  Only applies to data partitions, but not to "ota" and "coredump".
  */
  static FLAG-READONLY  ::= 1 << 1  // Only in recent ESP-IDF versions.

  partitions_/List ::= []

  add partition/Partition -> none:
    partitions_.add partition

  find --name/string -> Partition?:
    partitions_.do: | partition/Partition |
      if partition.name == name: return partition
    return null

  find-app -> Partition?:
    first/Partition? := null
    partitions_.do: | partition/Partition |
      if partition.type != Partition.TYPE-APP: continue.do
      if not first or partition.subtype < first.subtype:
        first = partition
    return first

  find-otadata -> Partition?:
    return find --type=Partition.TYPE-DATA --subtype=Partition.SUBTYPE-DATA-OTA

  find --type/int --subtype/int=0xff -> Partition?:
    partitions_.do: | partition/Partition |
      if partition.type != type: continue.do
      if subtype == 0xff or partition.subtype == subtype:
        return partition
    return null

  find-first-free-offset -> int:
    offset := 0
    partitions_.do: | partition/Partition |
      end := round-up (partition.offset + partition.size) 4096
      offset = max offset end
    return offset

  /**
  Decodes a partition table.

  The given $bytes can be either a binary partition table or a CSV table.
  */
  static decode bytes/ByteArray -> PartitionTable:
    if bytes.size > 2 and bytes[..2] == Partition.MAGIC-BYTES:
      return decode-bin_ bytes
    return decode-csv_ bytes

  static decode-bin_ bytes/ByteArray -> PartitionTable:
    table := PartitionTable
    checksum := md5.Md5
    cursor := 0
    while cursor < bytes.size:
      next := cursor + 32
      entry := bytes[cursor..next]
      if entry[..2] == MAGIC-BYTES-MD5:
        if entry[16..] != checksum.get:
          throw "Malformed table - wrong checksum"
      else if (entry.every: it == 0xff):
        return table
      else:
        table.add (Partition.decode entry)
        checksum.add entry
      cursor = next
    throw "Malformed table - not terminated"

  static decode-csv_ bytes/ByteArray -> PartitionTable:
    // Something like:
    //    # Name,   Type, SubType,  Offset,    Size,     Flags
    //    # bootloader,,  ,         0x001000,  0x007000
    //    # partitions,,  ,         0x008000,  0x000c00
    //    secure,   0x42, 0x00,     0x009000,  0x004000,
    //    otadata,  data, ota,      0x00d000,  0x002000,
    //    phy_init, data, phy,      0x00f000,  0x001000,
    //    ota_0,    app,  ota_0,    0x010000,  0x1a0000,
    //    ota_1,    app,  ota_1,    0x1b0000,  0x1a0000,
    //    nvs,      data, nvs,      0x350000,  0x010000,
    //    programs, 0x40, 0x00,     0x360000,  0x0a0000, encrypted
    //
    // Offsets may be missing, in which case they are calculated from the
    // previous entry.

    table := PartitionTable

    lines := (io.Reader bytes).read-lines
    lines.filter --in-place: | line/string |
      trimmed := line.trim
      trimmed != "" and trimmed[0] != '#'

    next-computed-offset/int? := null
    lines.do: | line/string |
      parts := line.split ","
      if parts.size < 5: throw "Malformed CSV line"
      parts.map --in-place: it.trim

      name := parts[0]

      type-string/string := parts[1]
      type/int := ?
      if type-string == "app": type = Partition.TYPE-APP
      else if type-string == "data": type = Partition.TYPE-DATA
      else if type-string.starts-with "0x": type = int.parse type-string[2..] --radix=16
      else: type = int.parse type-string

      subtypes-map/Map := type == Partition.TYPE-APP ? PARTITION-SUBTYPES-APP : PARTITION-SUBTYPES-DATA
      subtype-string/string := parts[2]
      subtype/int := ?
      if subtypes-map.contains subtype-string: subtype = subtypes-map[subtype-string]
      else if subtype-string.starts-with "0x": subtype = int.parse subtype-string[2..] --radix=16
      else: subtype = int.parse subtype-string

      offset-string := parts[3]
      offset/int := ?
      if offset-string == "":
        if not next-computed-offset: throw "Missing initial offset"
        offset = next-computed-offset
      else if offset-string.starts-with "0x": 
        offset = int.parse offset-string[2..] --radix=16
      else: 
        offset = int.parse offset-string

      size-string := parts[4]
      size/int := ?
      if size-string.starts-with "0x": size = int.parse size-string[2..] --radix=16
      else: size = int.parse size-string

      next-computed-offset = offset + size

      flags/int := 0
      flag-strings := parts.size > 5 ? parts[5].split "+" : []
      flag-strings.filter --in-place: it != ""
      flag-strings.do: | flag-string/string |
        if flag-string == "encrypted": flags |= FLAG-ENCRYPTED
        else if flag-string == "readonly": flags |= FLAG-READONLY
        else: throw "Unknown flag"

      partition := Partition
          --name=name
          --type=type
          --subtype=subtype
          --offset=offset
          --size=size
          --flags=flags

      table.add partition

    return table

  encode -> ByteArray:
    result := ByteArray 0x1000: 0xff
    sorted := partitions_.sort: | a b |
      a.offset.compare-to b.offset
    cursor := 0
    sorted.do: | partition/Partition |
      encoded := partition.encode
      result.replace cursor encoded
      cursor += encoded.size
    md5 := encode-md5-partition_ result[..cursor]
    result.replace cursor md5
    return result

  encode --csv/True -> string:
    result := "#      Name, Type, SubType,   Offset,     Size, Flags\n"
    sorted := partitions_.sort: | a b |
      a.offset.compare-to b.offset
    sorted.do: | partition/Partition |
      result += partition.encode --csv-line
    return result

  encode-md5-partition_ partitions/ByteArray -> ByteArray:
    partition := ByteArray 32: 0xff
    partition.replace 0 MAGIC-BYTES-MD5
    partition.replace 16 (md5.md5 partitions)
    return partition

  partitions -> List:
    return partitions_.copy

  do [block]:
    partitions_.do block

  stringify -> string:
    return encode --csv

class Partition:
  static MAGIC-BYTES ::= #[0xaa, 0x50]

  static TYPE-APP  ::= 0
  static TYPE-DATA ::= 1

  static SUBTYPE-DATA-OTA ::= 0

  // struct {
  //   uint8   magic[2];
  //   uint8   type;
  //   uint8   subtype;
  //   uint32  offset;
  //   uint32  size;
  //   uint8   name[16];
  //   uint32  flags;
  // }
  name/string
  type/int
  subtype/int
  offset/int
  size/int
  flags/int

  constructor --.name --.type --.subtype --.offset --.size --.flags:

  static decode bytes/ByteArray -> Partition:
    if bytes[..2] != MAGIC-BYTES: throw "Malformed entry - magic"
    return Partition
        --name=decode-name_ bytes[12..28]
        --type=bytes[2]
        --subtype=bytes[3]
        --offset=LITTLE-ENDIAN.uint32 bytes 4
        --size=LITTLE-ENDIAN.uint32 bytes 8
        --flags=LITTLE-ENDIAN.uint32 bytes 28

  encode -> ByteArray:
    result := ByteArray 32
    result.replace 0 MAGIC-BYTES
    result[2] = type
    result[3] = subtype
    LITTLE-ENDIAN.put-uint32 result 4 offset
    LITTLE-ENDIAN.put-uint32 result 8 size
    result.replace 12 encode-name_
    LITTLE-ENDIAN.put-uint32 result 28 flags
    return result

  encode --csv-line/True -> string:
    name-string := "$name,".pad 12

    type-string/string := ?
    if type == TYPE-APP: type-string = "app"
    else if type == TYPE-DATA: type-string = "data"
    else: type-string = "0x$(%02x type)"
    type-string = "$type-string,".pad 5

    subtype-string/string? := null
    reverse-map/Map := ?
    if type == TYPE-APP: reverse-map = PartitionTable.PARTITION-SUBTYPES-APP
    else if type == TYPE-DATA: reverse-map = PartitionTable.PARTITION-SUBTYPES-DATA
    else: reverse-map = {:}
    reverse-map.any: | name/string value/int |
      if value == subtype:
        subtype-string = name
        true
      else:
        false
    if not subtype-string: subtype-string = "0x$(%02x subtype)"
    subtype-string = "$subtype-string,".pad 8

    offset-string := "0x$(%06x offset),"
    size-string := "0x$(%06x size),"

    flag-entries := []
    if (flags & PartitionTable.FLAG-ENCRYPTED) != 0: flag-entries.add "encrypted"
    if (flags & PartitionTable.FLAG-READONLY) != 0: flag-entries.add "readonly"
    flags-string := flag-entries.join ":"

    return "$name-string $type-string $subtype-string $offset-string $size-string $flags-string\n"

  static decode-name_ bytes/ByteArray -> string:
    zero := bytes.index-of 0
    if zero < 0: throw "Malformed entry - name"
    return bytes[..zero].to-string-non-throwing

  encode-name_ -> ByteArray:
    bytes := name.to-byte-array
    n := min 15 bytes.size
    return bytes[..n] + (ByteArray 16 - n)
