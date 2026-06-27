#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# packer-build.sh — thin wrapper around `packer init / validate / build`.
#
# Usage:
#   ./packer-build.sh <action> [target] [var-file]
#
#   action   : init | validate | build   (default: validate)
#   target   : a build name or source, e.g. linux, windows,
#              amazon-ebs.ubuntu, or "all" (default: all)
#   var-file : path to a *.pkrvars.hcl file (default: example.pkrvars.hcl)
#
# Examples:
#   ./packer-build.sh validate
#   ./packer-build.sh build amazon-ebs.ubuntu prod.pkrvars.hcl
#   ./packer-build.sh build linux dev.auto.pkrvars.hcl
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

ACTION="${1:-validate}"
TARGET="${2:-all}"
VAR_FILE="${3:-example.pkrvars.hcl}"

if ! command -v packer >/dev/null 2>&1; then
  echo "error: packer is not installed or not on PATH" >&2
  exit 1
fi

VAR_ARG=()
if [ -f "${VAR_FILE}" ]; then
  VAR_ARG=(-var-file="${VAR_FILE}")
  echo ">> using var-file: ${VAR_FILE}"
else
  echo ">> var-file '${VAR_FILE}' not found; proceeding with defaults"
fi

ONLY_ARG=()
if [ "${TARGET}" != "all" ]; then
  ONLY_ARG=(-only="${TARGET}")
fi

case "${ACTION}" in
  init)
    echo ">> packer init"
    packer init .
    ;;
  fmt)
    echo ">> packer fmt -check -recursive"
    packer fmt -check -recursive .
    ;;
  validate)
    echo ">> packer init"
    packer init .
    echo ">> packer validate (${TARGET})"
    packer validate "${VAR_ARG[@]}" "${ONLY_ARG[@]}" .
    ;;
  build)
    echo ">> packer init"
    packer init .
    echo ">> packer validate (${TARGET})"
    packer validate "${VAR_ARG[@]}" "${ONLY_ARG[@]}" .
    echo ">> packer build (${TARGET})"
    packer build -timestamp-ui "${VAR_ARG[@]}" "${ONLY_ARG[@]}" .
    ;;
  *)
    echo "error: unknown action '${ACTION}' (expected init|fmt|validate|build)" >&2
    exit 1
    ;;
esac
