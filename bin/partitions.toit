// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import cli

import host.file
import host.os
import partition-table show *
import partition-table.otadata show *
import system

import .src.esptool
import .version

main args:
  // We don't want to advertise the '--version' on the root command
  // as that would make it available to all sub commands.
  // However, being able to write `app --version` is nice, so we handle
  // that here.
  if args.size == 1 and
     (args[0] == "--version" or args[0] == "-v"):
    print-version

  cmd := cli.Command "root"
      --short-help="Commands to manage OTA partitions on the ESP32."
      --options=[
        cli.Option "esptool"
            --short-help="Path to esptool.py.",
        cli.Option "port"
            --short-name="p"
            --short-help="Serial port to use.",
        cli.Option "partition-table-offset"
            --short-help="Offset of the partition table."
            --default="0x8000",
        cli.Option "partition-table-size"
            --short-help="Size of the partition table."
            --default="0xc00",
      ]

  print-partitions-cmd := cli.Command "print-partitions"
      --short-help="Print the partition table."
      --run=:: print-partition-table it
  cmd.add print-partitions-cmd

  print-otadata-cmd := cli.Command "print-otadata"
      --short-help="Print the otadata partition."
      --run=:: print-otadata it
  cmd.add print-otadata-cmd

  read-cmd := cli.Command "read"
      --short-help="Reads a partition from the flash."
      --options=[
        cli.Option "out"
            --short-name="o"
            --short-help="Output file."
            --required,
      ]
      --rest=[
        cli.Option "partition"
            --short-help="Partition to read."
            --required
      ]
      --run=:: read-partition it
  cmd.add read-cmd

  write-cmd := cli.Command "write"
      --short-help="Writes a partition to the flash."
      --options=[
        cli.Option "in"
            --short-name="i"
            --short-help="Input file."
            --required,
      ]
      --rest=[
        cli.Option "partition"
            --short-help="Partition to write."
            --required
      ]
      --run=:: write-partition it
  cmd.add write-cmd

  set-ota-state-cmd := cli.Command "set-ota-state"
      --short-help="Sets the partition's state."
      --options=[
        cli.Flag "make-active"
            --short-help="Make the partition active by changing the sequence number."
            --default=true,
        cli.OptionEnum "state" ["new", "pending-verify", "valid", "aborted", "undefined"]
            --short-help="The new state of the partition."
            --default="valid",
        cli.OptionInt "select-entry"
            --short-help="The select entry to update. (default: 0 for ota_0, 1 for ota_1)"
      ]
      --rest=[
        cli.Option "partition"
            --short-help="Partition to set as boot."
            --required,
      ]
      --run=:: set-ota-state it
  cmd.add set-ota-state-cmd

  version-cmd := cli.Command "version"
      --short-help="Print the version and exit."
      --run=:: print-version

  cmd.run args

with-esptool parsed/cli.Parsed [block]:
  esptool-path := parsed["esptool"]
  if not esptool-path:
    // Try to find the esptool.py script in the PATH.
    path-var := os.env["PATH"]
    if not path-var:
      print "Can't find esptool. PATH environment variable not set."
      exit 1
    env-split-char := ?
    exe-extension := ?
    if system.platform == system.PLATFORM-WINDOWS:
      env-split-char = ";"
      exe-extension = ".exe"
    else:
      env-split-char = ":"
      exe-extension = ""

    bin-paths := path-var.split env-split-char
    for i := 0; i < bin-paths.size; i++:
      bin-path := bin-paths[i]
      py-path := "$bin-path/esptool.py"
      if file.is-file py-path:
        esptool-path = py-path
        break
      exe-path := "$bin-path/esptool$exe-extension"
      if file.is-file exe-path:
        esptool-path = exe-path
        break
    if not esptool-path:
      // Just try the executable.
      // It's probably not going to work, but it's better than nothing.
      esptool-path = "esptool$exe-extension"
      print "Can't find esptool. Trying to use '$esptool-path'."

  port := parsed["port"]
  partition-table-offset-str/string := parsed["partition-table-offset"]
  partition-table-size-str/string := parsed["partition-table-size"]
  partition-table-offset-str = partition-table-offset-str.to-ascii-lower
  partition-table-size-str = partition-table-size-str.to-ascii-lower

  partition-table-offset := partition-table-offset-str.starts-with "0x"
      ? int.parse partition-table-offset-str[2..] --radix=16
      : int.parse partition-table-offset-str
  partition-table-size := partition-table-size-str.starts-with "0x"
      ? int.parse partition-table-size-str[2..] --radix=16
      : int.parse partition-table-size-str

  esptool := Esptool esptool-path
      --port=port
      --partition-table-offset=partition-table-offset
      --partition-table-size=partition-table-size

  block.call esptool

