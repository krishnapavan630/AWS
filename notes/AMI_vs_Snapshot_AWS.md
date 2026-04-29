# AWS AMI vs EBS Snapshot — Complete Guide

> A complete reference covering the differences, use cases, and internals of Amazon Machine Images (AMI) and EBS Snapshots, built from real scenario-based learning.

---

## Table of Contents
1. [Core Concepts](#1-core-concepts)
2. [What Each One Contains](#2-what-each-one-contains)
3. [Real Scenario — t3.small Ubuntu Instance](#3-real-scenario--t3small-ubuntu-instance)
4. [Launching from Snap1 — Will Software Be There?](#4-launching-from-snap1--will-software-be-there)
5. [Can You Use a Different OS When Restoring from Snapshot?](#5-can-you-use-a-different-os-when-restoring-from-snapshot)
6. [Snap1 vs AMI — What You Actually Observe Inside the Instance](#6-snap1-vs-ami--what-you-actually-observe-inside-the-instance)
7. [The Real Power of AMI — Multi Volume Scenario](#7-the-real-power-of-ami--multi-volume-scenario)
8. [AMI Automatically Converts Snapshots to Volumes](#8-ami-automatically-converts-snapshots-to-volumes)
9. [Lazy Loading — Does AMI Launch Faster than Manual Snapshot Restore?](#9-lazy-loading--does-ami-launch-faster-than-manual-snapshot-restore)
10. [Quick Reference Table](#10-quick-reference-table)
11. [Mental Models to Remember](#11-mental-models-to-remember)

---

## 1. Core Concepts

### EBS Snapshot
A **point-in-time backup of a single EBS volume**. It captures the complete block-level state of that volume and stores it in S3 (AWS managed, not visible to you).

- Contains **only raw disk data** of that one volume
- Has no concept of OS boot config, instance type, or architecture
- You **cannot directly launch an EC2 instance** from a snapshot alone
- It is region-locked by default

### AMI (Amazon Machine Image)
A **complete blueprint of an entire EC2 instance**. It internally references one or more EBS snapshots along with all the metadata needed to launch a perfect copy of the original instance.

An AMI is made up of:
- One or more EBS snapshots (one per volume)
- Block device mapping (which volumes to attach, sizes, types, device names)
- Launch permissions (who can use it)
- Architecture & virtualization type (x86_64, ARM, HVM, etc.)
- Kernel ID and boot configuration

> **Key Insight:** A Snapshot is an ingredient. An AMI is the complete recipe.

---

## 2. What Each One Contains

```
EBS Snapshot                        AMI
────────────────────                ──────────────────────────────────
Raw volume data only                = Snapshot(s) + Metadata + Config
│                                   │
├── Can restore a volume            ├── Launch new EC2 instances
├── Can create an AMI from it       ├── Use in Auto Scaling Groups
└── Cannot launch EC2 directly      ├── Share across accounts/regions
                                    ├── Use in Launch Templates
                                    └── Disaster Recovery baseline
```

---

## 3. Real Scenario — t3.small Ubuntu Instance

```
Instance: t3.small | Ubuntu | 20GB Volume
Installed & Configured: GIT + Python + AWS-CLI

After taking Snapshot & AMI:
├── Snap1  → Created from direct EBS Snapshot (volume data only)
├── Snap2  → Auto-created internally by AMI
└── AMI    → References Snap2 + all instance metadata
```

> **Important:** Snap1 and Snap2 contain the **exact same data**. The difference is that AMI wraps Snap2 with metadata that makes launching reliable and automatic.

---

## 4. Launching from Snap1 — Will Software Be There?

### Yes — Everything Will Be There

When you take an EBS snapshot it captures the complete state of the volume at block level. Everything on that disk is captured:

```
What Snap1 Contains (full 20GB disk state):
├── Ubuntu OS files
├── /usr/bin/git           ✅ GIT is there
├── /usr/bin/python3       ✅ Python is there
├── /usr/local/bin/aws     ✅ AWS-CLI is there
├── /home/ubuntu/.bashrc   ✅ Shell configs
├── /etc/environment       ✅ Environment variables
└── All config files       ✅
```

### Critical Catch with Snap1

| Item | Status |
|---|---|
| Software (GIT, Python, AWS-CLI) | ✅ Present |
| Config files | ✅ Present |
| SSH Keys / Credentials | ✅ Present (be careful — security risk!) |
| Direct launch as EC2 instance | ❌ NOT possible directly |

You **cannot directly launch** an EC2 instance from Snap1. You must either:
- Attach it to a running instance as a secondary volume, OR
- Convert it into an AMI first, then launch from that AMI

---

## 5. Can You Use a Different OS When Restoring from Snapshot?

**No — You must stick to the same OS family.**

```
Snap1 was created from Ubuntu:
├── Filesystem format : ext4 (Ubuntu default)
├── Boot loader       : GRUB configured for Ubuntu
├── Kernel modules    : Ubuntu kernel specific
└── Package manager   : apt (Ubuntu)

If you attach Snap1 to an Amazon Linux instance:
├── Kernel mismatch         ❌ Will fail to boot
├── Different init system   ❌ Services won't start
└── Filesystem conflicts    ❌ Mount errors
```

> Always restore to the same OS family and architecture.

---

## 6. Snap1 vs AMI — What You Actually Observe Inside the Instance

### Inside the Running Instance — Almost Zero Difference

```bash
# Both instances will show:
$ git --version       → same ✅
$ python3 --version   → same ✅
$ aws --version       → same ✅
$ cat /etc/hostname   → DIFFERENT (new hostname assigned by AWS)
$ env                 → mostly same except instance-specific vars
```

### The Difference is NOT Inside — It is How You Got There

| Feature | Instance from Snap1 | Instance from AMI |
|---|---|---|
| GIT / Python / AWS-CLI | ✅ Present | ✅ Present |
| Your configurations | ✅ Present | ✅ Present |
| Direct Launch | ❌ Must convert first | ✅ Launch directly |
| Boot reliability | ⚠️ Not guaranteed | ✅ 100% reliable |
| Traceability in Console | ❌ No link to Snap1 | ✅ AMI ID visible |
| Reproducibility | ⚠️ Manual, error-prone | ✅ Identical every time |
| Region portability | ❌ Region-locked | ✅ Can be copied |

### Launch Process Comparison

```
From AMI:
→ Go to Launch Instance
→ Select your AMI
→ Choose instance type
→ Done. Boots perfectly ✅

From Snap1:
→ Go to Snapshots
→ Create Volume from Snap1
→ Launch a separate base Ubuntu instance
→ Stop that instance
→ Detach its root volume
→ Attach your Snap1 volume
→ Mark it as /dev/xvda (root)
→ Start instance → Hope it boots ⚠️
```

### Honest Bottom Line for Single Volume Use Case

> For a **single volume, single instance, same account, same region** use case — AMI is just a **convenient wrapper** around the snapshot. The data inside the running instance will be identical.

---

## 7. The Real Power of AMI — Multi Volume Scenario

This is where AMI truly proves its value beyond just convenience.

### Setup

```
Original Instance with 3 Volumes:
├── Volume 1 - 20GB   (Root) → OS + GIT + Python + AWS-CLI
├── Volume 2 - 50GB   (Data) → Application files
└── Volume 3 - 100GB  (DB)   → Database files
```

### What AMI Remembers (Block Device Mapping)

```
AMI internally stores:
├── Snap2-Vol1 → 20GB  → attach as /dev/xvda  (root)
├── Snap2-Vol2 → 50GB  → attach as /dev/xvdb
└── Snap2-Vol3 → 100GB → attach as /dev/xvdc
```

When you launch from this AMI, AWS automatically creates all 3 volumes from their respective snapshots and attaches them in the correct order, correct size, and correct device name — without any manual work.

### What If One Snapshot Gets Deleted?

```
Suppose Snap2-Vol3 (DB snapshot) gets deleted:

Launch from AMI → ❌ FAILS
AWS Error: "Cannot find snapshot snap-0abc1234 
            referenced in block device mapping"
```

> AMI expects ALL referenced snapshots to exist. If even one is missing, the instance will not launch.

### Multi Volume: AMI vs Manual Snapshots

```
From AMI:
→ Click Launch
→ All 3 volumes auto created   ✅
→ All attached correctly       ✅
→ Instance boots perfectly     ✅

From 3 Manual Snapshots:
→ Create Vol1 from Snap1 manually
→ Create Vol2 from Snap2 manually
→ Create Vol3 from Snap3 manually
→ Launch base Ubuntu instance
→ Detach its root volume
→ Attach Vol1 as /dev/xvda   ← wrong name = won't boot
→ Attach Vol2 as /dev/xvdb
→ Attach Vol3 as /dev/xvdc
→ Pray it boots 🙏
```

---

## 8. AMI Automatically Converts Snapshots to Volumes

When you click "Launch Instance" from an AMI, this is what AWS does silently in the background:

```
You click "Launch Instance"
              ↓
AWS reads the Block Device Mapping inside AMI
              ↓
    ┌─────────────────────────────────────┐
    │  Snap2-Vol1 → Creates 20GB  Volume  │
    │  Snap2-Vol2 → Creates 50GB  Volume  │
    │  Snap2-Vol3 → Creates 100GB Volume  │
    └─────────────────────────────────────┘
              ↓
AWS attaches all volumes to the new instance
in correct device names automatically
              ↓
Instance boots up perfectly ✅
```

You will never see these intermediate volumes being created. By the time your instance is in **Running** state, all volumes are already attached and ready.

> You can verify this: After launching from AMI, go to **EC2 → Volumes** in the console and you will see brand new volumes already created and attached — without you doing anything manually.

---

## 9. Lazy Loading — Does AMI Launch Faster than Manual Snapshot Restore?

**No — the underlying behavior is exactly the same.**

### How Lazy Loading Works

```
Instance Launched (from AMI or Manual Snapshot)
         ↓
Volumes created from snapshots
         ↓
Instance enters "Running" state ✅
         ↓
BUT volume blocks are not fully loaded yet ⚠️
         ↓
Data is being lazily loaded from S3 in background
         ↓
First access of each block → Slight latency hit
         ↓
Full normal speed after all blocks are loaded ✅
```

### What You Actually Experience

```
├── Instance shows "Running"        ✅ immediately
├── You can SSH in                  ✅ immediately
├── Software is accessible          ✅ immediately
├── First read of each disk block   ⚠️  slightly slow
└── Full normal speed               ✅ after all blocks loaded
```

For lightweight workloads (GIT, Python, AWS-CLI) you will barely notice the difference. It hurts most with large database volumes (100GB+) where first queries hit unloaded blocks causing extreme latency.

### AWS Fast Snapshot Restore (FSR)
FSR pre-warms volumes so all blocks are ready before the instance even starts. This eliminates lazy loading latency but comes at an additional cost.

### Bottom Line on Speed

```
Manual Snapshot → Volume  → Lazy loading applies ✅
AMI launch      → Volumes → Lazy loading applies ✅

AMI does NOT get any special speed priority.
Speed is same. Convenience is different.
```

---

## 10. Quick Reference Table

| Use Case | Use This |
|---|---|
| Backup volume data only | EBS Snapshot |
| Launch identical new instance | AMI |
| Single volume, simple restore | Snapshot (convert to AMI first) |
| Multi volume instance restore | AMI (only reliable option) |
| Cross-region deployment | AMI (copy to other region) |
| Share setup with another AWS account | AMI (share permissions) |
| Auto Scaling / Load Balancing | AMI (mandatory) |
| Quick data recovery | EBS Snapshot |

---

## 11. Mental Models to Remember

### Snapshot vs AMI
> **Snapshot** = You pulled the hard drive out of your old laptop and plugged it into a new one. Data is all there but compatibility issues may arise and manual setup is needed.

> **AMI** = A professional cloning tool that captured the hard drive AND all hardware configuration profiles. Press one button and the new machine boots up perfectly identical.

### Ingredient vs Recipe
> **Snapshot** = An ingredient (raw disk data)

> **AMI** = The complete recipe (snapshots + how to assemble them)

### Single vs Multi Volume Reality Check
```
Single Volume Instance:
└── AMI = just a convenient wrapper over snapshot. Period.

Multi Volume Instance:
└── AMI = the ONLY reliable way to capture and restore
          the complete instance with all volumes intact,
          in correct order, correct sizes, correct device names.
```

---

*This document was created as a personal revision reference covering EBS Snapshots and AMI concepts from a scenario-based learning approach.*
