import argparse
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


LAB2_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = LAB2_ROOT / "python" / "lab-03-starter-project-python"
DOCKERFILES = ("Dockerfile.bad", "Dockerfile.good")
PIP_COMMAND = "RUN pip install --no-cache-dir -r requirements/backend.in"


def run_command(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        check=False,
    )


def ensure_tool_exists(tool: str) -> None:
    if shutil.which(tool) is None:
        raise RuntimeError(f"Required tool not found in PATH: {tool}")


def copy_project_to_temp() -> Path:
    temp_dir = Path(tempfile.mkdtemp(prefix="lab2-python-layers-"))
    work_dir = temp_dir / "project"

    def ignore(directory: str, entries: list[str]) -> set[str]:
        ignored = {".git", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", "lab2-python-notes.md"}
        return ignored.intersection(entries)

    shutil.copytree(PROJECT_ROOT, work_dir, ignore=ignore)
    return work_dir


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        sock.listen(1)
        return int(sock.getsockname()[1])


def build_image(work_dir: Path, dockerfile: str, tag: str, no_cache: bool) -> tuple[float, str]:
    command = ["docker", "build"]
    if no_cache:
        command.append("--no-cache")
    command.extend(["-f", dockerfile, "-t", tag, "."])

    started = time.perf_counter()
    result = run_command(command, cwd=work_dir)
    duration = time.perf_counter() - started
    if result.returncode != 0:
        raise RuntimeError(
            f"Docker build failed for {dockerfile}.\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return duration, result.stdout + result.stderr


def inspect_image_size(tag: str) -> int:
    result = run_command(["docker", "image", "inspect", tag, "--format", "{{.Size}}"])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to inspect image size for {tag}: {result.stderr}")
    return int(result.stdout.strip())


def wait_for_http(url: str, timeout_seconds: float = 20.0) -> tuple[bool, str]:
    deadline = time.time() + timeout_seconds
    last_error = ""
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                return True, response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
            last_error = str(exc)
            time.sleep(0.5)
    return False, last_error


def runtime_check(tag: str) -> dict:
    container_name = f"lab2-py-layers-{uuid.uuid4().hex[:8]}"
    port = find_free_port()
    run_result = run_command(
        ["docker", "run", "--rm", "-d", "-p", f"{port}:8080", "--name", container_name, tag]
    )
    if run_result.returncode != 0:
        return {"passed": False, "details": run_result.stderr.strip()}

    try:
        passed, details = wait_for_http(f"http://127.0.0.1:{port}/api")
        return {"passed": passed, "details": details}
    finally:
        run_command(["docker", "stop", container_name])


def append_marker(work_dir: Path, marker_text: str) -> None:
    index_path = work_dir / "build" / "index.html"
    original = index_path.read_text(encoding="utf-8")
    insertion = f"        <p>{marker_text}</p>\n"
    updated = original.replace("        <ul>\n", insertion + "        <ul>\n", 1)
    index_path.write_text(updated, encoding="utf-8")


def pip_layer_cached(build_log: str) -> bool:
    position = build_log.find(PIP_COMMAND)
    if position == -1:
        return False
    return "CACHED" in build_log[position : position + 300]


def bytes_to_mib(size_bytes: int) -> float:
    return size_bytes / (1024 * 1024)


def cleanup_images(tags: list[str]) -> None:
    for tag in tags:
        run_command(["docker", "image", "rm", "-f", tag])


def run_experiment(dockerfile: str, no_cache_initial: bool) -> dict:
    work_dir = copy_project_to_temp()
    image_prefix = f"lab2-{dockerfile.replace('Dockerfile.', '')}-{uuid.uuid4().hex[:8]}"
    initial_tag = f"{image_prefix}:initial"
    rebuild_tag = f"{image_prefix}:rebuild"

    try:
        initial_time, _ = build_image(work_dir, dockerfile, initial_tag, no_cache=no_cache_initial)
        initial_size = inspect_image_size(initial_tag)
        runtime = runtime_check(initial_tag)

        append_marker(work_dir, f"Automated rebuild marker [{uuid.uuid4().hex}]")

        rebuild_time, rebuild_log = build_image(work_dir, dockerfile, rebuild_tag, no_cache=False)
        rebuild_size = inspect_image_size(rebuild_tag)

        return {
            "dockerfile": dockerfile,
            "initial_build_time_seconds": initial_time,
            "initial_image_size_bytes": initial_size,
            "rebuild_time_seconds": rebuild_time,
            "rebuild_image_size_bytes": rebuild_size,
            "pip_layer_cached": pip_layer_cached(rebuild_log),
            "runtime_validity": runtime["passed"],
        }
    finally:
        cleanup_images([initial_tag, rebuild_tag])
        shutil.rmtree(work_dir.parent, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Python experiment: Docker layers and rebuild cache.")
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable Docker build cache for the initial build of each experiment.",
    )
    args = parser.parse_args()

    try:
        ensure_tool_exists("docker")
        ensure_tool_exists("python")
        results = [run_experiment(dockerfile, no_cache_initial=args.no_cache) for dockerfile in DOCKERFILES]
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Python Layers Experiment")
    for result in results:
        print(f"\nDockerfile: {result['dockerfile']}")
        print(f"  Initial build time: {result['initial_build_time_seconds']:.2f} s")
        print(
            f"  Initial image size: {result['initial_image_size_bytes']} bytes "
            f"({bytes_to_mib(result['initial_image_size_bytes']):.2f} MiB)"
        )
        print(f"  Rebuild time: {result['rebuild_time_seconds']:.2f} s")
        print(
            f"  Rebuild image size: {result['rebuild_image_size_bytes']} bytes "
            f"({bytes_to_mib(result['rebuild_image_size_bytes']):.2f} MiB)"
        )
        print(f"  Pip layer cached: {'yes' if result['pip_layer_cached'] else 'no'}")
        print(f"  Runtime validity: {'passed' if result['runtime_validity'] else 'failed'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
