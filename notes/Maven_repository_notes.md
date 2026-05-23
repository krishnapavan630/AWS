# Maven Repositories — Revision Notes

> A complete beginner-friendly guide to understanding `.m2`, local vs remote repositories, and the difference between `package`, `install`, and `deploy`.

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [What is `.m2`?](#2-what-is-m2)
3. [Inside `.m2/repository/` — The Folder Structure](#3-inside-m2repository--the-folder-structure)
4. [The Most Common Confusion: What Does `install` Actually Do?](#4-the-most-common-confusion-what-does-install-actually-do)
5. [Maven Phase Ladder](#5-maven-phase-ladder)
6. [Remote Repositories](#6-remote-repositories)
7. [How Maven Looks for Dependencies (The Flow)](#7-how-maven-looks-for-dependencies-the-flow)
8. [The `settings.xml` File](#8-the-settingsxml-file)
9. [A Simple Real Example: math-helper + calculator-app](#9-a-simple-real-example-math-helper--calculator-app)
10. [Quick Decision Guide: Which Maven Command to Use?](#10-quick-decision-guide-which-maven-command-to-use)
11. [Key Takeaways](#11-key-takeaways)

---

## 1. The Big Picture

When you run `mvn clean install`, Maven needs to find **dependencies** (other JARs your project uses — Spring, Jackson, JUnit, etc.). These dependencies live in **repositories**. Think of repositories as warehouses of JAR files.

There are **three layers** Maven cares about:

1. **Local repository** — on your machine, the `.m2` folder
2. **Remote repositories** — Maven Central, company Nexus/JFrog, etc.
3. **Your project's own build output** — the JAR/WAR in your `target/` folder

---

## 2. What is `.m2`?

`.m2` is just a **folder on your computer**:

- **Windows**: `C:\Users\<you>\.m2`
- **Linux/Mac**: `~/.m2`

Inside it there's a subfolder `repository/` — this is your **local repository**. It's a cache of:

- Every JAR Maven has ever downloaded for you
- Every JAR you've ever built with `mvn install`

### Why this matters

When you run `mvn clean install` and it needs `spring-core-6.0.0.jar`:

- First, it checks `~/.m2/repository/org/springframework/spring-core/6.0.0/`
- If **found** → uses it instantly (no internet needed) ✅
- If **not found** → goes to remote repositories, downloads it, saves it into `.m2`, then uses it

This is why:
- The **first build** of a new project is slow (downloads everything)
- The **second build** is fast (everything is cached)

> **Real-world superpower:** Once dependencies are in `.m2`, you can build offline — on an airplane, in a train, anywhere.

---

## 3. Inside `.m2/repository/` — The Folder Structure

```
~/.m2/repository/
├── org/
│   ├── apache/
│   │   └── commons/
│   │       └── commons-lang3/
│   │           └── 3.12.0/
│   │               ├── commons-lang3-3.12.0.jar
│   │               └── commons-lang3-3.12.0.pom
│   └── springframework/
│       └── spring-core/
│           └── 6.0.0/
│               ├── spring-core-6.0.0.jar
│               └── spring-core-6.0.0.pom
└── com/
    └── fasterxml/
        └── jackson/
            └── ...
```

### The folder path mirrors `groupId + artifactId + version`

```xml
<dependency>
    <groupId>org.apache.commons</groupId>       <!-- becomes folder org/apache/commons -->
    <artifactId>commons-lang3</artifactId>      <!-- becomes folder commons-lang3 -->
    <version>3.12.0</version>                   <!-- becomes folder 3.12.0 -->
</dependency>
```

So Maven knows **exactly** which folder path to look in. No searching, no guessing — it's deterministic.

### Each version folder contains:

| File | Purpose |
|---|---|
| `.jar` | The actual compiled code |
| `.pom` | That dependency's own pom.xml (it may have its own dependencies — called **transitive dependencies**) |
| `.jar.sha1` | Checksum to verify file integrity |

---

## 4. The Most Common Confusion: What Does `install` Actually Do?

> **Most people think `install` means "install dependencies." It does NOT.**
>
> It means: **"Take the JAR I just built and copy it into my local `.m2` repository."**

### Two roles a JAR can play

A JAR can play **two completely different roles**, and `.m2` is used for both:

#### Role 1: A JAR as a **dependency** (input to a build)
- Example: `spring-core-6.0.0.jar`, `commons-lang3-3.12.0.jar`
- Your project **consumes** these
- They get into `.m2` by being **downloaded** from a remote repo
- This happens during `package`, `install`, or any phase that needs to compile

#### Role 2: A JAR as a **build output** (your own project's artifact)
- Example: `my-utils-1.0.0.jar`, `myapp.war`
- Your project **produces** this
- It gets into `.m2` **only when you run `mvn install`**

**`package` handles Role 1. `install` adds Role 2.** That's the whole distinction.

---

## 5. Maven Phase Ladder

When you run `mvn clean install`, Maven runs **all phases in order** up to and including `install`:

```
clean    →  delete the target/ folder (your previous build output)
validate →  check the project is correct
compile  →  compile your source code
test     →  run unit tests
package  →  bundle into a JAR/WAR (lives in target/)
verify   →  run integration tests
install  →  COPY the JAR from target/ into ~/.m2/repository/  ← THE KEY STEP
deploy   →  UPLOAD the JAR to a remote repo (company Nexus/JFrog)
```

### What each command does:

| Command | What happens |
|---|---|
| `mvn clean` | Deletes `target/`. Does **NOT** touch `.m2`. |
| `mvn compile` | Compiles your code only |
| `mvn test` | Compiles + runs unit tests |
| `mvn package` | Compiles + tests + creates JAR/WAR in `target/` |
| `mvn install` | Everything above + copies JAR into `~/.m2/repository/` |
| `mvn deploy` | Everything above + uploads to company Nexus/JFrog |

### Important: `clean` only wipes `target/`, NEVER `.m2`

Your `.m2` is precious cached data. Maven won't throw it away just because you ran `clean`.

---

## 6. Remote Repositories

### 6.1 Maven Central

- The **default public repository** Maven uses out of the box
- Hosted at `https://repo.maven.apache.org/maven2/`
- Almost every open-source Java library is here (Spring, Jackson, Apache Commons, JUnit, etc.)
- You don't have to configure anything — Maven knows about it by default

### 6.2 Company-Managed Repositories (Nexus / JFrog Artifactory)

Private repositories hosted by your company. Think of them as your company's own Maven Central.

**Two reasons companies run these:**

**(a) Hosting internal artifacts**
- Your company's proprietary libraries (e.g., `com.mycompany.payments-sdk`, `com.mycompany.auth-lib`) can't go to public Maven Central
- They're hosted on the company's Nexus/JFrog instead
- Any developer at the company can pull them

**(b) Acting as a proxy/cache for Maven Central**
- Even for public libraries, the company server caches them
- If 500 developers need `spring-core-6.0.0`, it's downloaded from Maven Central **once** to the company server
- All 500 developers pull from the company server (faster + no risk if Maven Central goes down)

### 6.3 Other Public Repositories

Sometimes a library isn't on Maven Central but is on a different public repo — JBoss, Spring's own repo, JitPack (for GitHub projects), etc. You can add these to your project if needed.

---

## 7. How Maven Looks for Dependencies (The Flow)

When Maven needs `commons-lang3` and it's not yet in your `.m2`:

```
mvn clean install
   │
   ▼
Look in ~/.m2/repository/...   ──► Not found
   │
   ▼
Look in remote repositories (in order configured):
   1. Company Nexus/JFrog       ──► Found? Download → save to .m2 → use it
   2. Maven Central             ──► Found? Download → save to .m2 → use it
   3. Other configured repos    ──► ...
   │
   ▼
None found? → BUILD FAILS with "Could not resolve dependency"
```

The order of remote repos matters and is controlled by `settings.xml`.

---

## 8. The `settings.xml` File

There are **two** `settings.xml` files Maven cares about:

| File | Scope |
|---|---|
| `<MAVEN_HOME>/conf/settings.xml` | **Global** — applies to everyone using that Maven install |
| `~/.m2/settings.xml` | **User** — applies only to you (overrides global) |

### Find your Maven installation

This is where you can find your maven home path to verify settings.xml

```bash
mvn -v
```

Output shows `Maven home: /path/to/maven` → the global `settings.xml` is at `<Maven home>/conf/settings.xml`.

Common locations:
- **Linux (apt)**: `/usr/share/maven/conf/settings.xml`
- **Mac (Homebrew)**: `/usr/local/Cellar/maven/<version>/libexec/conf/settings.xml`
- **Windows**: `C:\Program Files\Apache\maven\conf\settings.xml`

### When to create your own `~/.m2/settings.xml`

Only when you need to customize:

| Reason | What to add |
|---|---|
| Company has a private Nexus/JFrog | `<servers>` (credentials) + `<mirrors>` (URL) |
| Behind a corporate firewall | `<proxies>` section |
| Want `.m2` on a different drive | `<localRepository>D:/maven-cache</localRepository>` |
| Different profiles for work/personal | `<profiles>` section |

### Minimal template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
    <!-- Your custom config goes here -->
</settings>
```

> Tip: Always customize the **user-level** file (`~/.m2/settings.xml`), not the global one. It survives Maven upgrades and doesn't need admin rights.

### Useful commands to inspect what's active

```bash
# Show the final merged settings Maven is using
mvn help:effective-settings

# Show just the local repo path
mvn help:evaluate -Dexpression=settings.localRepository -q -DforceStdout
```
### What `settings.xml` controls:

- Where your local repo lives (default: `~/.m2/repository`)
- Which remote repos to use, and in what order
- Credentials (username/password) for private repos like company Nexus
- Proxy settings if your company is behind a firewall

### Example: routing everything through company Nexus

```xml
<settings>
    <servers>
        <server>
            <id>company-nexus</id>
            <username>your-username</username>
            <password>your-password</password>
        </server>
    </servers>

    <mirrors>
        <mirror>
            <id>company-nexus</id>
            <mirrorOf>*</mirrorOf>   <!-- intercept ALL remote requests -->
            <url>https://nexus.mycompany.com/repository/maven-public/</url>
        </mirror>
    </mirrors>
</settings>
```

### Key piece: `<mirrorOf>*</mirrorOf>`

This says: *"Whenever Maven wants to talk to **any** remote repo (including Maven Central), redirect it through our company Nexus instead."*

This is how companies enforce that everything goes through their own cache.

> Without the `<mirror>` URL and `<server>` credentials, the redirect alone wouldn't work — Maven needs to know **where** to go and **how to log in**.

---

## 8.1 Repositories vs Mirrors — The Difference

This is subtle but important. There are two separate concepts:

### `<repositories>` = WHERE to look (the original destinations)

Declared in `pom.xml` or `settings.xml`. They literally list URLs to check for dependencies.

```xml
<repositories>
    <repository>
        <id>spring-releases</id>
        <url>https://repo.spring.io/release</url>
    </repository>
</repositories>
```

Maven Central is included by default — no need to declare it.

### `<mirrors>` = REDIRECT rules (override destinations)

Mirrors don't add new places to look — they **hijack** existing requests and redirect them.

```xml
<mirrors>
    <mirror>
        <id>company-nexus</id>
        <mirrorOf>*</mirrorOf>
        <url>https://nexus.mycompany.com/repository/maven-public/</url>
    </mirror>
</mirrors>
```

### How requests flow

```
Your pom.xml says: "I need X from <repositories>"
│
▼
Maven asks: "Is there a <mirror> that intercepts this request?"
│
├── YES → Use the mirror URL (original repo NEVER contacted)
│
└── NO  → Go to the original repository URL
```
### Mail-forwarding analogy 📬

- `<repositories>` = the addresses written on envelopes
- `<mirrors>` = a forwarding rule that redirects envelopes to a different PO Box

The original address is still on the envelope — but the rule intercepts before delivery.

### `<mirrorOf>` patterns — control which repos get hijacked

| `<mirrorOf>` value | What it intercepts |
|---|---|
| `*` | **Every** remote repository (most common in companies) |
| `central` | Only Maven Central |
| `central,spring-releases` | Multiple specific repos (comma-separated) |
| `*,!internal-repo` | Everything EXCEPT `internal-repo` |
| `external:*` | Everything except localhost / file-based repos |

### Quick test scenario

```xml
<mirrors>
    <mirror>
        <mirrorOf>central</mirrorOf>   <!-- only intercepts Maven Central -->
        <url>https://nexus.mycompany.com/...</url>
    </mirror>
</mirrors>

<repositories>
    <repository>
        <id>spring-releases</id>
        <url>https://repo.spring.io/release</url>
    </repository>
</repositories>
```

| Request | Goes to |
|---|---|
| Anything from Maven Central | Company Nexus (intercepted) |
| Anything from `repo.spring.io` | `repo.spring.io` directly (not intercepted — no `*`) |

### Why companies use mirrors

1. **Single point of control** — audit, scan, approve all dependencies
2. **Caching for speed** — 500 devs share one cached copy from local network
3. **Reliability** — keeps building even if Maven Central goes down
4. **Internal artifacts** — same Nexus also hosts company's private JARs

### Refined definition

> **`<repositories>` tells Maven *where to look*.**
> **`<mirror>` tells Maven *where to look INSTEAD*.**


## 9. A Simple Real Example: math-helper + calculator-app

This is the easiest example to remember the concept.

### Project A: `math-helper` (a JAR)

A simple class with math methods:

```java
public class MathHelper {
    public static int add(int a, int b) {
        return a + b;
    }
    public static int multiply(int a, int b) {
        return a * b;
    }
}
```

Its `pom.xml`:

```xml
<groupId>com.learning</groupId>
<artifactId>math-helper</artifactId>
<version>1.0.0</version>
<packaging>jar</packaging>
```

Run `mvn clean install` →
`math-helper-1.0.0.jar` is now at:
`~/.m2/repository/com/learning/math-helper/1.0.0/math-helper-1.0.0.jar` ✅

### Project B: `calculator-app` (uses math-helper)

```java
import com.learning.MathHelper;

public class Calculator {
    public static void main(String[] args) {
        int sum = MathHelper.add(5, 3);          // using Project A's code!
        int product = MathHelper.multiply(4, 2);
        System.out.println("Sum: " + sum);
        System.out.println("Product: " + product);
    }
}
```

Its `pom.xml`:

```xml
<groupId>com.learning</groupId>
<artifactId>calculator-app</artifactId>
<version>1.0.0</version>

<dependencies>
    <dependency>
        <groupId>com.learning</groupId>
        <artifactId>math-helper</artifactId>   <!-- uses Project A -->
        <version>1.0.0</version>
    </dependency>
</dependencies>
```

Run `mvn clean package` on Project B → it works because Maven finds `math-helper-1.0.0.jar` in `.m2`. ✅

### What happens if you skip `install` on Project A?

If you only ran `mvn clean package` on Project A:
- `math-helper-1.0.0.jar` is in `math-helper/target/` only
- It is **NOT** in `.m2`
- Project B fails with: `Could not find artifact com.learning:math-helper:jar:1.0.0`

> Project B has **no idea** that there's a JAR sitting inside Project A's `target/` folder. Maven only looks in `.m2` and remote repos — never in random folders on your laptop.

### One-line takeaway

> **Project A is a toolbox. Project B borrows tools from it. `mvn install` puts Project A's toolbox into the shared shelf (`.m2`) so Project B can grab tools from it.**

---

## 10. Quick Decision Guide: Which Maven Command to Use?

Use the **lowest phase** that does the job:

| Situation | Command |
|---|---|
| Just want to compile code? | `mvn compile` |
| Just want to run tests? | `mvn test` |
| Want a deployable JAR/WAR for a single standalone app? | `mvn package` |
| Need other local projects on your machine to consume the JAR? | `mvn install` |
| Need to share the JAR with your whole team/company? | `mvn deploy` |

### Specific guidance for common situations:

| Situation | Need `install`? |
|---|---|
| Single standalone Spring Boot app you deploy to Tomcat | ❌ No — `package` is enough |
| Multi-module project where module B depends on module A | ✅ Yes — `install` module A first |
| Shared library used by your other local projects | ✅ Yes |
| Shared library used by other teams in the company | ✅ Use `deploy` instead — pushes to Nexus/JFrog |

### Why not always use `mvn clean install`?

Most developers reflexively type `mvn clean install` because that's what they saw in a tutorial. But:
- It wastes disk space in `.m2` if no other project uses your JAR
- It's slower (extra step that does nothing useful)
- Using the right command shows you understand the tool

---

## 11. Key Takeaways

### The Three Repositories

```
┌─────────────────────────────────────────────────────────────────┐
│  REMOTE REPOSITORIES (internet / company server)                │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │  Maven Central  │  │  Company Nexus   │  │  Other public  │  │
│  │   (default)     │  │  /JFrog (private)│  │     repos      │  │
│  └─────────────────┘  └──────────────────┘  └────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ download (when missing locally)
                             │ upload (via mvn deploy)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  LOCAL REPOSITORY  (~/.m2/repository/)                          │
│  - Cache of downloaded dependencies                             │
│  - Storage for YOUR JARs (added via mvn install)                │
│  - Folder structure: groupId/artifactId/version/                │
└────────────────────────────┬────────────────────────────────────┘
                             │ read during build
                             │ written by mvn install
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PROJECT BUILD OUTPUT  (your-project/target/)                   │
│  - Where compile/package puts the freshly built JAR/WAR         │
│  - Wiped by mvn clean                                           │
│  - Invisible to other Maven projects until you `install`        │
└─────────────────────────────────────────────────────────────────┘
```

### The Phase Ladder Summary

```
clean → validate → compile → test → package → verify → install → deploy
  │                                     │                  │          │
deletes                              creates           copies to  uploads
target/                              JAR/WAR           local       to remote
                                     in target/        .m2         Nexus/JFrog
```

### The Mental Shortcuts to Remember

1. **`.m2` is a cache.** It stores downloaded dependencies AND your own built JARs.
2. **`package` builds to `target/`.** The JAR is trapped there — no other project can see it.
3. **`install` copies to `.m2`.** Now other local projects can use it as a dependency.
4. **`deploy` uploads to Nexus/JFrog.** Now the whole company can use it.
5. **`clean` only deletes `target/`.** Never touches `.m2`.
6. **Project B looks in `.m2`, not `target/`.** This is why `install` exists.
7. **JAR = reusable building block.** **WAR = deployable end product.**
8. **First build is slow** (downloads everything). **Second build is fast** (everything cached).
