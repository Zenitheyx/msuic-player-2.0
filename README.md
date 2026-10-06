# NEXUS OS

A modular operating-system environment for CC:Tweaked Advanced Computers.

## Architecture

CraftOS BIOS -> NEXUS bootloader -> kernel -> device manager -> process manager -> services -> compositor -> userspace applications.

The kernel uses Lua coroutines and event-driven scheduling because CC:Tweaked executes Lua cooperatively. It does not claim impossible hardware isolation or a native hypervisor.

## Browser backend

`backend/server.py` is a small standard-library Python backend. It fetches public HTTP/HTTPS pages, extracts readable text and links, and exposes JSON endpoints for the NEXUS browser. This is intentionally a backend proxy: the Minecraft computer does not need to implement a JavaScript engine.

Run:

```bash
python server.py --host 0.0.0.0 --port 8080
```

Then configure `etc/network.cfg` on the computer with the backend URL, e.g. `http://YOUR_SERVER:8080`.

For an SMP, the CC:Tweaked server administrator must allow the computer to reach that backend. CC:Tweaked blocks private/local IPs by default.
