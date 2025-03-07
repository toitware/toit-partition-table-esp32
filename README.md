# ESP32 partition table parser

A Toit package and binary for handling ESP32 partition tables.

## Package

The package contains a library for parsing ESP32 partition tables.

Example usage:

``` toit
import partition-table show *
import host.file

main:
  table-bytes := file.read-contents "partitions.bin"
  table := PartitionTable.decode table-bytes
  table.do: | partition/Partition |
    print partition.name
```

## Binary

The binary in the 'bin' directory can be used to manipulate ESP32 partitions.
It uses the `esptool` to read and write the partitions (including the partition table).

See `partitions --help` for usage information. See the help output below.

The `partitions` binary requires the `--esptool` option to point to an `esptool` binary or
`esptool.py` file. You can find a binary in the SDK releases of Toit in the `tools` directory,
or you can download one from
https://github.com/espressif/esptool/releases or
https://github.com/toitlang/esptool/releases.

### Help output

Here is the help output of the `partitions` executable:

```
A tool to manage OTA partitions on the ESP32.

Usage:
  partitions <command> [<options>]

Commands:
  help              Show help for a command.
  print-otadata     Print the otadata partition.
  print-partitions  Print the partition table.
  read              Reads a partition from the flash.
  set-ota-state     Sets the partition's state.
  write             Writes a partition to the flash.

Options:
      --esptool string                 Path to esptool.py.
  -h, --help                           Show help for this command.
      --partition-table-offset string  Offset of the partition table. (default: 0x8000)
      --partition-table-size string    Size of the partition table. (default: 0xc00)
  -p, --port string                    Serial port to use.

Examples:
  # Print the partition table:
  partitions print-partitions

  # Print the otadata partition:
  partitions print-otadata

  # Read the partition 'ota_0' to 'ota_0.bin':
  partitions read -o ota_0.bin ota_0

  # Write the partition 'ota_0' from 'ota_0.bin':
  partitions write -i ota_0.bin ota_0

  # Set the state of 'ota_0' to 'pending-verify':
  partitions set-ota-state --state=pending-verify ota_0
```

