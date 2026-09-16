"""Generate a dependency-free Xcode project from the Swift source tree."""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def quote(value):
    return json.dumps(str(value))

def generate():
    objects = []
    def obj(key, isa, body):
        objects.append(f"\t\t{uid(key)} = {{isa = {isa}; {body} }};")
        return uid(key)
    def ids(values):
        return "(" + ", ".join(values) + ("," if values else "") + ")"
    targets = []
    groups = []
    products = []
    for target, folder, product_type in [
        ("GymTracker", "GymTracker", "application"),
        ("GymTrackerTests", "GymTrackerTests", "bundle.unit-test"),
        ("GymTrackerUITests", "GymTrackerUITests", "bundle.ui-testing"),
    ]:
        sources = sorted((ROOT / folder).glob("*.swift"))
        if not sources:
            continue
        files, builds, resources = [], [], []
        for source in sources:
            ref = obj(source.relative_to(ROOT).as_posix(), "PBXFileReference", f"lastKnownFileType = sourcecode.swift; path = {quote(source.name)}; sourceTree = \"<group>\";")
            files.append(ref)
            builds.append(obj("build:" + source.relative_to(ROOT).as_posix(), "PBXBuildFile", f"fileRef = {ref};"))
        if target == "GymTracker":
            for resource, kind in [("Assets.xcassets", "folder.assetcatalog"), ("PrivacyInfo.xcprivacy", "text.xml")]:
                ref = obj(resource, "PBXFileReference", f"lastKnownFileType = {kind}; path = {quote(resource)}; sourceTree = \"<group>\";")
                files.append(ref)
                resources.append(obj("build:" + resource, "PBXBuildFile", f"fileRef = {ref};"))
        groups.append(obj("group:" + target, "PBXGroup", f"children = {ids(files)}; path = {quote(folder)}; sourceTree = \"<group>\";"))
        extension = "app" if product_type == "application" else "xctest"
        product = obj("product:" + target, "PBXFileReference", f"explicitFileType = wrapper.{extension if extension == 'app' else 'cfbundle'}; includeInIndex = 0; path = {quote(target + '.' + extension)}; sourceTree = BUILT_PRODUCTS_DIR;")
        products.append(product)
        phases = [
            obj("sources:" + target, "PBXSourcesBuildPhase", f"buildActionMask = 2147483647; files = {ids(builds)}; runOnlyForDeploymentPostprocessing = 0;"),
            obj("frameworks:" + target, "PBXFrameworksBuildPhase", "buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;"),
            obj("resources:" + target, "PBXResourcesBuildPhase", f"buildActionMask = 2147483647; files = {ids(resources)}; runOnlyForDeploymentPostprocessing = 0;"),
        ]
        config_ids = []
        for config in ["Debug", "Release"]:
            settings = {
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.codex.gymtracker" + ("" if target == "GymTracker" else "." + target),
                "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "16.0", "TARGETED_DEVICE_FAMILY": "1",
                "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
                "GENERATE_INFOPLIST_FILE": "YES", "SWIFT_STRICT_CONCURRENCY": "targeted",
            }
            if target == "GymTracker":
                settings.update({"INFOPLIST_FILE": "GymTracker/Info.plist", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor"})
            elif target == "GymTrackerTests":
                settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/GymTracker.app/GymTracker", "BUNDLE_LOADER": "$(TEST_HOST)"})
            else:
                settings["TEST_TARGET_NAME"] = "GymTracker"
            body = " ".join(f"{key} = {quote(value)};" for key, value in settings.items())
            config_ids.append(obj(f"config:{target}:{config}", "XCBuildConfiguration", f"buildSettings = {{{body}}}; name = {config};"))
        config_list = obj("configlist:" + target, "XCConfigurationList", f"buildConfigurations = {ids(config_ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
        dependencies = []
        if target != "GymTracker":
            proxy = obj("proxy:" + target, "PBXContainerItemProxy", f"containerPortal = {uid('project')}; proxyType = 1; remoteGlobalIDString = {uid('target:GymTracker')}; remoteInfo = GymTracker;")
            dependencies.append(obj("dependency:" + target, "PBXTargetDependency", f"target = {uid('target:GymTracker')}; targetProxy = {proxy};"))
        targets.append(obj("target:" + target, "PBXNativeTarget", f"buildConfigurationList = {config_list}; buildPhases = {ids(phases)}; buildRules = (); dependencies = {ids(dependencies)}; name = {target}; productName = {target}; productReference = {product}; productType = {quote('com.apple.product-type.' + product_type)};"))
    groups.append(obj("products", "PBXGroup", f"children = {ids(products)}; name = Products; sourceTree = \"<group>\";"))
    obj("main", "PBXGroup", f"children = {ids(groups)}; sourceTree = \"<group>\";")
    configs = []
    for name in ["Debug", "Release"]:
        settings = {"SDKROOT": "iphoneos", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym", "ENABLE_TESTABILITY": "YES" if name == "Debug" else "NO", "ONLY_ACTIVE_ARCH": "YES" if name == "Debug" else "NO"}
        if name == "Debug": settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        configs.append(obj("projectconfig:" + name, "XCBuildConfiguration", "buildSettings = {" + " ".join(f"{k} = {quote(v)};" for k, v in settings.items()) + f"}}; name = {name};"))
    obj("projectconfiglist", "XCConfigurationList", f"buildConfigurations = {ids(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
    obj("project", "PBXProject", f"attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600;}}; buildConfigurationList = {uid('projectconfiglist')}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = es; hasScannedForEncodings = 0; knownRegions = (es, en, Base); mainGroup = {uid('main')}; productRefGroup = {uid('products')}; projectDirPath = \"\"; projectRoot = \"\"; targets = {ids(targets)};")
    project_dir = ROOT / "GymTracker.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    (project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {uid('project')};\n}}\n", encoding="utf-8")
    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    def reference(parent, target):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=uid("target:" + target), BuildableName=target + (".app" if target == "GymTracker" else ".xctest"), BlueprintName=target, ReferencedContainer="container:GymTracker.xcodeproj")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    reference(entry, "GymTracker")
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    testables = ET.SubElement(test, "Testables")
    for target in ["GymTrackerTests", "GymTrackerUITests"]:
        if (ROOT / target).exists():
            item = ET.SubElement(testables, "TestableReference", skipped="NO"); reference(item, target)
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
    reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), "GymTracker")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), "GymTracker")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    scheme_dir = project_dir / "xcshareddata" / "xcschemes"; scheme_dir.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(scheme_dir / "GymTracker.xcscheme", encoding="utf-8", xml_declaration=True)
    print(f"Generated {project_dir} with {len(targets)} targets")

if __name__ == "__main__": generate()
