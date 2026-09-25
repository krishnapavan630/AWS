# Terraform Fundamentals

> Beginner-friendly Terraform notes — from zero knowledge to understanding the core Terraform workflow, providers, state, drift, import, and RPC.

---

# 1. What is Terraform?

**Terraform is an Infrastructure as Code (IaC) tool developed by HashiCorp.**

Infrastructure as Code means:

> Instead of manually creating infrastructure through a cloud console, we describe the infrastructure we want using code, and Terraform creates and manages it for us.

For example, instead of manually creating an EC2 instance through the AWS Console, we can write:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-xxxxxxxx"
  instance_type = "t3.micro"
}
```

Terraform reads this configuration and works with AWS to make the infrastructure match what we declared.

---

# 2. Terraform's Basic Mental Model

The most important concept is:

```text
Terraform Configuration
        ↓
   Desired State
        ↓
     Terraform
        ↓
   Cloud Provider
        ↓
       AWS
        ↓
Actual Infrastructure
```

There are three important things to distinguish:

### 1. Configuration

What we **want**.

Example:

```hcl
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}
```

### 2. Terraform State

What Terraform **knows and manages**.

Example:

```text
aws_instance.web
        ↓
i-0123456789
```

### 3. Real Infrastructure

What **actually exists** in AWS.

Example:

```text
EC2 instance
i-0123456789
t3.micro
```

Terraform compares these concepts to determine what needs to change.

---

# 3. Terraform Provider

Terraform itself does not contain the implementation for every cloud or service.

A **provider is a plugin that allows Terraform to interact with a particular platform or service.**

Examples:

```text
AWS Provider       → AWS
Azure Provider     → Azure
Google Provider    → Google Cloud
Kubernetes Provider → Kubernetes
GitHub Provider    → GitHub
```

For AWS:

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

This tells Terraform:

> "Use the AWS provider and work with the AWS environment."

---

# 4. Terraform Core vs Provider

Terraform can be thought of as two major parts:

```text
              Terraform Core
                    │
                    │
              Plugin communication
                    │
                    ▼
              AWS Provider
                    │
                    │ AWS API
                    ▼
                   AWS
```

### Terraform Core

Handles Terraform-specific functionality such as:

* Reading configuration
* Building the resource dependency graph
* Planning changes
* Managing state
* Determining what needs to change
* Executing the planned operations

### Provider

Knows how to interact with a particular platform.

For example, the AWS provider knows how to:

* Create EC2 instances
* Create VPCs
* Create S3 buckets
* Create IAM resources
* Read AWS resources
* Modify AWS resources
* Delete AWS resources

---

# 5. What is Terraform RPC?

**RPC = Remote Procedure Call.**

RPC is a communication mechanism used between Terraform Core and provider plugins.

The provider is a separate plugin/process from Terraform Core.

Conceptually:

```text
Terraform Core
      │
      │ RPC / plugin communication
      ▼
AWS Provider
      │
      │ AWS API
      ▼
AWS
```

For example, Terraform Core may determine:

> "I need to create `aws_instance.web`."

It communicates this operation to the AWS provider.

The AWS provider knows how to translate that operation into AWS API calls.

So:

```text
Terraform Core
     │
     │ "Create this EC2"
     ▼
AWS Provider
     │
     │ AWS API request
     ▼
AWS
```

### Important

RPC is normally an **under-the-hood mechanism**.

We generally don't configure RPC ourselves in normal Terraform usage.

Think of it as:

> **RPC = how Terraform Core communicates with provider plugins.**

It is separate from Terraform state.

```text
RPC       → Communication
State     → Resource tracking/mapping
```

---

# 6. Terraform Provider Binary

The provider is distributed as a binary executable appropriate for the operating system and CPU architecture.

For example:

```text
Windows AMD64
Linux AMD64
macOS ARM64
```

The Terraform configuration itself is generally portable.

For example, the same:

```hcl
resource "aws_instance" "web" {
  ...
}
```

can be used by someone on:

```text
Windows
Linux
macOS
```

Terraform obtains the appropriate provider package for that platform.

---

# 7. `terraform init`

The first major Terraform command is:

```bash
terraform init
```

## Definition

> **`terraform init` initializes a Terraform working directory and installs/configures the dependencies required by the configuration, including providers and modules.**

Suppose we have:

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

Terraform sees that the AWS provider is required.

Running:

```bash
terraform init
```

downloads the required provider.

---

# 8. What happens during `terraform init`?

Conceptually:

```text
terraform init
      ↓
