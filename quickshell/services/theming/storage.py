import contextlib, fcntl, json, os, tempfile, time, math, stat
from pathlib import Path

MAX_JSON = 256 * 1024

def read_json(path, limit=MAX_JSON):
    if type(limit) is not int or limit < 0: raise ValueError('invalid JSON byte limit')
    # NONBLOCK prevents a FIFO/device open from hanging before we can reject it.
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError(str(path) + ': expected a regular JSON file')
        chunks=[]; remaining=limit+1
        while remaining:
            chunk=os.read(fd,remaining)
            if not chunk: break
            chunks.append(chunk); remaining-=len(chunk)
        raw=b''.join(chunks)
    finally: os.close(fd)
    if len(raw) > limit: raise ValueError(str(path) + ': exceeds size limit')
    def pairs(values):
        result = {}
        for k, v in values:
            if k in result: raise ValueError('duplicate field: ' + k)
            result[k] = v
        return result
    def finite(value):
        number=float(value)
        if not math.isfinite(number):raise ValueError('non-finite number: '+value)
        return number
    return json.loads(raw, object_pairs_hook=pairs, parse_float=finite, parse_constant=lambda x: (_ for _ in ()).throw(ValueError('non-finite number: '+x)))

def encoded(value):
    return value if isinstance(value, bytes) else (value if isinstance(value, str) else json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n').encode()

def atomic(path, value):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    raw = encoded(value)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(raw); f.flush(); os.fsync(f.fileno())
        os.replace(tmp, path)
        sync_dir(path.parent)
    finally:
        Path(tmp).unlink(missing_ok=True)

def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(fd)
    finally: os.close(fd)

def remove(path):
    path.unlink(missing_ok=True); sync_dir(path.parent)

@contextlib.contextmanager
def lock(path, timeout=15):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as f:
        deadline = time.monotonic() + timeout
        while True:
            try: fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB); break
            except BlockingIOError:
                if time.monotonic() >= deadline: raise TimeoutError('Theme operation busy; retry shortly')
                time.sleep(.025)
        try: yield
        finally: fcntl.flock(f, fcntl.LOCK_UN)
