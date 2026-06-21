# Node.js & npm Revision Notes (DevOps Perspective)

# 1. What is Node.js?

**Node.js is a JavaScript Runtime.**

-   JavaScript is the programming language.
-   Node.js executes JavaScript outside the browser.
-   Node.js reads a `.js` file and executes it line by line.
-   Node.js does **not** compile code like Java.

Example:

``` javascript
console.log("Hello World");
```

Run:

``` bash
node index.js
```

Flow:

``` text
You
  |
node index.js
  |
Node Runtime
  |
Reads index.js
  |
Executes JavaScript
```

------------------------------------------------------------------------

# 2. What is npm?

**npm = Node Package Manager**

Its responsibilities are:

-   Install dependencies
-   Manage project packages
-   Read `package.json`
-   Execute scripts defined in `package.json`

npm **does not execute JavaScript**. Node does.

------------------------------------------------------------------------

# 3. Difference Between Node and npm

  Node                  npm
  --------------------- ---------------------------------
  Executes JavaScript   Installs packages
  Runs index.js         Reads package.json
  Runtime               Package Manager & Script Runner

------------------------------------------------------------------------

# 4. package.json

Think of it as the project's instruction manual.

It stores:

-   Project name
-   Version
-   Dependencies
-   Scripts

Example:

``` json
{
  "name":"demo",
  "scripts":{
      "start":"node index.js"
  },
  "dependencies":{
      "express":"^5.1.0"
  }
}
```

------------------------------------------------------------------------

# 5. package-lock.json

Purpose:

-   Locks the exact dependency versions.
-   Ensures Developer, Jenkins, Docker and Production all install
    identical packages.
-   Also locks transitive dependencies.

Example:

    package.json

    express

    ↓

    package-lock.json

    express
    body-parser
    debug
    mime-types
    ...

## Should we commit it?

**Yes** (for applications).

------------------------------------------------------------------------

# 6. node_modules

Contains downloaded libraries.

Example:

    node_modules/

    express/

    mathjs/

    axios/

Do **NOT** commit this folder to Git.

Add to `.gitignore`:

    node_modules/

------------------------------------------------------------------------

# 7. npm install

Reads:

    package.json

Downloads dependencies.

Creates:

-   node_modules
-   package-lock.json (if missing)

Flow:

    npm install

    ↓

    Read package.json

    ↓

    Download packages

    ↓

    Create node_modules

    ↓

    Update package-lock.json

------------------------------------------------------------------------

# 8. node index.js

Runs the application.

    node index.js

    ↓

    Node Runtime

    ↓

    Reads index.js

    ↓

    Executes JavaScript

------------------------------------------------------------------------

# 9. npm start

Example:

``` json
"scripts":{
    "start":"node index.js"
}
```

Command:

``` bash
npm start
```

Flow:

    npm

    ↓

    Read package.json

    ↓

    Find "start"

    ↓

    node index.js

    ↓

    Node executes JavaScript

------------------------------------------------------------------------

\# 10. npm run
```{=html}
<script>
```
Any custom script must use `run`.

Example:

``` json
"scripts":{
    "hello":"echo Hello",
    "build":"touch success.txt"
}
```

Execute:

``` bash
npm run hello
npm run build
```

npm simply launches the command written in the script.

------------------------------------------------------------------------

# 11. Why npm start but npm run build?

Special shortcuts:

    npm start
    npm test
    npm stop

Custom scripts:

    npm run build
    npm run hello
    npm run deploy

------------------------------------------------------------------------

# 12. npm run build

Important:

**npm does NOT know what build means.**

It simply executes whatever the developer writes.

Examples:

``` json
"build":"echo Hello"
```

or

``` json
"build":"touch success.txt"
```

or

``` json
"build":"webpack"
```

or

``` json
"build":"react-scripts build"
```

or

``` json
"build":"vite build"
```

Different projects have different build commands.

Unlike Maven, there is no fixed build lifecycle.

------------------------------------------------------------------------

# 13. Maven vs npm

  Maven                npm
  -------------------- ----------------------------------
  pom.xml              package.json
  mvn install          npm install
  mvn package          npm run build (project-specific)
  Standard lifecycle   Developer-defined scripts

------------------------------------------------------------------------

# 14. Git Repository

Commit:

    index.js
    package.json
    package-lock.json
    .gitignore
    Dockerfile
    Jenkinsfile

Do NOT commit:

    node_modules/

------------------------------------------------------------------------

# 15. Docker Best Practices

Recommended Dockerfile:

``` dockerfile
FROM node:20

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm","start"]
```

Why copy package.json first?

Docker Layer Cache.

If only source code changes:

    package.json

    ↓

    No change

    ↓

    Reuse npm install layer

If package.json changes:

    COPY package.json

    ↓

    RUN npm install executes again

------------------------------------------------------------------------

# 16. Jenkins Pipeline Flow

Typical pipeline:

    Git Clone

    ↓

    Docker Build

    ↓

    RUN npm install

    ↓

    Docker Image

    ↓

    Docker Run

    ↓

    npm start

    ↓

    Node Runtime

    ↓

    Application Running

Alternative pipeline:

    Git Clone

    ↓

    npm install

    ↓

    npm test

    ↓

    docker build

    ↓

    docker run

Both approaches are valid depending on project requirements.

------------------------------------------------------------------------

# 17. Mental Model

Developer writes:

    index.js
    package.json

DevOps Engineer:

    Open package.json

    ↓

    Check dependencies

    ↓

    Check scripts

    ↓

    Create Dockerfile

    ↓

    Create Jenkins Pipeline

------------------------------------------------------------------------

# 18. Interview Questions

### Who executes JavaScript?

**Node**

### Who installs dependencies?

**npm**

### Who reads package.json?

**npm**

### Who executes the commands under scripts?

**npm launches them (via the shell).**

### Who executes commands like touch, mkdir, echo?

**The operating system shell (bash/sh).**

------------------------------------------------------------------------

# 19. Quick Revision

    node index.js

→ Execute JavaScript

    npm install

→ Install dependencies

    npm start

→ Run the "start" script

    npm run build

→ Run the "build" script

    npm run hello

→ Run the "hello" script

------------------------------------------------------------------------

# 20. DevOps Golden Rules

1.  Always inspect `package.json` first.
2.  Never commit `node_modules`.
3.  Commit `package-lock.json`.
4.  Use Docker layer caching (`COPY package*.json` first).
5.  Don't assume what `npm run build` does---read the `build` script.
6.  Node executes JavaScript. npm manages packages and launches scripts.
