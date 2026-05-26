# Jenkins Shared Libraries — Complete Learning Notes

> Personal notes by Krishna Pavan
> A complete reference covering Jenkins Shared Libraries from beginner concepts to working pipeline templates, with sections for advanced topics to study next.

---

## Table of Contents

1. [What Is a Shared Library?](#1-what-is-a-shared-library)
2. [Why Shared Libraries Exist (The Problem They Solve)](#2-why-shared-libraries-exist-the-problem-they-solve)
3. [Folder Structure](#3-folder-structure)
4. [Just Enough Groovy](#4-just-enough-groovy)
5. [The `vars/` Folder — Public Steps](#5-the-vars-folder--public-steps)
6. [The `src/` Folder — Private Internals](#6-the-src-folder--private-internals)
7. [Loading Libraries in Jenkinsfiles](#7-loading-libraries-in-jenkinsfiles)
8. [Versioning with Git Tags](#8-versioning-with-git-tags)
9. [Pipeline Templates — The Killer Feature](#9-pipeline-templates--the-killer-feature)
10. [The `when` Block — Conditional Stages](#10-the-when-block--conditional-stages)
11. [Common Bugs & Their Fixes](#11-common-bugs--their-fixes)
12. [The `resources/` Folder (To Study Next)](#12-the-resources-folder-to-study-next)
13. [Credentials Handling (To Study Next)](#13-credentials-handling-to-study-next)
14. [Quick Reference Cheat Sheet](#14-quick-reference-cheat-sheet)

---

## 1. What Is a Shared Library?

A **Jenkins Shared Library** is a Git repository containing reusable Groovy code that any Jenkinsfile can import and use. It centralizes pipeline logic so you write it once and use it everywhere.

**Key facts:**
- Lives in a Git repository (GitHub, GitLab, Bitbucket, etc.)
- Contains reusable Groovy functions and classes
- Loaded into Jenkinsfiles using the `@Library` annotation
- Changes to the library propagate automatically to all pipelines that use it
- Jenkins re-fetches the library on every build (no restart needed)

---

## 2. Why Shared Libraries Exist (The Problem They Solve)

### The Pain Point

Without shared libraries, every microservice has its own Jenkinsfile with duplicated code:

```
user-service/Jenkinsfile     → owns full build/notify/deploy code
payment-service/Jenkinsfile  → owns full build/notify/deploy code  (duplicate)
order-service/Jenkinsfile    → owns full build/notify/deploy code  (duplicate)
```

When you need to change something (e.g., update a Slack URL, add a security scan, fix a bug), you have to update **every single Jenkinsfile manually**. With 50 microservices, this becomes a nightmare.

### The Solution

Put the logic in one shared library:

```
                ┌──────────────────────────┐
                │   SHARED LIBRARY REPO    │
                │                          │
                │  - buildMaven()          │
                │  - notifySlack()         │
                │  - deployToK8s()         │
                └────────────▲─────────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    user-service     payment-service    order-service
    Jenkinsfile      Jenkinsfile        Jenkinsfile
    (just 5 lines)   (just 5 lines)     (just 5 lines)
```

**Benefits:**
- Update once → applies everywhere automatically
- Standardize processes across teams
- Version control your pipeline logic
- Smaller, cleaner Jenkinsfiles
- Centralized bug fixes and improvements

---

## 3. Folder Structure

Every shared library MUST follow this exact structure. The folder names `vars`, `src`, and `resources` are **hardcoded by Jenkins** — if you use different names, Jenkins will not find them.

```
my-shared-lib/                ← Your Git repo
│
├── vars/                     ← Public API: custom pipeline steps
│   ├── gitCheckout.groovy
│   ├── mavenBuild.groovy
│   └── deployToTomcat.groovy
│
├── src/                      ← Private internals: supporting classes
│   └── org/
│       └── mycompany/
│           └── Deployer.groovy
│
└── resources/                ← Static files: templates, configs, scripts
    └── templates/
        └── k8s-deploy.yaml
```

### Analogy: Restaurant

- **`vars/` is the MENU** — what customers (Jenkinsfiles) can order: `pizza()`, `burger()`, `salad()`
- **`src/` is the KITCHEN** — internal staff and equipment that supports the menu items
- **`resources/` is the PANTRY** — pre-made ingredients (templates, configs) the kitchen uses

---

## 4. Just Enough Groovy

Jenkins pipelines are written in **Groovy**, a JVM language. You only need a small subset to be effective.

### Variables — `def` keyword

```groovy
def name = "Krishna"        // String
def age = 25                // Integer
def isActive = true         // Boolean
def fruits = ['apple', 'banana']            // List
def person = [name: 'Krishna', age: 25]     // Map (key-value pairs)
```

### String Interpolation — Double quotes only

```groovy
def name = "Krishna"

echo "Hello, ${name}!"        // ✅ Works → "Hello, Krishna!"
echo 'Hello, ${name}!'        // ❌ Single quotes → literal "Hello, ${name}!"
```

**Rule:** `${...}` works ONLY inside double-quoted strings. Outside, use the variable name directly.

### Functions / Methods

```groovy
def greet(String name) {
    return "Hello, ${name}"
}

greet("Krishna")
greet "Krishna"        // Groovy lets you skip parentheses
```

### Maps as Function Arguments (HUGE in Jenkins)

```groovy
def deploy(Map config) {
    echo "Deploying ${config.app} to ${config.env}"
}

// All three of these work:
deploy([app: 'web', env: 'prod'])
deploy(app: 'web', env: 'prod')
deploy app: 'web', env: 'prod'      // ← Common style in Jenkinsfiles
```

### Closures — Blocks of Code in `{ }`

```groovy
def numbers = [1, 2, 3, 4]

numbers.each { num ->
    echo "Number is ${num}"
}
```

That `{ num -> ... }` is a closure — passable code. Every `stage { }` and `steps { }` in pipelines is a closure.

### The Elvis Operator `?:`

```groovy
def version = config.version ?: '1.0'
```

Means: *"Use `config.version` if it has a truthy value. Otherwise, use `'1.0'`."*

### ⚠️ The Elvis Trap (CRITICAL)

The Elvis operator treats these as "falsy" and replaces them with the default:
- `null`
- `false`
- `0`
- `''` (empty string)
- `[]` (empty list)

**The bug:** If your default is `true` and a user passes `false`, Elvis treats `false` as "missing" and uses `true` anyway!

```groovy
def shouldDeploy = config.deploy ?: true    // ❌ DANGEROUS
// User passes deploy: false → still becomes true!

def shouldDeploy = config.deploy != false   // ✅ SAFE
// User passes deploy: false → correctly stays false
```

**Rule:** When your default is `true` and `false` is a meaningful value, use `!= false` instead of Elvis.

### Logical Operators

| Operator | Meaning | Example |
|---|---|---|
| `&&` | AND | `if (x && y)` |
| `\|\|` | OR | `if (x \|\| y)` |
| `!` | NOT | `if (!x)` |

**Important:** Commas are NOT logical operators. Use `&&` or `||` to combine conditions.

---

## 5. The `vars/` Folder — Public Steps

### The Golden Rule

> **The filename inside `vars/` becomes the step name in your Jenkinsfile.**

If you create `vars/sayHello.groovy`, you can call `sayHello()` in any Jenkinsfile.
If you create `vars/deployToK8s.groovy`, you can call `deployToK8s()`.

### The `call` Method

Every `vars/` file should define a function named `call`. Groovy treats objects with a `call` method as callable, so the filename becomes a pseudo-function.

```groovy
// vars/sayHello.groovy
def call(String name = 'World') {
    echo "Hello, ${name}!"
}
```

Usage in Jenkinsfile:
```groovy
sayHello('Krishna')   // Hello, Krishna!
sayHello()            // Hello, World!  (uses default)
```

### Method Overloading — Multiple `call` Methods

You can have MULTIPLE `call` methods in the same file with different parameter types:

```groovy
// Convenience wrapper
def call(String message) {
    call(message: message)
}

// Main logic
def call(Map config) {
    def message = config.message
    def type = config.type ?: 'info'
    echo "[${type}] ${message}"
}
```

Now users can call:
```groovy
notify('Quick message')                              // String version
notify(message: 'Detailed', type: 'failure')         // Map version
```

### Validation Pattern

```groovy
def call(Map config) {
    if (!config.gitUrl) {
        error "gitCheckout: 'gitUrl' is required"
    }
    // ... rest of logic
}
```

The `error` step immediately fails the pipeline with the message. Better than a confusing crash later.

### Available Pipeline Globals

Inside `vars/` files, you automatically have access to Jenkins pipeline globals:
- `sh`, `echo`, `error`, `git`, `mail`
- `env` (environment variables)
- `params` (build parameters)
- `currentBuild` (info about the running build)
- All installed plugin steps (`slackSend`, `deploy`, etc.)

No imports needed — Jenkins injects them automatically.

### Real Example from Krishna's Project

```groovy
// vars/gitCheckout.groovy (formerly getRepo.groovy)
def call(String addr, String branchName) {
    echo "Trying to clone ${addr} from branch ${branchName}"
    git url: addr, branch: branchName
    echo "Checkout complete"
}
```

```groovy
// vars/mavenBuild.groovy
def call() {
    echo "Starting Maven build..."
    sh 'mvn clean install'
    echo "Build completed"
}
```

```groovy
// vars/deployToTomcat.groovy
def call(String tomcatUrl) {
    echo "Deploying to Tomcat server at ${tomcatUrl}..."
    deploy adapters: [tomcat9(
        alternativeDeploymentContext: '',
        credentialsId: 'Tomcat-Credentials',
        path: '',
        url: tomcatUrl
    )], contextPath: null, war: '**/*.war'
    echo "Deployed successfully"
}
```

---

## 6. The `src/` Folder — Private Internals

### What It Is

`src/` holds **Groovy classes** for complex internal logic. These are NOT exposed as pipeline steps — they're supporting code that `vars/` files use behind the scenes.

### When to Use `src/`

| Use `vars/` when... | Use `src/` when... |
|---|---|
| The logic is a single action | The logic involves related actions on the same data |
| No state needs to persist | You want to track state across calls |
| The function is < 30 lines | You'd repeat the same parameters in many functions |
| You don't need helper methods | You can imagine subclasses |

**Rule of thumb:** Start with `vars/`. Move to `src/` only when `vars/` starts feeling cramped.

### Stateful vs Stateless

- **Stateless** (vars/): Each call is independent. No memory. Like a calculator.
- **Stateful** (src/ classes): Remembers things between calls. Like a shopping cart.

### Example: A Stateful Class

```groovy
// src/com/krishna/BuildReport.groovy
package com.krishna

class BuildReport implements Serializable {
    Map<String, Long> stages = [:]
    long buildStart = System.currentTimeMillis()

    void recordStage(String name, long durationMs) {
        stages[name] = durationMs
    }

    String summary() {
        long total = System.currentTimeMillis() - buildStart
        def lines = []
        lines << "═══════ Build Report ═══════"
        stages.each { name, duration ->
            lines << "  ${name.padRight(15)} ${duration} ms"
        }
        lines << "  TOTAL          ${total} ms"
        return lines.join('\n')
    }
}
```

### Critical Rules for `src/` Classes

1. **`implements Serializable` is REQUIRED**
   Pipelines can pause and resume; all state must be saveable to disk.

2. **Pass `this` from the wrapper**
   Classes in `src/` don't have direct access to pipeline steps (`sh`, `echo`). You must pass the pipeline context:

   ```groovy
   class Deployer implements Serializable {
       def script    // ← holds the pipeline reference

       Deployer(script) {
           this.script = script
       }

       void deploy() {
           script.sh 'deploy.sh'    // ← use script.xxx
           script.echo 'Done'
       }
   }
   ```

3. **Use `package` matching the folder path**
   File at `src/com/krishna/Deployer.groovy` needs `package com.krishna`.

4. **Use explicit types, not `def`, for class fields**
   `String name` is safer than `def name` for serialization.

### The Bridge Pattern

```groovy
// src/com/krishna/Deployer.groovy
package com.krishna
class Deployer implements Serializable {
    def script
    Deployer(script) { this.script = script }
    void deploy() { script.sh 'deploy.sh' }
}

// vars/deployApp.groovy
import com.krishna.Deployer

def call() {
    new Deployer(this).deploy()
}
```

The `vars/` wrapper is thin. It imports the class and provides a clean public API. The Jenkinsfile only sees `deployApp()` and never knows the class exists.

---

## 7. Loading Libraries in Jenkinsfiles

### The `@Library` Annotation

```groovy
@Library('my-shared-lib') _              // Use default version
@Library('my-shared-lib@main') _         // Specific branch
@Library('my-shared-lib@v1.0.0') _       // Specific tag (production-safe!)
@Library('my-shared-lib@feature-x') _    // Feature branch for testing
@Library('my-shared-lib@a3f9b21') _      // Specific commit hash
```

**The trailing underscore `_`** is required. It's a placeholder because `@Library` is an annotation and Groovy annotations must annotate something.

### Configuring the Library in Jenkins

**Manage Jenkins → System → Global Pipeline Libraries → Add**

| Field | What to enter |
|---|---|
| Name | `my-shared-lib` (must match what's in `@Library('...')`) |
| Default version | `main` (branch) or `v1.0.0` (tag) |
| Retrieval method | Modern SCM |
| Source Code Management | Git |
| Project Repository | `https://github.com/krishnapavan630/my-shared-library.git` |

### Important Rules

- The library Name in Jenkins config **must exactly match** what you write in `@Library('...')`
- Jenkins re-fetches the library on every build (no restart needed for code changes)
- "Default version" specifies which Git reference (branch/tag) Jenkins uses if `@Library` doesn't specify one
- The `_` after `@Library` annotation is mandatory

---

## 8. Versioning with Git Tags

### Why Tag Your Library

Tagging gives you immutable references. Once `v1.0.0` is created and pushed, it points to the same commit forever. Production pipelines pinned to `v1.0.0` keep working even if `main` gets a buggy commit.

### Tag Workflow

```bash
# 1. Make your changes and commit them
git add .
git commit -m "Add new feature"

# 2. Create an annotated tag (with message and metadata)
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable version"

# 3. Push commits AND tags together
git push --follow-tags
```

### Important: `git push` Does NOT Push Tags by Default

```bash
git push                       # Pushes commits only
git push origin v1.0.0         # Pushes one specific tag
git push --tags                # Pushes ALL local tags
git push --follow-tags         # Pushes commits + their tags (recommended)
```

Make `--follow-tags` your default:
```bash
git config --global push.followTags true
```

### Annotated vs Lightweight Tags

```bash
git tag v1.0.0                          # Lightweight (just a pointer)
git tag -a v1.0.0 -m "Release notes"    # Annotated (with metadata)
```

**Always use annotated tags for releases.** They store author, date, and message — better for audits and release history.

### Production Pipeline Pinning

```groovy
// Development: use main branch (always latest)
@Library('my-shared-lib@main') _

// Production: pin to a specific tag (rock solid)
@Library('my-shared-lib@v1.0.0') _
```

---

## 9. Pipeline Templates — The Killer Feature

### The Big Idea

Put an entire `pipeline { }` block inside ONE function in your shared library. Every team's Jenkinsfile becomes just 2-3 lines.

### Before Templates

Every microservice's Jenkinsfile has 30+ lines:
```groovy
@Library('my-shared-lib') _
pipeline {
    agent any
    tools { maven "mymaven" }
    stages {
        stage("Checkout") { steps { gitCheckout('...', 'main') } }
        stage("Build") { steps { mavenBuild() } }
        stage("Deploy") { steps { deployToTomcat('...') } }
    }
    post {
        success { echo "✅ Done" }
        failure { echo "❌ Failed" }
    }
}
```

### After Templates

Every Jenkinsfile becomes 4 lines:
```groovy
@Library('my-shared-lib') _

mavenTomcatPipeline(
    gitUrl: 'https://github.com/krishnapavan630/ecommerce_app.git',
    tomcatURL: 'http://13.218.204.45:8080'
)
```

### The Template Definition

```groovy
// vars/mavenTomcatPipeline.groovy
def call(Map config) {

    // === Validate required inputs ===
    if (!config.gitUrl || !config.tomcatURL) {
        error "mavenTomcatPipeline: Both gitUrl and tomcatURL are required"
    }

    // === Apply defaults ===
    def branchName   = config.branch    ?: 'main'
    def buildCmd     = config.buildCmd  ?: 'mvn clean install'
    def mavenTool    = config.mavenTool ?: 'mymaven'
    def shouldDeploy = config.deploy != false   // default: true

    // === Run the actual pipeline ===
    pipeline {
        agent any

        tools {
            maven mavenTool
        }

        stages {
            stage('SCM Checkout') {
                steps {
                    gitCheckout(config.gitUrl, branchName)
                }
            }

            stage('Build') {
                steps {
                    sh buildCmd
                }
            }

            stage('Deploy') {
                when {
                    expression { shouldDeploy }
                }
                steps {
                    deployToTomcat(config.tomcatURL)
                }
            }
        }

        post {
            success { echo "Pipeline completed successfully" }
            failure { echo "Pipeline failed" }
        }
    }
}
```

### Why Templates Are So Powerful

When the security team says *"Add a vulnerability scan stage to every pipeline"*:

- **Without templates:** Update 50 Jenkinsfiles manually
- **With templates:** Add one stage to `mavenTomcatPipeline.groovy`, push, done. All 50 services get it on next build.

### Important Rule

A Jenkinsfile using a template should have **NO `pipeline { }` block** of its own. The template already contains one.

```groovy
// ❌ WRONG — nesting pipeline inside pipeline
@Library('my-shared-lib') _
pipeline {
    agent any
    steps {
        mavenTomcatPipeline(gitUrl: '...')
    }
}

// ✅ CORRECT — just call the template
@Library('my-shared-lib') _
mavenTomcatPipeline(gitUrl: '...', tomcatURL: '...')
```

---

## 10. The `when` Block — Conditional Stages

### What It Does

`when` decides whether a stage runs AT ALL. If `when` is false, the stage is **skipped** (gray in Jenkins UI), and the `steps { }` never execute.

### Basic Syntax

```groovy
stage('Deploy') {
    when {
        expression { shouldDeploy }
    }
    steps {
        deployToTomcat(url)
    }
}
```

### Common `when` Patterns

```groovy
// Only on the main branch
when { branch 'main' }

// Only when triggered by a Git tag
when { tag 'v*' }   // matches v1.0.0, v2.5.1, etc.

// Only when certain files changed
when { changeset 'frontend/**' }

// Multiple conditions (ALL must be true)
when {
    allOf {
        branch 'main'
        expression { params.DEPLOY_ENABLED == true }
    }
}

// Multiple conditions (ANY can be true)
when {
    anyOf {
        branch 'main'
        branch 'release/*'
    }
}

// Negate a condition
when {
    not { branch 'experimental' }
}
```

### Flow Diagram

```
              ┌───────────────────┐
              │ Pipeline reaches  │
              │ a stage with when │
              └─────────┬─────────┘
                        │
                        ▼
              ┌───────────────────┐
              │ Evaluate when {}  │
              │ condition         │
              └─────────┬─────────┘
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
         ┌─────────┐         ┌─────────┐
         │  TRUE   │         │  FALSE  │
         └────┬────┘         └────┬────┘
              │                   │
              ▼                   ▼
       Run steps{}         Skip stage entirely
       (Green ✓)           (Gray "Skipped")
```

---

## 11. Common Bugs & Their Fixes

### Bug Diary from My Learning Journey

| Bug | Cause | Fix |
|---|---|---|
| `No such DSL method 'X'` | Filename in `vars/` doesn't match the function call | Check filename case-sensitively; `gitRepo()` requires `vars/gitRepo.groovy` |
| `MissingPropertyException: No such property` | Variable name inside code doesn't match the parameter declaration | Rename consistently everywhere (e.g., renamed `branch` to `branchName` but forgot to update `${branch}` in echo) |
| `Library not found` | Name in `@Library('...')` doesn't match Jenkins config | Make them match EXACTLY (case-sensitive) |
| `Tag not found` | Forgot to push the Git tag | `git push --follow-tags` |
| Pipeline deploys even with `deploy: false` | Elvis operator treats `false` as falsy | Use `!= false` instead of `?:` for boolean defaults of true |
| `sh` not found inside `src/` class | Pipeline globals not auto-available in `src/` | Pass `this` as `script`, use `script.sh()` |
| Pipeline crashes after a pause | Class missing serialization | Add `implements Serializable` to all `src/` classes |
| `You must use POST method to trigger builds` | Direct GET request to build URL | Use "Build Now" button in Jenkins UI sidebar |
| Comma in `if (a, b)` | Comma is not a logical operator | Use `&&` (AND) or `\|\|` (OR) |
| `${url}` outside a string fails | `${}` only works inside double-quoted strings | Use the variable directly without `${}` when passing as argument |

### Reading Jenkins Error Messages

When you see `java.lang.NoSuchMethodError: No such DSL method 'X' found among steps [...] or globals [...]`, scan the `globals [...]` list — your function might be there with a slightly different spelling.

This saved me when I called `gitRepo()` but the file was `getRepo.groovy`.

---

## 12. The `resources/` Folder (To Study Next)

### What It Is

The `resources/` folder holds **static files** (YAML, JSON, shell scripts, config templates) that your shared library can load at runtime.

### Why It Exists

Sometimes you need to load a template file rather than build everything in code. For example:
- Kubernetes deployment YAML templates
- JSON config templates
- Shell scripts for complex operations
- Email templates

### Basic Pattern

**Place a template file:**
```
resources/templates/k8s-deploy.yaml
```

Contents (with placeholders):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
spec:
  replicas: ${REPLICAS}
```

**Load it in a `vars/` function:**
```groovy
// vars/k8sDeploy.groovy
def call(Map config) {
    def template = libraryResource 'templates/k8s-deploy.yaml'

    def manifest = template
        .replace('${APP_NAME}', config.app)
        .replace('${REPLICAS}', config.replicas.toString())

    writeFile file: 'deploy.yaml', text: manifest
    sh 'kubectl apply -f deploy.yaml'
}
```

The `libraryResource` step is the key — it loads files from the library's `resources/` folder.

### Real-World Use Cases

- **Multi-environment configs:** One template, fill in `dev` / `staging` / `prod` values
- **Standardized k8s manifests:** Same structure across all services
- **Reusable shell scripts:** Complex scripts kept in library, not duplicated
- **Notification templates:** HTML email bodies, Slack message formats

### To Learn (For Next Session)
- [ ] How to use `libraryResource` step
- [ ] Best practices for template variable substitution
- [ ] Loading binary files vs text files
- [ ] When templates are better than building strings in code

---

## 13. Credentials Handling (To Study Next)

### Why It Matters

**Never hardcode passwords, API tokens, or SSH keys** in your shared library code. Anyone with read access to the repo would see them. Plus, credentials change — hardcoding means every change requires a code update.

### The Problem in Current Code

Look at my current `deployToTomcat.groovy`:
```groovy
deploy adapters: [tomcat9(
    credentialsId: 'Tomcat-Credentials',
    url: tomcatUrl
)], contextPath: null, war: '**/*.war'
```

The `credentialsId: 'Tomcat-Credentials'` references credentials stored in Jenkins — that's good. But what about scenarios where I need to pass credentials directly to a `sh` step? That requires `withCredentials`.

### The `withCredentials` Block

```groovy
withCredentials([usernamePassword(
    credentialsId: 'my-creds',
    usernameVariable: 'USER',
    passwordVariable: 'PASS'
)]) {
    sh '''
        curl -u $USER:$PASS https://api.example.com/deploy
    '''
}
```

Inside the block, the variables are available as environment variables. Jenkins automatically masks them in console output, so they never appear in logs.

### Credential Types

| Type | When to use |
|---|---|
| `usernamePassword` | Username + password combinations |
| `string` | API tokens, single secret strings |
| `file` | Files like SSH keys, kubeconfig, certificates |
| `sshUserPrivateKey` | SSH private keys |
| `certificate` | Code signing certificates |

### Using Credentials in Shared Libraries

```groovy
// vars/deployToProd.groovy
def call(Map config) {
    withCredentials([
        string(credentialsId: 'prod-api-token', variable: 'API_TOKEN'),
        usernamePassword(credentialsId: 'prod-db', usernameVariable: 'DB_USER', passwordVariable: 'DB_PASS')
    ]) {
        sh '''
            ./deploy.sh --token=$API_TOKEN --db-user=$DB_USER --db-pass=$DB_PASS
        '''
    }
}
```

### To Learn (For Next Session)
- [ ] How to add credentials in Jenkins UI
- [ ] All the credential types and when to use each
- [ ] `withCredentials` syntax and best practices
- [ ] How to keep secrets out of logs and stack traces
- [ ] Using credentials from inside `src/` classes
- [ ] Environment variable approach vs. file-based credentials

---

## 14. Quick Reference Cheat Sheet

### Folder Structure
```
my-shared-lib/
├── vars/              ← Public steps (filename = step name)
├── src/               ← Private classes (need vars/ wrapper to use)
└── resources/         ← Static files (loaded with libraryResource)
```

### Loading the Library
```groovy
@Library('my-shared-lib') _              // default version
@Library('my-shared-lib@v1.0.0') _       // pinned to tag (production)
@Library('my-shared-lib@feature-x') _    // for testing on a branch
```

### Defining a Step
```groovy
// vars/myStep.groovy
def call(Map config) {
    if (!config.required) { error "required parameter missing" }

    def optional = config.optional ?: 'default'      // safe for strings
    def flag = config.flag != false                   // safe for boolean default-true
    def disabled = config.disabled ?: false           // safe for boolean default-false

    sh "do-something --arg ${optional}"
}
```

### Pipeline Template
```groovy
// vars/myPipelineTemplate.groovy
def call(Map config) {
    pipeline {
        agent any
        stages {
            stage('X') {
                when { expression { config.runX != false } }
                steps { myStep(arg: config.value) }
            }
        }
    }
}
```

### Git Workflow for Library Updates
```bash
# Make changes on a branch
git checkout -b feature-x
git add .
git commit -m "Add feature"
git push

# Test in Jenkinsfile
@Library('my-shared-lib@feature-x') _

# Merge to main when ready
git checkout main
git merge feature-x

# Tag for production
git tag -a v1.0.0 -m "Stable release"
git push --follow-tags

# Pin production
@Library('my-shared-lib@v1.0.0') _
```

### Groovy Quick Tips

```groovy
// Strings
"with ${interp}"        // double quotes interpolate
'no ${interp}'          // single quotes are literal

// Default values
config.x ?: 'default'           // ✅ for strings, numbers
config.x != false               // ✅ for boolean default-true
config.x ?: false               // ✅ for boolean default-false

// Logical operators
&&    // AND
||    // OR
!     // NOT
```

### Common Things That Go Wrong

1. **Library not found** → Name mismatch between `@Library` and Jenkins config
2. **Step not found** → Filename in `vars/` doesn't match the call
3. **Property missing** → Renamed something but forgot to update all references
4. **Always deploys despite `false`** → Elvis trap; use `!= false`
5. **`sh` not found in `src/`** → Pass `this` as `script`, use `script.sh`
6. **Tag not visible** → Forgot `git push --follow-tags`
7. **Pause/resume crash** → Missing `implements Serializable`

---

## Future Topics to Explore (After Resources & Credentials)

**Tier 2 — Should-know eventually:**
- Parallel stages in templates
- Library overrides per branch/job
- Folder-scoped vs Global libraries
- Multibranch pipelines + shared libraries

**Tier 3 — Advanced:**
- Unit testing shared libraries (JenkinsPipelineUnit)
- Custom pipeline DSLs
- Dynamic library loading mid-pipeline
- CPS vs non-CPS code (`@NonCPS`)

**Tier 4 — Adjacent topics:**
- Jenkins Configuration as Code (JCasC)
- Job DSL plugin
- Build agents and Docker agents
- Webhooks and triggers
- Artifact management (Nexus, Artifactory, S3)

---

## My Journey So Far

- Started: Didn't know what Groovy was
- Built: A versioned shared library on GitHub (`my-shared-library`)
- Shipped: Three `vars/` functions (`gitCheckout`, `mavenBuild`, `deployToTomcat`)
- Created: A pipeline template (`mavenTomcatTemplate`)
- Deployed: A real Maven app to a real Tomcat server using the template
- Debugged: Multiple stack traces and fixed naming bugs independently

**Status:** Competent practitioner with the foundation needed for real DevOps work. Ready to learn `resources/` and `credentials` to complete the beginner tier.

---

*Notes compiled and maintained by Krishna Pavan. Refer back here anytime to refresh or prepare.*