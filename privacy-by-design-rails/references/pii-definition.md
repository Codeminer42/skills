---
title: What Counts as Personal Data (PII)
description: Official definitions from GDPR, LGPD, and NIST. Use this as the authoritative reference when deciding if a field is PII.
---

# What Counts as Personal Data (PII)

## The Core Principle: Direct OR Indirect Identification

All three major frameworks agree: personal data is **any information that relates to a person who can be identified, directly or indirectly**.

The word **indirectly** is critical. A piece of data does not need to identify someone on its own — if it can be **combined with other available information** to identify a person, it is personal data.

## Official Definitions

### GDPR — Article 4(1)

> "Personal data" means any information relating to an identified or **identifiable** natural person; an identifiable natural person is one who can be identified, **directly or indirectly**, in particular by reference to an identifier such as a name, an identification number, location data, an online identifier or to one or more factors specific to the physical, physiological, genetic, mental, economic, cultural or social identity of that natural person.

### LGPD (Brazil) — Article 5(I) and 5(II)

> **Personal data:** information related to an identified or **identifiable** natural person.
>
> **Sensitive personal data:** personal data on racial or ethnic origin, religious conviction, political opinion, union affiliation or religious, philosophical or political organization, health or sexual life data, genetic or biometric data, when linked to a natural person.

### NIST SP 800-122 / SP 800-188

> PII is information that can be used to distinguish or trace an individual's identity, **either alone or when combined with other information** that is linked or linkable to a specific individual.

NIST distinguishes two categories:
- **Directly identifiable:** name, SSN, biometric records, date/place of birth
- **Linked or linkable:** medical, educational, financial, employment information — not identifying alone, but identifying when combined with other data

## Applying This to Code: The Linkability Test

When deciding if a database field is PII, ask:

**"Could this value, combined with other reasonably available information, identify a specific person?"**

If yes → treat it as PII. If genuinely no → not PII.

### Examples of indirect/linkable PII

| Field | Seems non-personal? | But consider... | PII? |
|-------|---------------------|-----------------|------|
| `farm_name` | It's a place, not a person | In rural areas, farms are closely associated with specific families. A well-known farm name identifies its owner. | **Yes** — linkable to an identifiable person |
| `animal_name` | It's an animal, not a person | Famous breeding animals (racehorses, prize bulls) are publicly associated with their owners. "Animal X belongs to Owner Y" is public knowledge in the industry. | **Context-dependent** — PII if the animal-owner link is publicly known or stored in the same system |
| `company_name` | It's a business entity | Sole proprietorships and small businesses are synonymous with their owner. | **Yes** for sole proprietors; **context-dependent** for larger companies |
| `ip_address` | It's a machine identifier | GDPR Recital 30 explicitly classifies IP addresses as online identifiers that can identify natural persons. | **Yes** |
| `device_id` | It's a device, not a person | Devices are used by people. Device IDs linked to user accounts are PII. | **Yes** when linked to a user |
| `employee_id` | It's just a number | It directly maps to one person within the organization. | **Yes** |
| `vehicle_plate` | It's a vehicle identifier | Registration databases link plates to owners. | **Yes** |
| `vehicle_vin` | It's a manufacturer serial | VIN registries and insurance records link VINs to owners. | **Yes** |
| `order_id` | It's a transaction | If orders are linked to users (and they almost always are), the order ID is linkable PII. | **Yes** when linked to a user |
| `student_id` | It's a school number | Directly maps to one person within the institution. | **Yes** |
| `property_address` | It's a location | Residential addresses identify who lives there via public records. | **Yes** |
| `social_media_handle` | It's a username | Public profiles link handles to real identities. | **Yes** |
| `phone_imei` | It's a hardware serial | Telecom records link IMEIs to subscribers. | **Yes** |
| `medical_record_number` | It's a clinical ID | Directly maps to a patient. | **Yes** |
| `tax_id` / `cpf` / `cnpj` | It's a government number | Directly identifies a person or sole proprietor. | **Yes** |
| `biometric_hash` | It's a derived value | Even hashed biometrics are PII — the biometric source is inherently personal. | **Yes** |
| `geolocation` (lat/lng) | It's coordinates | Home/work locations identify residents. Repeated patterns reveal identity. | **Yes** |
| `cookie_id` / `tracking_id` | It's an anonymous token | When linked to browsing history or accounts, it identifies a person. GDPR Recital 30 covers online identifiers. | **Yes** when linked to a user |
| `salary` / `income` | It's a number | Financial data linked to an employee or user record is PII. | **Yes** when linked to a person |

