"""Structural checks usable on Windows. This does NOT compile or type-check Swift."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
project = ROOT / "GymTracker.xcodeproj" / "project.pbxproj"
subprocess.run([sys.executable, str(ROOT / "tools/generate_project.py")], check=True)
before = project.read_bytes()
subprocess.run([sys.executable, str(ROOT / "tools/generate_project.py")], check=True)
assert before == project.read_bytes(), "Project generation must be deterministic"
text = before.decode()
defined = re.findall(r"([A-F0-9]{24}) = \{isa =", text)
assert len(defined) == len(set(defined)), "Duplicate project object IDs"
assert set(re.findall(r"\b[A-F0-9]{24}\b", text)) <= set(defined), "Dangling project object reference"
swift_files = sorted(ROOT.glob("GymTracker*/*.swift"))
for path in swift_files:
    relative = path.relative_to(ROOT).as_posix()
    identity = hashlib.sha256(relative.encode()).hexdigest()[:24].upper()
    assert identity in defined, f"Missing source: {path}"
for path in [ROOT / "GymTracker/Info.plist", ROOT / "GymTracker/PrivacyInfo.xcprivacy"]:
    with path.open("rb") as file:
        plistlib.load(file)
scheme = ET.parse(ROOT / "GymTracker.xcodeproj/xcshareddata/xcschemes/GymTracker.xcscheme")
for reference in scheme.iter("BuildableReference"):
    assert reference.attrib["BlueprintIdentifier"] in defined, "Scheme references nonexistent target"
for path in (ROOT / "GymTracker/Assets.xcassets").rglob("Contents.json"):
    obj = json.loads(path.read_text())
    for image in obj.get("images", []):
        if "filename" in image:
            assert (path.parent / image["filename"]).is_file(), "Missing image resource"
seed = (ROOT / "GymTracker/ExerciseSeed.swift").read_text(encoding="utf-8")
assert len(re.findall(r"Exercise\(id:", seed)) == 104, "Expected full 104 exercise catalog"
source_seed = ROOT / "reference/ExerciseSeed.kt"
if source_seed.exists():
    original = source_seed.read_text(encoding="utf-8")
    android_rows = re.findall(r'^\s*(?:chest|back|shoulder|legs|arms|core|cardio|technogym)\("([^"]+)".*?mapOf\((.*?)\)\)', original, re.M)
    swift_rows = re.findall(r'Exercise\(id: "([^"]+)", name: "([^"]+)".*?muscles: \[([^\]]*)\]', seed)
    assert len(android_rows) == len(swift_rows) == 104
    for (name, muscles), (identifier, swift_name, swift_muscles) in zip(android_rows, swift_rows):
        assert name == swift_name
        assert re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_') == identifier
        left = {key: int(value) for key, value in re.findall(r'"([^"]+)" to (\d+)', muscles)}
        right = {key: int(value) for key, value in re.findall(r'"([^"]+)": (\d+)', swift_muscles)}
        assert left == right and sum(right.values()) == 100, name
assert not re.search(r'Button\(\s*"[^"\n]*"\s*,\s*systemImage:', "\n".join(p.read_text(encoding="utf-8") for p in swift_files)), "Use iOS 16 compatible Button/Label initializers"
report = {
    "status": "structural-checks-passed",
    "swiftSourceFiles": len(swift_files),
    "projectObjects": len(defined),
    "seedExercises": 104,
    "xcodeBuildRun": False,
    "swiftTypeCheckingRun": False,
    "xctestRun": False,
    "ipaGenerated": False,
}
output = ROOT / "validation-structure.json"
output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
