// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show LITTLE_ENDIAN
import crypto.crc show Crc

class Otadata:
  static ENTRY_OFFSET_0 ::= 0
  static ENTRY_OFFSET_1 ::= 4096
  static OTADATA_SIZE ::= 8192
  select_entries/List

  constructor .select_entries:

  static decode bytes/ByteArray -> Otadata:
    select_entry1 := SelectEntry.decode bytes --offset=ENTRY_OFFSET_0
    select_entry2 := SelectEntry.decode bytes --offset=ENTRY_OFFSET_1
    return Otadata [select_entry1, select_entry2]

  select_entry1 -> SelectEntry:
    return select_entries[0]

  select_entry2 -> SelectEntry:
    return select_entries[1]

  encode -> ByteArray:
    bytes := ByteArray OTADATA_SIZE: -1
    bytes.replace ENTRY_OFFSET_0 select_entry1.encode
    bytes.replace ENTRY_OFFSET_1 select_entry2.encode
    return bytes

class SelectEntry:
  /**
  Monitor the first boot.
  In the bootloader this state is changed to $STATE_IMAGE_PENDING_VERIFY
  */
  static STATE_IMAGE_NEW ::= 0
  /**
  First time this image has been booted.
  The bootloader changes this state to $STATE_IMAGE_ABORTED.
  */
  static STATE_IMAGE_PENDING_VERIFY ::= 1
  /**
  The image has been marked as working.
  The partition can boot and work without limits.
  */
  static STATE_IMAGE_VALID ::= 2
  /**
  The image was neither marked as working nor non-working.
  The bootloader will not use this image again.
  */
  static STATE_IMAGE_ABORTED ::= 3
  /**
  Undefined state.
  App can boot and work without limits (according to documentation).
  */
  static STATE_IMAGE_UNDEFINED ::= -1

  sequence_number/int
  label/ByteArray
  state/int
  crc/int

  constructor --.sequence_number --.label --.state --.crc:

  static decode bytes/ByteArray --offset/int -> SelectEntry:
    ota_seq := LITTLE_ENDIAN.int32 bytes offset
    offset += 4
    seq_label_bytes := bytes[offset..offset + 20]
    offset += 20
    ota_state := LITTLE_ENDIAN.int32 bytes offset
    offset += 4
    crc := LITTLE_ENDIAN.uint32 bytes offset
    offset += 4

    if ota_seq != -1 and crc != (crc32 ota_seq):
      print "CRC mismatch: $ota_seq"

    return SelectEntry
        --sequence_number=ota_seq
        --label=seq_label_bytes
        --state=ota_state
        --crc=crc

  encode -> ByteArray:
    bytes := ByteArray 32
    LITTLE_ENDIAN.put_int32 bytes 0 sequence_number
    bytes.replace 4 label
    LITTLE_ENDIAN.put_int32 bytes 24 state
    LITTLE_ENDIAN.put_uint32 bytes 28 crc
    return bytes

  with --sequence_number/int?=null --state/int?=null -> SelectEntry:
    new_crc := sequence_number ? (crc32 sequence_number) : crc
    return SelectEntry
        --sequence_number=sequence_number or this.sequence_number
        --label=this.label
        --state=state or this.state
        --crc=new_crc

  static state_stringify state/int -> string:
    if state == STATE_IMAGE_NEW: return "STATE_IMAGE_NEW"
    if state == STATE_IMAGE_PENDING_VERIFY: return "STATE_IMAGE_PENDING_VERIFY"
    if state == STATE_IMAGE_VALID: return "STATE_IMAGE_VALID"
    if state == STATE_IMAGE_ABORTED: return "STATE_IMAGE_ABORTED"
    if state == STATE_IMAGE_UNDEFINED: return "STATE_IMAGE_UNDEFINED"
    return "unknown"

  static crc32 sequence_number/int -> int:
    bytes := ByteArray 4
    LITTLE_ENDIAN.put_int32 bytes 0 sequence_number
    crc := Crc.little_endian 32 --normal_polynomial=0x04C11DB7 --initial_state=0 --xor_result=0xffffffff
    crc.add bytes
    return crc.get_as_int

  stringify -> string:
    return """
      OTA seq: $sequence_number
      Seq label: $label.to_string_non_throwing
      OTA state: $state - $(state_stringify state)
      CRC: $(%x crc)
    """
