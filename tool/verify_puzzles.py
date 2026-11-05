"""Second, independent verification of the shipped puzzles (Master-Prompt 7).

Written separately from the Dart engine: plain backtracking over row/column/box
sets. For every puzzle it checks format, that the givens agree with the stored
solution, that the solution is a valid complete grid and that the puzzle has
exactly one solution. Also checks that no puzzle appears twice.

usage: python3 tool/verify_puzzles.py assets/puzzles/pool.json assets/puzzles/daily.json
"""
import json
import sys


def box(r, c):
    return (r // 3) * 3 + c // 3


def count_solutions(grid, limit=2):
    rows = [set() for _ in range(9)]
    cols = [set() for _ in range(9)]
    boxes = [set() for _ in range(9)]
    empty = []
    for i, v in enumerate(grid):
        r, c = divmod(i, 9)
        if v:
            if v in rows[r] or v in cols[c] or v in boxes[box(r, c)]:
                return 0
            rows[r].add(v)
            cols[c].add(v)
            boxes[box(r, c)].add(v)
        else:
            empty.append(i)
    found = 0

    def search():
        nonlocal found
        best, best_opts = None, None
        for i in empty:
            if grid[i]:
                continue
            r, c = divmod(i, 9)
            opts = [d for d in range(1, 10)
                    if d not in rows[r] and d not in cols[c] and d not in boxes[box(r, c)]]
            if best is None or len(opts) < len(best_opts):
                best, best_opts = i, opts
                if len(opts) <= 1:
                    break
        if best is None:
            found += 1
            return found >= limit
        r, c = divmod(best, 9)
        for d in best_opts:
            grid[best] = d
            rows[r].add(d)
            cols[c].add(d)
            boxes[box(r, c)].add(d)
            stop = search()
            rows[r].discard(d)
            cols[c].discard(d)
            boxes[box(r, c)].discard(d)
            grid[best] = 0
            if stop:
                return True
        return False

    search()
    return found


def valid_solution(sol):
    for k in range(9):
        row = {sol[k * 9 + c] for c in range(9)}
        col = {sol[r * 9 + k] for r in range(9)}
        bx = {sol[(3 * (k // 3) + r) * 9 + 3 * (k % 3) + c] for r in range(3) for c in range(3)}
        if row != set(range(1, 10)) or col != set(range(1, 10)) or bx != set(range(1, 10)):
            return False
    return True


def check(entry, where):
    p, s = entry["p"], entry["s"]
    assert len(p) == 81 and len(s) == 81 and p.isdigit() and s.isdigit(), f"{where}: format"
    puzzle = [int(ch) for ch in p]
    solution = [int(ch) for ch in s]
    assert all(v == 0 or v == solution[i] for i, v in enumerate(puzzle)), f"{where}: givens differ from solution"
    assert valid_solution(solution), f"{where}: invalid solution"
    n = count_solutions(list(puzzle))
    assert n == 1, f"{where}: {n} solutions"
    return p


def main(paths):
    seen = {}
    total = 0
    for path in paths:
        data = json.load(open(path))
        entries = []
        if "days" in data:
            for d, day in enumerate(data["days"]):
                assert len(day) == len(data["levels"]), f"{path} day {d}: wrong count"
                for lvl, e in zip(data["levels"], day):
                    entries.append((e, f"{path} day {d} {lvl}"))
        else:
            for lvl, items in data["levels"].items():
                for k, e in enumerate(items):
                    entries.append((e, f"{path} {lvl} #{k}"))
        for e, where in entries:
            fp = check(e, where)
            assert fp not in seen, f"{where}: duplicate of {seen[fp]}"
            seen[fp] = where
            total += 1
        print(f"{path}: {len(entries)} puzzles OK")
    print(f"all {total} puzzles verified, no duplicates")


if __name__ == "__main__":
    main(sys.argv[1:])
