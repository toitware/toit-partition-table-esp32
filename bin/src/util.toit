// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import host.directory

with_tmp_directory [block]:
  tmpdir := directory.mkdtemp "/tmp/ota_v1_v2-"
  try:
    block.call tmpdir
  finally:
    directory.rmdir --recursive tmpdir
