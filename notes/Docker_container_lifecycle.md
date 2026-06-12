# Docker Container Lifecycle — Revision Notes

---

## Core Rule (Never Forget This)

> **A container lives as long as its PID 1 (the main process) is alive.**
> The moment PID 1 exits → the container stops. No exceptions.

---

## What is PID 1?

PID 1 is the **first process** that starts inside a container when you do `docker run`.
It is determined by your `ENTRYPOINT` and/or `CMD` instructions.

If you define neither → Docker inherits them from the **base image**.

---

## The `-itd` Flag — What It Actually Does

| Flag | Full Form | What it does |
|------|-----------|--------------|
| `-i` | `--interactive` | Keeps STDIN open |
| `-t` | `--tty` | Attaches a pseudo-terminal (TTY) |
| `-d` | `--detach` | Runs container in background |

> **`-itd` does NOT keep a container alive on its own.**
> It only detaches you from it. The container still dies if PID 1 exits.

---

## Why bash Stays Alive With `-itd`

`/bin/bash` has special behavior:
- **No terminal attached** → bash exits immediately (nothing to do)
- **Terminal attached (`-it`)** → bash stays open, waiting for your input

So `docker run -itd` + `bash` as PID 1 = container stays alive, because bash is sitting and waiting on the TTY.

---

## Why `apt install git` Dies Even With `-itd`

`apt install -y git` is **not an interactive process.**
It does not wait for terminal input.
It runs → finishes → exits.
TTY or no TTY — it doesn't care. Container dies within seconds.

---

## The Ubuntu Base Image Default

When you write a Dockerfile like this with **no CMD or ENTRYPOINT**:

```dockerfile
FROM ubuntu
LABEL author="Krishna Pavan"
ADD https://dlcdn.apache.org/httpd/httpd-2.4.68.tar.gz .
WORKDIR krishna/aws/devops
COPY test.txt .
```

Docker inherits Ubuntu's default, which you can verify with:

```bash
docker inspect ubuntu
```

Output:
```json
"Cmd": ["/bin/bash"],
"Entrypoint": null
```

So PID 1 becomes `/bin/bash` automatically → container stays alive with `-itd`.

> ⚠️ This is **implicit behavior** — relying on it is fragile.
> Always explicitly declare `CMD ["/bin/bash"]` so intent is clear.

---

## Comparison Table

| Dockerfile Setup | PID 1 | With `-itd` | Result |
|---|---|---|---|
| No CMD / ENTRYPOINT | `/bin/bash` (Ubuntu default) | bash waits on TTY | ✅ Stays alive |
| `CMD ["/bin/bash"]` | `/bin/bash` | bash waits on TTY | ✅ Stays alive |
| `CMD ["sleep", "infinity"]` | `sleep infinity` | sleeps forever | ✅ Stays alive |
| `ENTRYPOINT ["apt","install","-y"]` + `CMD ["git"]` | `apt install -y git` | runs and exits | ❌ Dies in seconds |

---

## Now see this

```dockerfile
FROM ubuntu
LABEL author="Krishna Pavan"
ADD https://dlcdn.apache.org/httpd/httpd-2.4.68.tar.gz .
WORKDIR krishna/aws/devops
COPY test.txt .
RUN apt update
RUN apt install tree -y
RUN touch app.py
ENTRYPOINT ["apt","install","-y"]
CMD ["git"]
```
So eventhough if I run it is using -itd ie., 

```bash
docker run -itd --name cont01 image01
```
The container will stay alive till it installs git. The moment apt install git completes — PID 1 is dead — container stops. -itd doesn't magically keep it alive. It just detaches you from it; it doesn't give the container a reason to stay running.

---

## Build Time vs Run Time

| Stage | Docker Command | Purpose |
|---|---|---|
| **Build time** | `docker build` | Set up the environment — install packages, copy files |
| **Run time** | `docker run` | *Use* the environment — start your app or shell |

### Wrong (what the original Dockerfile did):
```dockerfile
ENTRYPOINT ["apt", "install", "-y"]   # installing at RUN TIME ❌
CMD ["git"]
```

### Correct:
```dockerfile
RUN apt install git -y                # install at BUILD TIME ✅
CMD ["/bin/bash"]                     # start a shell at RUN TIME ✅
```

---

## Processes That Keep a Container Alive

| Process | Why it keeps container alive |
|---|---|
| `/bin/bash` (with TTY) | Waits for user input |
| `sleep infinity` | Sleeps forever, never exits |
| `apache2ctl -D FOREGROUND` | Web server runs continuously |
| `python app.py` | App runs continuously (if it has a loop/server) |

---

## Quick Mental Model

```
docker run -itd myimage
        │
        └──> Starts PID 1 (from ENTRYPOINT/CMD or base image default)
                    │
                    ├── PID 1 is long-running? (bash, sleep, server)
                    │         └──> ✅ Container stays alive
                    │
                    └── PID 1 exits quickly? (apt install, echo, ls)
                              └──> ❌ Container stops immediately
```

---

*Notes by Krishna Pavan | Docker Learning Series*