Read configuration
      ↓
Identify required providers
      ↓
Download required provider
      ↓
Prepare Terraform working directory
      ↓
Create/update dependency information
```

It can create:

```text
.terraform/
```

and:

```text
.terraform.lock.hcl
```

---

# 9. `.terraform/` Directory

The `.terraform/` directory contains local Terraform working data.

One important part is the downloaded provider plugins.

Conceptually:

```text
.terraform/
└── providers/
    └── registry.terraform.io/
        └── hashicorp/
            └── aws/
                └── AWS provider binary
```

Think:

> `.terraform/` = local files Terraform needs to work with the project.

### Should `.terraform/` normally be committed to Git?

**No.**

It is local working/dependency data.

Another developer can obtain the required providers by running:

```bash
terraform init
```

---

# 10. `.terraform.lock.hcl`

Terraform can create:

```text
.terraform.lock.hcl
```

This is the **dependency lock file**.

It records information about selected provider versions and acceptable provider package hashes/checksums.

Conceptually:

```text
AWS Provider
     │
     ├── Version
     │
     └── Checksums
```

### Should `.terraform.lock.hcl` be committed to Git?

**Yes, normally.**

It helps different users/environments consistently use the expected provider versions and verify provider packages.

---

# 11. What is a Checksum?

A **checksum is essentially a fingerprint of a file/package.**

Imagine Terraform downloads an AWS provider package.

Conceptually:

```text
AWS Provider Package
        ↓
Hash/checksum calculation
        ↓
ABC123XYZ...
```

Terraform can compare that fingerprint against an expected/accepted fingerprint.

If they match:

```text
Expected:   ABC123
Downloaded: ABC123

           ✅ Match
```

If they don't:

```text
Expected:   ABC123
Downloaded: XYZ789

           ❌ Mismatch
```

This helps Terraform verify that the provider package is the expected package.

### Important distinction

A checksum is **not**:

* The provider version
* The provider itself
* Terraform state
* Terraform configuration

Instead:

> **Checksum = fingerprint used to verify a provider package.**

---

# 12. Why can the lock file contain multiple checksums?

Provider packages can be built for different platforms/architectures.

For example:

```text
AWS Provider

Windows AMD64 → checksum A
Linux AMD64   → checksum B
macOS ARM64   → checksum C
```

The lock file can record hashes for valid provider packages.

Therefore:

```text
Same Terraform configuration
        ↓
Different operating systems
        ↓
Different provider binaries
        ↓
Corresponding accepted checksums
```

---

# 13. `terraform plan`

After initialization, we can run:

```bash
terraform plan
```

## Definition

> **`terraform plan` creates a preview of the changes Terraform intends to make to bring the infrastructure in line with the configuration.**

For example, if no EC2 exists yet:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The `+` symbol generally represents a resource to be created.

---

# 14. Does `terraform plan` create infrastructure?

**No.**

`terraform plan` is primarily a preview.

Think:

```text
terraform plan
      ↓
"What would happen?"
      ↓
Preview changes
      ↓
Infrastructure normally unchanged
```

This is why plan is an important safety step.

---

# 15. `terraform apply`

```bash
terraform apply
```

## Definition

> **`terraform apply` executes the planned infrastructure changes.**

For example:

```text
terraform apply
      ↓
Calculate plan
      ↓
Show proposed changes
      ↓
Confirmation
      ↓
Execute changes
      ↓
AWS infrastructure changes
```

Terraform may ask:

```text
Do you want to perform these actions?

Enter a value: yes
```

After confirmation, Terraform communicates with the provider, and the provider communicates with AWS.

---

# 16. `terraform plan` vs `terraform apply`

The easiest way to remember:

```text
terraform plan
    ↓
