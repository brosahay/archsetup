#!/bin/bash

######################################################################
#
#  Copyright (c) 2019 revosftw (https://github.com/revosftw)
#
######################################################################

if [[ -f `pwd`/scripts/shared_functions ]]; then
  source ./scripts/shared_functions
else
  echo "missing file: shared_functions"
  exit 1
fi
