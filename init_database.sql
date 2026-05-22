-- ============================================================
-- Fintech DB Schema and Sample Data
-- ============================================================

DROP TABLE IF EXISTS card_transactions CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS merchant_categories CASCADE;

-- ------------------------------------------------------------
-- Reference: merchant categories
-- ------------------------------------------------------------
CREATE TABLE merchant_categories (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(120) NOT NULL
);

INSERT INTO merchant_categories (code, description) VALUES
  ('groceries',        'Supermarkets and grocery stores'),
  ('dining',           'Restaurants and food delivery'),
  ('fuel',             'Petrol stations and EV charging'),
  ('travel',           'Airlines, hotels, and car rentals'),
  ('entertainment',    'Cinema, streaming, events'),
  ('utilities',        'Electricity, water, internet bills'),
  ('health',           'Pharmacies, clinics, gyms'),
  ('retail',           'General merchandise and apparel'),
  ('education',        'Courses, books, subscriptions'),
  ('miscellaneous',    'Other transactions');

-- ------------------------------------------------------------
-- Accounts
-- ------------------------------------------------------------
CREATE TABLE accounts (
    id             SERIAL PRIMARY KEY,
    account_number VARCHAR(20)     NOT NULL UNIQUE,
    holder_name    VARCHAR(100)    NOT NULL,
    account_type   VARCHAR(20)     NOT NULL CHECK (account_type IN ('savings','current','premium')),
    created_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO accounts (account_number, holder_name, account_type) VALUES
  ('ACC-001', 'Arjun Mehta',       'premium'),
  ('ACC-002', 'Priya Nair',        'current'),
  ('ACC-003', 'Rohit Sharma',      'savings'),
  ('ACC-004', 'Sunita Rao',        'current'),
  ('ACC-005', 'Vikram Singh',      'premium'),
  ('ACC-006', 'Deepa Krishnan',    'savings'),
  ('ACC-007', 'Kiran Patel',       'current'),
  ('ACC-008', 'Ananya Iyer',       'premium'),
  ('ACC-009', 'Suresh Gupta',      'savings'),
  ('ACC-010', 'Meena Pillai',      'current');

-- ------------------------------------------------------------
-- Cards linked to accounts
-- ------------------------------------------------------------
CREATE TABLE cards (
    id          SERIAL PRIMARY KEY,
    account_id  INT          NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    card_number VARCHAR(20)  NOT NULL UNIQUE,
    card_type   VARCHAR(20)  NOT NULL CHECK (card_type IN ('debit','credit')),
    issued_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO cards (account_id, card_number, card_type) VALUES
  (1,  'CARD-1001', 'credit'),
  (1,  'CARD-1002', 'debit'),
  (2,  'CARD-2001', 'debit'),
  (3,  'CARD-3001', 'credit'),
  (3,  'CARD-3002', 'debit'),
  (4,  'CARD-4001', 'debit'),
  (5,  'CARD-5001', 'credit'),
  (6,  'CARD-6001', 'debit'),
  (7,  'CARD-7001', 'credit'),
  (8,  'CARD-8001', 'credit'),
  (8,  'CARD-8002', 'debit'),
  (9,  'CARD-9001', 'debit'),
  (10, 'CARD-9002', 'credit');

-- ------------------------------------------------------------
-- Card transactions  (main table — will be large)
-- ------------------------------------------------------------
CREATE TABLE card_transactions (
    id                  SERIAL PRIMARY KEY,
    account_id          INT             NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    card_id             INT             NOT NULL REFERENCES cards(id)    ON DELETE CASCADE,
    merchant_category   VARCHAR(50)     NOT NULL REFERENCES merchant_categories(code),
    merchant_name       VARCHAR(120)    NOT NULL,
    amount              NUMERIC(12, 2)  NOT NULL CHECK (amount > 0),
    currency            CHAR(3)         NOT NULL DEFAULT 'INR',
    posted_at           TIMESTAMPTZ     NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'settled' CHECK (status IN ('settled','pending','reversed'))
);

-- ------------------------------------------------------------
-- Seed ~150 000 transactions using generate_series
-- Distribution: accounts 1-10, cards mapped, random categories,
-- amounts between 50 and 25000, dates spread over last 120 days.
-- ------------------------------------------------------------
INSERT INTO card_transactions (
    account_id,
    card_id,
    merchant_category,
    merchant_name,
    amount,
    currency,
    posted_at,
    status
)
SELECT
    acc_id,
    card_id,
    category,
    merchant,
    amount,
    'INR',
    posted_at,
    status
FROM (
    SELECT
        (ARRAY[1,1,2,3,3,4,5,6,7,8,8,9,10])[
            1 + (FLOOR(RANDOM() * 13))::INT
        ]                                                          AS acc_id,
        (ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13])[
            1 + (FLOOR(RANDOM() * 13))::INT
        ]                                                          AS card_id,
        (ARRAY[
            'groceries','dining','fuel','travel','entertainment',
            'utilities','health','retail','education','miscellaneous'
        ])[1 + (FLOOR(RANDOM() * 10))::INT]                        AS category,
        (ARRAY[
            'BigBasket','Swiggy','HP Fuels','IndiGo','BookMyShow',
            'Tata Power','Apollo Pharmacy','Myntra','Coursera',
            'Amazon','Zomato','BPCL','MakeMyTrip','Netflix',
            'Airtel','Reliance Fresh','Decathlon','Udemy','Ola','Uber'
        ])[1 + (FLOOR(RANDOM() * 20))::INT]                        AS merchant,
        ROUND((50 + RANDOM() * 24950)::NUMERIC, 2)                 AS amount,
        NOW() - (RANDOM() * INTERVAL '120 days')                   AS posted_at,
        (ARRAY['settled','settled','settled','pending','reversed'])[
            1 + (FLOOR(RANDOM() * 5))::INT
        ]                                                          AS status
    FROM generate_series(1, 150000)
) subq
WHERE card_id BETWEEN 1 AND 13
  AND acc_id  BETWEEN 1 AND 10;

-- Ensure accounts 1-3 have a healthy number of recent rows
-- so performance differences are obvious during testing.
INSERT INTO card_transactions (
    account_id, card_id, merchant_category, merchant_name,
    amount, currency, posted_at, status
)
SELECT
    acct,
    CASE acct WHEN 1 THEN 1 WHEN 2 THEN 3 ELSE 4 END,
    (ARRAY[
        'groceries','dining','fuel','travel','entertainment',
        'utilities','health','retail','education','miscellaneous'
    ])[1 + (FLOOR(RANDOM() * 10))::INT],
    'SeedMerchant',
    ROUND((100 + RANDOM() * 4900)::NUMERIC, 2),
    'INR',
    NOW() - (RANDOM() * INTERVAL '30 days'),
    'settled'
FROM (
    SELECT acct FROM generate_series(1,3) AS acct,
                     generate_series(1,3000)
) s;

ANALYZE card_transactions;
