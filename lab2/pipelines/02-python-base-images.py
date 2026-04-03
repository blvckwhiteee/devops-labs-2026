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
EXPERIMENTS = (("debian", "Dockerfile.good"), ("alpine", "Dockerfile.alpine"))


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
    temp_dir = Path(tempfile.mkdtemp(prefix="lab2-python-base-"))
    work_dir = temp_dir / "project"

    def ignore(directory: str, entries: list[str]) -> set[str]:
        ignored = {".git", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", "lab2-python-notes.md"}
        return ignored.intersection(entries)

    shutil.copytree(PROJECT_ROOT, work_dir, ignore=ignore)
    return work_dir


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


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        sock.listen(1)
        return int(sock.getsockname()[1])


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


def runtime_check(tag: str) -> bool:
    container_name = f"lab2-py-base-{uuid.uuid4().hex[:8]}"
    port = find_free_port()
    run_result = run_command(
        ["docker", "run", "--rm", "-d", "-p", f"{port}:8080", "--name", container_name, tag]
    )
    if run_result.returncode != 0:
        return False
    try:
        passed, _ = wait_for_http(f"http://127.0.0.1:{port}/api/matrix-product")
        return passed
    finally:
        run_command(["docker", "stop", container_name])


def detect_numpy_wheel(build_log: str) -> str:
    if "musllinux" in build_log:
        return "musllinux"
    if "manylinux" in build_log:
        return "manylinux"
    return "unknown"


def bytes_to_mib(size_bytes: int) -> float:
    return size_bytes / (1024 * 1024)


def cleanup_image(tag: str) -> None:
    run_command(["docker", "image", "rm", "-f", tag])


def run_experiment(name: str, dockerfile: str, no_cache: bool) -> dict:
    work_dir = copy_project_to_temp()
    tag = f"lab2-{name}-base:{uuid.uuid4().hex[:8]}"
    try:
        build_time, build_log = build_image(work_dir, dockerfile, tag, no_cache=no_cache)
        image_size = inspect_image_size(tag)
        runtime_validity = runtime_check(tag)
        return {
            "name": name,
            "dockerfile": dockerfile,
            "build_time_seconds": build_time,
            "image_size_bytes": image_size,
            "numpy_wheel_type": detect_numpy_wheel(build_log),
            "runtime_validity": runtime_validity,
        }
    finally:
        cleanup_image(tag)
        shutil.rmtree(work_dir.parent, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Python experiment: Debian vs Alpine base images.")
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable Docker build cache for both image builds.",
    )
    args = parser.parse_args()

    try:
        ensure_tool_exists("docker")
        ensure_tool_exists("python")
        results = [run_experiment(name, dockerfile, args.no_cache) for name, dockerfile in EXPERIMENTS]
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Python Base Image Comparison")
    for result in results:
        print(f"\nImage: {result['name']}")
        print(f"  Dockerfile: {result['dockerfile']}")
        print(f"  Build time: {result['build_time_seconds']:.2f} s")
        print(
            f"  Image size: {result['image_size_bytes']} bytes "
            f"({bytes_to_mib(result['image_size_bytes']):.2f} MiB)"
        )
        print(f"  Numpy wheel type: {result['numpy_wheel_type']}")
        print(f"  Runtime validity: {'passed' if result['runtime_validity'] else 'failed'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
