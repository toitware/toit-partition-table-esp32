// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import cli

import host.file
import host.os
import partition_table show *
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
    print_version

  cmd := cli.Command "root"
      --short_help="Commands to manage OTA partitions on the ESP32."
      --options=[
        cli.Option "esptool"
            --short_help="Path to esptool.py.",
        cli.Option "port"
            --short_name="p"
            --short_help="Serial port to use.",
        cli.Option "partition-table-offset"
            --short_help="Offset of the partition table."
            --default="0x8000",
        cli.Option "partition-table-size"
            --short_help="Size of the partition table."
            --default="0xc00",
      ]

  print_partitions_cmd := cli.Command "print-partitions"
      --short_help="Print the partition table."
      --run=:: print_partition_table it
  cmd.add print_partitions_cmd

  print_otadata_cmd := cli.Command "print-otadata"
      --short_help="Print the otadata partition."
      --run=:: print_otadata it
  cmd.add print_otadata_cmd

  read_cmd := cli.Command "read"
      --short_help="Reads a partition from the flash."
      --options=[
        cli.Option "out"
            --short_name="o"
            --short_help="Output file."
            --required,
      ]
      --rest=[
        cli.Option "partition"
            --short_help="Partition to read."
            --required
      ]
      --run=:: read_partition it
  cmd.add read_cmd

  write_cmd := cli.Command "write"
      --short_help="Writes a partition to the flash."
      --options=[
        cli.Option "in"
            --short_name="i"
            --short_help="Input file."
            --required,
      ]
      --rest=[
        cli.Option "partition"
            --short_help="Partition to write."
            --required
      ]
      --run=:: write_partition it
  cmd.add write_cmd

  set_ota_state_cmd := cli.Command "set-ota-state"
      --short_help="Sets the partition's state."
      --options=[
        cli.Flag "make-active"
            --short_help="Make the partition active by changing the sequence number."
            --default=true,
        cli.OptionEnum "state" ["new", "pending-verify", "valid", "aborted", "undefined"]
            --short_help="The new state of the partition."
            --default="valid",
        cli.OptionInt "select-entry"
            --short_help="The select entry to update. (default: 0 for ota_0, 1 for ota_1)"
      ]
      --rest=[
        cli.Option "partition"
            --short_help="Partition to set as boot."
            --required,
      ]
      --run=:: set_ota_state it
  cmd.add set_ota_state_cmd

  version_cmd := cli.Command "version"
      --short_help="Print the version and exit."
      --run=:: print_version

  cmd.run args

with_esptool parsed/cli.Parsed [block]:
  esptool_path := parsed["esptool"]
  if not esptool_path:
    // Try to find the esptool.py script in the PATH.
    path-var := os.env["PATH"]
    if not path-var:
      print "Can't find esptool. PATH environment variable not set"
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
        esptool_path = py-path
        break
      exe-path := "$bin-path/esptool$exe-extension"
      if file.is-file exe-path:
        esptool_path = exe-path
        break
    if not esptool_path:
      // Just try the executable.
      // It's probably not going to work, but it's better than nothing.
      esptool_path = "esptool$exe-extension"
      print "Can't find esptool. Trying to use '$esptool_path'."

  port := parsed["port"]
  partition_table_offset_str/string := parsed["partition-table-offset"]
  partition_table_size_str/string := parsed["partition-table-size"]
  partition_table_offset_str = partition_table_offset_str.to-ascii-lower
  partition_table_size_str = partition_table_size_str.to-ascii-lower

  partition_table_offset := partition_table_offset_str.starts_with "0x"
      ? int.parse partition_table_offset_str[2..] --radix=16
      : int.parse partition_table_offset_str
  partition_table_size := partition_table_size_str.starts_with "0x"
      ? int.parse partition_table_size_str[2..] --radix=16
      : int.parse partition_table_size_str

  esptool := Esptool esptool_path
      --port=port
      --partition_table_offset=partition_table_offset
      --partition_table_size=partition_table_size

  block.call esptool

