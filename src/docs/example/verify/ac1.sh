#!/bin/sh
# AC1 frozen 검증: complete(음수/범위밖)은 IndexError + 상태 불변. 통과=exit0.
# (실제 task에선 .ultra-waterfall/verify/ac1.sh로 emit되어 merge 시점 CI가 재실행한다.)
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
PYTHONPATH="$here/../src" python3 - <<'EOF'
from todo import TodoList
import sys
t = TodoList()
for x in ("a", "b", "c"):
    t.add(x)
try:
    t.complete(-1); print("MISS: complete(-1) no raise"); sys.exit(1)
except IndexError:
    pass
try:
    t.complete(3); print("MISS: complete(len) no raise"); sys.exit(1)
except IndexError:
    pass
if t.pending() != ["a", "b", "c"]:
    print("MISS: state changed"); sys.exit(1)
print("OK"); sys.exit(0)
EOF
