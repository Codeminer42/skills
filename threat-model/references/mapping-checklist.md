# Mapping checklist

What to look for in each area while mapping the system (step 4). Every finding needs a citation: file and function, or file and line for configuration.

Record what you find in two lists: **threat candidates** (something an actor could do) and **controls** (something that stops it, and where it stops). Both go into the model.

## Entry points

- Every route, grouped by guard or middleware stack. Note the routes with no authentication on purpose: login, password reset, invitations, webhooks, health checks, signed links.
- Webhooks: how the sender is authenticated (signature, shared secret, IP allowlist, nothing).
- Sockets and long-lived connections: how they authenticate after the handshake.
- Background jobs and scheduled tasks: who can enqueue them, and with what arguments.
- CLIs, consoles, admin panels, seed and migration scripts that run in deployed environments.

## Authentication and sessions

- How a session is created, stored, rotated and destroyed. Cookie flags (`HttpOnly`, `Secure`, `SameSite`).
- Password storage, reset tokens (lifetime, single use, bound to the account), invitation tokens.
- API tokens: where they are stored, whether they are hashed, whether they expire, who can create them.
- More than one guard or login (customer app, staff app): can an account of one kind open a session in the other?
- CSRF and Origin checks for cookie-based sessions. CORS configuration.

## Authorization

- Where permissions are checked: middleware, policies, services, queries.
- **Early returns** that skip the check: `isAdmin`, `isSuperuser`, `isStaff`, feature flags, "internal" roles.
- Permissions the UI checks but the server doesn't. Compare the list of declared permissions with the ones the server actually checks.
- Tenant scoping: is every query that reads tenant data scoped by tenant, or does it rely on the caller passing the right ID?
- Object-level access: can a user read or change a record by guessing its ID?
- Who can grant roles, and whether a user can grant a role higher than their own.

## Data stores

- What each store holds: database, cache, queue, search index, object storage.
- **Who else writes it.** Other apps, legacy systems, devices, payment providers, ETL jobs. Every table another system writes is input.
- Which database user the app connects with, and what else that user can reach.
- Secrets or tokens stored in tables, and who can read them.
- Personal data: which tables, which fields, and whether logs or exports copy it.

## Outbound integrations

- Each external system called: payment, devices, email, SMS, storage, AI providers, third-party APIs.
- How each call authenticates, and where the credential comes from.
- Transport: TLS, plain TCP, internal network.
- What the system trusts in the response, and what happens when the response is late, wrong or missing.
- Callbacks from the integration back into the system (see Webhooks).

## Files and media

- Uploads: size limits, type checks, where they are stored, whether they are served from the app's origin.
- Signed links: lifetime, who can generate one, whether it can be shared.
- Who can read which files, and whether the check happens on the server.
- Processing of uploaded files (images, PDFs, archives) by libraries with a history of vulnerabilities.

## Secrets and configuration

- Where secrets come from: environment, secret manager, files, database rows.
- Secrets committed to the repository, in history or in example files.
- Secrets shared with other systems: one compromise opens both.
- Debug flags, verbose errors and stack traces in deployed environments.

## Build and deploy

- CI: which actions or orbs run, whether they are pinned to a SHA, which secrets each job sees, whether pull requests from forks can reach them.
- Package registries, including private ones, and lockfiles.
- Who can deploy, and from where. Configuration kept outside the repository (hosting dashboards, cloud consoles): say it is not visible from here.
- Container images: base image, user, what is copied in.

## Logging and audit

- What is logged for security-relevant actions: sign-in, role changes, money movement, physical actions, data exports.
- Whether logs can be changed or deleted by the actor they record.
- Personal data or secrets written to logs.
