# Copyright (C) 2024 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/LICENSE file.

toit_project(tests "${CMAKE_CURRENT_LIST_DIR}")

file(GLOB TESTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*_test.toit" "*-test.toit" "*_test_slow.toit" "*-test-slow.toit")

# Add windows exe extension.
set(TOIT_EXEC "toit.run${CMAKE_EXECUTABLE_SUFFIX}" CACHE FILEPATH "The executable used to run the tests")
set(TPKG_EXEC "toit.pkg${CMAKE_EXECUTABLE_SUFFIX}" CACHE FILEPATH "The executable used to install the packages")
set(TEST_TIMEOUT 40 CACHE STRING "The maximal amount of time each test is allowed to run")
set(SLOW_TEST_TIMEOUT 200 CACHE STRING "The maximal amount of time each slow test is allowed to run")

include(ProcessorCount)
ProcessorCount(NUM_CPU)

# Add a custom target 'check' that runs our unit tests.
add_custom_target(
  "check"
  COMMAND "${CMAKE_CTEST_COMMAND}" -j${NUM_CPU} --output-on-failure -C Debug
  USES_TERMINAL
)

set(TEST_PREFIX "")
# Tests that fail locally and on toitlang/toit.
include(fail.cmake OPTIONAL)
# Tests that only fail when called with this test runner.
include(fail_pkg.cmake OPTIONAL)

message("Failing tests: ${FAILING_TESTS}")
message("Skipped tests: ${SKIP_TESTS}")

foreach(file ${TESTS})
  set(test_name "/tests/${file}")
  if("${test_name}" IN_LIST SKIP_TESTS)
    continue()
  endif()

  add_test(
    NAME "${test_name}"
    COMMAND "${TOIT_EXEC}" "tests/${file}"
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  )

  if ("${file}" MATCHES "slow.toit")
    set_tests_properties(${test_name} PROPERTIES TIMEOUT ${SLOW_TEST_TIMEOUT})
  else()
    set_tests_properties(${test_name} PROPERTIES TIMEOUT ${TEST_TIMEOUT})
  endif()

  if ("${test_name}" IN_LIST FAILING_TESTS)
    set_tests_properties("${test_name}" PROPERTIES WILL_FAIL TRUE)
  endif()

endforeach()
