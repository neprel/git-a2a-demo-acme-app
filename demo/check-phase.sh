#!/usr/bin/env bash
set -euo pipefail

phase=${1:?usage: check-phase.sh baseline|final}
cd "${DEMO_APP_ROOT:-/workspace/app}"

case "$phase" in
  baseline)
    npm_result=$(node app.mjs '   ')
    uv_result=$(uv run --frozen python app.py '   ')
    go_result=$(go run ./cmd/demo '   ')
    test -z "$npm_result"
    test -z "$uv_result"
    test -z "$go_result"
    cmake -S . -B .demo-build -DBUILD_TESTING=OFF >/dev/null
    cmake --build .demo-build >/dev/null
    cmake_result=$(./.demo-build/cmake/acme_consumer_cpp '   ')
    test -z "$cmake_result"
    printf 'npm blank => %q\nuv blank => %q\nGo blank => %q\nCMake blank => %q\n' \
      "$npm_result" "$uv_result" "$go_result" "$cmake_result"
    ;;
  final)
    npm_result=$(node --input-type=module -e \
      'import {formatDisplayName} from "@acme/lib-utils"; const got=formatDisplayName("  ", " Anonymous "); if(got!=="Anonymous") process.exit(1); console.log(got)')
    uv_result=$(uv run --frozen python -c \
      'from acme_lib_utils import format_display_name; got=format_display_name("  ", " Anonymous "); assert got == "Anonymous"; print(got)')
    mkdir -p .demo-final-go
    printf '%s\n' \
      'package main' \
      'import ("fmt"; lib "github.com/neprel/git-a2a-demo-acme-lib")' \
      'func main(){ got:=lib.FormatDisplayName("  ", " Anonymous "); if got!="Anonymous" { panic(got) }; fmt.Println(got) }' \
      > .demo-final-go/main.go
    go_result=$(go run ./.demo-final-go)
    cp cmake/main.cpp .demo-main.cpp
    trap 'mv .demo-main.cpp cmake/main.cpp' EXIT
    printf '%s\n' \
      '#include "acme_lib_utils.hpp"' \
      '#include <iostream>' \
      'int main(){auto got=acme::format_display_name("  ", " Anonymous "); if(got!="Anonymous") return 1; std::cout << got << "\n";}' \
      > cmake/main.cpp
    cmake -S . -B .demo-build -DBUILD_TESTING=OFF >/dev/null
    cmake --build .demo-build >/dev/null
    cmake_result=$(./.demo-build/cmake/acme_consumer_cpp)
    test "$npm_result" = Anonymous
    test "$uv_result" = Anonymous
    test "$go_result" = Anonymous
    test "$cmake_result" = Anonymous
    printf 'npm blank+fallback => %q\nuv blank+fallback => %q\nGo blank+fallback => %q\nCMake blank+fallback => %q\n' \
      "$npm_result" "$uv_result" "$go_result" "$cmake_result"
    ;;
  *) echo "unknown phase: $phase" >&2; exit 2;;
esac