"Show me what will happen."

terraform apply
    ↓
"Actually do it."
```

`terraform apply` itself calculates a plan before execution, which is why you see the proposed changes during `apply`.

---

# 17. `terraform destroy`

```bash
terraform destroy
```

## Definition

> **`terraform destroy` creates and applies a plan to destroy resources managed by the Terraform configuration/state.**

For example:

```text
Terraform state

aws_instance.web
       ↓
EC2-B
```

Running:

```bash
terraform destroy
```

can result in:

```text
EC2-B
  ↓
DELETED
```

---

# 18. Terraform Does NOT Mean "Delete Everything in AWS"

Suppose AWS contains:

```text
EC2-A → manually created
EC2-B → Terraform managed
```

Terraform state contains:

```text
aws_instance.web
       ↓
EC2-B
```

Running:

```bash
terraform destroy
```

does not mean:

```text
Delete every EC2 in AWS
```

It means:

```text
Destroy resources managed by this Terraform configuration/state.
```

Therefore:

```text
EC2-A → untouched
EC2-B → destroyed
```

---

# 19. Terraform State

The state file is one of the most important Terraform concepts.

A local Terraform project may contain:

```text
terraform.tfstate
```

## Definition

> **Terraform state is Terraform's record of the resources it manages and the information Terraform uses to map Terraform resource addresses to real infrastructure.**

For example:

```text
Terraform resource address
        │
        ▼
aws_instance.web
        │
        ▼
AWS resource
i-0123456789
```

The state maintains this relationship.

---

# 20. Why does Terraform need state?

Suppose Terraform created:

```text
aws_instance.web
```

which corresponds to:

```text
i-0123456789
```

Later Terraform needs to determine:

> "Which real AWS resource does `aws_instance.web` represent?"

State provides that mapping.

Without state, Terraform loses important information about resources it previously managed.

---

# 21. State is NOT the Infrastructure

This distinction is extremely important.

```text
Terraform configuration
       ↓
What I WANT

Terraform state
       ↓
What Terraform KNOWS/MANAGES

AWS
       ↓
What ACTUALLY EXISTS
```

Deleting the state file does **not** delete the AWS infrastructure.

For example:

```text
terraform.tfstate
     ❌ deleted

AWS EC2
     ✅ still exists
```

But Terraform has lost its tracking/mapping information.

---

# 22. What happens if the State File is Deleted?

Suppose:

```text
Terraform state
       ↓
aws_instance.web
       ↓
i-123456
```

The state file is deleted.

Now:

```text
Terraform configuration
       ✅ exists

AWS EC2
       ✅ exists

Terraform state
       ❌ missing
```

The EC2 is still running.

But Terraform may no longer know that:

```text
aws_instance.web
        =
i-123456
```

This can cause Terraform to interpret an existing resource as something it needs to create or otherwise require reconciliation.

---

# 23. State Recovery

The preferred recovery mechanism in a real organization is **restoring the state from reliable remote storage/versioning/backups**.

But consider the extreme scenario:

```text
State
      ❌ lost

State backups
      ❌ lost

AWS infrastructure
      ✅ exists
```

Now Terraform's mapping information is gone.

There is no magical command that can perfectly reconstruct historical Terraform state if that information no longer exists anywhere.

Resources may have to be rediscovered and imported/adopted into Terraform.

This can be a significant recovery exercise.

---

# 24. Terraform Import

Terraform provides import functionality for existing infrastructure.

Example:

```bash
terraform import aws_instance.web i-123456789
```

This tells Terraform:

> "The existing AWS resource `i-123456789` corresponds to the Terraform resource address `aws_instance.web`."

Conceptually:

```text
Existing AWS resource
i-123456
     │
     │ import
     ▼
aws_instance.web
     │
     ▼
Terraform state
```

### Important

Import does **not** mean Terraform created the resource.

It means Terraform is being told:

> "Start tracking this already-existing resource."

---

# 25. Import Does Not Automatically Make the Configuration Correct

Suppose AWS has:

```text
Instance type = t3.large
Disk = 100 GB
```

But Terraform configuration says:

```hcl
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}
```

After importing:

```text
aws_instance.web
       ↓
