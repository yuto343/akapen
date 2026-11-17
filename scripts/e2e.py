#!/usr/bin/env python3
"""同一リポジトリの全 E2E を flock で直列化。ロックは終了時に OS が解放する。"""
import fcntl, os, pathlib, re, subprocess, sys, time, shutil, json
root = pathlib.Path(__file__).resolve().parents[1]
os.chdir(root)
# clean で inode が変わらないよう、ロックは build の外に置く。
import hashlib, tempfile
lock_path = pathlib.Path(tempfile.gettempdir()) / ('akapen-e2e-' + hashlib.sha256(str(root).encode()).hexdigest()[:16] + '.lock')
with lock_path.open('w') as lock:
    print('Waiting for E2E lock...', flush=True)
    fcntl.flock(lock, fcntl.LOCK_EX)
    start = time.monotonic()
    subprocess.run(['make', 'gen'], check=True)
    mode, only = sys.argv[1:3]
    sources = list(pathlib.Path('e2e/tests').rglob('*.swift'))
    classes = []
    for source in sources:
        if ('Live' in source.parts) != (mode == 'live'): continue
        classes += re.findall(r'(?:final\s+)?class\s+(\w+)\s*:\s*AkapenUITestCase', source.read_text())
    if only:
        if only not in classes: sys.exit('Unknown test class for this mode: ' + only)
        classes = [only]
    if not classes: sys.exit('No test classes for ' + mode)
    shutil.rmtree('build/e2e.xcresult', ignore_errors=True)
    env = os.environ.copy(); env['AKAPEN_CAPTURE'] = mode
    env['TEST_RUNNER_AKAPEN_CAPTURE'] = mode
    args = ['bash', 'scripts/xcode.sh', 'test', '-destination', 'platform=macOS', '-parallel-testing-enabled', 'NO', '-resultBundlePath', 'build/e2e.xcresult']
    args += ['-only-testing:AkapenE2E/' + name for name in classes]
    result = subprocess.run(args, env=env)
    if pathlib.Path('build/e2e.xcresult').exists():
        summary = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', 'build/e2e.xcresult'], capture_output=True, text=True)
        pathlib.Path('build/logs/e2e-summary.json').write_text(summary.stdout)
        if summary.returncode == 0:
            data = json.loads(summary.stdout)
            print(f"{data['result']}: {data['passedTests']} passed, {data['failedTests']} failed, {data['skippedTests']} skipped")
            for failure in data.get('testFailures', []):
                print(f"{failure['testIdentifierString']}: {failure['failureText']}")
        else:
            print(summary.stderr, file=sys.stderr)
    print(f'E2E elapsed: {time.monotonic()-start:.1f}s', flush=True)
    sys.exit(result.returncode)
