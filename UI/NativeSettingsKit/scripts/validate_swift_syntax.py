"""Optional syntax check only. Install tree-sitter and tree-sitter-swift in an isolated env."""
from pathlib import Path
import sys
try:
    import tree_sitter
    import tree_sitter_swift
except ImportError:
    print("NOT RUN: install tree-sitter==0.26.0 and tree-sitter-swift==0.7.4 in an isolated environment.")
    raise SystemExit(2)

root = Path(__file__).resolve().parents[1]
parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
files = sorted(root.rglob("*.swift"))
failed = []
for file in files:
    if any(part in {".build", ".validation", ".swiftpm"} for part in file.relative_to(root).parts):
        continue
    tree = parser.parse(file.read_bytes())
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == "ERROR" or node.is_missing:
            failed.append(f"{file.relative_to(root)}:{node.start_point.row + 1}: {node.type}")
        stack.extend(reversed(node.children))
for issue in failed:
    print(issue)
print(f"{'FAIL' if failed else 'PASS'}: {len(files)} Swift files parsed; syntax grammar only, no type checking.")
sys.exit(bool(failed))