### The "same system" rule

If your application stores both the potentially-identifying field AND the person it could identify, assume linkability. For example, if your database has both a `bulls` table with `name` and an `owners` table linked via `owner_id`, then `bulls.name` is linkable to the owner through a simple join.

## Mandatory Classification Rules

When performing a privacy assessment, apply these rules **in order** to every column flagged by the scanner or found during manual review.

### Rule 1: Universal PII identifiers (always PII, any jurisdiction)

The following column names are **always PII** regardless of context or market:

**Personal identifiers:** `name`, `first_name`, `last_name`, `full_name`, `email`, `email_address`, `phone`, `phone_number`, `mobile`, `date_of_birth`, `birthday`, `dob`, `ip_address`, `current_sign_in_ip`, `last_sign_in_ip`

**Addresses:** `address`, `full_address`, `street`, `zip_code`, `postal_code`. Note: `city`, `state`, `neighborhood` are PII when on a person model but not when on a location/office model.

**Financial data (when linked to a person):** `salary`, `income`, `hourly_rate`, `wage`, `credit_card`, `card_number`, `cvv`, `bank_account`, `account_number`, `iban`

**Government IDs (generic):** `national_id`, `national_id_number`, `tax_id`, `passport`, `passport_number`, `driver_license`, `social_security`, `ssn`, `identity_number`

**Exception:** A column named `name` on a model that represents a non-person entity (e.g., `Product.name`, `Role.name`, `Technology.name`) is NOT PII — but only if the model has **no direct or indirect association** to a person model. If it does have such an association, apply Rule 2.

### Rule 1b: Market-specific PII identifiers (from dynamic lookup)

During Step 2a of the assessment, you will perform a web search for government document types and PII-specific identifiers for the markets the application serves (as provided by the user in Step 0). The results of that search produce an additional list of column name patterns to check. For example:

- A Brazilian app might add: `cpf`, `rg`, `pis`, `cnh`, `cnpj`, `pix`, `cep`, `titulo_eleitor`
- A UK app might add: `nino`, `nhs_number`, `sort_code`
- A US app might add: `ein`, `itin`, `state_id`, `dl_number`, `routing_number`
- A German app might add: `personalausweisnummer`, `steuer_id`, `sozialversicherungsnummer`

These are discovered dynamically — not hardcoded here — because government document types vary by country and change over time. The web search step (in assessment-reference.md, section A2b) is the authoritative source.

### Rule 2: Same-system linkability (mandatory)

If a model has a `belongs_to`, `has_many`, `has_one`, or `has_many :through` relationship (direct or indirect) with a model that stores person names or emails, then **any identifying field on that model is PII**.

Apply this transitively: if Model A belongs_to Model B (through a join table), and Model B has `name` (a person's name), then identifying fields on Model A are linkable PII.

**Domain-specific identifiers** that uniquely map to a person or entity linked to a person — such as external system codes, internal reference numbers, or business-specific IDs — are PII under this rule when both the identifier and the person's identity exist in the same database. When in doubt about a domain-specific identifier, apply the linkability test: can this value be joined with other data in this system to identify a natural person? If yes, treat it as PII.

This is **not optional** — do not dismiss fields as "entity names" or "reference codes" if the same-system linkability rule applies.

### Rule 3: Organizational identifiers

Company tax IDs (e.g., CNPJ in Brazil, EIN in US, VAT number in EU), company `name`, and organization `address` fields are PII when **any** of:
- The organization model also stores individual person data (e.g., `legal_representative_name`, `owner_name`, `contact_email`)
- The organization is a sole proprietorship, freelancer, or small entity where the identifier maps to one person
- The organization model has associations to person models

### Rule 4: When still uncertain — flag as PII

If a field doesn't clearly fall under Rules 1-3 but could plausibly be PII, **flag it as a finding** with a note in the description explaining the edge case. Over-reporting is acceptable; under-reporting is not.

## When in Doubt

**Treat it as PII.** The cost of encrypting a non-PII field is negligible. The cost of leaving actual PII unencrypted is a compliance violation.

## References

- GDPR Article 4: https://gdpr-info.eu/art-4-gdpr/
- GDPR Recital 26 (identifiability): https://gdpr-info.eu/recitals/no-26/
- GDPR Recital 30 (online identifiers): https://gdpr-info.eu/recitals/no-30/
- LGPD Article 5: https://lgpd-brazil.info/chapter_01/article_05
- NIST SP 800-122: https://csrc.nist.gov/pubs/sp/800/122/final
