#!/usr/bin/env bash
# Usage: ./lint.sh [AddonName]  (defaults to all)
luacheck "${1:-.}" --config .luacheckrc
