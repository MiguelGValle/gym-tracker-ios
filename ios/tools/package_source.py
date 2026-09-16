"""Create a reviewable source bundle; intentionally contains no APK, data or secrets."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[2]
output = root / "outputs" / "ios"
output.mkdir(parents=True, exist_ok=True)
archive = output / "GymTracker-iPhone-source.zip"
paths = [p for p in (root / "ios").rglob("*") if p.is_file()
         and not any(part in {"build", "__pycache__", "xcuserdata", ".DS_Store"} for part in p.relative_to(root / "ios").parts)
         and p.suffix not in {".ipa", ".p12", ".mobileprovision", ".p8", ".pyc"}]
paths += [root / ".github/workflows/ios.yml", root / ".gitattributes"]
manifest = {}
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
    for path in sorted(paths):
        name = path.relative_to(root).as_posix()
        data = path.read_bytes()
        package.writestr(name, data)
        manifest[name] = hashlib.sha256(data).hexdigest()
    package.writestr("README.md", "# Gym Tracker para iPhone\n\nApp nativa SwiftUI. Estado, compilación e instalación en [ios/README.md](ios/README.md).\n\nEl paquete contiene fuentes; no contiene un IPA ya compilado.\n")
    package.writestr(".gitignore", "ios/build/\n**/xcuserdata/\n**/__pycache__/\n*.ipa\n*.p12\n*.p8\n*.mobileprovision\noutputs/\n")
(output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
(output / "GymTracker-iPhone-source.zip.sha256").write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n", encoding="utf-8")
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert ".github/workflows/ios.yml" in package.namelist()
    assert "ios/GymTracker.xcodeproj/project.pbxproj" in package.namelist()
    assert all(not name.startswith("/") and ".." not in Path(name).parts for name in package.namelist())
print(json.dumps({"path": str(archive), "bytes": archive.stat().st_size, "sourceFiles": len(paths)}, indent=2))
