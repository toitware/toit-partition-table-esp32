// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import host.pipe
import host.file
import .util

PARTITION_TABLE_OFFSET ::= 0x8000
PARTITION_TABLE_SIZE ::= 0xc00

class Esptool:
  path_/string
  port_/string?
  partition_table_offset_/int
  partition_table_size_/int

  constructor .path_ --port/string?=null --partition_table_offset/int --partition_table_size/int:
    port_ = port
    partition_table_offset_ = partition_table_offset
    partition_table_size_ = partition_table_size

  read_partition_table -> ByteArray:
    return read_flash --offset=partition_table_offset_ --size=partition_table_size_

  read_flash --offset/int --size/int -> ByteArray:
    with_tmp_directory: | tmp_dir/string |
      out := "$tmp_dir/out.bin"
      read_flash --offset=offset --size=size --out=out
      return file.read_content out
    unreachable

  read_flash --offset/int --size/int --out/string:
    args := [
        "-b", "460800",
        "read_flash",
        "$offset",
        "$size",
        out,
    ]
    if port_:
      args += ["--port", port_]
    run_ args

  write_flash --offset/int --path/string:
    args := [
        "--after", "no_reset",
        "-b", "460800",
        "write_flash",
        "$offset",
        path,
    ]
    if port_:
      args += ["--port", port_]
    run_ args

  write_flash --offset/int --bytes/ByteArray:
    with_tmp_directory: | tmp_dir/string |
      in := "$tmp_dir/in.bin"
      file.write_content --path=in bytes
      write_flash --offset=offset --path=in

  run_ args/List:
    command := path_.ends-with ".py" ? ["python", path_] : [path_]
    command += args
    pipe.run-program command
