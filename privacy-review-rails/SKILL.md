---
name: privacy-review-rails
description: Review uncommitted or recently changed files for privacy-by-design rule violations (based on privacy laws like GDPR and LGPD) before committing.
license: MIT
metadata:
  author: talyssonoc
  version: "1.0"
allowed-tools: Bash, Read, Glob, Grep, Edit
---

# Check Privacy — Review Changed Files

## Prerequisite

Dependency path: !`test -d "${CLAUDE_SKILL_DIR}/../privacy-by-design-rails" && echo "${CLAUDE_SKILL_DIR}/../privacy-by-design-rails" || echo "NOT_FOUND"`

If the dependency path above is `NOT_FOUND`, stop and tell the user:

> This skill depends on **privacy-by-design-rails**, which is not installed.
> Install it with: `npx skills add codeminer42/skills --skill privacy-by-design-rails`
> (add `-g` for global installation)

Do not proceed until the dependency is installed.

## Step 1: Scan Changed Files + Related Files

If `ruby` is not found when running the command below, ask the user how to run Ruby in their environment instead of trying to resolve it yourself.

Run the scanner in `--changed-only` mode. This scans the changed files AND automatically pulls in related files (e.g., a changed migration pulls in its model and `filter_parameter_logging.rb`; a changed mailer template pulls in its mailer class):

```bash
ruby ${CLAUDE_SKILL_DIR}/../privacy-by-design-rails/scripts/scanner.rb --changed-only
```

Parse the JSON output. It includes:
- **`changed_files`** — files the developer actually modified
- **`related_files`** — files pulled in for context (not changed, but affected by the changes)
- **`findings`** — scanner findings across both changed and related files
- **`checklist`** — privacy checklist status

If `changed_files` is empty, tell the user there are no privacy-relevant changes and stop.

## Step 2: Deep-Dive on Changed Files

The scanner catches mechanical violations. Now verify the findings and check for things the scanner can't detect. For each **changed file**, apply the relevant checks from `${CLAUDE_SKILL_DIR}/../privacy-by-design-rails/references/pii-definition.md` and the rules in `${CLAUDE_SKILL_DIR}/../privacy-by-design-rails/rules/`:

### For changed models:
- **PII classification:** Read the model and its schema columns. Apply the Mandatory Classification Rules (Rules 1-4) from `references/pii-definition.md` to classify every column. Don't just rely on the scanner's pattern matching — check for domain-specific fields with non-standard names.
- **Encryption:** Does every PII column have `encrypts`?
- **filter_attributes:** Does the model declare `self.filter_attributes` listing all its PII fields?
- **ransackable_attributes:** If the model defines `ransackable_attributes`, are sensitive fields (encrypted_password, reset_password_token) or PII fields exposed?

### For changed migrations:
- Read the corresponding model (from `related_files`) to check if `encrypts` declarations exist for new PII columns.
- Check if `config/initializers/filter_parameter_logging.rb` (from `related_files`) includes the new PII field names.

### For changed mailers/templates:
- Check `from:` addresses for PII (user emails as sender).
- Check subject lines for PII (names, emails visible in inbox previews).
- Check template bodies: distinguish emails sent to OTHER users (violation) vs emails sent to the data subject themselves (acceptable — note with justification).

### For changed jobs/workers:
- Does the base class (`ApplicationJob`) set `self.log_arguments = false`?
- Do `perform` parameters pass PII data instead of record IDs?

### For changed controllers:
- Is `session[...]` assigned a full ActiveRecord object instead of just an ID?
- Do `render json:` responses include PII that shouldn't be exposed?

### For changed initializers:
- If it configures an error reporter (Rollbar, Sentry, Bugsnag): are `scrub_fields` configured? Is `anonymize_user_ip` enabled? Are `person_*_method` settings restricted to ID only?

### For changed services:
- Does the service send data to an external API? If so, does the payload include PII?

## Step 3: Report

Group verified violations by severity (**CRITICAL > HIGH > MEDIUM**). For each violation:
- **Location:** `file:line`
- **What's wrong:** clear description
- **Correct pattern:** code example from the relevant rule in `${CLAUDE_SKILL_DIR}/../privacy-by-design-rails/rules/`
- **Changed vs related:** note whether the violation is in a changed file (developer should fix) or a related file (pre-existing issue exposed by the change)

For scanner findings you verified as false positives, briefly explain why you dismissed them.

If no violations, tell the user their changes look privacy-compliant.

## Step 4: Offer to Fix

Ask the user if they want fixes applied. Apply unambiguous fixes directly; ask about ambiguous ones (e.g., deterministic vs non-deterministic encryption, whether a field is genuinely PII).
