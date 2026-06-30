# 워크드 예시 — 수정 후(fixed) 구현. AC1을 충족한다.
# (수정 전 baseline은 complete()가 `self.items[i]["done"]=True`로 음수 인덱스를 silent wrap했다.)
class TodoList:
    def __init__(self):
        self.items = []

    def add(self, t):
        self.items.append({"text": t, "done": False})
        return len(self.items) - 1

    def complete(self, i):
        if not isinstance(i, int) or not 0 <= i < len(self.items):
            raise IndexError(i)
        self.items[i]["done"] = True

    def pending(self):
        return [x["text"] for x in self.items if not x["done"]]
