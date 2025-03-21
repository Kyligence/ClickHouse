#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$CLICKHOUSE_LOCAL --multiquery "SELECT 100"
$CLICKHOUSE_LOCAL --multiquery "SELECT 101;"
$CLICKHOUSE_LOCAL --multiquery "SELECT 102;SELECT 103;"

# Invalid SQL.
$CLICKHOUSE_LOCAL --multiquery "SELECT 200; S" 2>&1 | grep -o 'Syntax error'
$CLICKHOUSE_LOCAL --multiquery "; SELECT 201;" 2>&1 | grep -o 'Empty query'
$CLICKHOUSE_LOCAL --multiquery "; S; SELECT 202" 2>&1 | grep -o 'Empty query'

# Error expectation cases.
# -n <SQL> is prohibited
$CLICKHOUSE_LOCAL -n "SELECT 301" 2>&1 | grep -o 'BAD_ARGUMENTS'
$CLICKHOUSE_LOCAL -n "SELECT 302;" 2>&1 | grep -o 'BAD_ARGUMENTS'
$CLICKHOUSE_LOCAL -n "SELECT 304;SELECT 305;" 2>&1 | grep -o 'BAD_ARGUMENTS'
$CLICKHOUSE_LOCAL --multiquery --multiquery 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL -n --multiquery 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --multiquery -n 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --multiquery --multiquery "SELECT 306; SELECT 307;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL -n --multiquery "SELECT 307; SELECT 308;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --multiquery "SELECT 309; SELECT 310;" --multiquery  2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --multiquery "SELECT 311;" --multiquery "SELECT 312;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --multiquery "SELECT 313;" -n "SELECT 314;" 2>&1 | grep -o 'BAD_ARGUMENTS'
$CLICKHOUSE_LOCAL --multiquery "SELECT 315;" --query "SELECT 316;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL -n "SELECT 320" --query "SELECT 317;" 2>&1 | grep -o 'BAD_ARGUMENTS'
$CLICKHOUSE_LOCAL --query --multiquery --multiquery "SELECT 318;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --query --multiquery "SELECT 319;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --query -n "SELECT 400;" 2>&1 | grep -o 'Bad arguments'
$CLICKHOUSE_LOCAL --query -n --multiquery "SELECT 401;" 2>&1 | grep -o 'Bad arguments'