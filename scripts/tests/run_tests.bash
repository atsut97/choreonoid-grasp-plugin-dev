#!/usr/bin/env bash

# Assumptions:
#   - Filenames of test scripts should begin with 'test_' and end with
#   '.bash'. For example, test script for run.bash should be
#   'test_run.bash'.
#   - Filenames of files that contain expected outputs of test scripts
#   should begin with 'test_' and end with '_expected'. For example,
#   exepected outputs of 'test_run.bash' should be described in
#   'test_run_expected'.

# Takes a filename of test script and returns the result of 'diff'
# command.
run_test() {
  # Ex. test_run.bash
  local test_script="$1"
  # Ex. test_run.bash => test_run_expected
  local expected_file="${test_script/%.bash/_expected}"

  # Execute 'diff' command.
  diff "${expected_file}" <("$test_script" 2>&1)
}

run_test "$1"
