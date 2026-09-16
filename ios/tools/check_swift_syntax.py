"""Parse Swift with tree-sitter; no type-checking or Apple SDK validation."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
local_tools = root.parent / "outputs" / "ios-validation-tools"
if local_tools.is_dir():
    sys.path.insert(0, str(local_tools))
from tree_sitter import Language, Parser
import tree_sitter_swift

parser = Parser(Language(tree_sitter_swift.language()))
errors = []
paths = sorted(root.glob("GymTracker*/*.swift"))
for path in paths:
    data = path.read_bytes()
    tree = parser.parse(data)
    nodes = [tree.root_node]
    while nodes:
        node = nodes.pop()
        if node.type == "ERROR" or node.is_missing:
            errors.append({"file": str(path.relative_to(root)), "line": node.start_point.row + 1,
                           "column": node.start_point.column + 1, "kind": node.type,
                           "text": data[node.start_byte:node.end_byte].decode(errors="replace")[:180]})
        else:
            nodes.extend(reversed(node.children))
report = {"parser": "tree-sitter-swift", "swiftFiles": len(paths), "errors": errors,
          "typeChecked": False, "xcodeCompiled": False}
(root / "validation-syntax.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2, ensure_ascii=False))
sys.exit(1 if errors else 0)
