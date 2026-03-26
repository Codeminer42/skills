# utils/pii_patterns.rb

module PiiPatterns
  # Universal PII field patterns — applies to all markets
  UNIVERSAL = %w[
    email
    email_address
    name
    first_name
    last_name
    full_name
    phone
    phone_number
    telephone
    mobile
    cell
    address
    street
    city
    zip
    zip_code
    postal
    ssn
    social_security
    national_id
    date_of_birth
    birthday
    dob
    birth_date
    ip_address
    ip
    passport
    driver_license
    credit_card
    card_number
    cvv
  ].freeze

  # Market-specific PII patterns
  MARKET_PATTERNS = {
    br: %w[
      cpf cnpj rg rg_issuer pis pasep cnh pix cep
      titulo_eleitor certidao cns
      identity_number identity_issuing_body
    ],

    eu: %w[
      nino nhs_number sort_code iban bic vat_number
      personalausweisnummer steuer_id bsn
    ],

    us: %w[
      ein itin state_id dl_number routing_number
    ]
  }.freeze

  # Fields handled by bcrypt — not PII columns to encrypt
  BCRYPT_FIELDS = %w[password password_digest].freeze

  # Exact matches on UNIVERSAL are high confidence
  HIGH_CONFIDENCE = UNIVERSAL.to_set.freeze

  # Returns all applicable patterns for the given markets
  def self.all_patterns(markets: [])
    patterns = UNIVERSAL.dup

    markets.each do |market|
      key = market.to_s.downcase.to_sym
      patterns.concat(MARKET_PATTERNS.fetch(key, []))
    end

    patterns.uniq
  end

  # Checks if a field name matches any PII pattern
  def self.pii_field?(name, markets: [])
    return false if BCRYPT_FIELDS.include?(name)

    all_patterns(markets: markets).any? do |pattern|
      name == pattern ||
        name.end_with?("_#{pattern}") ||
        name.start_with?("#{pattern}_")
    end
  end

  # Returns confidence level for a field name
  def self.pii_confidence(name)
    HIGH_CONFIDENCE.include?(name) ? "high" : "medium"
  end
end
