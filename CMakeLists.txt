# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by an MIT-style license that can be
# found in the LICENSE file.

cmake_minimum_required(VERSION 3.23)

project(partition-table)

set(TOIT
    "toit${CMAKE_EXECUTABLE_SUFFIX}"
    CACHE
    FILEPATH
    "The executable used to compile, run, and install packages")

set(DEFAULT_SDK_VERSION CACHE STRING "The default SDK version to use")

set(PARTITION_TABLE_GIT_VERSION "$ENV{PARTITION_TABLE_GIT_VERSION}")
if ("${PARTITION_TABLE_GIT_VERSION}" STREQUAL "")
  include(tools/gitversion.cmake)
  # The Git version is only computed when cmake generates the Ninja files, but
  # that should be good enough.
  compute_git_version(PARTITION_TABLE_GIT_VERSION)
endif()

# Replace the version in app/version.toit.
configure_file(
  bin/version.toit.in
  ${CMAKE_CURRENT_SOURCE_DIR}/bin/version.toit
  @ONLY)

include("tools/toit.cmake")

add_custom_target(build)

enable_testing()
add_subdirectory(bin)
add_subdirectory(tests)