Existing EC2
```

Terraform can discover differences during planning.

Therefore, the safe workflow is:

```text
Import
  ↓
Plan
  ↓
Understand differences
  ↓
Correct Terraform configuration if necessary
  ↓
Plan again
  ↓
Apply when confident
```

Never blindly assume an imported resource perfectly matches the Terraform configuration.

---

# 26. Drift

## Definition

> **Drift is a difference between the infrastructure Terraform expects and the actual infrastructure that exists.**

Example:

Terraform configuration:

```text
EBS = 20 GB
```

Terraform state initially knows:

```text
EBS = 20 GB
```

Someone manually changes AWS:

```text
EBS = 50 GB
```

Now:

```text
Desired configuration = 20 GB
State                  = 20 GB
AWS actual             = 50 GB
```

This difference is **drift**.

---

# 27. How Terraform Detects Drift

Terraform can query the provider for information about the real infrastructure.

Conceptually:

```text
terraform plan
      ↓
Terraform
      ↓
Provider
      ↓
AWS
      ↓
"Current resource is 50 GB"
      ↓
Terraform compares
      ↓
Configuration says 20 GB
      ↓
Difference detected
```

Therefore, you do not have to wait for `terraform apply` just to discover drift.

`terraform plan` can reveal proposed reconciliation.

---

# 28. What Happens When We Apply After Drift?

Suppose:

```text
Terraform configuration = 20 GB
AWS actual              = 50 GB
```

You run:

```bash
terraform plan
```

Terraform may propose changing the infrastructure to match the declared configuration.

Then:

```bash
terraform apply
```

can actually execute that change.

So:

```text
plan
 ↓
Detect/preview

apply
 ↓
Execute
```

---

# 29. What if an AWS Resource Was Never Managed by Terraform?

Suppose:

```text
AWS

EC2-A → manually created
EC2-B → created by Terraform
```

Terraform state contains:

```text
aws_instance.web
       ↓
EC2-B
```

Running:

```bash
terraform destroy
```

does not normally destroy EC2-A because Terraform does not have EC2-A represented in its state.

---

# 30. Can Terraform Destroy an Originally Manually-Created Resource?

Yes.

If you import it:

```bash
terraform import aws_instance.existing i-123456
```

then it becomes represented in Terraform state.

Now Terraform can manage its lifecycle.

Therefore:

```text
Manually created EC2
        ↓
terraform import
        ↓
Terraform state
        ↓
Terraform-managed resource
```

The important concept is:

> Terraform does not care whether Terraform originally created the resource. What matters is whether the resource is represented and managed in Terraform state.

---

# 31. Data Sources vs Import

These two concepts should not be confused.

### Data source

Used to **read information about an existing resource**.

Conceptually:

```text
AWS existing resource
       ↓
Data source
       ↓
Terraform reads information
```

It does not automatically make Terraform responsible for destroying that resource.

### Import

Used to associate an existing resource with a Terraform resource address and put it under Terraform management/state.

```text
Existing resource
       ↓
Import
       ↓
Terraform state
       ↓
Terraform manages it
```

---

# 32. Production Terraform and Remote State

In a small learning project, state might be local:

```text
terraform.tfstate
```

In an organization, Terraform state is commonly stored in a **remote backend**.

Conceptually:

```text
Developer / CI
      ↓
Terraform
      ↓
Remote Backend
      ↓
Terraform State
      ↓
AWS infrastructure
```

For AWS environments, S3 is a common remote state storage option, with appropriate state locking/coordination.

The exact backend architecture depends on the organization's Terraform setup.

---

# 33. Why Remote State?

Imagine a company has:

```text
Developer A
Developer B
Developer C
CI/CD
```

You don't want each person to have an independent local state file.

Instead:

```text
                  Remote State
                 ┌────────────┐
Developer A ────►│            │
Developer B ────►│ Terraform  │
Developer C ────►│   State    │
CI/CD ──────────►│            │
                 └────────────┘
```

This allows the team/processes to work against shared state.

---

# 34. What If an Organization Completely Loses State?

This is a serious disaster scenario.

Suppose:

```text
Terraform configuration
        ✅ exists

