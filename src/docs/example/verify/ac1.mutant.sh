#!/bin/sh
# AC1 teeth: 막으려는 위반(mutant)을 주입하면 검증이 MISS여야 한다(=비0).
# mutant = upper-bound만 검사하는 약화 가드(음수 래핑 허용). 이게 통과하면 검증이 약한 것.
set -eu
d=$(mktemp -d)
cat > "$d/todo.py" <<'EOF'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError   # mutant: 음수는 그대로 통과 → 래핑
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
EOF
PYTHONPATH="$d" python3 - <<'EOF'
from todo import TodoList
import sys
t = TodoList()
for x in ("a", "b", "c"):
    t.add(x)
try:
    t.complete(-1); sys.exit(1)   # 래핑되면 raise 안 됨 → exit1(=mutant이 잡힘=teeth 있음)
except IndexError:
    pass
if t.pending() != ["a", "b", "c"]:
    sys.exit(1)
sys.exit(0)
EOF
rc=$?
rm -rf "$d"
exit $rc
