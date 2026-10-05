#!/usr/bin/env python3
"""Run the game in x64sc and talk to it through VICE's remote text monitor.

    tools/vicemon.py [--prg build/loukoumas.prg] [--wait SECONDS]
                     [--shot out.png] [--keys "..."] CMD [CMD ...]

Starts x64sc in warp with the remote monitor on a local port, lets the
machine run for --wait seconds of wall time, then sends each monitor command
in turn (e.g. "r", "m 0002 0060", "x" to continue) and prints what comes
back. With --shot it saves a screenshot through the monitor first.

A debugging tool, not a test: the scripted checks use tools/c64run.py.
"""

import argparse
import os
import socket
import subprocess
import sys
import time

PORT = 6510


def recv_all(s, quiet=0.3):
    s.settimeout(quiet)
    out = b""
    while True:
        try:
            d = s.recv(65536)
            if not d:
                break
            out += d
        except socket.timeout:
            break
    return out.decode("latin-1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prg", default="build/loukoumas.prg")
    ap.add_argument("--wait", type=float, default=3.0)
    ap.add_argument("--shot")
    ap.add_argument("--warp", action="store_true", default=True)
    ap.add_argument("cmds", nargs="*")
    a = ap.parse_args()

    args = ["x64sc", "-default", "-sounddev", "dummy",
            "-remotemonitor", "-remotemonitoraddress", "ip4://127.0.0.1:%d" % PORT,
            "-autostartprgmode", "1", "-autostart", a.prg]
    if a.warp:
        args.insert(2, "-warp")
    p = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(a.wait)
        s = None
        for _ in range(50):
            try:
                s = socket.create_connection(("127.0.0.1", PORT))
                break
            except OSError:
                time.sleep(0.2)
        if s is None:
            sys.exit("vicemon: no monitor")
        recv_all(s, 1.0)
        cmds = list(a.cmds)
        if a.shot:
            cmds.insert(0, 'screenshot "%s" 2' % os.path.abspath(a.shot))
        for c in cmds:
            s.sendall((c + "\n").encode())
            print("> " + c)
            print(recv_all(s, 1.0))
        s.sendall(b"quit\n")
        time.sleep(0.5)
    finally:
        p.kill()


if __name__ == "__main__":
    main()
