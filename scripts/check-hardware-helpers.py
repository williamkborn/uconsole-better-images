#!/usr/bin/env python3
"""Exercise hardware-control logic with fake GPIO commands; never access hardware."""
import io
import os
import pathlib
import subprocess
import sys
import tempfile
import types

root = pathlib.Path(sys.argv[1]).resolve()
audio = root / 'usr/local/bin/audio_3.5_patch.py'
modem = root / 'usr/local/bin/uconsole-4g-cm4'

class EndIteration(Exception):
    pass

for level, expected in [('lo', 'pinctrl set 11 op dh'), ('hi', 'pinctrl set 11 op dl')]:
    calls = []
    def popen(command):
        calls.append(command)
        return io.StringIO(f'10: ip    pn | {level} // GPIO10 = input\n' if command == 'pinctrl 10' else '')
    def sleep(_):
        raise EndIteration
    saved = {name: sys.modules[name] for name in ('os', 'time')}
    try:
        sys.modules['os'] = types.SimpleNamespace(popen=popen)
        sys.modules['time'] = types.SimpleNamespace(sleep=sleep)
        try:
            exec(compile(audio.read_text(), str(audio), 'exec'), {})
        except EndIteration:
            pass
    finally:
        sys.modules.update(saved)
    assert calls == ['pinctrl set 11 op', 'pinctrl set 10 ip pn', 'pinctrl 10', expected], calls

with tempfile.TemporaryDirectory() as temporary:
    directory = pathlib.Path(temporary)
    for name, body in {
        'sudo': '#!/bin/sh\nexec "$@"\n',
        'pinctrl': '#!/bin/sh\nprintf "pinctrl %s\\n" "$*" >> "$GPIO_TEST_LOG"\n',
        'sleep': '#!/bin/sh\nprintf "sleep %s\\n" "$*" >> "$GPIO_TEST_LOG"\n',
    }.items():
        path = directory / name
        path.write_text(body)
        path.chmod(0o755)
    env = dict(os.environ, PATH=str(directory) + ':' + os.environ['PATH'], GPIO_TEST_LOG=str(directory / 'calls'))
    sequences = {
        'enable': ['pinctrl set 24 op dh', 'pinctrl set 15 op dh', 'sleep 5', 'pinctrl set 15 dl', 'sleep 13'],
        'disable': ['pinctrl set 24 op dl', 'pinctrl set 24 dh', 'sleep 3', 'pinctrl set 24 dl', 'sleep 20'],
    }
    for mode, sequence in sequences.items():
        (directory / 'calls').write_text('')
        subprocess.run(['bash', str(modem), mode], env=env, check=True, stdout=subprocess.DEVNULL)
        assert (directory / 'calls').read_text().splitlines() == sequence
print('PASS: jack-in/jack-out speaker logic and modem power GPIO/timing sequences')