print-partition-table parsed/cli.Parsed:
  with-esptool parsed: | esptool/Esptool |
    partition-table-bytes := esptool.read-partition-table
    table := PartitionTable.decode partition-table-bytes
    print "# Name, Type, SubType, Offset, Size, Size in K"
    table.do: | partition/Partition |
      type-string/string := ?
      if partition.type == 0: type-string = "app"
      else if partition.type == 1: type-string = "data"
      else: type-string = "$partition.type"

      k-size := partition.size / 1024
      print "$partition.name, $type-string, $partition.subtype, 0x$(%x partition.offset), 0x$(%x partition.size), $(k-size)K"

print-otadata parsed/cli.Parsed:
  with-esptool parsed: | esptool/Esptool |
    partition-table-bytes := esptool.read-partition-table
    table := PartitionTable.decode partition-table-bytes
    otadata-partition := table.find-otadata
    otadata-offset := otadata-partition.offset
    otadata-size := otadata-partition.size
    otadata-bytes := esptool.read-flash
        --offset=otadata-offset
        --size=otadata-size

    otadata := Otadata.decode otadata-bytes
    2.repeat:
      if it == 1: print
      entry/SelectEntry := otadata.select-entries[it]
      print """
      otadata$it:
        sequence-number: $entry.sequence-number
        label: $entry.label.to-string-non-throwing
        state: $entry.state ($(SelectEntry.state-stringify entry.state))
        crc: $(%x entry.crc)"""

read-partition parsed/cli.Parsed:
  with-esptool parsed: | esptool/Esptool|
    out := parsed["out"]
    partition-name := parsed["partition"]

    partition-table-bytes := esptool.read-partition-table
    table := PartitionTable.decode partition-table-bytes
    partition := table.find --name=partition-name
    if not partition:
      print "Partition '$partition-name' not found"
      exit 1

    esptool.read-flash
        --offset=partition.offset
        --size=partition.size
        --out=out

write-partition parsed/cli.Parsed:
  with-esptool parsed: | esptool/Esptool |
    in := parsed["in"]
    partition-name := parsed["partition"]

    partition-table-bytes := esptool.read-partition-table
    table := PartitionTable.decode partition-table-bytes
    partition := table.find --name=partition-name
    if not partition:
      print "Partition '$partition-name' not found"
      exit 1

    esptool.write-flash
        --offset=partition.offset
        --path=in

set-ota-state parsed/cli.Parsed:
  with-esptool parsed: | esptool/Esptool |
    partition-name := parsed["partition"]
    make-active := parsed["make-active"]
    select-entry-index := parsed["select-entry"]

    if partition-name != "ota_0" and partition-name != "ota_1":
      print "Invalid partition name '$partition-name'"
      exit 1

    partition-table-bytes := esptool.read-partition-table
    table := PartitionTable.decode partition-table-bytes
    otadata-bytes := esptool.read-flash
        --offset=table.find-otadata.offset
        --size=table.find-otadata.size

    otadata := Otadata.decode otadata-bytes

    index := select-entry-index or (partition-name == "ota_0" ? 0 : 1)
    sequence-number := otadata.select-entries[index].sequence-number
    if make-active:
      max-sequence-number := max otadata.select-entry1.sequence-number otadata.select-entry2.sequence-number
      sequence-number = max-sequence-number + 1
      if sequence-number % 2 == index:
        // The active partition is chosen by taking the highest sequence number and then
        // using the parity to decide whether to use the first or second entry.
        sequence-number++
    state-mapping := {
      "new": SelectEntry.STATE-IMAGE-NEW,
      "pending-verify": SelectEntry.STATE-IMAGE-PENDING-VERIFY,
      "valid": SelectEntry.STATE-IMAGE-VALID,
      "aborted": SelectEntry.STATE-IMAGE-ABORTED,
      "undefined": SelectEntry.STATE-IMAGE-UNDEFINED,
    }
    new-state/int := state-mapping[parsed["state"]]
    otadata.select-entries[index] = otadata.select-entries[index].with
        --state = new-state
        --sequence-number = sequence-number

    print "new-state: $otadata"
    new-otadata-bytes := otadata.encode

    esptool.write-flash
        --offset=table.find-otadata.offset
        --bytes=new-otadata-bytes

print-version:
  print PARTITION-TABLE-VERSION
