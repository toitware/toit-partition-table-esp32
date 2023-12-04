// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import host.pipe
import host.file
import .util

PARTITION-TABLE-OFFSET ::= 0x8000
PARTITION-TABLE-SIZE ::= 0xc00

class Esptool:
  path_/string
  port_/string?
  partition-table-offset_/int
  partition-table-size_/int

  constructor .path_ --port/string?=null --partition-table-offset/int --partition-table-size/int:
    port_ = port
    partition-table-offset_ = partition-table-offset
    partition-table-size_ = partition-table-size

  read-partition-table -> ByteArray:
    return read-flash --offset=partition-table-offset_ --size=partition-table-size_

  read-flash --offset/int --size/int -> ByteArray:
    with-tmp-directory: | tmp-dir/string |
      out := "$tmp-dir/out.bin"
      read-flash --offset=offset --size=size --out=out
      return file.read-content out
    unreachable

  read-flash --offset/int --size/int --out/string:
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

  write-flash --offset/int --path/string:
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

  write-flash --offset/int --bytes/ByteArray:
    with-tmp-directory: | tmp-dir/string |
      in := "$tmp-dir/in.bin"
      file.write-content --path=in bytes
      write-flash --offset=offset --path=in

  run_ args/List:
    command := path_.ends-with ".py" ? ["python", path_] : [path_]
    command += args
    pipe.run-program command
