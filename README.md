# ESP32 partition table parser

A Toit package and binary for handling ESP32 partition tables.

## Package

The package contains a library for parsing ESP32 partition tables.

Example usage:

``` toit
import partition-table show *
import host.file

main:
  table-bytes := file.read-content "partitions.bin"
  table := PartitionTable.decode table-bytes
  table.do: | partition/Partition |
    print partition.name
```

## Binary

The binary in the 'bin' directory can be used to manipulate ESP32 partitions.
It uses the `esptool` to read and write the partitions (including the partition table).

See `partitions --help` for usage information.

The `partitions` binary requires the `--esptool` option to point to an `esptool` binary or
`esptool.py` file. You can find a binary in the SDK releases of Toit in the `tools` directory,
or you can download one from
https://github.com/espressif/esptool/releases or
https://github.com/toitlang/esptool/releases.
