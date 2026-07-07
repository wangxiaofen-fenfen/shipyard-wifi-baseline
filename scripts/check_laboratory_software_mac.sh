#!/usr/bin/env bash

set -u

pass_count=0
fail_count=0
warn_count=0

print_result() {
  local level="$1"
  local name="$2"
  local detail="$3"

  printf '%s %-34s %s\n' "$level" "$name" "$detail"

  case "$level" in
    PASS) pass_count=$((pass_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
  esac
}

check_command() {
  local command_name="$1"
  local label="$2"
  local version_args="${3:---version}"

  if command -v "$command_name" >/dev/null 2>&1; then
    local version_output
    version_output="$("$command_name" $version_args 2>&1 | head -n 1)"
    print_result "PASS" "$label" "$version_output"
  else
    print_result "FAIL" "$label" "command not found: $command_name"
  fi
}

check_python_module() {
  local module_name="$1"

  if ! command -v python3 >/dev/null 2>&1; then
    print_result "FAIL" "Python module $module_name" "python3 not available"
    return
  fi

  local module_output
  module_output="$(python3 -c "import ${module_name}; print(${module_name}.__version__)" 2>&1)"
  if [ "$?" -eq 0 ]; then
    print_result "PASS" "Python module $module_name" "$module_output"
  else
    print_result "FAIL" "Python module $module_name" "$module_output"
  fi
}

check_interface_ip() {
  local interface_name="$1"

  if ! command -v ipconfig >/dev/null 2>&1; then
    print_result "WARN" "$interface_name IP" "ipconfig command not available"
    return
  fi

  local ip_addr
  ip_addr="$(ipconfig getifaddr "$interface_name" 2>/dev/null || true)"
  if [ -n "$ip_addr" ]; then
    print_result "PASS" "$interface_name IP" "$ip_addr"
  else
    print_result "WARN" "$interface_name IP" "no IPv4 address reported"
  fi
}

check_wifi_network() {
  local interface_name="$1"

  if ! command -v networksetup >/dev/null 2>&1; then
    print_result "WARN" "$interface_name Wi-Fi network" "networksetup command not available"
    return
  fi

  local network_output
  network_output="$(networksetup -getairportnetwork "$interface_name" 2>&1 || true)"
  if printf '%s' "$network_output" | grep -qi "not a Wi-Fi interface"; then
    print_result "WARN" "$interface_name Wi-Fi network" "$network_output"
  elif printf '%s' "$network_output" | grep -qi "not associated"; then
    print_result "WARN" "$interface_name Wi-Fi network" "$network_output"
  else
    print_result "PASS" "$interface_name Wi-Fi network" "$network_output"
  fi
}

echo "Laboratory Wi-Fi5 software check for macOS"
echo "Read-only checks only. No software will be installed or removed."
echo

check_command "brew" "Homebrew"
check_command "iperf3" "iPerf3"
check_command "python3" "Python 3"
check_command "pip3" "pip3"
check_python_module "pandas"
check_python_module "numpy"
check_command "git" "Git"

if command -v matlab >/dev/null 2>&1; then
  matlab_version="$(matlab -batch "disp(version)" 2>&1 | tail -n 1)"
  print_result "PASS" "MATLAB" "$matlab_version"
else
  print_result "WARN" "MATLAB" "matlab command not found in PATH"
fi

check_interface_ip "en0"
check_interface_ip "en1"
check_wifi_network "en0"
check_wifi_network "en1"

echo
echo "Summary"
echo "PASS: $pass_count"
echo "FAIL: $fail_count"
echo "WARN: $warn_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
