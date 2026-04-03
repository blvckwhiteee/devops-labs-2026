import argparse
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


LAB2_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = LAB2_ROOT / "golang" / "deploy.lab-containers-starter-project-golang"
EXPERIMENTS = (
    ("single", "Dockerfile.single"),
    ("scratch", "Dockerfile.scratch"),
    ("distroless", "Dockerfile.distroless"),
)


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


def build_image(dockerfile: str, tag: str, no_cache: bool) -> float:
    command = ["docker", "build"]
    if no_cache:
        command.append("--no-cache")
    command.extend(["-f", dockerfile, "-t", tag, "."])

    started = time.perf_counter()
    result = run_command(command, cwd=PROJECT_ROOT)
    duration = time.perf_counter() - started
    if result.returncode != 0:
        raise RuntimeError(
            f"Docker build failed for {dockerfile}.\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return duration


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


def wait_for_http(url: str, timeout_seconds: float = 20.0) -> tuple[bool, int | None]:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                return True, response.status
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(0.5)
    return False, None


def runtime_check(tag: str) -> tuple[bool, int | None]:
    container_name = f"lab2-go-run-{uuid.uuid4().hex[:8]}"
    port = find_free_port()
    run_result = run_command(
        ["docker", "run", "--rm", "-d", "-p", f"{port}:8080", "--name", container_name, tag]
    )
    if run_result.returncode != 0:
        return False, None
    try:
        return wait_for_http(f"http://127.0.0.1:{port}/")
    finally:
        run_command(["docker", "stop", container_name])


def count_history_layers(tag: str) -> int:
    result = run_command(["docker", "history", tag, "--format", "{{.CreatedBy}}"])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to inspect history for {tag}: {result.stderr}")
    return len([line for line in result.stdout.splitlines() if line.strip()])


def bytes_to_mib(size_bytes: int) -> float:
    return size_bytes / (1024 * 1024)


def cleanup_image(tag: str) -> None:
    run_command(["docker", "image", "rm", "-f", tag])


def run_experiment(name: str, dockerfile: str, no_cache: bool) -> dict:
    tag = f"lab2-go-{name}:{uuid.uuid4().hex[:8]}"
    try:
        build_time = build_image(dockerfile, tag, no_cache=no_cache)
        image_size = inspect_image_size(tag)
        layer_count = count_history_layers(tag)
        runtime_validity, status_code = runtime_check(tag)
        return {
            "name": name,
            "dockerfile": dockerfile,
            "build_time_seconds": build_time,
            "image_size_bytes": image_size,
            "layer_count": layer_count,
            "runtime_validity": runtime_validity,
            "http_status": status_code,
        }
    finally:
        cleanup_image(tag)


def main() -> int:
    parser = argparse.ArgumentParser(description="Golang experiment: single-stage, scratch, distroless.")
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable Docker build cache for all image builds.",
    )
    args = parser.parse_args()

    try:
        ensure_tool_exists("docker")
        ensure_tool_exists("python")
        results = [run_experiment(name, dockerfile, args.no_cache) for name, dockerfile in EXPERIMENTS]
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Golang Image Comparison")
    for result in results:
        print(f"\nImage: {result['name']}")
        print(f"  Dockerfile: {result['dockerfile']}")
        print(f"  Build time: {result['build_time_seconds']:.2f} s")
        print(
            f"  Image size: {result['image_size_bytes']} bytes "
            f"({bytes_to_mib(result['image_size_bytes']):.2f} MiB)"
        )
        print(f"  Layer count: {result['layer_count']}")
        print(f"  Runtime validity: {'passed' if result['runtime_validity'] else 'failed'}")
        if result["http_status"] is not None:
            print(f"  HTTP status: {result['http_status']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
