#!/usr/bin/env python3
import argparse, hashlib, json, pathlib, re, sys

def fail(message): raise ValueError(message)

def digest_json(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

def verify_board(root):
    board = json.loads((root / "docs/engineering/board.json").read_text())
    tasks = [task for task in board.get("tasks", []) if task.get("id") == "M0-001"]
    if len(tasks) != 1: fail("current M0-001 task missing or ambiguous")
    task = tasks[0]
    revisions = [item for item in task.get("revisions", []) if item.get("revision") == task.get("current_revision")]
    if len(revisions) != 1: fail("current M0-001 revision missing or ambiguous")
    revision = revisions[0]
    recorded_hash = revision.get("content_hash")
    hash_input = dict(revision); hash_input.pop("content_hash", None)
    if recorded_hash != digest_json(hash_input): fail("current task revision digest mismatch")
    packet = root / f"docs/engineering/tasks/{task['id']}-R{task['current_revision']}.md"
    if hashlib.sha256(packet.read_bytes()).hexdigest() != revision.get("authoritative_inputs", {}).get("task_packet"):
        fail("current task packet digest mismatch")
    bindings = revision.get("architecture_bindings")
    if not isinstance(bindings, list) or len(bindings) != 3: fail("current architecture bindings missing")
    if len({binding.get("design") for binding in bindings}) != len(bindings):
        fail("duplicate architecture design binding")
    if len({binding.get("review_id") for binding in bindings}) != len(bindings):
        fail("duplicate architecture review binding")
    reviews = {review.get("id"): review for review in board.get("architecture_reviews", [])}
    for binding in bindings:
        design = root / binding["design"]
        actual = hashlib.sha256(design.read_bytes()).hexdigest()
        if actual != binding.get("sha256"): fail(f"stale architecture hash: {binding['design']}")
        review = reviews.get(binding.get("review_id"))
        if not review or review.get("verdict") != "pass" or review.get("adopted") is not True:
            fail(f"architecture review not passing/adopted: {binding.get('review_id')}")
        if review.get("design_hash") != actual: fail(f"review hash mismatch: {binding.get('review_id')}")
        if review.get("design_revision") != binding.get("revision"): fail("review revision mismatch")
        if task["id"] not in review.get("covered_tasks", []): fail("review task coverage missing")
        if review.get("invalidation") is not None: fail("architecture review invalidated")
        if review.get("reviewer") == review.get("author"): fail("architecture review is not independent")
        if not (root / review["evidence"]).is_file(): fail(f"review evidence missing: {review['evidence']}")
    attempts = task.get("attempts", [])
    if not attempts: fail("task attempt missing")
    attempt = attempts[-1]
    if attempt.get("task_revision") != task["current_revision"]: fail("latest attempt revision mismatch")
    inputs = attempt.get("input_manifest", {})
    if inputs.get("task_revision") != recorded_hash: fail("latest attempt task input mismatch")
    if inputs.get("architectures") != [binding["sha256"] for binding in bindings]:
        fail("latest attempt architecture inputs mismatch")
    if attempt.get("repair_ordinal", 0) > 0:
        previous = attempts[-2].get("candidate") if len(attempts) > 1 else None
        if not previous or inputs.get("prior_candidate") != previous.get("sha256"):
            fail("latest attempt prior candidate mismatch")
    candidate = attempt.get("candidate")
    if attempt.get("status") == "submitted":
        if not candidate: fail("submitted attempt candidate missing")
        manifest = root / candidate["source_manifest"]
        data = manifest.read_bytes()
        if hashlib.sha256(data).hexdigest() != candidate.get("sha256"):
            fail("submitted candidate manifest hash mismatch")
        if data != source_manifest(root): fail("submitted candidate source inventory mismatch")
    elif candidate is not None:
        fail("active construction attempt must not bind a candidate")

def maintained_markdown(root):
    files = [root / "README.md", root / "AGENTS.md"] + list((root / "docs").rglob("*.md"))
    return [p for p in files if "/reviews/" not in p.as_posix() and "/templates/" not in p.as_posix()]

def verify_links(root):
    pattern = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
    for document in maintained_markdown(root):
        for target in pattern.findall(document.read_text(errors="replace")):
            target = target.strip().split("#", 1)[0].strip("<>")
            if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target): continue
            if not (document.parent / target).resolve().exists():
                fail(f"broken local link in {document.relative_to(root)}: {target}")

def source_files(root):
    result = [root / name for name in ("Package.swift", ".swift-format", ".gitignore")]
    for directory in ("Sources", "Tests", "App", "scripts", "Arma3Launcher.xcodeproj"):
        result += [
            p for p in (root / directory).rglob("*") if p.is_file()
            and "xcuserdata" not in p.parts and "__pycache__" not in p.parts and p.suffix != ".pyc"
        ]
    return sorted(set(result))

def source_manifest(root):
    return "".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(root).as_posix()}\n"
        for path in source_files(root)
    ).encode()

def physical_lines(data): return data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)

def verify_lines(root, output=None):
    rows = [(physical_lines(path.read_bytes()), path.relative_to(root)) for path in source_files(root)]
    for count, path in rows:
        if count > 1400: fail(f"hard line limit exceeded: {path} ({count})")
    text = "".join(f"{count:8d} {path}\n" for count, path in rows) + f"{sum(r[0] for r in rows):8d} total\n"
    if output: output.write_text(text)
    else: print(text, end="")

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    parser.add_argument("--only", choices=("board", "links", "lines")); parser.add_argument("--line-output", type=pathlib.Path)
    parser.add_argument("--manifest-output", type=pathlib.Path)
    args = parser.parse_args(); root = args.root.resolve()
    try:
        if args.only in (None, "board"): verify_board(root)
        if args.only in (None, "links"): verify_links(root)
        if args.only in (None, "lines"): verify_lines(root, args.line_output)
        if args.manifest_output:
            args.manifest_output.write_bytes(source_manifest(root))
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"verification failed: {error}", file=sys.stderr); return 1
    return 0

if __name__ == "__main__": raise SystemExit(main())
