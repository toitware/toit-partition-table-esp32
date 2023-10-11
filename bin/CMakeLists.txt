# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by an MIT-style license that can be
# found in the LICENSE file.

toit_project(partition "${CMAKE_CURRENT_LIST_DIR}")

set(PARTITIONS_SOURCE "${CMAKE_CURRENT_LIST_DIR}/partitions.toit")
set(PARTITIONS_EXE "${CMAKE_BINARY_DIR}/partitions${CMAKE_EXECUTABLE_SUFFIX}")
set(PARTITIONS_DEP "${CMAKE_CURRENT_BINARY_DIR}/partitions.dep")

ADD_TOIT_EXE(
  ${PARTITIONS_SOURCE}
  ${PARTITIONS_EXE}
  ${PARTITIONS_DEP}
  ""
)

add_custom_target(
  build_partitions
  DEPENDS ${PARTITIONS_EXE}
)

add_dependencies(build build_partitions)
