# Proxy, Reverse Proxy, Web Server & App Server — Revision Notes

> Read these to refresh the concepts anytime.

---

## 1. Proxy — The Core Idea

A **proxy** is a middleman server that sits between a client and another server and **forwards requests** on someone's behalf.

There are two types, based on **whose side it's on**:

| Type | Whose side? | Represents | Example |
|---|---|---|---|
| **Forward proxy** | Client side | The client | Office firewall proxy filtering employee traffic |
| **Reverse proxy** | Server side | The backend server(s) | Nginx in front of Tomcat |

### The golden definition (lock this in)

> **A forward proxy is a middleman that represents the client to the world.**
> **A reverse proxy is a middleman that represents the server to the world.**
> Both forward traffic in both directions. Their identity is fixed by *whose side they're on*, not by which way bytes are flowing right now.

---

## 2. Forward Proxy vs Reverse Proxy — Visual

```
   YOU                                                    BACKEND
   (client,         FORWARD          REVERSE              (server,
   originator)       PROXY            PROXY               final dest)
      |                |                |                    |
      | --request-->   | --request-->   | --request-->       |
      |                |                |                    |
      | <--response--  | <--response--  | <--response--      |
      |                |                |                    |
   [endpoint]      [middleman      [middleman           [endpoint]
                    for YOU]       for BACKEND]
```

- Endpoints (you, backend) are **fixed**.
- Proxies are middlemen with **fixed roles**.
- Traffic flows both ways through proxies, but proxies **never change identity**.

---

## 3. Analogy to Remember

**International business call (you in India ↔ CEO in the US):**

- **You** → the originator (client).
- **Your translator** → forward proxy. Works for *you*. Translates your words out, translates CEO's words back in.
- **CEO's secretary** → reverse proxy. Works for the *CEO's office*. Screens incoming calls, routes them to the right person.
- **The CEO** → backend server. Final destination.

Translators and secretaries don't switch jobs based on which way the conversation is flowing.

---

## 4. Web Server vs Application Server

| | Web Server (Nginx) | Application Server (Tomcat, Gunicorn, etc.) |
|---|---|---|
| **Job** | Serve static files, act as front door / reverse proxy | Run application code (Java, Python, etc.) |
| **Handles** | HTML, CSS, JS, images, SSL, routing | Business logic, DB queries, dynamic responses |
| **Examples** | Nginx, Apache HTTPD | Tomcat (Java), Gunicorn (Python), Node.js |

### How they work together

```
Client → Nginx (port 443, HTTPS) → Tomcat (port 8080, HTTP) → Database
```

- Nginx serves static files directly (`/static/logo.png` never reaches Tomcat).
- Nginx forwards dynamic requests (`/dashboard`) to Tomcat.
- Tomcat runs the code, talks to DB, returns the result.

### Restaurant analogy

- **Tomcat = the kitchen** → does the actual cooking (runs your code).
- **Nginx = the front desk + waiter** → greets customers, serves bread (static files), routes orders to the kitchen.
- You don't let customers walk into the kitchen directly. Same in production.

---

## 5. Is the App Server a Reverse Proxy When It Talks to the DB?

**No.** The app server is not a proxy of any kind.

### Why?

A proxy **forwards** traffic on someone's behalf. The app server doesn't forward — it:

1. **Originates** its own DB requests based on business logic.
2. **Consumes** the DB response (it's the final destination of that data).
3. **Transforms** the data into something completely different (HTML, JSON) before responding to the client.
4. Uses a **different protocol** (DB wire protocol, not HTTP).

### The rule

> **A proxy forwards. An application processes.**

Chef in the kitchen analogy: when the chef goes to the pantry for eggs, they're not "proxying" your order — they're independently deciding what they need to make your dish.

---

## 6. Why We Use a Reverse Proxy in Front of Backend Servers

Never expose application servers directly to the internet. Reasons:

1. **Security** — Nginx is hardened for the internet; Tomcat/Gunicorn aren't.
2. **Hide backend topology** — Attackers see one IP, not all your servers.
3. **SSL/TLS termination** — One place to manage HTTPS certificates.
4. **Load balancing** — Distribute traffic across multiple backends.
5. **Rate limiting / DDoS protection** — Block bad clients before they hit your backend.
6. **Centralized concerns** — Logging, auth, compression, caching in one place.

### Why can't we use a forward proxy instead?

A forward proxy lives on the **client side** — it represents the client. Putting it in front of your servers would be like asking your translator to screen the CEO's calls. Wrong tool for wrong role. They're not interchangeable — they're the same kind of middleman in two different positions.

---

## 7. Production Rule (lock this in too)

> **Never expose application servers directly to the internet. Always front them with a reverse proxy** (Nginx, AWS ALB, Kubernetes Ingress, CDN — they're all variations of the same idea).

This pattern is everywhere:

- **Kubernetes Ingress** → reverse proxy.
- **AWS ALB / NLB** → managed reverse proxy.
- **API Gateway** (Kong, AWS API Gateway) → reverse proxy + auth + rate limiting.
- **Service mesh sidecars** (Istio's Envoy) → tiny reverse proxy next to every service.
- **CDN** (CloudFront, Cloudflare) → distributed reverse proxy + caching.

When you meet any of these, ask: **"Whose side is this on? Who is it representing?"**

---

## 8. Common Pitfalls to Avoid

- ❌ Saying "Nginx vs Tomcat" — they do different jobs, they're not competitors.
- ❌ Thinking Nginx runs your code — it doesn't; it forwards to something that does.
- ❌ Confusing Apache HTTPD with Apache Tomcat — different products, same foundation.
- ❌ Forgetting to pass `X-Real-IP` / `X-Forwarded-For` headers — the backend will only see the proxy's IP otherwise.
- ❌ Thinking direction of traffic changes a proxy's identity — it doesn't. Role is fixed.
- ❌ Thinking the app server is a proxy because it "asks the DB" — no, it originates and processes.

---

## 9. One-Line Summaries

- **Proxy** = middleman that forwards requests on someone's behalf.
- **Forward proxy** = on the client side; represents the client.
- **Reverse proxy** = on the server side; represents the backend.
- **Web server (Nginx)** = front door; serves static files, forwards dynamic requests.
- **Application server (Tomcat, Gunicorn)** = runs your code.
- **App server is NOT a proxy** — it originates and processes, doesn't forward.
- **Production rule** = always put a reverse proxy in front of your backend.

---

## 10. What to Learn Next

1. Load balancing (natural extension of reverse proxies).
2. HTTPS / SSL termination (how certificates are handled at the proxy).
3. Kubernetes Ingress (this whole concept in cloud-native form).
4. DNS (the layer that comes before the proxy).

---

*Notes generated from our conversation. Refer back anytime.*