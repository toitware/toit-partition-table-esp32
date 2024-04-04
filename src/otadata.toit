// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io show LITTLE-ENDIAN
import crypto.crc show Crc

class Otadata:
  static ENTRY-OFFSET-0 ::= 0
  static ENTRY-OFFSET-1 ::= 4096
  static OTADATA-SIZE ::= 8192
  select-entries/List

  constructor .select-entries:

  static decode bytes/ByteArray -> Otadata:
    select-entry1 := SelectEntry.decode bytes --offset=ENTRY-OFFSET-0
    select-entry2 := SelectEntry.decode bytes --offset=ENTRY-OFFSET-1
    return Otadata [select-entry1, select-entry2]

  select-entry1 -> SelectEntry:
    return select-entries[0]

  select-entry2 -> SelectEntry:
    return select-entries[1]

  encode -> ByteArray:
    bytes := ByteArray OTADATA-SIZE: -1
    bytes.replace ENTRY-OFFSET-0 select-entry1.encode
    bytes.replace ENTRY-OFFSET-1 select-entry2.encode
    return bytes

class SelectEntry:
  /**
  Monitor the first boot.
  In the bootloader this state is changed to $STATE-IMAGE-PENDING-VERIFY
  */
  static STATE-IMAGE-NEW ::= 0
  /**
  First time this image has been booted.
  The bootloader changes this state to $STATE-IMAGE-ABORTED.
  */
  static STATE-IMAGE-PENDING-VERIFY ::= 1
  /**
  The image has been marked as working.
  The partition can boot and work without limits.
  */
  static STATE-IMAGE-VALID ::= 2
  /**
  The image was neither marked as working nor non-working.
  The bootloader will not use this image again.
  */
  static STATE-IMAGE-ABORTED ::= 3
  /**
  Undefined state.
  App can boot and work without limits (according to documentation).
  */
  static STATE-IMAGE-UNDEFINED ::= -1

  sequence-number/int
  label/ByteArray
  state/int
  crc/int

  constructor --.sequence-number --.label --.state --.crc:

  static decode bytes/ByteArray --offset/int -> SelectEntry:
    ota-seq := LITTLE-ENDIAN.int32 bytes offset
    offset += 4
    seq-label-bytes := bytes[offset..offset + 20]
    offset += 20
    ota-state := LITTLE-ENDIAN.int32 bytes offset
    offset += 4
    crc := LITTLE-ENDIAN.uint32 bytes offset
    offset += 4

    if ota-seq != -1 and crc != (crc32 ota-seq):
      print "CRC mismatch: $ota-seq"

    return SelectEntry
        --sequence-number=ota-seq
        --label=seq-label-bytes
        --state=ota-state
        --crc=crc

  encode -> ByteArray:
    bytes := ByteArray 32
    LITTLE-ENDIAN.put-int32 bytes 0 sequence-number
    bytes.replace 4 label
    LITTLE-ENDIAN.put-int32 bytes 24 state
    LITTLE-ENDIAN.put-uint32 bytes 28 crc
    return bytes

  with --sequence-number/int?=null --state/int?=null -> SelectEntry:
    new-crc := sequence-number ? (crc32 sequence-number) : crc
    return SelectEntry
        --sequence-number=sequence-number or this.sequence-number
        --label=this.label
        --state=state or this.state
        --crc=new-crc

  static state-stringify state/int -> string:
    if state == STATE-IMAGE-NEW: return "STATE_IMAGE_NEW"
    if state == STATE-IMAGE-PENDING-VERIFY: return "STATE_IMAGE_PENDING_VERIFY"
    if state == STATE-IMAGE-VALID: return "STATE_IMAGE_VALID"
    if state == STATE-IMAGE-ABORTED: return "STATE_IMAGE_ABORTED"
    if state == STATE-IMAGE-UNDEFINED: return "STATE_IMAGE_UNDEFINED"
    return "unknown"

  static crc32 sequence-number/int -> int:
    bytes := ByteArray 4
    LITTLE-ENDIAN.put-int32 bytes 0 sequence-number
    crc := Crc.little-endian 32 --normal-polynomial=0x04C11DB7 --initial-state=0 --xor-result=0xffffffff
    crc.add bytes
    return crc.get-as-int

  stringify -> string:
    return """
      OTA seq: $sequence-number
      Seq label: $label.to-string-non-throwing
      OTA state: $state - $(state-stringify state)
      CRC: $(%x crc)
    """