Terraform state
        ❌ lost

State backups/version history
        ❌ lost

AWS infrastructure
        ✅ exists
```

The infrastructure itself is still there.

However, Terraform has lost its mapping between:

```text
Terraform resource addresses
        ↓
AWS resources
```

For example:

```text
aws_instance.web
        ↓
i-123456
```

That relationship may be lost.

---

# 35. Can Terraform Automatically Discover Everything It Used to Manage?

No.

There is no magical command like:

```bash
terraform find-everything-I-used-to-manage
```

AWS can tell you what resources currently exist.

But if all Terraform state and other ownership records are gone, AWS does not inherently know:

```text
"This EC2 was previously managed by Terraform."
```

Therefore, complete state loss can require a major recovery effort.

---

# 36. How Could a Large Organization Recover?

They may use multiple sources of information:

```text
AWS inventory
       +
Tags
       +
Naming conventions
       +
Terraform configuration
       +
Infrastructure documentation
       +
CI/CD information
       +
Resource relationships
```

Then resources can be identified and imported/re-adopted into Terraform.

For a large infrastructure estate, this can be automated or partially automated.

But:

> **There is no magic recovery mechanism that reconstructs information that has been completely destroyed everywhere.**

This is why Terraform state is treated as important infrastructure data.

---

# 37. Why State Backups Matter

A production Terraform architecture should protect state using mechanisms such as:

* Remote state
* State versioning
* Backups
* Access controls
* State locking/coordination
* Disaster recovery procedures

The goal is:

```text
State accidentally lost
        ↓
Restore known-good state
        ↓
Terraform continues managing infrastructure
```

The preferred solution to state loss is normally **state recovery**, not manually importing thousands of resources.

---

# 38. `.terraform/` vs `.terraform.lock.hcl` vs State

These three are very different.

| File / Directory      | Purpose                                     | Normally commit to Git? |
| --------------------- | ------------------------------------------- | ----------------------- |
| `.terraform/`         | Local working data and downloaded providers | ❌ No                    |
| `.terraform.lock.hcl` | Provider versions/checksums                 | ✅ Yes                   |
| `terraform.tfstate`   | Terraform's resource state/mapping          | ❌ Normally no           |

A common `.gitignore` contains:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
```

Do not add:

```text
.terraform.lock.hcl
```

to the ignore list if you want the normal dependency-locking workflow.

---

# 39. The Four Fundamental Terraform Commands

For a beginner, remember them like this:

## `terraform init`

> **Prepare Terraform.**

```text
Download providers
Initialize working directory
Set up dependencies/backend
```

---

## `terraform plan`

> **Show me what will change.**

```text
Calculate proposed changes
Preview additions/changes/deletions
```

---

## `terraform apply`

> **Actually make the changes.**

```text
Execute the Terraform plan
Create/update/destroy resources as required
```

---

## `terraform destroy`

> **Remove the infrastructure managed by this Terraform configuration/state.**

```text
Destroy managed resources
```

---

# 40. Complete Terraform Workflow

The basic workflow is:

```text
                 main.tf
                    │
                    ▼
             terraform init
                    │
                    ▼
          Provider is available
                    │
                    ▼
             terraform plan
                    │
                    ▼
           Review the changes
                    │
                    ▼
            terraform apply
                    │
                    ▼
              AWS changes
                    │
                    ▼
            State is updated
```

Later, you modify the configuration:

```text
Modify .tf
   ↓
terraform plan
   ↓
Review
   ↓
terraform apply
   ↓
Infrastructure updated
```

When the infrastructure should be removed:

```text
terraform destroy
   ↓
Managed infrastructure removed
```

---

# 41. The Complete Mental Model

Keep this diagram in mind:

```text
                         Terraform
                            │
                   ┌────────┴────────┐
                   │                 │
                   ▼                 ▼
             Configuration        State
                main.tf        terraform.tfstate
                   │                 │
                   │                 │
                   └────────┬────────┘
                            │
                            ▼
                       Terraform Core
                            │
                            │ RPC / Plugin
                            ▼
                     AWS Provider
                            │
                            │ AWS API
                            ▼
                           AWS
                            │
                            ▼
                  Actual Infrastructure
```

