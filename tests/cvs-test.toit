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
  csv-no-offsets-contents := file.read-contents "$program-dir/cvs-test-partitions-no-offsets.cvs"

  partition-table-bin := PartitionTable.decode bin-contents
  partition-table-cvs := PartitionTable.decode csv-contents
  partition-table-cvs-no-offsets := PartitionTable.decode csv-no-offsets-contents

  expect-equals-partition-tables partition-table-cvs partition-table-cvs-no-offsets

  partitions-bin := partition-table-bin.partitions
  partitions-cvs := partition-table-cvs.partitions
  expect-equals partitions-bin.size partitions-cvs.size

  expect-equals-partition-tables partition-table-bin partition-table-cvs

  encoded := partition-table-cvs.encode
  if encoded.size > bin-contents.size:
    bin-contents += ByteArray (encoded.size - bin-contents.size): 0xff

  expect-equals bin-contents encoded

  encoded-csv := partition-table-bin.encode --csv
  decoded-cvs := PartitionTable.decode encoded-csv.to-byte-array
  expect-equals-partition-tables partition-table-bin decoded-cvs

  encoded-csv2 := partition-table-cvs.encode --csv
  expect-equals encoded-csv encoded-csv2

  print encoded-csv

expect-equals-partition-tables partition-table1/PartitionTable partition-table2/PartitionTable:
  expect-equals partition-table1.partitions.size partition-table2.partitions.size
  for i := 0; i < partition-table1.partitions.size; i++:
    partition1/Partition := partition-table1.partitions[i]
    partition2/Partition := partition-table2.partitions[i]
    expect-equals partition1.name partition2.name
    expect-equals partition1.type partition2.type
    expect-equals partition1.subtype partition2.subtype
    expect-equals partition1.offset partition2.offset
    expect-equals partition1.size partition2.size
    expect-equals partition1.flags partition2.flags