print_partition_table parsed/cli.Parsed:
  with_esptool parsed: | esptool/Esptool |
    partition_table_bytes := esptool.read_partition_table
    table := PartitionTable.decode partition_table_bytes
    print "# Name, Type, SubType, Offset, Size, Size in K"
    table.do: | partition/Partition |
      type_string/string := ?
      if partition.type == 0: type_string = "app"
      else if partition.type == 1: type_string = "data"
      else: type_string = "$partition.type"

      k_size := partition.size / 1024
      print "$partition.name, $type_string, $partition.subtype, 0x$(%x partition.offset), 0x$(%x partition.size), $(k_size)K"

print_otadata parsed/cli.Parsed:
  with_esptool parsed: | esptool/Esptool |
    partition_table_bytes := esptool.read_partition_table
    table := PartitionTable.decode partition_table_bytes
    otadata_partition := table.find_otadata
    otadata_offset := otadata_partition.offset
    otadata_size := otadata_partition.size
    otadata_bytes := esptool.read_flash
        --offset=otadata_offset
        --size=otadata_size

    otadata := Otadata.decode otadata_bytes
    2.repeat:
      if it == 1: print
      entry/SelectEntry := otadata.select_entries[it]
      print """
      otadata$it:
        sequence-number: $entry.sequence_number
        label: $entry.label.to_string_non_throwing
        state: $entry.state ($(SelectEntry.state_stringify entry.state))
        crc: $(%x entry.crc)"""

read_partition parsed/cli.Parsed:
  with_esptool parsed: | esptool/Esptool|
    out := parsed["out"]
    partition_name := parsed["partition"]

    partition_table_bytes := esptool.read_partition_table
    table := PartitionTable.decode partition_table_bytes
    partition := table.find --name=partition_name
    if not partition:
      print "Partition '$partition_name' not found"
      exit 1

    esptool.read_flash
        --offset=partition.offset
        --size=partition.size
        --out=out

write_partition parsed/cli.Parsed:
  with_esptool parsed: | esptool/Esptool |
    in := parsed["in"]
    partition_name := parsed["partition"]

    partition_table_bytes := esptool.read_partition_table
    table := PartitionTable.decode partition_table_bytes
    partition := table.find --name=partition_name
    if not partition:
      print "Partition '$partition_name' not found"
      exit 1

    esptool.write_flash
        --offset=partition.offset
        --path=in

set_ota_state parsed/cli.Parsed:
  with_esptool parsed: | esptool/Esptool |
    partition_name := parsed["partition"]
    make_active := parsed["make-active"]
    select_entry_index := parsed["select-entry"]

    if partition_name != "ota_0" and partition_name != "ota_1":
      print "Invalid partition name '$partition_name'"
      exit 1

    partition_table_bytes := esptool.read_partition_table
    table := PartitionTable.decode partition_table_bytes
    otadata_bytes := esptool.read_flash
        --offset=table.find_otadata.offset
        --size=table.find_otadata.size

    otadata := Otadata.decode otadata_bytes

    index := select_entry_index or (partition_name == "ota_0" ? 0 : 1)
    sequence_number := otadata.select_entries[index].sequence_number
    if make_active:
      max_sequence_number := max otadata.select_entry1.sequence_number otadata.select_entry2.sequence_number
      sequence_number = max_sequence_number + 1
      if sequence_number % 2 == index:
        // The active partition is chosen by taking the highest sequence number and then
        // using the parity to decide whether to use the first or second entry.
        sequence_number++
    state_mapping := {
      "new": SelectEntry.STATE_IMAGE_NEW,
      "pending-verify": SelectEntry.STATE_IMAGE_PENDING_VERIFY,
      "valid": SelectEntry.STATE_IMAGE_VALID,
      "aborted": SelectEntry.STATE_IMAGE_ABORTED,
      "undefined": SelectEntry.STATE_IMAGE_UNDEFINED,
    }
    new_state/int := state_mapping[parsed["state"]]
    otadata.select_entries[index] = otadata.select_entries[index].with
        --state = new_state
        --sequence_number = sequence_number

    print "new-state: $otadata"
    new_otadata_bytes := otadata.encode

    esptool.write_flash
        --offset=table.find_otadata.offset
        --bytes=new_otadata_bytes

print-version:
  print PARTITION_TABLE_VERSION
