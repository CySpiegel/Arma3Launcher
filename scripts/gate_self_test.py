#!/usr/bin/env python3
import copy, hashlib, importlib.util, json, pathlib, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERIFY = ROOT / "scripts/verify_repo.py"
spec = importlib.util.spec_from_file_location("verify_repo", VERIFY)
verify_repo = importlib.util.module_from_spec(spec); spec.loader.exec_module(verify_repo)
def run(root, only):
    return subprocess.run(["python3", str(VERIFY), "--root", str(root), "--only", only], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
def require_failure(root, only, name):
    if run(root, only) == 0: raise RuntimeError(f"negative gate case unexpectedly passed: {name}")

with tempfile.TemporaryDirectory() as temporary:
    fixture = pathlib.Path(temporary); (fixture / "docs/engineering").mkdir(parents=True)
    board = json.loads((ROOT / "docs/engineering/board.json").read_text())
    # The live board may be in any attempt phase. Board-structure fixtures start
    # in construction state so their validity is independent of a live candidate.
    live_task = next(item for item in board["tasks"] if item["id"] == "M0-001")
    live_task["attempts"][-1]["status"] = "running"
    live_task["attempts"][-1]["candidate"] = None
    task = next(item for item in board["tasks"] if item["id"] == "M0-001")
    revision = next(item for item in task["revisions"] if item["revision"] == task["current_revision"])
    for source in [binding["design"] for binding in revision["architecture_bindings"]]:
        target = fixture / source; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes((ROOT / source).read_bytes())
    for review in board["architecture_reviews"]:
        if review.get("evidence"):
            target = fixture / review["evidence"]; target.parent.mkdir(parents=True, exist_ok=True); target.write_text("fixture")
    packet = fixture / f"docs/engineering/tasks/M0-001-R{task['current_revision']}.md"
    packet.parent.mkdir(parents=True, exist_ok=True)
    packet.write_bytes((ROOT / f"docs/engineering/tasks/M0-001-R{task['current_revision']}.md").read_bytes())
    board_path = fixture / "docs/engineering/board.json"
    def write(value): board_path.write_text(json.dumps(value))
    write(board)
    if run(fixture, "board") != 0: raise RuntimeError("valid board fixture failed")
    board_path.write_text("{"); require_failure(fixture, "board", "malformed JSON")
    missing = copy.deepcopy(board); next(item for item in missing["tasks"] if item["id"] == "M0-001")["revisions"][-1].pop("architecture_bindings")
    omitted = copy.deepcopy(board); next(item for item in omitted["tasks"] if item["id"] == "M0-001")["revisions"][-1]["architecture_bindings"].pop()
    duplicate = copy.deepcopy(board); duplicate_bindings = next(item for item in duplicate["tasks"] if item["id"] == "M0-001")["revisions"][-1]["architecture_bindings"]; duplicate_bindings[2] = copy.deepcopy(duplicate_bindings[1])
    stale = copy.deepcopy(board); next(item for item in stale["tasks"] if item["id"] == "M0-001")["revisions"][-1]["architecture_bindings"][1]["sha256"] = "0" * 64
    no_review = copy.deepcopy(board); no_review["tasks"][-1]["revisions"][-1]["architecture_bindings"][1]["review_id"] = "missing"
    failed = copy.deepcopy(board); next(r for r in failed["architecture_reviews"] if r["id"] == "AR-002-R1")["verdict"] = "changes-required"
    bad_digest = copy.deepcopy(board); next(item for item in bad_digest["tasks"] if item["id"] == "M0-001")["revisions"][-1]["content_hash"] = "0" * 64
    bad_attempt = copy.deepcopy(board); next(item for item in bad_attempt["tasks"] if item["id"] == "M0-001")["attempts"][-1]["input_manifest"]["task_revision"] = "0" * 64
    invalidated = copy.deepcopy(board); next(r for r in invalidated["architecture_reviews"] if r["id"] == "AR-002-R1")["invalidation"] = {"reason": "fixture"}
    uncovered = copy.deepcopy(board); next(r for r in uncovered["architecture_reviews"] if r["id"] == "AR-002-R1")["covered_tasks"] = []
    wrong_revision = copy.deepcopy(board); next(r for r in wrong_revision["architecture_reviews"] if r["id"] == "AR-002-R1")["design_revision"] = 99
    for value, name in ((missing, "missing bindings"), (omitted, "omitted third binding"), (duplicate, "duplicate binding"), (stale, "historical match"), (no_review, "missing review"), (failed, "nonpassing review"), (bad_digest, "task digest"), (bad_attempt, "attempt input"), (invalidated, "invalidated review"), (uncovered, "review coverage"), (wrong_revision, "review revision")):
        write(value); require_failure(fixture, "board", name)
    packet.write_text("changed"); write(board); require_failure(fixture, "board", "task packet digest")
    packet.write_bytes((ROOT / f"docs/engineering/tasks/M0-001-R{task['current_revision']}.md").read_bytes())

    for name in ("Package.swift", ".swift-format", ".gitignore"):
        (fixture / name).write_text(name)
    for directory in ("Sources", "Tests", "App", "scripts", "Arma3Launcher.xcodeproj"):
        (fixture / directory).mkdir(exist_ok=True)
    (fixture / "Sources/example.swift").write_text("source")
    submitted = copy.deepcopy(board)
    submitted_task = next(item for item in submitted["tasks"] if item["id"] == "M0-001")
    submitted_attempt = submitted_task["attempts"][-1]
    submitted_attempt["status"] = "submitted"
    manifest = fixture / ".build/evidence/candidate/source-sha256.txt"
    manifest.parent.mkdir(parents=True)
    manifest.write_bytes(verify_repo.source_manifest(fixture))
    submitted_attempt["candidate"] = {"source_manifest": str(manifest.relative_to(fixture)), "sha256": hashlib.sha256(manifest.read_bytes()).hexdigest()}
    write(submitted)
    if run(fixture, "board") != 0: raise RuntimeError("valid submitted candidate failed")
    missing_candidate = copy.deepcopy(submitted)
    next(item for item in missing_candidate["tasks"] if item["id"] == "M0-001")["attempts"][-1]["candidate"] = None
    write(missing_candidate); require_failure(fixture, "board", "submitted candidate required")
    wrong_candidate_hash = copy.deepcopy(submitted)
    next(item for item in wrong_candidate_hash["tasks"] if item["id"] == "M0-001")["attempts"][-1]["candidate"]["sha256"] = "0" * 64
    write(wrong_candidate_hash); require_failure(fixture, "board", "candidate manifest hash")
    write(submitted)
    (fixture / "Sources/example.swift").write_text("changed")
    require_failure(fixture, "board", "candidate inventory mismatch")

with tempfile.TemporaryDirectory() as temporary:
    fixture = pathlib.Path(temporary); (fixture / "docs").mkdir(); (fixture / "README.md").write_text("[broken](missing.md)"); (fixture / "AGENTS.md").write_text("")
    require_failure(fixture, "links", "broken maintained link")

with tempfile.TemporaryDirectory() as temporary:
    fixture = pathlib.Path(temporary); (fixture / "Sources").mkdir(); (fixture / "Tests").mkdir(); (fixture / "App").mkdir(); (fixture / "scripts").mkdir()
    (fixture / "Arma3Launcher.xcodeproj").mkdir()
    (fixture / "Package.swift").write_bytes(b"one\ntwo")
    (fixture / ".swift-format").write_text(""); (fixture / ".gitignore").write_text("")
    result = subprocess.run(["python3", str(VERIFY), "--root", str(fixture), "--only", "lines"], capture_output=True, text=True, check=True)
    if "       2 Package.swift" not in result.stdout: raise RuntimeError("final unterminated line not counted")
print("Gate negative tests passed")
