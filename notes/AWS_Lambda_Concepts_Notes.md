# AWS Lambda Notes -- Cold Starts, Warm Starts, Statelessness, Concurrency & Batching

## 1. Mental Model

Think of Lambda as an **event-driven worker**.

    Event Occurs
          |
          V
    AWS invokes Lambda
          |
    Runs your code
          |
    Returns result
          |
    Execution environment may stay alive or may be removed

Lambda is not continuously running waiting for requests like a
traditional server.

------------------------------------------------------------------------

# 2. Real-World Use Cases

## Image Upload

    User
      |
    Upload Image
      |
      V
    S3
      |
    (Event)
      |
    Lambda
      |
    Resize / Compress
      |
    Store back in S3

## Jenkins Notification

    Jenkins Build Completed
            |
         Lambda
            |
    Slack / Email / Teams

## CloudWatch Alarm

    CPU > 90%
        |
    CloudWatch
        |
    Lambda
        |
    Restart Service / Send Notification

## User Registration

    Register User
          |
    Lambda
     |      |      |
    Email  Analytics Folder Creation

------------------------------------------------------------------------

# 3. Lambda Function Structure

Typical Lambda:

``` python
import boto3

# INIT PHASE
s3 = boto3.client("s3")

def lambda_handler(event, context):
    # HANDLER
    print(event)
```

INIT runs once **per execution environment**.

Handler runs **for every invocation**.

------------------------------------------------------------------------

# 4. Cold Start

Cold start happens when AWS creates a **new execution environment**.

Steps:

1.  Create environment
2.  Load runtime
3.  Import libraries
4.  Execute INIT code
5.  Call handler()

------------------------------------------------------------------------

# 5. Warm Start

If AWS reuses the same execution environment:

-   Runtime already loaded
-   Libraries already imported
-   Global variables already exist
-   INIT is skipped

Only the handler executes.

------------------------------------------------------------------------

# 6. Biggest Doubt: If Lambda is Stateless, Why Isn't Every Invocation a Cold Start?

## The confusion

Many people think:

> Stateless = AWS destroys everything after every request.

This is **incorrect**.

Stateless means:

> Your application must not depend on memory from previous invocations.

AWS **may reuse** the execution environment.

Therefore:

-   Same environment -\> Warm start
-   New environment -\> Cold start

------------------------------------------------------------------------

# 7. Restaurant Analogy

First customer:

    Wear Apron
    Turn On Stove
    Arrange Kitchen
    Cook Food

Second customer:

    Kitchen already ready
    Cook Food

Kitchen = Execution Environment

Order = Invocation

Every order is independent.

The kitchen may be reused.

------------------------------------------------------------------------

# 8. Execution Environment

An execution environment contains:

-   Runtime
-   Imported libraries
-   Global variables
-   Database connections (if still valid)
-   /tmp storage

AWS may keep it alive after execution.

AWS may remove it anytime.

There is **no guaranteed idle timeout**.

------------------------------------------------------------------------

# 9. Concurrency

One execution environment can process:

**Exactly ONE invocation at a time.**

Example:

    Request 1 ---> Environment A

    Request 2 ---> Environment B

    Request 3 ---> Environment C

If Request 4 arrives after Environment A finishes:

    Environment A
          |
    Request 4

Warm start.

------------------------------------------------------------------------

# 10. Can One Environment Process Thousands of Requests?

Yes.

Over time:

    Environment A

    Request1
    Request2
    Request3
    ...
    Request500

Only one at a time.

------------------------------------------------------------------------

# 11. Massive Traffic Example

Suppose 1 million users upload photos.

AWS does NOT create unlimited environments instantly.

It creates environments according to available concurrency.

Example:

Concurrency = 1000

    1000000 Requests

    ↓

    1000 Lambdas Running

    ↓

    Remaining Requests Wait (depending on trigger/service)

Large systems often use queues such as SQS to smooth bursts.

------------------------------------------------------------------------

# 12. Batching

Batching is **controlled by the event source**, not Lambda.

Supports batching:

-   SQS
-   Kinesis
-   DynamoDB Streams
-   Kafka

No batching:

-   API Gateway
-   S3
-   EventBridge

------------------------------------------------------------------------

# 13. SQS Example

Queue:

    Order1
    Order2
    Order3
    Order4
    Order5

Batch Size = 5

Lambda receives:

``` python
{
    "Records":[
        {...},
        {...},
        {...},
        {...},
        {...}
    ]
}
```

Code:

``` python
def lambda_handler(event, context):

    for record in event["Records"]:
        print(record["body"])
```

Only ONE Lambda invocation.

Processes five messages.

------------------------------------------------------------------------

# 14. Billing with Batching

Without batching

    10 Messages

    ↓

    10 Lambda Invocations

Invocation charges = 10

With batch size = 10

    10 Messages

    ↓

    1 Lambda Invocation

Invocation charges = 1

Execution duration is roughly the total time to process all messages.

Batching reduces invocation count but not necessarily compute time.

------------------------------------------------------------------------

# 15. Key Interview Points

## Cold Start

Occurs only when AWS creates a new execution environment.

## Warm Start

Occurs when AWS reuses an existing execution environment.

## Stateless

Never rely on in-memory variables across invocations.

Store persistent data in:

-   DynamoDB
-   S3
-   RDS
-   ElastiCache

## Concurrency

One execution environment = One concurrent invocation.

## Batching

Provided by the event source.

Reduces invocation count and improves throughput.

------------------------------------------------------------------------

# Final Takeaways

-   Event != Execution Environment
-   Invocation != Cold Start
-   Stateless != Environment Destroyed
-   One Environment == One Concurrent Invocation
-   Same Environment can serve many invocations over time
-   New Environment always causes a Cold Start
-   Batching is configured on services like SQS, not inside Lambda
-   Use external storage for persistent state
