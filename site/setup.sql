-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.admins (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  email text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admins_pkey PRIMARY KEY (id)
);
CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  company_name text NOT NULL,
  contact_name text,
  phone text,
  email text,
  city text,
  address text,
  tax_office text,
  tax_id text,
  status text DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'passive'::text])),
  created_at timestamp with time zone DEFAULT now(),
  hardware_id text,
  ip_address text,
  installation_date timestamp with time zone,
  trial_days_used integer DEFAULT 0,
  CONSTRAINT customers_pkey PRIMARY KEY (id)
);
CREATE TABLE public.demo_users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  company_name text,
  contact_name text,
  phone text,
  email text,
  start_date timestamp with time zone DEFAULT now(),
  ip_address text,
  status text DEFAULT 'active'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT demo_users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.languages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  short_code text NOT NULL,
  locale_code text NOT NULL,
  direction text DEFAULT 'ltr'::text CHECK (direction = ANY (ARRAY['ltr'::text, 'rtl'::text])),
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  is_default boolean DEFAULT false,
  is_system boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT languages_pkey PRIMARY KEY (id)
);
CREATE TABLE public.licenses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  package_name text NOT NULL,
  license_key text NOT NULL UNIQUE,
  start_date date NOT NULL,
  end_date date NOT NULL,
  hardware_id text,
  modules jsonb DEFAULT '[]'::jsonb,
  type text CHECK (type = ANY (ARRAY['Aylık'::text, 'Yıllık'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT licenses_pkey PRIMARY KEY (id),
  CONSTRAINT licenses_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id)
);
CREATE TABLE public.program_deneme (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  hardware_id text NOT NULL UNIQUE,
  license_id text DEFAULT upper(encode(gen_random_bytes(4), 'hex')),
  ip_address text,
  city text,
  install_date timestamp with time zone DEFAULT now(),
  last_activity timestamp with time zone DEFAULT now(),
  days_used integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  is_online boolean DEFAULT false,
  last_heartbeat timestamp with time zone DEFAULT now(),
  machine_name text,
  trial_start_date timestamp with time zone,
  trial_total_days integer DEFAULT 45,
  trial_type text DEFAULT 'trial'::text CHECK (trial_type = ANY (ARRAY['trial'::text, 'grace'::text])),
  status text DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'converted'::text])),
  CONSTRAINT program_deneme_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  transaction_date timestamp with time zone DEFAULT now(),
  type text,
  description text,
  payment_channel text,
  amount numeric NOT NULL,
  status text DEFAULT 'completed'::text CHECK (status = ANY (ARRAY['completed'::text, 'pending'::text, 'failed'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id)
);
CREATE TABLE public.translations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  language_id uuid,
  phrase_key text NOT NULL,
  translation_value text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT translations_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(id)
);

CREATE TABLE public.lite_settings (
  id integer PRIMARY KEY CHECK (id = 1),
  max_current_accounts integer DEFAULT 50,
  max_daily_transactions integer DEFAULT 20,
  max_daily_retail_sales integer DEFAULT 50,
  report_days_limit integer DEFAULT 30,
  is_bank_credit_active boolean DEFAULT false,
  is_check_promissory_active boolean DEFAULT false,
  is_cloud_backup_active boolean DEFAULT false,
  is_excel_export_active boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now()
);

-- Insert initial settings row
INSERT INTO public.lite_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.user_db_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  mode text NOT NULL CHECK (mode IN ('local', 'hybrid', 'cloud')),
  supabase_url text,
  supabase_anon_key text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
