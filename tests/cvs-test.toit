// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import fs
import host.file
import partition-table show *
import system

main:
  program-path := system.program-path
  program-dir := fs.dirname program-path
  bin-contents := file.read-contents "$program-dir/cvs-test-partitions.bin"
  csv-contents := file.read-contents "$program-dir/cvs-test-partitions.cvs"

  partition-table-bin := PartitionTable.decode bin-contents
  partition-table-cvs := PartitionTable.decode-csv csv-contents

  partitions-bin := partition-table-bin.partitions
  partitions-cvs := partition-table-cvs.partitions
  expect-equals partitions-bin.size partitions-cvs.size

  for i := 0; i < partitions-bin.size; i++:
    partition-bin/Partition := partitions-bin[i]
    partition-cvs/Partition := partitions-cvs[i]
    expect-equals partition-bin.name partition-cvs.name
    expect-equals partition-bin.type partition-cvs.type
    expect-equals partition-bin.subtype partition-cvs.subtype
    expect-equals partition-bin.offset partition-cvs.offset
    expect-equals partition-bin.size partition-cvs.size
    expect-equals partition-bin.flags partition-cvs.flags

  encoded := partition-table-cvs.encode
  if encoded.size > bin-contents.size:
    bin-contents += ByteArray (encoded.size - bin-contents.size): 0xff

  expect-equals bin-contents encoded
