import os
import sys
import time

class _physics_Auditor:
    def __init__(self, logfile):
        if not hasattr(logfile, "write"):
            logfile = open(logfile, "a")
        self._fp = logfile
        self._executable = sys.executable
        self._prefix = os.path.dirname(self._executable)
        prefix, bindir = os.path.split(self._prefix)
        if bindir == "bin":
            self._prefix = prefix
        self._libdir = os.path.join(
            self._prefix,
            "lib",
            f"python{sys.version_info.major}.{sys.version_info.minor}",
        )

    def __call__(self, event, args):
        print(f"{event}: {args}", file=self._fp)
        if event == "subprocess.Popen":
            self.on_subprocess_popen(args)

    POPEN_ALLOWLIST = {
        "('lsb_release', ['lsb_release', '-a'], None, None)",
        "('uname', ['uname', '-rs'], None, None)",
    }

    PYLIB_ALLOWLIST = {
        "/site-packages/pip/_vendor/pep517/in_process/_in_process.py",
    }

    def on_subprocess_popen(self, args):
        if repr(args) in self.POPEN_ALLOWLIST:
            return
        executable, args, cwd, env = args
        if executable != self._executable:
            raise ValueError(executable)
        script = args[1]
        if (script.startswith("/tmp/pip-standalone-pip-")
            and script.endswith("/__env_pip__.zip/pip")):
            return  # XXX for now
        if not script.startswith(self._libdir):
            return  # raise ValueError(script)
        if script[len(self._libdir):] not in self.PYLIB_ALLOWLIST:
            return  # raise ValueError(script)

# Figure out where we are and which module we're shadowing
_physics_moddir, _physics_modname = os.path.split(__file__)
print(f"_physics_moddir = {_physics_moddir!r}")
_physics_modname = _physics_modname.rsplit(".", 1)[0]
print(f"_physics_modname = {_physics_modname!r}")

# Create and install the audit hook
_physics_logdir = _physics_moddir
while not os.path.exists(os.path.join(_physics_logdir, "pyvenv.cfg")):
    _physics_logdir = os.path.dirname(_physics_logdir)

_physics_logfile = f"audit-{int(time.time())}.log"
_physics_logfile = os.path.join(_physics_logdir, _physics_logfile)
sys.addaudithook(_physics_Auditor(_physics_logfile))

# Tweak sys.path so we can import the module we're shadowing
_physics_sys_path_index = sys.path.index(_physics_moddir)
print(f"sys.path = {sys.path}")
sys.path.pop(_physics_sys_path_index)

# Import everything from the shadowed module
_physics_module = sys.modules.pop(_physics_modname)
_physics_shadow_module = __import__(_physics_modname)
for _physics_attr in dir(_physics_shadow_module):
    setattr(_physics_module, _physics_attr,
            getattr(_physics_shadow_module,_physics_attr))

# Restore sys.path
sys.path.insert(_physics_sys_path_index, _physics_moddir)
print(f"sys.path = {sys.path}")

# Clear out our namespace
for _physics_attr in list(dir(_physics_module)):
    if _physics_attr == "_physics_shadow_module":
        continue
    if hasattr(_physics_shadow_module, _physics_attr):
        continue
    globals().pop(_physics_attr)
del _physics_shadow_module, _physics_attr
