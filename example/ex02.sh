#!/bin/sh
set -xe
cd "$(dirname $0)"
[ -d dummy_rails_app ] || rails new dummy_rails_app
cd dummy_rails_app
unset RUBYOPT
time strace -o wo_require_faster.strace rails c < /dev/null
export RequireFaster_DEBUG=1
RUBYOPT="-I$(cd ../../lib && /bin/pwd) -rrequire_faster" time strace -o w_require_faster.strace rails c < /dev/null
wc -l *.strace
