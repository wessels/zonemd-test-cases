#!/bin/sh
set -e

origin=$1 ; shift
file=$1; shift

/path/to/ldns-verify-zone -Z $file
