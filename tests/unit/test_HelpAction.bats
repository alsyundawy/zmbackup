#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../setup'

setup() {
  setup_mock_path
  source "${LIB_DIR}/HelpAction.sh"
}

@test "show_help: outputs zmbackup usage line" {
  run show_help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zmbackup"* ]]
}

@test "show_help: lists -f / --full option" {
  run show_help
  [[ "$output" == *"-f"* ]]
  [[ "$output" == *"--full"* ]]
}

@test "show_help: lists -i / --incremental option" {
  run show_help
  [[ "$output" == *"-i"* ]]
  [[ "$output" == *"--incremental"* ]]
}

@test "show_help: lists -l / --list option" {
  run show_help
  [[ "$output" == *"-l"* ]]
  [[ "$output" == *"--list"* ]]
}

@test "show_help: lists -r / --restore option" {
  run show_help
  [[ "$output" == *"-r"* ]]
  [[ "$output" == *"--restore"* ]]
}

@test "show_help: lists -d / --delete option" {
  run show_help
  [[ "$output" == *"-d"* ]]
  [[ "$output" == *"--delete"* ]]
}

@test "show_help: lists -hp / --housekeep option" {
  run show_help
  [[ "$output" == *"-hp"* ]]
  [[ "$output" == *"--housekeep"* ]]
}

@test "show_help: lists -t / --truncate option" {
  run show_help
  [[ "$output" == *"-t"* ]]
  [[ "$output" == *"--truncate"* ]]
}

@test "show_help: lists -mg / --migrate option" {
  run show_help
  [[ "$output" == *"-mg"* ]]
  [[ "$output" == *"--migrate"* ]]
}

@test "show_help: lists -v / --version option" {
  run show_help
  [[ "$output" == *"-v"* ]]
  [[ "$output" == *"--version"* ]]
}

@test "show_help: lists -h / --help option" {
  run show_help
  [[ "$output" == *"-h"* ]]
  [[ "$output" == *"--help"* ]]
}

@test "show_help: lists full backup sub-options" {
  run show_help
  [[ "$output" == *"-dl"* ]]
  [[ "$output" == *"--distributionlist"* ]]
  [[ "$output" == *"-al"* ]]
  [[ "$output" == *"--alias"* ]]
  [[ "$output" == *"-ldp"* ]]
  [[ "$output" == *"--ldap"* ]]
  [[ "$output" == *"-sig"* ]]
  [[ "$output" == *"--signature"* ]]
}

@test "show_help: lists restore sub-options" {
  run show_help
  [[ "$output" == *"-ro"* ]]
  [[ "$output" == *"--restoreOnAccount"* ]]
}

@test "show_help: lists domain and account flags" {
  run show_help
  [[ "$output" == *"--domain"* ]]
  [[ "$output" == *"--account"* ]]
}

@test "show_help: lists -dom / --domain-backup option" {
  run show_help
  [[ "$output" == *"-dom"* ]]
  [[ "$output" == *"--domain-backup"* ]]
}

@test "show_help: lists Full Backup Options section" {
  run show_help
  [[ "$output" == *"Full Backup Options"* ]]
}

@test "show_help: lists Restore Backup Options section" {
  run show_help
  [[ "$output" == *"Restore Backup Options"* ]]
}
