#!/bin/sh
# AC1 teeth injector: 음수 래핑을 허용하는 약화 가드를 주입한다.
# 주입 자체는 exit 0. CI가 이어서 frozen ac1.sh의 MISS를 판정한다.
set -eu
cat > src/todo.py <<'EOF'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError   # mutant: 음수는 그대로 통과
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
EOF