The roles are:

```text
Configuration
    ↓
What I want

State
    ↓
What Terraform knows/manages

Provider
    ↓
How Terraform communicates with a platform

RPC
    ↓
How Terraform Core communicates with provider plugins

AWS
    ↓
What actually exists
```

---

# 42. Interview Quick Revision

### What is Terraform?

> Terraform is an Infrastructure as Code tool used to define and manage infrastructure using declarative configuration.

### What is a provider?

> A provider is a plugin that allows Terraform to interact with a specific platform or service such as AWS, Azure, Kubernetes, or GitHub.

### What does `terraform init` do?

> It initializes the Terraform working directory and installs/configures required providers, modules, and backend dependencies.

### Does `terraform init` create infrastructure?

> No.

### What does `terraform plan` do?

> It calculates and displays the changes Terraform intends to make without normally applying those changes.

### Does `terraform plan` create infrastructure?

> No.

### What does `terraform apply` do?

> It executes the planned infrastructure changes.

### What does `terraform destroy` do?

> It creates and applies a plan to destroy resources managed by the Terraform configuration/state.

### What is Terraform state?

> State is Terraform's record of managed resources and the mapping between Terraform resource addresses and real infrastructure.

### What is drift?

> Drift is a difference between the desired configuration and the actual infrastructure.

### What is `terraform import`?

> Import associates an existing real-world resource with a Terraform resource address and records it in Terraform state so Terraform can manage it.

### What is a checksum?

> A checksum is a cryptographic fingerprint of a provider package used to verify that the downloaded package matches an expected/accepted package.

### What is `.terraform.lock.hcl`?

> It is Terraform's dependency lock file that records selected provider versions and provider package checksums.

### What is `.terraform/`?

> It is a local Terraform working directory containing downloaded providers and other working data.

### What is RPC?

> RPC is a communication mechanism used by Terraform's plugin architecture for communication between Terraform Core and provider plugins.

---

# 43. Final Cheat Sheet

```text
┌──────────────────────────────────────────────┐
│              TERRAFORM BASICS                │
├──────────────────────────────────────────────┤
│                                              │
│ main.tf                                      │
│   ↓                                          │
│ Desired configuration                        │
│                                              │
│ terraform init                               │
│   ↓                                          │
│ Prepare Terraform + download providers       │
│                                              │
│ .terraform/                                  │
│   ↓                                          │
│ Local provider/working files                 │
│                                              │
│ .terraform.lock.hcl                           │
│   ↓                                          │
│ Provider versions + checksums                │
│                                              │
│ terraform plan                               │
│   ↓                                          │
│ Preview changes                              │
│                                              │
│ terraform apply                              │
│   ↓                                          │
│ Execute changes                              │
│                                              │
│ terraform.tfstate                            │
│   ↓                                          │
│ Terraform's resource mapping/state           │
│                                              │
│ Drift                                        │
│   ↓                                          │
│ Desired ≠ Actual                             │
│                                              │
│ terraform import                             │
│   ↓                                          │
│ Existing resource → Terraform state         │
│                                              │
│ terraform destroy                            │
│   ↓                                          │
│ Destroy Terraform-managed resources          │
│                                              │
│ RPC                                          │
│   ↓                                          │
│ Terraform Core ↔ Provider communication      │
│                                              │
└──────────────────────────────────────────────┘
```

---

# 44. The One Mental Model to Remember

If you forget everything else, remember:

```text
                 "What do I WANT?"
                         │
                         ▼
                    main.tf
                         │
                         ▼
                  Terraform Core
                    /         \
                   /           \
                  ▼             ▼
             State              Provider
          "What do I        "How do I talk
           manage?"           to AWS?"
                  │             │
                  │             ▼
                  │            AWS
                  │             │
                  └──────┬──────┘
                         ▼
                 "What ACTUALLY
                    exists?"
```

Terraform's job is essentially to **reconcile the desired configuration with real infrastructure while maintaining state about the resources it manages.**
