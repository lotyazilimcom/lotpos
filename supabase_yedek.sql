--
-- PostgreSQL database dump
--

\restrict iJoqUHvkf7KrWlgQ76nNvmdmm23ycghBbsJesV1Mr3Xuzzn8ZhZwWGHPjx2X3KQ

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.1 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP EVENT TRIGGER IF EXISTS "pgrst_drop_watch";
DROP EVENT TRIGGER IF EXISTS "pgrst_ddl_watch";
DROP EVENT TRIGGER IF EXISTS "issue_pg_net_access";
DROP EVENT TRIGGER IF EXISTS "issue_pg_graphql_access";
DROP EVENT TRIGGER IF EXISTS "issue_pg_cron_access";
DROP EVENT TRIGGER IF EXISTS "issue_graphql_placeholder";
DROP PUBLICATION IF EXISTS "supabase_realtime";
ALTER TABLE IF EXISTS ONLY "storage"."vector_indexes" DROP CONSTRAINT IF EXISTS "vector_indexes_bucket_id_fkey";
ALTER TABLE IF EXISTS ONLY "storage"."s3_multipart_uploads_parts" DROP CONSTRAINT IF EXISTS "s3_multipart_uploads_parts_upload_id_fkey";
ALTER TABLE IF EXISTS ONLY "storage"."s3_multipart_uploads_parts" DROP CONSTRAINT IF EXISTS "s3_multipart_uploads_parts_bucket_id_fkey";
ALTER TABLE IF EXISTS ONLY "storage"."s3_multipart_uploads" DROP CONSTRAINT IF EXISTS "s3_multipart_uploads_bucket_id_fkey";
ALTER TABLE IF EXISTS ONLY "storage"."objects" DROP CONSTRAINT IF EXISTS "objects_bucketId_fkey";
ALTER TABLE IF EXISTS ONLY "public"."quick_products" DROP CONSTRAINT IF EXISTS "quick_products_product_id_fkey";
ALTER TABLE IF EXISTS ONLY "public"."product_devices" DROP CONSTRAINT IF EXISTS "product_devices_product_id_fkey";
ALTER TABLE IF EXISTS ONLY "public"."production_recipe_items" DROP CONSTRAINT IF EXISTS "fk_production";
ALTER TABLE IF EXISTS ONLY "public"."expense_items" DROP CONSTRAINT IF EXISTS "expense_items_expense_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."sso_domains" DROP CONSTRAINT IF EXISTS "sso_domains_sso_provider_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."sessions" DROP CONSTRAINT IF EXISTS "sessions_user_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."sessions" DROP CONSTRAINT IF EXISTS "sessions_oauth_client_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_relay_states" DROP CONSTRAINT IF EXISTS "saml_relay_states_sso_provider_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_relay_states" DROP CONSTRAINT IF EXISTS "saml_relay_states_flow_state_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_providers" DROP CONSTRAINT IF EXISTS "saml_providers_sso_provider_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."refresh_tokens" DROP CONSTRAINT IF EXISTS "refresh_tokens_session_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."one_time_tokens" DROP CONSTRAINT IF EXISTS "one_time_tokens_user_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_consents" DROP CONSTRAINT IF EXISTS "oauth_consents_user_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_consents" DROP CONSTRAINT IF EXISTS "oauth_consents_client_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_authorizations" DROP CONSTRAINT IF EXISTS "oauth_authorizations_user_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_authorizations" DROP CONSTRAINT IF EXISTS "oauth_authorizations_client_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_factors" DROP CONSTRAINT IF EXISTS "mfa_factors_user_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_challenges" DROP CONSTRAINT IF EXISTS "mfa_challenges_auth_factor_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_amr_claims" DROP CONSTRAINT IF EXISTS "mfa_amr_claims_session_id_fkey";
ALTER TABLE IF EXISTS ONLY "auth"."identities" DROP CONSTRAINT IF EXISTS "identities_user_id_fkey";
DROP TRIGGER IF EXISTS "update_objects_updated_at" ON "storage"."objects";
DROP TRIGGER IF EXISTS "protect_objects_delete" ON "storage"."objects";
DROP TRIGGER IF EXISTS "protect_buckets_delete" ON "storage"."buckets";
DROP TRIGGER IF EXISTS "enforce_bucket_name_length_trigger" ON "storage"."buckets";
DROP TRIGGER IF EXISTS "tr_check_filters" ON "realtime"."subscription";
DROP TRIGGER IF EXISTS "trg_update_products_metadata" ON "public"."products";
DROP TRIGGER IF EXISTS "trg_update_products_count" ON "public"."products";
DROP TRIGGER IF EXISTS "trg_update_productions_search_tags" ON "public"."productions";
DROP TRIGGER IF EXISTS "trg_update_productions_metadata" ON "public"."productions";
DROP TRIGGER IF EXISTS "trg_update_productions_count" ON "public"."productions";
DROP TRIGGER IF EXISTS "trg_update_depots_search_tags" ON "public"."depots";
DROP TRIGGER IF EXISTS "trg_update_credit_card_search_tags" ON "public"."credit_card_transactions";
DROP TRIGGER IF EXISTS "trg_update_cash_register_search_tags" ON "public"."cash_register_transactions";
DROP TRIGGER IF EXISTS "trg_update_bank_search_tags" ON "public"."bank_transactions";
DROP TRIGGER IF EXISTS "trg_update_account_metadata" ON "public"."current_accounts";
DROP TRIGGER IF EXISTS "trg_cat_refresh_search_tags" ON "public"."current_account_transactions";
DROP INDEX IF EXISTS "storage"."vector_indexes_name_bucket_id_idx";
DROP INDEX IF EXISTS "storage"."name_prefix_search";
DROP INDEX IF EXISTS "storage"."idx_objects_bucket_id_name_lower";
DROP INDEX IF EXISTS "storage"."idx_objects_bucket_id_name";
DROP INDEX IF EXISTS "storage"."idx_multipart_uploads_list";
DROP INDEX IF EXISTS "storage"."buckets_analytics_unique_name_idx";
DROP INDEX IF EXISTS "storage"."bucketid_objname";
DROP INDEX IF EXISTS "storage"."bname";
DROP INDEX IF EXISTS "realtime"."subscription_subscription_id_entity_filters_action_filter_key";
DROP INDEX IF EXISTS "realtime"."messages_inserted_at_topic_index";
DROP INDEX IF EXISTS "realtime"."ix_realtime_subscription_entity";
DROP INDEX IF EXISTS "public"."idx_warehouse_stocks_wid";
DROP INDEX IF EXISTS "public"."idx_warehouse_stocks_pcode";
DROP INDEX IF EXISTS "public"."idx_ut_user_id";
DROP INDEX IF EXISTS "public"."idx_ut_type";
DROP INDEX IF EXISTS "public"."idx_ut_date_brin";
DROP INDEX IF EXISTS "public"."idx_sync_outbox_status";
DROP INDEX IF EXISTS "public"."idx_sm_warehouse_id";
DROP INDEX IF EXISTS "public"."idx_sm_shipment_id";
DROP INDEX IF EXISTS "public"."idx_sm_ref";
DROP INDEX IF EXISTS "public"."idx_sm_product_id";
DROP INDEX IF EXISTS "public"."idx_sm_date_brin";
DROP INDEX IF EXISTS "public"."idx_sm_date";
DROP INDEX IF EXISTS "public"."idx_sm_created_at_brin";
DROP INDEX IF EXISTS "public"."idx_shipments_source_id";
DROP INDEX IF EXISTS "public"."idx_shipments_items_gin";
DROP INDEX IF EXISTS "public"."idx_shipments_dest_id";
DROP INDEX IF EXISTS "public"."idx_shipments_description_trgm";
DROP INDEX IF EXISTS "public"."idx_shipments_date";
DROP INDEX IF EXISTS "public"."idx_shipments_created_by_trgm";
DROP INDEX IF EXISTS "public"."idx_saved_descriptions_search";
DROP INDEX IF EXISTS "public"."idx_recipe_production_id";
DROP INDEX IF EXISTS "public"."idx_recipe_product_code";
DROP INDEX IF EXISTS "public"."idx_quotes_tarih";
DROP INDEX IF EXISTS "public"."idx_quotes_integration_ref";
DROP INDEX IF EXISTS "public"."idx_quote_items_quote_id";
DROP INDEX IF EXISTS "public"."idx_psm_warehouse_id";
DROP INDEX IF EXISTS "public"."idx_psm_related_shipments_gin";
DROP INDEX IF EXISTS "public"."idx_psm_production_id";
DROP INDEX IF EXISTS "public"."idx_psm_date";
DROP INDEX IF EXISTS "public"."idx_psm_created_at_brin";
DROP INDEX IF EXISTS "public"."idx_products_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_products_kod_trgm";
DROP INDEX IF EXISTS "public"."idx_products_kod_btree";
DROP INDEX IF EXISTS "public"."idx_products_kdv_btree";
DROP INDEX IF EXISTS "public"."idx_products_grubu_btree";
DROP INDEX IF EXISTS "public"."idx_products_created_by";
DROP INDEX IF EXISTS "public"."idx_products_created_at_brin";
DROP INDEX IF EXISTS "public"."idx_products_birim_btree";
DROP INDEX IF EXISTS "public"."idx_products_barkod_trgm";
DROP INDEX IF EXISTS "public"."idx_products_barkod_btree";
DROP INDEX IF EXISTS "public"."idx_products_aktif_btree";
DROP INDEX IF EXISTS "public"."idx_products_ad_trgm";
DROP INDEX IF EXISTS "public"."idx_productions_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_productions_ozellikler_trgm";
DROP INDEX IF EXISTS "public"."idx_productions_kullanici_trgm";
DROP INDEX IF EXISTS "public"."idx_productions_kod_trgm";
DROP INDEX IF EXISTS "public"."idx_productions_kod_btree";
DROP INDEX IF EXISTS "public"."idx_productions_kdv_btree";
DROP INDEX IF EXISTS "public"."idx_productions_grubu_btree";
DROP INDEX IF EXISTS "public"."idx_productions_created_by";
DROP INDEX IF EXISTS "public"."idx_productions_birim_btree";
DROP INDEX IF EXISTS "public"."idx_productions_barkod_trgm";
DROP INDEX IF EXISTS "public"."idx_productions_aktif_btree";
DROP INDEX IF EXISTS "public"."idx_productions_ad_trgm";
DROP INDEX IF EXISTS "public"."idx_pd_product_id";
DROP INDEX IF EXISTS "public"."idx_pd_identity_value";
DROP INDEX IF EXISTS "public"."idx_orders_tarih";
DROP INDEX IF EXISTS "public"."idx_orders_integration_ref";
DROP INDEX IF EXISTS "public"."idx_order_items_order_id";
DROP INDEX IF EXISTS "public"."idx_notes_type";
DROP INDEX IF EXISTS "public"."idx_notes_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_notes_ref";
DROP INDEX IF EXISTS "public"."idx_notes_note_no_trgm";
DROP INDEX IF EXISTS "public"."idx_notes_issue_date_brin";
DROP INDEX IF EXISTS "public"."idx_notes_is_active";
DROP INDEX IF EXISTS "public"."idx_notes_due_date_brin";
DROP INDEX IF EXISTS "public"."idx_notes_customer_name_trgm";
DROP INDEX IF EXISTS "public"."idx_notes_company_id";
DROP INDEX IF EXISTS "public"."idx_note_transactions_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_note_transactions_note_id";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_default_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2031_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2030_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2029_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2028_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2027_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2026_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2025_basic";
DROP INDEX IF EXISTS "public"."idx_kasa_trans_2024_basic";
DROP INDEX IF EXISTS "public"."idx_installments_ref";
DROP INDEX IF EXISTS "public"."idx_installments_cari";
DROP INDEX IF EXISTS "public"."idx_expenses_tarih_brin";
DROP INDEX IF EXISTS "public"."idx_expenses_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_expenses_odeme_durumu_btree";
DROP INDEX IF EXISTS "public"."idx_expenses_kullanici_btree";
DROP INDEX IF EXISTS "public"."idx_expenses_kod_trgm";
DROP INDEX IF EXISTS "public"."idx_expenses_kategori_btree";
DROP INDEX IF EXISTS "public"."idx_expenses_baslik_trgm";
DROP INDEX IF EXISTS "public"."idx_expenses_aktif_btree";
DROP INDEX IF EXISTS "public"."idx_expense_items_expense_id";
DROP INDEX IF EXISTS "public"."idx_depots_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_depots_kod_trgm";
DROP INDEX IF EXISTS "public"."idx_depots_kod_btree";
DROP INDEX IF EXISTS "public"."idx_depots_ad_trgm";
DROP INDEX IF EXISTS "public"."idx_currency_rates_pair";
DROP INDEX IF EXISTS "public"."idx_credit_cards_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_cheques_type";
DROP INDEX IF EXISTS "public"."idx_cheques_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_cheques_ref";
DROP INDEX IF EXISTS "public"."idx_cheques_issue_date_brin";
DROP INDEX IF EXISTS "public"."idx_cheques_is_active";
DROP INDEX IF EXISTS "public"."idx_cheques_due_date_brin";
DROP INDEX IF EXISTS "public"."idx_cheques_customer_name_trgm";
DROP INDEX IF EXISTS "public"."idx_cheques_company_id";
DROP INDEX IF EXISTS "public"."idx_cheques_check_no_trgm";
DROP INDEX IF EXISTS "public"."idx_cheque_transactions_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_cheque_transactions_cheque_id";
DROP INDEX IF EXISTS "public"."idx_cash_registers_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_cash_registers_name_trgm";
DROP INDEX IF EXISTS "public"."idx_cash_registers_code_trgm";
DROP INDEX IF EXISTS "public"."idx_banks_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_accounts_type_btree";
DROP INDEX IF EXISTS "public"."idx_accounts_search_tags_gin";
DROP INDEX IF EXISTS "public"."idx_accounts_kod_trgm";
DROP INDEX IF EXISTS "public"."idx_accounts_kod_btree";
DROP INDEX IF EXISTS "public"."idx_accounts_created_at_covering";
DROP INDEX IF EXISTS "public"."idx_accounts_created_at_btree";
DROP INDEX IF EXISTS "public"."idx_accounts_city_btree";
DROP INDEX IF EXISTS "public"."idx_accounts_aktif_btree";
DROP INDEX IF EXISTS "public"."idx_accounts_ad_trgm";
DROP INDEX IF EXISTS "public"."idx_cct_type";
DROP INDEX IF EXISTS "public"."idx_cct_integration_ref";
DROP INDEX IF EXISTS "public"."idx_cct_date";
DROP INDEX IF EXISTS "public"."idx_cct_credit_card_id";
DROP INDEX IF EXISTS "public"."idx_cct_created_at";
DROP INDEX IF EXISTS "public"."idx_cat_ref";
DROP INDEX IF EXISTS "public"."idx_cat_date_brin";
DROP INDEX IF EXISTS "public"."idx_cat_date_btree";
DROP INDEX IF EXISTS "public"."idx_cat_account_id";
DROP INDEX IF EXISTS "public"."idx_crt_type";
DROP INDEX IF EXISTS "public"."idx_crt_integration_ref";
DROP INDEX IF EXISTS "public"."idx_crt_date";
DROP INDEX IF EXISTS "public"."idx_crt_created_at_brin";
DROP INDEX IF EXISTS "public"."idx_crt_created_at";
DROP INDEX IF EXISTS "public"."idx_crt_cash_register_id";
DROP INDEX IF EXISTS "public"."idx_bt_type";
DROP INDEX IF EXISTS "public"."idx_bt_integration_ref";
DROP INDEX IF EXISTS "public"."idx_bt_date";
DROP INDEX IF EXISTS "public"."idx_bt_created_at_brin";
DROP INDEX IF EXISTS "public"."idx_bt_created_at";
DROP INDEX IF EXISTS "public"."idx_bt_bank_id";
DROP INDEX IF EXISTS "auth"."users_is_anonymous_idx";
DROP INDEX IF EXISTS "auth"."users_instance_id_idx";
DROP INDEX IF EXISTS "auth"."users_instance_id_email_idx";
DROP INDEX IF EXISTS "auth"."users_email_partial_key";
DROP INDEX IF EXISTS "auth"."user_id_created_at_idx";
DROP INDEX IF EXISTS "auth"."unique_phone_factor_per_user";
DROP INDEX IF EXISTS "auth"."sso_providers_resource_id_pattern_idx";
DROP INDEX IF EXISTS "auth"."sso_providers_resource_id_idx";
DROP INDEX IF EXISTS "auth"."sso_domains_sso_provider_id_idx";
DROP INDEX IF EXISTS "auth"."sso_domains_domain_idx";
DROP INDEX IF EXISTS "auth"."sessions_user_id_idx";
DROP INDEX IF EXISTS "auth"."sessions_oauth_client_id_idx";
DROP INDEX IF EXISTS "auth"."sessions_not_after_idx";
DROP INDEX IF EXISTS "auth"."saml_relay_states_sso_provider_id_idx";
DROP INDEX IF EXISTS "auth"."saml_relay_states_for_email_idx";
DROP INDEX IF EXISTS "auth"."saml_relay_states_created_at_idx";
DROP INDEX IF EXISTS "auth"."saml_providers_sso_provider_id_idx";
DROP INDEX IF EXISTS "auth"."refresh_tokens_updated_at_idx";
DROP INDEX IF EXISTS "auth"."refresh_tokens_session_id_revoked_idx";
DROP INDEX IF EXISTS "auth"."refresh_tokens_parent_idx";
DROP INDEX IF EXISTS "auth"."refresh_tokens_instance_id_user_id_idx";
DROP INDEX IF EXISTS "auth"."refresh_tokens_instance_id_idx";
DROP INDEX IF EXISTS "auth"."recovery_token_idx";
DROP INDEX IF EXISTS "auth"."reauthentication_token_idx";
DROP INDEX IF EXISTS "auth"."one_time_tokens_user_id_token_type_key";
DROP INDEX IF EXISTS "auth"."one_time_tokens_token_hash_hash_idx";
DROP INDEX IF EXISTS "auth"."one_time_tokens_relates_to_hash_idx";
DROP INDEX IF EXISTS "auth"."oauth_consents_user_order_idx";
DROP INDEX IF EXISTS "auth"."oauth_consents_active_user_client_idx";
DROP INDEX IF EXISTS "auth"."oauth_consents_active_client_idx";
DROP INDEX IF EXISTS "auth"."oauth_clients_deleted_at_idx";
DROP INDEX IF EXISTS "auth"."oauth_auth_pending_exp_idx";
DROP INDEX IF EXISTS "auth"."mfa_factors_user_id_idx";
DROP INDEX IF EXISTS "auth"."mfa_factors_user_friendly_name_unique";
DROP INDEX IF EXISTS "auth"."mfa_challenge_created_at_idx";
DROP INDEX IF EXISTS "auth"."idx_user_id_auth_method";
DROP INDEX IF EXISTS "auth"."idx_oauth_client_states_created_at";
DROP INDEX IF EXISTS "auth"."idx_auth_code";
DROP INDEX IF EXISTS "auth"."identities_user_id_idx";
DROP INDEX IF EXISTS "auth"."identities_email_idx";
DROP INDEX IF EXISTS "auth"."flow_state_created_at_idx";
DROP INDEX IF EXISTS "auth"."factor_id_created_at_idx";
DROP INDEX IF EXISTS "auth"."email_change_token_new_idx";
DROP INDEX IF EXISTS "auth"."email_change_token_current_idx";
DROP INDEX IF EXISTS "auth"."confirmation_token_idx";
DROP INDEX IF EXISTS "auth"."audit_logs_instance_id_idx";
ALTER TABLE IF EXISTS ONLY "storage"."vector_indexes" DROP CONSTRAINT IF EXISTS "vector_indexes_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."s3_multipart_uploads" DROP CONSTRAINT IF EXISTS "s3_multipart_uploads_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."s3_multipart_uploads_parts" DROP CONSTRAINT IF EXISTS "s3_multipart_uploads_parts_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."objects" DROP CONSTRAINT IF EXISTS "objects_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."migrations" DROP CONSTRAINT IF EXISTS "migrations_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."migrations" DROP CONSTRAINT IF EXISTS "migrations_name_key";
ALTER TABLE IF EXISTS ONLY "storage"."buckets_vectors" DROP CONSTRAINT IF EXISTS "buckets_vectors_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."buckets" DROP CONSTRAINT IF EXISTS "buckets_pkey";
ALTER TABLE IF EXISTS ONLY "storage"."buckets_analytics" DROP CONSTRAINT IF EXISTS "buckets_analytics_pkey";
ALTER TABLE IF EXISTS ONLY "realtime"."schema_migrations" DROP CONSTRAINT IF EXISTS "schema_migrations_pkey";
ALTER TABLE IF EXISTS ONLY "realtime"."subscription" DROP CONSTRAINT IF EXISTS "pk_subscription";
ALTER TABLE IF EXISTS ONLY "realtime"."messages" DROP CONSTRAINT IF EXISTS "messages_pkey";
ALTER TABLE IF EXISTS ONLY "public"."warehouse_stocks" DROP CONSTRAINT IF EXISTS "warehouse_stocks_pkey";
ALTER TABLE IF EXISTS ONLY "public"."users" DROP CONSTRAINT IF EXISTS "users_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_default" DROP CONSTRAINT IF EXISTS "user_transactions_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2031" DROP CONSTRAINT IF EXISTS "user_transactions_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2030" DROP CONSTRAINT IF EXISTS "user_transactions_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2029" DROP CONSTRAINT IF EXISTS "user_transactions_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2028" DROP CONSTRAINT IF EXISTS "user_transactions_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2027" DROP CONSTRAINT IF EXISTS "user_transactions_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2026" DROP CONSTRAINT IF EXISTS "user_transactions_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2025" DROP CONSTRAINT IF EXISTS "user_transactions_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions_2024" DROP CONSTRAINT IF EXISTS "user_transactions_2024_pkey";
ALTER TABLE IF EXISTS ONLY "public"."user_transactions" DROP CONSTRAINT IF EXISTS "user_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."saved_descriptions" DROP CONSTRAINT IF EXISTS "unique_category_content";
ALTER TABLE IF EXISTS ONLY "public"."table_counts" DROP CONSTRAINT IF EXISTS "table_counts_pkey";
ALTER TABLE IF EXISTS ONLY "public"."sync_outbox" DROP CONSTRAINT IF EXISTS "sync_outbox_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_default" DROP CONSTRAINT IF EXISTS "stock_movements_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2031" DROP CONSTRAINT IF EXISTS "stock_movements_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2030" DROP CONSTRAINT IF EXISTS "stock_movements_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2029" DROP CONSTRAINT IF EXISTS "stock_movements_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2028" DROP CONSTRAINT IF EXISTS "stock_movements_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2027" DROP CONSTRAINT IF EXISTS "stock_movements_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2026" DROP CONSTRAINT IF EXISTS "stock_movements_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements_2025" DROP CONSTRAINT IF EXISTS "stock_movements_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_pkey";
ALTER TABLE IF EXISTS ONLY "public"."shipments" DROP CONSTRAINT IF EXISTS "shipments_pkey";
ALTER TABLE IF EXISTS ONLY "public"."sequences" DROP CONSTRAINT IF EXISTS "sequences_pkey";
ALTER TABLE IF EXISTS ONLY "public"."saved_descriptions" DROP CONSTRAINT IF EXISTS "saved_descriptions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."roles" DROP CONSTRAINT IF EXISTS "roles_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quotes_y2026_m03" DROP CONSTRAINT IF EXISTS "quotes_y2026_m03_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quotes_y2026_m02" DROP CONSTRAINT IF EXISTS "quotes_y2026_m02_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quotes_default" DROP CONSTRAINT IF EXISTS "quotes_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quotes" DROP CONSTRAINT IF EXISTS "quotes_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quote_items" DROP CONSTRAINT IF EXISTS "quote_items_pkey";
ALTER TABLE IF EXISTS ONLY "public"."quick_products" DROP CONSTRAINT IF EXISTS "quick_products_product_id_key";
ALTER TABLE IF EXISTS ONLY "public"."quick_products" DROP CONSTRAINT IF EXISTS "quick_products_pkey";
ALTER TABLE IF EXISTS ONLY "public"."promissory_notes" DROP CONSTRAINT IF EXISTS "promissory_notes_pkey";
ALTER TABLE IF EXISTS ONLY "public"."products" DROP CONSTRAINT IF EXISTS "products_pkey";
ALTER TABLE IF EXISTS ONLY "public"."productions" DROP CONSTRAINT IF EXISTS "productions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_default" DROP CONSTRAINT IF EXISTS "production_stock_movements_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2036" DROP CONSTRAINT IF EXISTS "production_stock_movements_2036_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2035" DROP CONSTRAINT IF EXISTS "production_stock_movements_2035_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2034" DROP CONSTRAINT IF EXISTS "production_stock_movements_2034_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2033" DROP CONSTRAINT IF EXISTS "production_stock_movements_2033_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2032" DROP CONSTRAINT IF EXISTS "production_stock_movements_2032_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2031" DROP CONSTRAINT IF EXISTS "production_stock_movements_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2030" DROP CONSTRAINT IF EXISTS "production_stock_movements_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2029" DROP CONSTRAINT IF EXISTS "production_stock_movements_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2028" DROP CONSTRAINT IF EXISTS "production_stock_movements_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2027" DROP CONSTRAINT IF EXISTS "production_stock_movements_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2026" DROP CONSTRAINT IF EXISTS "production_stock_movements_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2025" DROP CONSTRAINT IF EXISTS "production_stock_movements_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2024" DROP CONSTRAINT IF EXISTS "production_stock_movements_2024_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2023" DROP CONSTRAINT IF EXISTS "production_stock_movements_2023_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2022" DROP CONSTRAINT IF EXISTS "production_stock_movements_2022_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2021" DROP CONSTRAINT IF EXISTS "production_stock_movements_2021_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements_2020" DROP CONSTRAINT IF EXISTS "production_stock_movements_2020_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_stock_movements" DROP CONSTRAINT IF EXISTS "production_stock_movements_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_recipe_items" DROP CONSTRAINT IF EXISTS "production_recipe_items_pkey";
ALTER TABLE IF EXISTS ONLY "public"."production_metadata" DROP CONSTRAINT IF EXISTS "production_metadata_pkey";
ALTER TABLE IF EXISTS ONLY "public"."product_metadata" DROP CONSTRAINT IF EXISTS "product_metadata_pkey";
ALTER TABLE IF EXISTS ONLY "public"."product_devices" DROP CONSTRAINT IF EXISTS "product_devices_pkey";
ALTER TABLE IF EXISTS ONLY "public"."print_templates" DROP CONSTRAINT IF EXISTS "print_templates_pkey";
ALTER TABLE IF EXISTS ONLY "public"."orders_y2026_m03" DROP CONSTRAINT IF EXISTS "orders_y2026_m03_pkey";
ALTER TABLE IF EXISTS ONLY "public"."orders_y2026_m02" DROP CONSTRAINT IF EXISTS "orders_y2026_m02_pkey";
ALTER TABLE IF EXISTS ONLY "public"."orders_default" DROP CONSTRAINT IF EXISTS "orders_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."orders" DROP CONSTRAINT IF EXISTS "orders_pkey";
ALTER TABLE IF EXISTS ONLY "public"."order_items" DROP CONSTRAINT IF EXISTS "order_items_pkey";
ALTER TABLE IF EXISTS ONLY "public"."note_transactions" DROP CONSTRAINT IF EXISTS "note_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."installments" DROP CONSTRAINT IF EXISTS "installments_pkey";
ALTER TABLE IF EXISTS ONLY "public"."hidden_descriptions" DROP CONSTRAINT IF EXISTS "hidden_descriptions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."general_settings" DROP CONSTRAINT IF EXISTS "general_settings_pkey";
ALTER TABLE IF EXISTS ONLY "public"."expenses" DROP CONSTRAINT IF EXISTS "expenses_pkey";
ALTER TABLE IF EXISTS ONLY "public"."expense_items" DROP CONSTRAINT IF EXISTS "expense_items_pkey";
ALTER TABLE IF EXISTS ONLY "public"."depots" DROP CONSTRAINT IF EXISTS "depots_pkey";
ALTER TABLE IF EXISTS ONLY "public"."current_accounts" DROP CONSTRAINT IF EXISTS "current_accounts_pkey";
ALTER TABLE IF EXISTS ONLY "public"."current_account_transactions_default" DROP CONSTRAINT IF EXISTS "current_account_transactions_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."currency_rates" DROP CONSTRAINT IF EXISTS "currency_rates_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_cards" DROP CONSTRAINT IF EXISTS "credit_cards_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_default" DROP CONSTRAINT IF EXISTS "credit_card_transactions_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2031" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2030" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2029" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2028" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2027" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2026" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2025" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions_2024" DROP CONSTRAINT IF EXISTS "credit_card_transactions_2024_pkey";
ALTER TABLE IF EXISTS ONLY "public"."credit_card_transactions" DROP CONSTRAINT IF EXISTS "credit_card_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."company_settings" DROP CONSTRAINT IF EXISTS "company_settings_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cheques" DROP CONSTRAINT IF EXISTS "cheques_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cheque_transactions" DROP CONSTRAINT IF EXISTS "cheque_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cat_y2026_m03" DROP CONSTRAINT IF EXISTS "cat_y2026_m03_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cat_y2026_m02" DROP CONSTRAINT IF EXISTS "cat_y2026_m02_pkey";
ALTER TABLE IF EXISTS ONLY "public"."current_account_transactions" DROP CONSTRAINT IF EXISTS "current_account_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_registers" DROP CONSTRAINT IF EXISTS "cash_registers_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_default" DROP CONSTRAINT IF EXISTS "cash_register_transactions_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2031" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2030" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2029" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2028" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2027" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2026" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2025" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions_2024" DROP CONSTRAINT IF EXISTS "cash_register_transactions_2024_pkey";
ALTER TABLE IF EXISTS ONLY "public"."cash_register_transactions" DROP CONSTRAINT IF EXISTS "cash_register_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."banks" DROP CONSTRAINT IF EXISTS "banks_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_default" DROP CONSTRAINT IF EXISTS "bank_transactions_default_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2031" DROP CONSTRAINT IF EXISTS "bank_transactions_2031_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2030" DROP CONSTRAINT IF EXISTS "bank_transactions_2030_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2029" DROP CONSTRAINT IF EXISTS "bank_transactions_2029_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2028" DROP CONSTRAINT IF EXISTS "bank_transactions_2028_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2027" DROP CONSTRAINT IF EXISTS "bank_transactions_2027_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2026" DROP CONSTRAINT IF EXISTS "bank_transactions_2026_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2025" DROP CONSTRAINT IF EXISTS "bank_transactions_2025_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions_2024" DROP CONSTRAINT IF EXISTS "bank_transactions_2024_pkey";
ALTER TABLE IF EXISTS ONLY "public"."bank_transactions" DROP CONSTRAINT IF EXISTS "bank_transactions_pkey";
ALTER TABLE IF EXISTS ONLY "public"."account_metadata" DROP CONSTRAINT IF EXISTS "account_metadata_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."users" DROP CONSTRAINT IF EXISTS "users_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."users" DROP CONSTRAINT IF EXISTS "users_phone_key";
ALTER TABLE IF EXISTS ONLY "auth"."sso_providers" DROP CONSTRAINT IF EXISTS "sso_providers_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."sso_domains" DROP CONSTRAINT IF EXISTS "sso_domains_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."sessions" DROP CONSTRAINT IF EXISTS "sessions_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."schema_migrations" DROP CONSTRAINT IF EXISTS "schema_migrations_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_relay_states" DROP CONSTRAINT IF EXISTS "saml_relay_states_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_providers" DROP CONSTRAINT IF EXISTS "saml_providers_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."saml_providers" DROP CONSTRAINT IF EXISTS "saml_providers_entity_id_key";
ALTER TABLE IF EXISTS ONLY "auth"."refresh_tokens" DROP CONSTRAINT IF EXISTS "refresh_tokens_token_unique";
ALTER TABLE IF EXISTS ONLY "auth"."refresh_tokens" DROP CONSTRAINT IF EXISTS "refresh_tokens_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."one_time_tokens" DROP CONSTRAINT IF EXISTS "one_time_tokens_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_consents" DROP CONSTRAINT IF EXISTS "oauth_consents_user_client_unique";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_consents" DROP CONSTRAINT IF EXISTS "oauth_consents_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_clients" DROP CONSTRAINT IF EXISTS "oauth_clients_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_client_states" DROP CONSTRAINT IF EXISTS "oauth_client_states_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_authorizations" DROP CONSTRAINT IF EXISTS "oauth_authorizations_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_authorizations" DROP CONSTRAINT IF EXISTS "oauth_authorizations_authorization_id_key";
ALTER TABLE IF EXISTS ONLY "auth"."oauth_authorizations" DROP CONSTRAINT IF EXISTS "oauth_authorizations_authorization_code_key";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_factors" DROP CONSTRAINT IF EXISTS "mfa_factors_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_factors" DROP CONSTRAINT IF EXISTS "mfa_factors_last_challenged_at_key";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_challenges" DROP CONSTRAINT IF EXISTS "mfa_challenges_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_amr_claims" DROP CONSTRAINT IF EXISTS "mfa_amr_claims_session_id_authentication_method_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."instances" DROP CONSTRAINT IF EXISTS "instances_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."identities" DROP CONSTRAINT IF EXISTS "identities_provider_id_provider_unique";
ALTER TABLE IF EXISTS ONLY "auth"."identities" DROP CONSTRAINT IF EXISTS "identities_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."flow_state" DROP CONSTRAINT IF EXISTS "flow_state_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."audit_log_entries" DROP CONSTRAINT IF EXISTS "audit_log_entries_pkey";
ALTER TABLE IF EXISTS ONLY "auth"."mfa_amr_claims" DROP CONSTRAINT IF EXISTS "amr_id_pk";
ALTER TABLE IF EXISTS "public"."sync_outbox" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."stock_movements" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."shipments" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."saved_descriptions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."quotes" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."quote_items" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."quick_products" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."promissory_notes" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."products" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."productions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."production_stock_movements" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."production_recipe_items" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."product_devices" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."print_templates" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."orders" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."order_items" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."note_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."installments" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."expenses" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."expense_items" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."depots" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."current_accounts" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."current_account_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."currency_rates" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."credit_cards" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."credit_card_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."company_settings" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."cheques" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."cheque_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."cash_registers" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."cash_register_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."banks" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "public"."bank_transactions" ALTER COLUMN "id" DROP DEFAULT;
ALTER TABLE IF EXISTS "auth"."refresh_tokens" ALTER COLUMN "id" DROP DEFAULT;
DROP TABLE IF EXISTS "storage"."vector_indexes";
DROP TABLE IF EXISTS "storage"."s3_multipart_uploads_parts";
DROP TABLE IF EXISTS "storage"."s3_multipart_uploads";
DROP TABLE IF EXISTS "storage"."objects";
DROP TABLE IF EXISTS "storage"."migrations";
DROP TABLE IF EXISTS "storage"."buckets_vectors";
DROP TABLE IF EXISTS "storage"."buckets_analytics";
DROP TABLE IF EXISTS "storage"."buckets";
DROP TABLE IF EXISTS "realtime"."subscription";
DROP TABLE IF EXISTS "realtime"."schema_migrations";
DROP TABLE IF EXISTS "realtime"."messages";
DROP TABLE IF EXISTS "public"."warehouse_stocks";
DROP TABLE IF EXISTS "public"."users";
DROP TABLE IF EXISTS "public"."user_transactions_default";
DROP TABLE IF EXISTS "public"."user_transactions_2031";
DROP TABLE IF EXISTS "public"."user_transactions_2030";
DROP TABLE IF EXISTS "public"."user_transactions_2029";
DROP TABLE IF EXISTS "public"."user_transactions_2028";
DROP TABLE IF EXISTS "public"."user_transactions_2027";
DROP TABLE IF EXISTS "public"."user_transactions_2026";
DROP TABLE IF EXISTS "public"."user_transactions_2025";
DROP TABLE IF EXISTS "public"."user_transactions_2024";
DROP TABLE IF EXISTS "public"."user_transactions";
DROP TABLE IF EXISTS "public"."table_counts";
DROP SEQUENCE IF EXISTS "public"."sync_outbox_id_seq";
DROP TABLE IF EXISTS "public"."sync_outbox";
DROP TABLE IF EXISTS "public"."stock_movements_default";
DROP TABLE IF EXISTS "public"."stock_movements_2031";
DROP TABLE IF EXISTS "public"."stock_movements_2030";
DROP TABLE IF EXISTS "public"."stock_movements_2029";
DROP TABLE IF EXISTS "public"."stock_movements_2028";
DROP TABLE IF EXISTS "public"."stock_movements_2027";
DROP TABLE IF EXISTS "public"."stock_movements_2026";
DROP TABLE IF EXISTS "public"."stock_movements_2025";
DROP SEQUENCE IF EXISTS "public"."stock_movements_id_seq";
DROP TABLE IF EXISTS "public"."stock_movements";
DROP SEQUENCE IF EXISTS "public"."shipments_id_seq";
DROP TABLE IF EXISTS "public"."shipments";
DROP TABLE IF EXISTS "public"."sequences";
DROP SEQUENCE IF EXISTS "public"."saved_descriptions_id_seq";
DROP TABLE IF EXISTS "public"."saved_descriptions";
DROP TABLE IF EXISTS "public"."roles";
DROP TABLE IF EXISTS "public"."quotes_y2026_m03";
DROP TABLE IF EXISTS "public"."quotes_y2026_m02";
DROP TABLE IF EXISTS "public"."quotes_default";
DROP SEQUENCE IF EXISTS "public"."quotes_id_seq";
DROP TABLE IF EXISTS "public"."quotes";
DROP SEQUENCE IF EXISTS "public"."quote_items_id_seq";
DROP TABLE IF EXISTS "public"."quote_items";
DROP SEQUENCE IF EXISTS "public"."quick_products_id_seq";
DROP TABLE IF EXISTS "public"."quick_products";
DROP SEQUENCE IF EXISTS "public"."promissory_notes_id_seq";
DROP TABLE IF EXISTS "public"."promissory_notes";
DROP SEQUENCE IF EXISTS "public"."products_id_seq";
DROP TABLE IF EXISTS "public"."products";
DROP SEQUENCE IF EXISTS "public"."productions_id_seq";
DROP TABLE IF EXISTS "public"."productions";
DROP TABLE IF EXISTS "public"."production_stock_movements_default";
DROP TABLE IF EXISTS "public"."production_stock_movements_2036";
DROP TABLE IF EXISTS "public"."production_stock_movements_2035";
DROP TABLE IF EXISTS "public"."production_stock_movements_2034";
DROP TABLE IF EXISTS "public"."production_stock_movements_2033";
DROP TABLE IF EXISTS "public"."production_stock_movements_2032";
DROP TABLE IF EXISTS "public"."production_stock_movements_2031";
DROP TABLE IF EXISTS "public"."production_stock_movements_2030";
DROP TABLE IF EXISTS "public"."production_stock_movements_2029";
DROP TABLE IF EXISTS "public"."production_stock_movements_2028";
DROP TABLE IF EXISTS "public"."production_stock_movements_2027";
DROP TABLE IF EXISTS "public"."production_stock_movements_2026";
DROP TABLE IF EXISTS "public"."production_stock_movements_2025";
DROP TABLE IF EXISTS "public"."production_stock_movements_2024";
DROP TABLE IF EXISTS "public"."production_stock_movements_2023";
DROP TABLE IF EXISTS "public"."production_stock_movements_2022";
DROP TABLE IF EXISTS "public"."production_stock_movements_2021";
DROP TABLE IF EXISTS "public"."production_stock_movements_2020";
DROP SEQUENCE IF EXISTS "public"."production_stock_movements_id_seq";
DROP TABLE IF EXISTS "public"."production_stock_movements";
DROP SEQUENCE IF EXISTS "public"."production_recipe_items_id_seq";
DROP TABLE IF EXISTS "public"."production_recipe_items";
DROP TABLE IF EXISTS "public"."production_metadata";
DROP TABLE IF EXISTS "public"."product_metadata";
DROP SEQUENCE IF EXISTS "public"."product_devices_id_seq";
DROP TABLE IF EXISTS "public"."product_devices";
DROP SEQUENCE IF EXISTS "public"."print_templates_id_seq";
DROP TABLE IF EXISTS "public"."print_templates";
DROP TABLE IF EXISTS "public"."orders_y2026_m03";
DROP TABLE IF EXISTS "public"."orders_y2026_m02";
DROP TABLE IF EXISTS "public"."orders_default";
DROP SEQUENCE IF EXISTS "public"."orders_id_seq";
DROP TABLE IF EXISTS "public"."orders";
DROP SEQUENCE IF EXISTS "public"."order_items_id_seq";
DROP TABLE IF EXISTS "public"."order_items";
DROP SEQUENCE IF EXISTS "public"."note_transactions_id_seq";
DROP TABLE IF EXISTS "public"."note_transactions";
DROP SEQUENCE IF EXISTS "public"."installments_id_seq";
DROP TABLE IF EXISTS "public"."installments";
DROP TABLE IF EXISTS "public"."hidden_descriptions";
DROP TABLE IF EXISTS "public"."general_settings";
DROP SEQUENCE IF EXISTS "public"."expenses_id_seq";
DROP TABLE IF EXISTS "public"."expenses";
DROP SEQUENCE IF EXISTS "public"."expense_items_id_seq";
DROP TABLE IF EXISTS "public"."expense_items";
DROP SEQUENCE IF EXISTS "public"."depots_id_seq";
DROP TABLE IF EXISTS "public"."depots";
DROP SEQUENCE IF EXISTS "public"."current_accounts_id_seq";
DROP TABLE IF EXISTS "public"."current_accounts";
DROP TABLE IF EXISTS "public"."current_account_transactions_default";
DROP SEQUENCE IF EXISTS "public"."currency_rates_id_seq";
DROP TABLE IF EXISTS "public"."currency_rates";
DROP SEQUENCE IF EXISTS "public"."credit_cards_id_seq";
DROP TABLE IF EXISTS "public"."credit_cards";
DROP TABLE IF EXISTS "public"."credit_card_transactions_default";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2031";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2030";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2029";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2028";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2027";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2026";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2025";
DROP TABLE IF EXISTS "public"."credit_card_transactions_2024";
DROP SEQUENCE IF EXISTS "public"."credit_card_transactions_id_seq";
DROP TABLE IF EXISTS "public"."credit_card_transactions";
DROP SEQUENCE IF EXISTS "public"."company_settings_id_seq";
DROP TABLE IF EXISTS "public"."company_settings";
DROP SEQUENCE IF EXISTS "public"."cheques_id_seq";
DROP TABLE IF EXISTS "public"."cheques";
DROP SEQUENCE IF EXISTS "public"."cheque_transactions_id_seq";
DROP TABLE IF EXISTS "public"."cheque_transactions";
DROP TABLE IF EXISTS "public"."cat_y2026_m03";
DROP TABLE IF EXISTS "public"."cat_y2026_m02";
DROP SEQUENCE IF EXISTS "public"."current_account_transactions_id_seq";
DROP TABLE IF EXISTS "public"."current_account_transactions";
DROP SEQUENCE IF EXISTS "public"."cash_registers_id_seq";
DROP TABLE IF EXISTS "public"."cash_registers";
DROP TABLE IF EXISTS "public"."cash_register_transactions_default";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2031";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2030";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2029";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2028";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2027";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2026";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2025";
DROP TABLE IF EXISTS "public"."cash_register_transactions_2024";
DROP SEQUENCE IF EXISTS "public"."cash_register_transactions_id_seq";
DROP TABLE IF EXISTS "public"."cash_register_transactions";
DROP SEQUENCE IF EXISTS "public"."banks_id_seq";
DROP TABLE IF EXISTS "public"."banks";
DROP TABLE IF EXISTS "public"."bank_transactions_default";
DROP TABLE IF EXISTS "public"."bank_transactions_2031";
DROP TABLE IF EXISTS "public"."bank_transactions_2030";
DROP TABLE IF EXISTS "public"."bank_transactions_2029";
DROP TABLE IF EXISTS "public"."bank_transactions_2028";
DROP TABLE IF EXISTS "public"."bank_transactions_2027";
DROP TABLE IF EXISTS "public"."bank_transactions_2026";
DROP TABLE IF EXISTS "public"."bank_transactions_2025";
DROP TABLE IF EXISTS "public"."bank_transactions_2024";
DROP SEQUENCE IF EXISTS "public"."bank_transactions_id_seq";
DROP TABLE IF EXISTS "public"."bank_transactions";
DROP TABLE IF EXISTS "public"."account_metadata";
DROP TABLE IF EXISTS "auth"."users";
DROP TABLE IF EXISTS "auth"."sso_providers";
DROP TABLE IF EXISTS "auth"."sso_domains";
DROP TABLE IF EXISTS "auth"."sessions";
DROP TABLE IF EXISTS "auth"."schema_migrations";
DROP TABLE IF EXISTS "auth"."saml_relay_states";
DROP TABLE IF EXISTS "auth"."saml_providers";
DROP SEQUENCE IF EXISTS "auth"."refresh_tokens_id_seq";
DROP TABLE IF EXISTS "auth"."refresh_tokens";
DROP TABLE IF EXISTS "auth"."one_time_tokens";
DROP TABLE IF EXISTS "auth"."oauth_consents";
DROP TABLE IF EXISTS "auth"."oauth_clients";
DROP TABLE IF EXISTS "auth"."oauth_client_states";
DROP TABLE IF EXISTS "auth"."oauth_authorizations";
DROP TABLE IF EXISTS "auth"."mfa_factors";
DROP TABLE IF EXISTS "auth"."mfa_challenges";
DROP TABLE IF EXISTS "auth"."mfa_amr_claims";
DROP TABLE IF EXISTS "auth"."instances";
DROP TABLE IF EXISTS "auth"."identities";
DROP TABLE IF EXISTS "auth"."flow_state";
DROP TABLE IF EXISTS "auth"."audit_log_entries";
DROP FUNCTION IF EXISTS "storage"."update_updated_at_column"();
DROP FUNCTION IF EXISTS "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer, "levels" integer, "start_after" "text", "sort_order" "text", "sort_column" "text", "sort_column_after" "text");
DROP FUNCTION IF EXISTS "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text");
DROP FUNCTION IF EXISTS "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text");
DROP FUNCTION IF EXISTS "storage"."protect_delete"();
DROP FUNCTION IF EXISTS "storage"."operation"();
DROP FUNCTION IF EXISTS "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "start_after" "text", "next_token" "text", "sort_order" "text");
DROP FUNCTION IF EXISTS "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "next_key_token" "text", "next_upload_token" "text");
DROP FUNCTION IF EXISTS "storage"."get_size_by_bucket"();
DROP FUNCTION IF EXISTS "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text");
DROP FUNCTION IF EXISTS "storage"."foldername"("name" "text");
DROP FUNCTION IF EXISTS "storage"."filename"("name" "text");
DROP FUNCTION IF EXISTS "storage"."extension"("name" "text");
DROP FUNCTION IF EXISTS "storage"."enforce_bucket_name_length"();
DROP FUNCTION IF EXISTS "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb");
DROP FUNCTION IF EXISTS "realtime"."topic"();
DROP FUNCTION IF EXISTS "realtime"."to_regrole"("role_name" "text");
DROP FUNCTION IF EXISTS "realtime"."subscription_check_filters"();
DROP FUNCTION IF EXISTS "realtime"."send"("payload" "jsonb", "event" "text", "topic" "text", "private" boolean);
DROP FUNCTION IF EXISTS "realtime"."quote_wal2json"("entity" "regclass");
DROP FUNCTION IF EXISTS "realtime"."list_changes"("publication" "name", "slot_name" "name", "max_changes" integer, "max_record_bytes" integer);
DROP FUNCTION IF EXISTS "realtime"."is_visible_through_filters"("columns" "realtime"."wal_column"[], "filters" "realtime"."user_defined_filter"[]);
DROP FUNCTION IF EXISTS "realtime"."check_equality_op"("op" "realtime"."equality_op", "type_" "regtype", "val_1" "text", "val_2" "text");
DROP FUNCTION IF EXISTS "realtime"."cast"("val" "text", "type_" "regtype");
DROP FUNCTION IF EXISTS "realtime"."build_prepared_statement_sql"("prepared_statement_name" "text", "entity" "regclass", "columns" "realtime"."wal_column"[]);
DROP FUNCTION IF EXISTS "realtime"."broadcast_changes"("topic_name" "text", "event_name" "text", "operation" "text", "table_name" "text", "table_schema" "text", "new" "record", "old" "record", "level" "text");
DROP FUNCTION IF EXISTS "realtime"."apply_rls"("wal" "jsonb", "max_record_bytes" integer);
DROP FUNCTION IF EXISTS "public"."update_table_counts"();
DROP FUNCTION IF EXISTS "public"."update_productions_search_tags"();
DROP FUNCTION IF EXISTS "public"."update_production_metadata"();
DROP FUNCTION IF EXISTS "public"."update_product_metadata"();
DROP FUNCTION IF EXISTS "public"."update_depots_search_tags"();
DROP FUNCTION IF EXISTS "public"."update_credit_card_search_tags"();
DROP FUNCTION IF EXISTS "public"."update_cash_register_search_tags"();
DROP FUNCTION IF EXISTS "public"."update_bank_search_tags"();
DROP FUNCTION IF EXISTS "public"."update_account_metadata"();
DROP FUNCTION IF EXISTS "public"."trg_refresh_account_search_tags"();
DROP FUNCTION IF EXISTS "public"."refresh_current_account_search_tags"("p_account_id" integer);
DROP FUNCTION IF EXISTS "public"."normalize_text"("val" "text");
DROP FUNCTION IF EXISTS "public"."get_professional_label"("raw_type" "text", "context" "text", "direction" "text");
DROP FUNCTION IF EXISTS "public"."get_professional_label"("raw_type" "text", "context" "text");
DROP PROCEDURE IF EXISTS "public"."archive_old_data"(IN "p_cutoff_year" integer);
DROP FUNCTION IF EXISTS "pgbouncer"."get_auth"("p_usename" "text");
DROP FUNCTION IF EXISTS "extensions"."set_graphql_placeholder"();
DROP FUNCTION IF EXISTS "extensions"."pgrst_drop_watch"();
DROP FUNCTION IF EXISTS "extensions"."pgrst_ddl_watch"();
DROP FUNCTION IF EXISTS "extensions"."grant_pg_net_access"();
DROP FUNCTION IF EXISTS "extensions"."grant_pg_graphql_access"();
DROP FUNCTION IF EXISTS "extensions"."grant_pg_cron_access"();
DROP FUNCTION IF EXISTS "auth"."uid"();
DROP FUNCTION IF EXISTS "auth"."role"();
DROP FUNCTION IF EXISTS "auth"."jwt"();
DROP FUNCTION IF EXISTS "auth"."email"();
DROP TYPE IF EXISTS "storage"."buckettype";
DROP TYPE IF EXISTS "realtime"."wal_rls";
DROP TYPE IF EXISTS "realtime"."wal_column";
DROP TYPE IF EXISTS "realtime"."user_defined_filter";
DROP TYPE IF EXISTS "realtime"."equality_op";
DROP TYPE IF EXISTS "realtime"."action";
DROP TYPE IF EXISTS "auth"."one_time_token_type";
DROP TYPE IF EXISTS "auth"."oauth_response_type";
DROP TYPE IF EXISTS "auth"."oauth_registration_type";
DROP TYPE IF EXISTS "auth"."oauth_client_type";
DROP TYPE IF EXISTS "auth"."oauth_authorization_status";
DROP TYPE IF EXISTS "auth"."factor_type";
DROP TYPE IF EXISTS "auth"."factor_status";
DROP TYPE IF EXISTS "auth"."code_challenge_method";
DROP TYPE IF EXISTS "auth"."aal_level";
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS "supabase_vault";
DROP EXTENSION IF EXISTS "pgcrypto";
DROP EXTENSION IF EXISTS "pg_trgm";
DROP EXTENSION IF EXISTS "pg_stat_statements";
DROP EXTENSION IF EXISTS "pg_graphql";
DROP SCHEMA IF EXISTS "vault";
DROP SCHEMA IF EXISTS "storage";
DROP SCHEMA IF EXISTS "realtime";
DROP SCHEMA IF EXISTS "pgbouncer";
DROP SCHEMA IF EXISTS "graphql_public";
DROP SCHEMA IF EXISTS "graphql";
DROP SCHEMA IF EXISTS "extensions";
DROP SCHEMA IF EXISTS "auth";
--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "auth";


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "extensions";


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "graphql";


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "graphql_public";


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "pgbouncer";


--
-- Name: SCHEMA "public"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA "public" IS 'standard public schema';


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "realtime";


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "storage";


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "vault";


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";


--
-- Name: EXTENSION "pg_graphql"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "pg_graphql" IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "pg_stat_statements"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "pg_stat_statements" IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";


--
-- Name: EXTENSION "pg_trgm"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "pg_trgm" IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "pgcrypto"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "pgcrypto" IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";


--
-- Name: EXTENSION "supabase_vault"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "supabase_vault" IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."aal_level" AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."code_challenge_method" AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."factor_status" AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."factor_type" AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."oauth_authorization_status" AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."oauth_client_type" AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."oauth_registration_type" AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."oauth_response_type" AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE "auth"."one_time_token_type" AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE "realtime"."action" AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE "realtime"."equality_op" AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE "realtime"."user_defined_filter" AS (
	"column_name" "text",
	"op" "realtime"."equality_op",
	"value" "text"
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE "realtime"."wal_column" AS (
	"name" "text",
	"type_name" "text",
	"type_oid" "oid",
	"value" "jsonb",
	"is_pkey" boolean,
	"is_selectable" boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE "realtime"."wal_rls" AS (
	"wal" "jsonb",
	"is_rls_enabled" boolean,
	"subscription_ids" "uuid"[],
	"errors" "text"[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE "storage"."buckettype" AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION "auth"."email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION "email"(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION "auth"."email"() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION "auth"."jwt"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION "auth"."role"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION "role"(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION "auth"."role"() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION "auth"."uid"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION "uid"(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION "auth"."uid"() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."grant_pg_cron_access"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION "grant_pg_cron_access"(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION "extensions"."grant_pg_cron_access"() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."grant_pg_graphql_access"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION "grant_pg_graphql_access"(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION "extensions"."grant_pg_graphql_access"() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."grant_pg_net_access"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION "grant_pg_net_access"(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION "extensions"."grant_pg_net_access"() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."pgrst_ddl_watch"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."pgrst_drop_watch"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION "extensions"."set_graphql_placeholder"() RETURNS "event_trigger"
    LANGUAGE "plpgsql"
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION "set_graphql_placeholder"(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION "extensions"."set_graphql_placeholder"() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth("text"); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION "pgbouncer"."get_auth"("p_usename" "text") RETURNS TABLE("username" "text", "password" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
  BEGIN
      RAISE DEBUG 'PgBouncer auth request: %', p_usename;

      RETURN QUERY
      SELECT
          rolname::text,
          CASE WHEN rolvaliduntil < now()
              THEN null
              ELSE rolpassword::text
          END
      FROM pg_authid
      WHERE rolname=$1 and rolcanlogin;
  END;
  $_$;


--
-- Name: archive_old_data(integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE "public"."archive_old_data"(IN "p_cutoff_year" integer)
    LANGUAGE "plpgsql"
    AS $_$
      DECLARE
          row RECORD;
      BEGIN
          -- 1. Arşiv şemasını garantiye al
          CREATE SCHEMA IF NOT EXISTS archive;

          -- 2. Belirtilen yıldan önceki tüm bölümleri (partition) bul
          FOR row IN 
              SELECT nmsp_parent.nspname AS parent_schema,
                     parent.relname      AS parent_table,
                     nmsp_child.nspname  AS child_schema,
                     child.relname       AS child_table,
                     (SUBSTRING(child.relname FROM '_([0-9]{4})$'))::INTEGER AS part_year
              FROM pg_inherits
              JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
              JOIN pg_class child             ON pg_inherits.inhrelid  = child.oid
              JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
              JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
              WHERE nmsp_child.nspname = 'public'
                AND child.relname ~ '_[0-9]{4}$'
          LOOP
              -- Sadece cutoff yilindan kucukleri arsivle
              IF row.part_year IS NOT NULL AND row.part_year < p_cutoff_year THEN
                  -- 3. Partition'ı ana tablodan ayır (DETACH)
                  EXECUTE format('ALTER TABLE %I.%I DETACH PARTITION %I.%I', 
                                 row.parent_schema, row.parent_table, 
                                 row.child_schema, row.child_table);
                  
                  -- 4. Ayrılan tabloyu 'archive' şemasına taşı (Cold Storage)
                  EXECUTE format('ALTER TABLE %I.%I SET SCHEMA archive', 
                                 row.child_schema, row.child_table);
                                 
                  RAISE NOTICE 'Bölüm arşivlendi: % (%) -> archive.% (Yıl: %)', 
                               row.child_table, row.parent_table, row.child_table, row.part_year;
              END IF;
          END LOOP;
      END;
      $_$;


--
-- Name: get_professional_label("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."get_professional_label"("raw_type" "text", "context" "text" DEFAULT ''::"text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
          DECLARE
              t TEXT := LOWER(TRIM(raw_type));
              ctx TEXT := LOWER(TRIM(context));
          BEGIN
              IF raw_type IS NULL OR raw_type = '' THEN
                  RETURN 'İşlem';
              END IF;

              -- KASA
              IF ctx = 'cash' OR ctx = 'kasa' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- BANKA
              IF ctx = 'bank' OR ctx = 'banka' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Banka Ödeme';
                  ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- KREDI KARTI
              IF ctx = 'credit_card' OR ctx = 'kredi_karti' THEN
                  IF t ~ 'tahsilat' OR t ~ 'collection' THEN RETURN 'K.Kartı Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'payment' THEN RETURN 'K.Kartı Ödeme';
                  ELSIF t ~ 'harcama' OR t ~ 'gider' THEN RETURN 'K.Kartı Harcama';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- ÇEK
              IF ctx = 'check' OR ctx = 'cek' THEN
                  IF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Ödendi';
                  ELSIF t ~ 'tahsil' THEN RETURN 'Çek Tahsil';
                  ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro';
                  ELSIF t ~ 'verilen' OR t ~ 'verildi' THEN RETURN 'Çek Verildi';
                  ELSIF t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'alındı' OR t ~ 'alindi' THEN RETURN 'Çek Alındı';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Çek';
                  ELSIF t = 'giriş' OR t = 'giris' THEN RETURN 'Çek Tahsil';
                  ELSIF t = 'çıkış' OR t = 'cikis' THEN RETURN 'Çek Ödendi';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- SENET
              IF ctx = 'promissory_note' OR ctx = 'senet' THEN
                  IF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Ödendi';
                  ELSIF t ~ 'tahsil' THEN RETURN 'Senet Tahsil';
                  ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro';
                  ELSIF t ~ 'verilen' OR t ~ 'verildi' THEN RETURN 'Senet Verildi';
                  ELSIF t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'alındı' OR t ~ 'alindi' THEN RETURN 'Senet Alındı';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- CARİ
              IF ctx = 'current_account' OR ctx = 'cari' THEN
                  -- 1. Satış / Alış
                  IF t = 'satış yapıldı' OR t = 'satis yapildi' OR t ~ 'sale-' THEN RETURN 'Satış Yapıldı';
                  ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' OR t ~ 'purchase-' THEN RETURN 'Alış Yapıldı';
                  
                  -- 2. Tahsilat / Ödeme
                  ELSIF t ~ 'para alındı' OR t ~ 'para alindi' OR t ~ 'collection' OR t ~ 'tahsilat' THEN RETURN 'Para Alındı';
                  ELSIF t ~ 'para verildi' OR t ~ 'para verildi' OR t ~ 'payment' OR t ~ 'ödeme' OR t ~ 'odeme' THEN RETURN 'Para Verildi';

                  -- 3. Borç / Alacak (Manuel)
                  ELSIF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
                  ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
                  ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
                  ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
                  ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
                  ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
                  ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
                  ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
                  -- ÇEK İŞLEMLERİ (CARİ)
                  ELSIF t ~ 'çek' OR t ~ 'cek' THEN
                      IF t ~ 'tahsil' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Çek';
                      ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Çek Verildi';
                      ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Çek Alındı';
                      ELSE RETURN 'Çek İşlemi';
                      END IF;
                  -- SENET İŞLEMLERİ (CARİ)
                  ELSIF t ~ 'senet' THEN
                      IF t ~ 'tahsil' THEN RETURN 'Senet Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                      ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Senet Verildi';
                      ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Senet Alındı';
                      ELSE RETURN 'Senet İşlemi';
                      END IF;
                  END IF;
                  RETURN raw_type;
              END IF;

              -- STOK
              IF ctx = 'stock' OR ctx = 'stok' THEN
                  IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
                  ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
                  ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
                  ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
                  ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
                  ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
                  END IF;
              END IF;

              RETURN raw_type;
          END;
          $$;


--
-- Name: get_professional_label("text", "text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."get_professional_label"("raw_type" "text", "context" "text", "direction" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
      DECLARE
          t TEXT := LOWER(TRIM(raw_type));
          ctx TEXT := LOWER(TRIM(context));
          yon TEXT := LOWER(TRIM(direction));
      BEGIN
          IF raw_type IS NULL OR raw_type = '' THEN
              RETURN 'İşlem';
          END IF;

          -- KASA
          IF ctx = 'cash' OR ctx = 'kasa' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
              END IF;
          END IF;

          -- BANKA / POS / CC
          IF ctx = 'bank' OR ctx = 'banka' OR ctx = 'bank_pos' OR ctx = 'cc' OR ctx = 'credit_card' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'harcama' THEN RETURN 'Banka Ödeme';
              ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
              END IF;
          END IF;

          -- CARİ
          IF ctx = 'current_account' OR ctx = 'cari' THEN
              IF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
              ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
              ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
              ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
              ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
              ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
              -- ÇEK İŞLEMLERİ (CARİ)
              ELSIF t ~ 'çek' OR t ~ 'cek' THEN
                  IF t ~ 'tahsil' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                  ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Verildi (Ödendi)';
                  ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro Edildi';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karşiliksiz' THEN RETURN 'Karşılıksız Çek';
                  ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Çek Verildi';
                  ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Çek Alındı';
                  ELSE RETURN 'Çek İşlemi';
                  END IF;
              -- SENET İŞLEMLERİ (CARİ)
              ELSIF t ~ 'senet' THEN
                  IF t ~ 'tahsil' THEN RETURN 'Senet Alındı (Tahsil Edildi)';
                  ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Verildi (Ödendi)';
                  ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro Edildi';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karşiliksiz' THEN RETURN 'Karşılıksız Senet';
                  ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Senet Verildi';
                  ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Senet Alındı';
                  ELSE RETURN 'Senet İşlemi';
                  END IF;
              -- PARA AL/VER FALLBACK (En Geniş Kapsam)
              ELSIF t ~ 'tahsilat' OR t ~ 'para alındı' OR t ~ 'para alindi' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'girdi' OR yon ~ 'alacak' THEN 
                  RETURN 'Para Alındı';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'para verildi' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'çıktı' OR yon ~ 'bor' THEN 
                  RETURN 'Para Verildi';
              END IF;
          END IF;

          -- STOK
          IF ctx = 'stock' OR ctx = 'stok' THEN
              IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
              ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
              ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
              ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
              END IF;
          END IF;

          RETURN raw_type;
      END;
      $$;


--
-- Name: normalize_text("text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."normalize_text"("val" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
      BEGIN
          IF val IS NULL THEN RETURN ''; END IF;
          -- Handle combining characters and common variations before translate
          val := REPLACE(val, 'i̇', 'i'); -- Turkish dotted i variation
          RETURN LOWER(
              TRANSLATE(val, 
                  'ÇĞİÖŞÜIçğıöşü', 
                  'cgiosuicgiosu'
              )
          );
      END;
      $$;


--
-- Name: refresh_current_account_search_tags(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."refresh_current_account_search_tags"("p_account_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
      BEGIN
        UPDATE current_accounts ca
        SET search_tags = normalize_text(
          'v2 ' ||
          -- ANA SATIR ALANLARI (DataTable'da görünen - İşlemler butonu HARİÇ)
          COALESCE(ca.kod_no, '') || ' ' || 
          COALESCE(ca.adi, '') || ' ' || 
          COALESCE(ca.hesap_turu, '') || ' ' || 
          CAST(ca.id AS TEXT) || ' ' ||
          (CASE WHEN ca.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          COALESCE(CAST(ca.bakiye_borc AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.bakiye_alacak AS TEXT), '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Fatura Bilgileri)
          COALESCE(ca.fat_unvani, '') || ' ' ||
          COALESCE(ca.fat_adresi, '') || ' ' ||
          COALESCE(ca.fat_ilce, '') || ' ' ||
          COALESCE(ca.fat_sehir, '') || ' ' ||
          COALESCE(ca.posta_kodu, '') || ' ' ||
          COALESCE(ca.v_dairesi, '') || ' ' ||
          COALESCE(ca.v_numarasi, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Ticari Bilgiler)
          COALESCE(ca.sf_grubu, '') || ' ' ||
          COALESCE(CAST(ca.s_iskonto AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.vade_gun AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.risk_limiti AS TEXT), '') || ' ' ||
          COALESCE(ca.para_birimi, '') || ' ' ||
          COALESCE(ca.bakiye_durumu, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (İletişim)
          COALESCE(ca.telefon1, '') || ' ' ||
          COALESCE(ca.telefon2, '') || ' ' ||
          COALESCE(ca.eposta, '') || ' ' ||
          COALESCE(ca.web_adresi, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Özel Bilgiler) - TÜM 5 ALAN
          COALESCE(ca.bilgi1, '') || ' ' ||
          COALESCE(ca.bilgi2, '') || ' ' ||
          COALESCE(ca.bilgi3, '') || ' ' ||
          COALESCE(ca.bilgi4, '') || ' ' ||
          COALESCE(ca.bilgi5, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Sevkiyat)
          COALESCE(ca.sevk_adresleri, '') || ' ' ||
          -- DİĞER ALANLAR (Renk ve Kullanıcı)
          COALESCE(ca.renk, '') || ' ' ||
          COALESCE(ca.created_by, '') || ' ' ||
          -- SON HAREKETLER TABLOSU (Genişleyen Satırdaki İşlemler - Son 50)
          COALESCE((
            SELECT STRING_AGG(
              get_professional_label(cat.source_type, 'cari', cat.type) || ' ' ||
              (CASE 
                WHEN cat.source_type ILIKE '%giris%' OR cat.source_type ILIKE '%tahsil%' OR cat.type = 'Alacak' 
                THEN 'para alındı çek alındı senet alındı tahsilat giriş'
                WHEN cat.source_type ILIKE '%cikis%' OR cat.source_type ILIKE '%odeme%' OR cat.type = 'Borç' 
                THEN 'para verildi çek verildi senet verildi ödeme çıkış'
                ELSE '' 
              END) || ' ' ||
              COALESCE(cat.source_type, '') || ' ' || 
              COALESCE(cat.type, '') || ' ' ||
              (CASE WHEN cat.type = 'Alacak' THEN 'girdi giriş' ELSE 'çıktı çıkış' END) || ' ' ||
              COALESCE(cat.date::TEXT, '') || ' ' ||
              COALESCE(cat.source_name, '') || ' ' ||
              COALESCE(cat.source_code, '') || ' ' ||
              COALESCE(CAST(cat.amount AS TEXT), '') || ' ' ||
              COALESCE(cat.description, '') || ' ' ||
              COALESCE(cat.user_name, ''),
              ' '
            )
            FROM (
              SELECT * FROM current_account_transactions sub_cat
              WHERE sub_cat.current_account_id = ca.id
              ORDER BY sub_cat.date DESC
              LIMIT 50
            ) cat
          ), '')
        )
        WHERE ca.id = p_account_id;
      END;
      $$;


--
-- Name: trg_refresh_account_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_refresh_account_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
      DECLARE
        v_account_id INTEGER;
      BEGIN
        IF (TG_OP = 'DELETE') THEN
          v_account_id := OLD.current_account_id;
        ELSE
          v_account_id := NEW.current_account_id;
        END IF;

        IF v_account_id IS NOT NULL THEN
          PERFORM refresh_current_account_search_tags(v_account_id);
        END IF;

        IF (TG_OP = 'DELETE') THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;


--
-- Name: update_account_metadata(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_account_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
           IF NEW.fat_sehir IS NOT NULL AND NEW.fat_sehir != '' THEN
             INSERT INTO account_metadata (type, value, frequency) VALUES ('city', NEW.fat_sehir, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = account_metadata.frequency + 1;
           END IF;
           -- (Diğer alanlar kısaltıldı, zaten mevcut logic'de var)
        END IF;
        -- Trigger logic simplified for brevity in this block, full logic is preserved in original code or assumed
        RETURN NULL;
      END;
      $$;


--
-- Name: update_bank_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_bank_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
	          BEGIN
	            UPDATE banks b
	            SET search_tags = normalize_text(
	              'v6 ' ||
	              COALESCE(b.code, '') || ' ' ||
	              COALESCE(b.name, '') || ' ' ||
	              COALESCE(b.currency, '') || ' ' ||
	              COALESCE(b.branch_code, '') || ' ' ||
              COALESCE(b.branch_name, '') || ' ' ||
              COALESCE(b.account_no, '') || ' ' ||
              COALESCE(b.iban, '') || ' ' ||
              COALESCE(b.info1, '') || ' ' ||
              COALESCE(b.info2, '') || ' ' ||
              CAST(b.id AS TEXT) || ' ' ||
              (CASE WHEN b.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
	              COALESCE((
             SELECT STRING_AGG(
               get_professional_label(bt.type, 'bank') || ' ' ||
               get_professional_label(bt.type, 'cari') || ' ' ||
               COALESCE(bt.type, '') || ' ' ||
               COALESCE(TO_CHAR(bt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(bt.description, '') || ' ' ||
               COALESCE(bt.location, '') || ' ' ||
               COALESCE(bt.location_code, '') || ' ' ||
                  COALESCE(bt.location_name, '') || ' ' ||
                  COALESCE(bt.user_name, '') || ' ' ||
                  COALESCE(CAST(bt.amount AS TEXT), '') || ' ' ||
                  COALESCE(bt.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN bt.integration_ref = 'opening_stock' OR bt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN bt.integration_ref LIKE '%production%' OR bt.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN bt.integration_ref LIKE '%transfer%' OR bt.description ILIKE '%Devir%' THEN 'devir'
                    WHEN bt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN bt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN bt.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN bt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM bank_transactions sub_bt
                  WHERE sub_bt.bank_id = b.id
                  ORDER BY sub_bt.created_at DESC
	                  LIMIT 50
	                ) bt
	              ), '')
	            )
	            WHERE b.id = COALESCE(NEW.bank_id, OLD.bank_id);
	            RETURN NULL;
	          END;
          $$;


--
-- Name: update_cash_register_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_cash_register_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
          BEGIN
            UPDATE cash_registers cr
            SET search_tags = normalize_text(
              'v4 ' ||
              COALESCE(cr.code, '') || ' ' ||
              COALESCE(cr.name, '') || ' ' ||
              COALESCE(cr.currency, '') || ' ' ||
              COALESCE(cr.info1, '') || ' ' ||
              COALESCE(cr.info2, '') || ' ' ||
              CAST(cr.id AS TEXT) || ' ' ||
              (CASE WHEN cr.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
                 get_professional_label(crt.type, 'cash') || ' ' ||
                 get_professional_label(crt.type, 'cari') || ' ' ||
                 COALESCE(crt.type, '') || ' ' ||
                 COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(crt.description, '') || ' ' ||
               COALESCE(crt.location, '') || ' ' ||
               COALESCE(crt.location_code, '') || ' ' ||
                  COALESCE(crt.location_name, '') || ' ' ||
                  COALESCE(crt.user_name, '') || ' ' ||
                  COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
                  COALESCE(crt.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                    WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM cash_register_transactions sub_crt
                  WHERE sub_crt.cash_register_id = cr.id
                  ORDER BY sub_crt.created_at DESC
                  LIMIT 50
                ) crt
              ), '')
            )
            WHERE cr.id = COALESCE(NEW.cash_register_id, OLD.cash_register_id);
            RETURN NULL;
          END;
          $$;


--
-- Name: update_credit_card_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_credit_card_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
          BEGIN
            UPDATE credit_cards cc
            SET search_tags = normalize_text(
              'v6 ' ||
              COALESCE(cc.code, '') || ' ' ||
              COALESCE(cc.name, '') || ' ' ||
              COALESCE(cc.currency, '') || ' ' ||
              COALESCE(cc.branch_code, '') || ' ' ||
              COALESCE(cc.branch_name, '') || ' ' ||
              COALESCE(cc.account_no, '') || ' ' ||
              COALESCE(cc.iban, '') || ' ' ||
              COALESCE(cc.info1, '') || ' ' ||
              COALESCE(cc.info2, '') || ' ' ||
              CAST(cc.id AS TEXT) || ' ' ||
              (CASE WHEN cc.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
              get_professional_label(cct.type, 'credit_card') || ' ' ||
              get_professional_label(cct.type, 'cari') || ' ' ||
               COALESCE(cct.type, '') || ' ' ||
               COALESCE(TO_CHAR(cct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(cct.description, '') || ' ' ||
               COALESCE(cct.location, '') || ' ' ||
               COALESCE(cct.location_code, '') || ' ' ||
                  COALESCE(cct.location_name, '') || ' ' ||
                  COALESCE(cct.user_name, '') || ' ' ||
                  COALESCE(CAST(cct.amount AS TEXT), '') || ' ' ||
                  COALESCE(cct.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN cct.integration_ref = 'opening_stock' OR cct.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN cct.integration_ref LIKE '%production%' OR cct.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN cct.integration_ref LIKE '%transfer%' OR cct.description ILIKE '%Devir%' THEN 'devir'
                    WHEN cct.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN cct.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN cct.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM credit_card_transactions sub_cct
                  WHERE sub_cct.credit_card_id = cc.id
                  ORDER BY sub_cct.created_at DESC
                  LIMIT 50
                ) cct
              ), '')
            )
            WHERE cc.id = COALESCE(NEW.credit_card_id, OLD.credit_card_id);
            RETURN NULL;
          END;
          $$;


--
-- Name: update_depots_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_depots_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
              DECLARE
                history_text TEXT := '';
                stats_text TEXT := '';
              BEGIN
                SELECT COALESCE(SUM(quantity), 0)::TEXT || ' ' || COUNT(DISTINCT product_code)::TEXT
                INTO stats_text
                FROM warehouse_stocks 
                WHERE warehouse_id = NEW.id AND quantity > 0;

                SELECT STRING_AGG(
                  LOWER(
                     (CASE 
                        WHEN s.integration_ref LIKE 'SALE-%' OR s.integration_ref LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
                        WHEN s.integration_ref LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
                        WHEN s.integration_ref = 'opening_stock' OR s.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                        WHEN s.integration_ref = 'production_output' OR s.description ILIKE '%Üretim (Çıktı)%' THEN 'üretim çıktısı üretim çıkışı'
                        WHEN s.description ILIKE '%Üretim (Girdi)%' OR s.description ILIKE '%Üretim (Giriş)%' THEN 'üretim girdisi üretim girişi'
                        WHEN EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type LIKE 'uretim%') THEN 'üretim'
                        WHEN s.source_warehouse_id = NEW.id AND s.dest_warehouse_id IS NOT NULL THEN 'transfer sevkiyat çıkış devir çıkış'
                        WHEN s.dest_warehouse_id = NEW.id AND s.source_warehouse_id IS NOT NULL THEN 'transfer sevkiyat giriş devir giriş'
                        WHEN s.dest_warehouse_id = NEW.id THEN 'giriş stok giriş'
                        ELSE 'çıkış stok çıkış'
                     END) || ' ' ||
                     TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                     COALESCE(s.description, '') || ' ' ||
                     COALESCE(s.created_by, '') || ' ' ||
                     (
                       SELECT STRING_AGG(
                         LOWER(
                           COALESCE(item->>'code', '') || ' ' ||
                           COALESCE(item->>'name', '') || ' ' ||
                           COALESCE(item->>'unit', '') || ' ' ||
                           COALESCE(item->>'quantity', '') || ' ' ||
                           COALESCE(item->>'unitCost', '')
                         ), ' '
                       )
                       FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item
                     )
                  ), ' '
                ) INTO history_text
                FROM (
                   SELECT * FROM shipments s 
                   WHERE s.source_warehouse_id = NEW.id OR s.dest_warehouse_id = NEW.id
                   ORDER BY s.date DESC LIMIT 50
                ) s;

                NEW.search_tags := LOWER(
                  COALESCE(NEW.kod, '') || ' ' || COALESCE(NEW.ad, '') || ' ' || COALESCE(NEW.adres, '') || ' ' || 
                  COALESCE(NEW.sorumlu, '') || ' ' || COALESCE(NEW.telefon, '') || ' ' ||
                  CAST(NEW.id AS TEXT) || ' ' || (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
                ) || ' ' || COALESCE(history_text, '') || ' ' || COALESCE(stats_text, '');
                RETURN NEW;
              END;
              $$;


--
-- Name: update_product_metadata(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_product_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           -- Group Değişimi
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;
           
           -- Birim Değişimi
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

           -- KDV Değişimi
           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        -- Temizlik (Sıfır olanları sil ki tablo şişmesin)
        DELETE FROM product_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      $$;


--
-- Name: update_production_metadata(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_production_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;
           
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        DELETE FROM production_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      $$;


--
-- Name: update_productions_search_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_productions_search_tags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
        DECLARE
          history_text TEXT := '';
        BEGIN
          -- 1 Milyar Kayıt İçin Hareket Geçmişi İndeksleme
          -- `search_tags` alanına üretim hareketlerini (Tarih, Depo, Miktar, Fiyat, Kullanıcı) ekler.
          SELECT STRING_AGG(sub.line, ' ') INTO history_text
          FROM (
             SELECT 
               LOWER(
                 COALESCE(
                   CASE 
                     WHEN psm.movement_type = 'uretim_giris' THEN 'üretim (girdi)'
                     WHEN psm.movement_type = 'uretim_cikis' THEN 'üretim (çıktı)'
                     WHEN psm.movement_type = 'satis_faturasi' THEN 'satış faturası'
                     WHEN psm.movement_type = 'alis_faturasi' THEN 'alış faturası'
                     WHEN psm.movement_type = 'devir_giris' THEN 'devir girdi'
                     WHEN psm.movement_type = 'devir_cikis' THEN 'devir çıktı'
                     WHEN psm.movement_type = 'sevkiyat' THEN 'sevkiyat' 
                     ELSE psm.movement_type 
                   END, 
                   'işlem'
                 ) || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM') || ' ' ||
                 TO_CHAR(psm.movement_date, 'HH24:MI') || ' ' ||
                 COALESCE(d.ad, '') || ' ' || 
                 COALESCE(psm.quantity::text, '') || ' ' ||
                 COALESCE(psm.unit_price::text, '') || ' ' ||
                 COALESCE(psm.created_by, '')
               ) as line
             FROM production_stock_movements psm
             LEFT JOIN depots d ON psm.warehouse_id = d.id
             WHERE psm.production_id = NEW.id
             ORDER BY psm.movement_date DESC
             LIMIT 50
          ) sub;

          NEW.search_tags := LOWER(
            COALESCE(NEW.kod, '') || ' ' || 
            COALESCE(NEW.ad, '') || ' ' || 
            COALESCE(NEW.barkod, '') || ' ' || 
            COALESCE(NEW.grubu, '') || ' ' || 
            COALESCE(NEW.kullanici, '') || ' ' || 
            COALESCE(NEW.ozellikler, '') || ' ' || 
            COALESCE(NEW.birim, '') || ' ' || 
            CAST(NEW.id AS TEXT) || ' ' ||
            COALESCE(CAST(NEW.alis_fiyati AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_1 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_2 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_3 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.erken_uyari_miktari AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.stok AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.kdv_orani AS TEXT), '') || ' ' ||
            (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
          ) || ' ' || COALESCE(history_text, '');
          RETURN NEW;
        END;
        $$;


--
-- Name: update_table_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."update_table_counts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO table_counts (table_name, row_count) 
          VALUES (TG_TABLE_NAME, 1) 
          ON CONFLICT (table_name) DO UPDATE SET row_count = table_counts.row_count + 1;
        ELSIF (TG_OP = 'DELETE') THEN
          UPDATE table_counts SET row_count = row_count - 1 WHERE table_name = TG_TABLE_NAME;
        END IF;
        RETURN NULL;
      END;
      $$;


--
-- Name: apply_rls("jsonb", integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."apply_rls"("wal" "jsonb", "max_record_bytes" integer DEFAULT (1024 * 1024)) RETURNS SETOF "realtime"."wal_rls"
    LANGUAGE "plpgsql"
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_
        -- Filter by action early - only get subscriptions interested in this action
        -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
        and (subs.action_filter = '*' or subs.action_filter = action::text);

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes("text", "text", "text", "text", "text", "record", "record", "text"); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."broadcast_changes"("topic_name" "text", "event_name" "text", "operation" "text", "table_name" "text", "table_schema" "text", "new" "record", "old" "record", "level" "text" DEFAULT 'ROW'::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql("text", "regclass", "realtime"."wal_column"[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."build_prepared_statement_sql"("prepared_statement_name" "text", "entity" "regclass", "columns" "realtime"."wal_column"[]) RETURNS "text"
    LANGUAGE "sql"
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast("text", "regtype"); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."cast"("val" "text", "type_" "regtype") RETURNS "jsonb"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $$;


--
-- Name: check_equality_op("realtime"."equality_op", "regtype", "text", "text"); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."check_equality_op"("op" "realtime"."equality_op", "type_" "regtype", "val_1" "text", "val_2" "text") RETURNS boolean
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters("realtime"."wal_column"[], "realtime"."user_defined_filter"[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."is_visible_through_filters"("columns" "realtime"."wal_column"[], "filters" "realtime"."user_defined_filter"[]) RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes("name", "name", integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."list_changes"("publication" "name", "slot_name" "name", "max_changes" integer, "max_record_bytes" integer) RETURNS SETOF "realtime"."wal_rls"
    LANGUAGE "sql"
    SET "log_min_messages" TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json("regclass"); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."quote_wal2json"("entity" "regclass") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send("jsonb", "text", "text", boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."send"("payload" "jsonb", "event" "text", "topic" "text", "private" boolean DEFAULT true) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."subscription_check_filters"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole("text"); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."to_regrole"("role_name" "text") RETURNS "regrole"
    LANGUAGE "sql" IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION "realtime"."topic"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: can_insert_object("text", "text", "uuid", "jsonb"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."enforce_bucket_name_length"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension("text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."extension"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
_parts text[];
_filename text;
BEGIN
	select string_to_array(name, '/') into _parts;
	select _parts[array_length(_parts,1)] into _filename;
	-- @todo return the last part instead of 2
	return reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename("text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."filename"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername("text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."foldername"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql"
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[1:array_length(_parts,1)-1];
END
$$;


--
-- Name: get_common_prefix("text", "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."get_size_by_bucket"() RETURNS TABLE("size" bigint, "bucket_id" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::int) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter("text", "text", "text", integer, "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "next_key_token" "text" DEFAULT ''::"text", "next_upload_token" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "id" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter("text", "text", "text", integer, "text", "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "start_after" "text" DEFAULT ''::"text", "next_token" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "metadata" "jsonb", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."operation"() RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."protect_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search("text", "text", integer, integer, integer, "text", "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp("text", "text", integer, integer, "text", "text", "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2("text", "text", integer, integer, "text", "text", "text", "text"); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "start_after" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text", "sort_column" "text" DEFAULT 'name'::"text", "sort_column_after" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION "storage"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."audit_log_entries" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "payload" json,
    "created_at" timestamp with time zone,
    "ip_address" character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE "audit_log_entries"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."audit_log_entries" IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."flow_state" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid",
    "auth_code" "text",
    "code_challenge_method" "auth"."code_challenge_method",
    "code_challenge" "text",
    "provider_type" "text" NOT NULL,
    "provider_access_token" "text",
    "provider_refresh_token" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "authentication_method" "text" NOT NULL,
    "auth_code_issued_at" timestamp with time zone,
    "invite_token" "text",
    "referrer" "text",
    "oauth_client_state_id" "uuid",
    "linking_target_id" "uuid",
    "email_optional" boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE "flow_state"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."flow_state" IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."identities" (
    "provider_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "identity_data" "jsonb" NOT NULL,
    "provider" "text" NOT NULL,
    "last_sign_in_at" timestamp with time zone,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "email" "text" GENERATED ALWAYS AS ("lower"(("identity_data" ->> 'email'::"text"))) STORED,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


--
-- Name: TABLE "identities"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."identities" IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN "identities"."email"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."identities"."email" IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."instances" (
    "id" "uuid" NOT NULL,
    "uuid" "uuid",
    "raw_base_config" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


--
-- Name: TABLE "instances"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."instances" IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."mfa_amr_claims" (
    "session_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "authentication_method" "text" NOT NULL,
    "id" "uuid" NOT NULL
);


--
-- Name: TABLE "mfa_amr_claims"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."mfa_amr_claims" IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."mfa_challenges" (
    "id" "uuid" NOT NULL,
    "factor_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "verified_at" timestamp with time zone,
    "ip_address" "inet" NOT NULL,
    "otp_code" "text",
    "web_authn_session_data" "jsonb"
);


--
-- Name: TABLE "mfa_challenges"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."mfa_challenges" IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."mfa_factors" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "friendly_name" "text",
    "factor_type" "auth"."factor_type" NOT NULL,
    "status" "auth"."factor_status" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "secret" "text",
    "phone" "text",
    "last_challenged_at" timestamp with time zone,
    "web_authn_credential" "jsonb",
    "web_authn_aaguid" "uuid",
    "last_webauthn_challenge_data" "jsonb"
);


--
-- Name: TABLE "mfa_factors"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."mfa_factors" IS 'auth: stores metadata about factors';


--
-- Name: COLUMN "mfa_factors"."last_webauthn_challenge_data"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."mfa_factors"."last_webauthn_challenge_data" IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."oauth_authorizations" (
    "id" "uuid" NOT NULL,
    "authorization_id" "text" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "redirect_uri" "text" NOT NULL,
    "scope" "text" NOT NULL,
    "state" "text",
    "resource" "text",
    "code_challenge" "text",
    "code_challenge_method" "auth"."code_challenge_method",
    "response_type" "auth"."oauth_response_type" DEFAULT 'code'::"auth"."oauth_response_type" NOT NULL,
    "status" "auth"."oauth_authorization_status" DEFAULT 'pending'::"auth"."oauth_authorization_status" NOT NULL,
    "authorization_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:03:00'::interval) NOT NULL,
    "approved_at" timestamp with time zone,
    "nonce" "text",
    CONSTRAINT "oauth_authorizations_authorization_code_length" CHECK (("char_length"("authorization_code") <= 255)),
    CONSTRAINT "oauth_authorizations_code_challenge_length" CHECK (("char_length"("code_challenge") <= 128)),
    CONSTRAINT "oauth_authorizations_expires_at_future" CHECK (("expires_at" > "created_at")),
    CONSTRAINT "oauth_authorizations_nonce_length" CHECK (("char_length"("nonce") <= 255)),
    CONSTRAINT "oauth_authorizations_redirect_uri_length" CHECK (("char_length"("redirect_uri") <= 2048)),
    CONSTRAINT "oauth_authorizations_resource_length" CHECK (("char_length"("resource") <= 2048)),
    CONSTRAINT "oauth_authorizations_scope_length" CHECK (("char_length"("scope") <= 4096)),
    CONSTRAINT "oauth_authorizations_state_length" CHECK (("char_length"("state") <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."oauth_client_states" (
    "id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "code_verifier" "text",
    "created_at" timestamp with time zone NOT NULL
);


--
-- Name: TABLE "oauth_client_states"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."oauth_client_states" IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."oauth_clients" (
    "id" "uuid" NOT NULL,
    "client_secret_hash" "text",
    "registration_type" "auth"."oauth_registration_type" NOT NULL,
    "redirect_uris" "text" NOT NULL,
    "grant_types" "text" NOT NULL,
    "client_name" "text",
    "client_uri" "text",
    "logo_uri" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "client_type" "auth"."oauth_client_type" DEFAULT 'confidential'::"auth"."oauth_client_type" NOT NULL,
    "token_endpoint_auth_method" "text" NOT NULL,
    CONSTRAINT "oauth_clients_client_name_length" CHECK (("char_length"("client_name") <= 1024)),
    CONSTRAINT "oauth_clients_client_uri_length" CHECK (("char_length"("client_uri") <= 2048)),
    CONSTRAINT "oauth_clients_logo_uri_length" CHECK (("char_length"("logo_uri") <= 2048)),
    CONSTRAINT "oauth_clients_token_endpoint_auth_method_check" CHECK (("token_endpoint_auth_method" = ANY (ARRAY['client_secret_basic'::"text", 'client_secret_post'::"text", 'none'::"text"])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."oauth_consents" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "scopes" "text" NOT NULL,
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone,
    CONSTRAINT "oauth_consents_revoked_after_granted" CHECK ((("revoked_at" IS NULL) OR ("revoked_at" >= "granted_at"))),
    CONSTRAINT "oauth_consents_scopes_length" CHECK (("char_length"("scopes") <= 2048)),
    CONSTRAINT "oauth_consents_scopes_not_empty" CHECK (("char_length"(TRIM(BOTH FROM "scopes")) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."one_time_tokens" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token_type" "auth"."one_time_token_type" NOT NULL,
    "token_hash" "text" NOT NULL,
    "relates_to" "text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "one_time_tokens_token_hash_check" CHECK (("char_length"("token_hash") > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."refresh_tokens" (
    "instance_id" "uuid",
    "id" bigint NOT NULL,
    "token" character varying(255),
    "user_id" character varying(255),
    "revoked" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "parent" character varying(255),
    "session_id" "uuid"
);


--
-- Name: TABLE "refresh_tokens"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."refresh_tokens" IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE "auth"."refresh_tokens_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE "auth"."refresh_tokens_id_seq" OWNED BY "auth"."refresh_tokens"."id";


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."saml_providers" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "entity_id" "text" NOT NULL,
    "metadata_xml" "text" NOT NULL,
    "metadata_url" "text",
    "attribute_mapping" "jsonb",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "name_id_format" "text",
    CONSTRAINT "entity_id not empty" CHECK (("char_length"("entity_id") > 0)),
    CONSTRAINT "metadata_url not empty" CHECK ((("metadata_url" = NULL::"text") OR ("char_length"("metadata_url") > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK (("char_length"("metadata_xml") > 0))
);


--
-- Name: TABLE "saml_providers"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."saml_providers" IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."saml_relay_states" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "request_id" "text" NOT NULL,
    "for_email" "text",
    "redirect_to" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "flow_state_id" "uuid",
    CONSTRAINT "request_id not empty" CHECK (("char_length"("request_id") > 0))
);


--
-- Name: TABLE "saml_relay_states"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."saml_relay_states" IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."schema_migrations" (
    "version" character varying(255) NOT NULL
);


--
-- Name: TABLE "schema_migrations"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."schema_migrations" IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."sessions" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "factor_id" "uuid",
    "aal" "auth"."aal_level",
    "not_after" timestamp with time zone,
    "refreshed_at" timestamp without time zone,
    "user_agent" "text",
    "ip" "inet",
    "tag" "text",
    "oauth_client_id" "uuid",
    "refresh_token_hmac_key" "text",
    "refresh_token_counter" bigint,
    "scopes" "text",
    CONSTRAINT "sessions_scopes_length" CHECK (("char_length"("scopes") <= 4096))
);


--
-- Name: TABLE "sessions"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."sessions" IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN "sessions"."not_after"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."sessions"."not_after" IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN "sessions"."refresh_token_hmac_key"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."sessions"."refresh_token_hmac_key" IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN "sessions"."refresh_token_counter"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."sessions"."refresh_token_counter" IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."sso_domains" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK (("char_length"("domain") > 0))
);


--
-- Name: TABLE "sso_domains"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."sso_domains" IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."sso_providers" (
    "id" "uuid" NOT NULL,
    "resource_id" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "disabled" boolean,
    CONSTRAINT "resource_id not empty" CHECK ((("resource_id" = NULL::"text") OR ("char_length"("resource_id") > 0)))
);


--
-- Name: TABLE "sso_providers"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."sso_providers" IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN "sso_providers"."resource_id"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."sso_providers"."resource_id" IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE "auth"."users" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "aud" character varying(255),
    "role" character varying(255),
    "email" character varying(255),
    "encrypted_password" character varying(255),
    "email_confirmed_at" timestamp with time zone,
    "invited_at" timestamp with time zone,
    "confirmation_token" character varying(255),
    "confirmation_sent_at" timestamp with time zone,
    "recovery_token" character varying(255),
    "recovery_sent_at" timestamp with time zone,
    "email_change_token_new" character varying(255),
    "email_change" character varying(255),
    "email_change_sent_at" timestamp with time zone,
    "last_sign_in_at" timestamp with time zone,
    "raw_app_meta_data" "jsonb",
    "raw_user_meta_data" "jsonb",
    "is_super_admin" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "phone" "text" DEFAULT NULL::character varying,
    "phone_confirmed_at" timestamp with time zone,
    "phone_change" "text" DEFAULT ''::character varying,
    "phone_change_token" character varying(255) DEFAULT ''::character varying,
    "phone_change_sent_at" timestamp with time zone,
    "confirmed_at" timestamp with time zone GENERATED ALWAYS AS (LEAST("email_confirmed_at", "phone_confirmed_at")) STORED,
    "email_change_token_current" character varying(255) DEFAULT ''::character varying,
    "email_change_confirm_status" smallint DEFAULT 0,
    "banned_until" timestamp with time zone,
    "reauthentication_token" character varying(255) DEFAULT ''::character varying,
    "reauthentication_sent_at" timestamp with time zone,
    "is_sso_user" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "is_anonymous" boolean DEFAULT false NOT NULL,
    CONSTRAINT "users_email_change_confirm_status_check" CHECK ((("email_change_confirm_status" >= 0) AND ("email_change_confirm_status" <= 2)))
);


--
-- Name: TABLE "users"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE "auth"."users" IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN "users"."is_sso_user"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN "auth"."users"."is_sso_user" IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: account_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."account_metadata" (
    "type" "text" NOT NULL,
    "value" "text" NOT NULL,
    "frequency" bigint DEFAULT 1
);


--
-- Name: bank_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions" (
    "id" integer NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE ("date");


--
-- Name: bank_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."bank_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bank_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."bank_transactions_id_seq" OWNED BY "public"."bank_transactions"."id";


--
-- Name: bank_transactions_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2024" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2025" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2026" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2027" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2028" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2029" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2030" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_2031" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bank_transactions_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."bank_transactions_default" (
    "id" integer DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "bank_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: banks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."banks" (
    "id" integer NOT NULL,
    "company_id" "text",
    "code" "text",
    "name" "text",
    "balance" numeric(15,2) DEFAULT 0,
    "currency" "text",
    "branch_code" "text",
    "branch_name" "text",
    "account_no" "text",
    "iban" "text",
    "info1" "text",
    "info2" "text",
    "is_active" integer DEFAULT 1,
    "is_default" integer DEFAULT 0,
    "search_tags" "text",
    "matched_in_hidden" integer DEFAULT 0
);


--
-- Name: banks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."banks_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: banks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."banks_id_seq" OWNED BY "public"."banks"."id";


--
-- Name: cash_register_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions" (
    "id" integer NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE ("date");


--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."cash_register_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."cash_register_transactions_id_seq" OWNED BY "public"."cash_register_transactions"."id";


--
-- Name: cash_register_transactions_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2024" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2025" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2026" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2027" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2028" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2029" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2030" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_2031" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_register_transactions_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_register_transactions_default" (
    "id" integer DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "cash_register_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cash_registers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cash_registers" (
    "id" integer NOT NULL,
    "company_id" "text",
    "code" "text",
    "name" "text",
    "balance" numeric(15,2) DEFAULT 0,
    "currency" "text",
    "info1" "text",
    "info2" "text",
    "is_active" integer DEFAULT 1,
    "is_default" integer DEFAULT 0,
    "search_tags" "text",
    "matched_in_hidden" integer DEFAULT 0
);


--
-- Name: cash_registers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."cash_registers_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cash_registers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."cash_registers_id_seq" OWNED BY "public"."cash_registers"."id";


--
-- Name: current_account_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."current_account_transactions" (
    "id" integer NOT NULL,
    "current_account_id" integer NOT NULL,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric DEFAULT 0,
    "type" "text",
    "source_type" "text",
    "source_id" integer,
    "user_name" "text",
    "source_name" "text",
    "source_code" "text",
    "integration_ref" "text",
    "urun_adi" "text",
    "miktar" numeric DEFAULT 0,
    "birim" "text",
    "birim_fiyat" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kur" numeric DEFAULT 1,
    "e_belge" "text",
    "irsaliye_no" "text",
    "fatura_no" "text",
    "aciklama2" "text",
    "vade_tarihi" timestamp without time zone,
    "ham_fiyat" numeric DEFAULT 0,
    "iskonto" numeric DEFAULT 0,
    "bakiye_borc" numeric DEFAULT 0,
    "bakiye_alacak" numeric DEFAULT 0,
    "belge" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE ("date");


--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."current_account_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."current_account_transactions_id_seq" OWNED BY "public"."current_account_transactions"."id";


--
-- Name: cat_y2026_m02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cat_y2026_m02" (
    "id" integer DEFAULT "nextval"('"public"."current_account_transactions_id_seq"'::"regclass") NOT NULL,
    "current_account_id" integer NOT NULL,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric DEFAULT 0,
    "type" "text",
    "source_type" "text",
    "source_id" integer,
    "user_name" "text",
    "source_name" "text",
    "source_code" "text",
    "integration_ref" "text",
    "urun_adi" "text",
    "miktar" numeric DEFAULT 0,
    "birim" "text",
    "birim_fiyat" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kur" numeric DEFAULT 1,
    "e_belge" "text",
    "irsaliye_no" "text",
    "fatura_no" "text",
    "aciklama2" "text",
    "vade_tarihi" timestamp without time zone,
    "ham_fiyat" numeric DEFAULT 0,
    "iskonto" numeric DEFAULT 0,
    "bakiye_borc" numeric DEFAULT 0,
    "bakiye_alacak" numeric DEFAULT 0,
    "belge" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cat_y2026_m03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cat_y2026_m03" (
    "id" integer DEFAULT "nextval"('"public"."current_account_transactions_id_seq"'::"regclass") NOT NULL,
    "current_account_id" integer NOT NULL,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric DEFAULT 0,
    "type" "text",
    "source_type" "text",
    "source_id" integer,
    "user_name" "text",
    "source_name" "text",
    "source_code" "text",
    "integration_ref" "text",
    "urun_adi" "text",
    "miktar" numeric DEFAULT 0,
    "birim" "text",
    "birim_fiyat" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kur" numeric DEFAULT 1,
    "e_belge" "text",
    "irsaliye_no" "text",
    "fatura_no" "text",
    "aciklama2" "text",
    "vade_tarihi" timestamp without time zone,
    "ham_fiyat" numeric DEFAULT 0,
    "iskonto" numeric DEFAULT 0,
    "bakiye_borc" numeric DEFAULT 0,
    "bakiye_alacak" numeric DEFAULT 0,
    "belge" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cheque_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cheque_transactions" (
    "id" integer NOT NULL,
    "company_id" "text",
    "cheque_id" integer,
    "date" timestamp without time zone,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "source_dest" "text",
    "user_name" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "search_tags" "text",
    "integration_ref" "text"
);


--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."cheque_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."cheque_transactions_id_seq" OWNED BY "public"."cheque_transactions"."id";


--
-- Name: cheques; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."cheques" (
    "id" integer NOT NULL,
    "company_id" "text",
    "type" "text",
    "collection_status" "text",
    "customer_code" "text",
    "customer_name" "text",
    "issue_date" timestamp without time zone,
    "due_date" timestamp without time zone,
    "amount" numeric(15,2) DEFAULT 0,
    "currency" "text",
    "check_no" "text",
    "bank" "text",
    "description" "text",
    "user_name" "text",
    "is_active" integer DEFAULT 1,
    "search_tags" "text",
    "matched_in_hidden" integer DEFAULT 0,
    "integration_ref" "text"
);


--
-- Name: cheques_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."cheques_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cheques_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."cheques_id_seq" OWNED BY "public"."cheques"."id";


--
-- Name: company_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."company_settings" (
    "id" integer NOT NULL,
    "kod" "text",
    "ad" "text",
    "basliklar" "text",
    "logolar" "text",
    "adres" "text",
    "vergi_dairesi" "text",
    "vergi_no" "text",
    "telefon" "text",
    "eposta" "text",
    "web_adresi" "text",
    "aktif_mi" integer,
    "varsayilan_mi" integer,
    "duzenlenebilir_mi" integer,
    "ust_bilgi_logosu" "text",
    "ust_bilgi_satirlari" "text"
);


--
-- Name: company_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."company_settings_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."company_settings_id_seq" OWNED BY "public"."company_settings"."id";


--
-- Name: credit_card_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions" (
    "id" integer NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE ("date");


--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."credit_card_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."credit_card_transactions_id_seq" OWNED BY "public"."credit_card_transactions"."id";


--
-- Name: credit_card_transactions_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2024" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2025" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2026" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2027" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2028" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2029" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2030" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_2031" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_card_transactions_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_card_transactions_default" (
    "id" integer DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass") NOT NULL,
    "company_id" "text",
    "credit_card_id" integer,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "location" "text",
    "location_code" "text",
    "location_name" "text",
    "user_name" "text",
    "integration_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."credit_cards" (
    "id" integer NOT NULL,
    "company_id" "text",
    "code" "text",
    "name" "text",
    "balance" numeric(15,2) DEFAULT 0,
    "currency" "text",
    "branch_code" "text",
    "branch_name" "text",
    "account_no" "text",
    "iban" "text",
    "info1" "text",
    "info2" "text",
    "is_active" integer DEFAULT 1,
    "is_default" integer DEFAULT 0,
    "search_tags" "text",
    "matched_in_hidden" integer DEFAULT 0
);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."credit_cards_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."credit_cards_id_seq" OWNED BY "public"."credit_cards"."id";


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."currency_rates" (
    "id" integer NOT NULL,
    "from_code" "text",
    "to_code" "text",
    "rate" real,
    "update_time" "text"
);


--
-- Name: currency_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."currency_rates_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: currency_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."currency_rates_id_seq" OWNED BY "public"."currency_rates"."id";


--
-- Name: current_account_transactions_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."current_account_transactions_default" (
    "id" integer DEFAULT "nextval"('"public"."current_account_transactions_id_seq"'::"regclass") NOT NULL,
    "current_account_id" integer NOT NULL,
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "amount" numeric DEFAULT 0,
    "type" "text",
    "source_type" "text",
    "source_id" integer,
    "user_name" "text",
    "source_name" "text",
    "source_code" "text",
    "integration_ref" "text",
    "urun_adi" "text",
    "miktar" numeric DEFAULT 0,
    "birim" "text",
    "birim_fiyat" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kur" numeric DEFAULT 1,
    "e_belge" "text",
    "irsaliye_no" "text",
    "fatura_no" "text",
    "aciklama2" "text",
    "vade_tarihi" timestamp without time zone,
    "ham_fiyat" numeric DEFAULT 0,
    "iskonto" numeric DEFAULT 0,
    "bakiye_borc" numeric DEFAULT 0,
    "bakiye_alacak" numeric DEFAULT 0,
    "belge" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: current_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."current_accounts" (
    "id" integer NOT NULL,
    "kod_no" "text" NOT NULL,
    "adi" "text" NOT NULL,
    "hesap_turu" "text",
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "bakiye_borc" numeric DEFAULT 0,
    "bakiye_alacak" numeric DEFAULT 0,
    "bakiye_durumu" "text" DEFAULT 'Borç'::"text",
    "telefon1" "text",
    "fat_sehir" "text",
    "aktif_mi" integer DEFAULT 1,
    "fat_unvani" "text",
    "fat_adresi" "text",
    "fat_ilce" "text",
    "posta_kodu" "text",
    "v_dairesi" "text",
    "v_numarasi" "text",
    "sf_grubu" "text",
    "s_iskonto" numeric DEFAULT 0,
    "vade_gun" integer DEFAULT 0,
    "risk_limiti" numeric DEFAULT 0,
    "telefon2" "text",
    "eposta" "text",
    "web_adresi" "text",
    "bilgi1" "text",
    "bilgi2" "text",
    "bilgi3" "text",
    "bilgi4" "text",
    "bilgi5" "text",
    "sevk_adresleri" "text",
    "resimler" "jsonb" DEFAULT '[]'::"jsonb",
    "renk" "text",
    "search_tags" "text",
    "created_by" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: current_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."current_accounts_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: current_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."current_accounts_id_seq" OWNED BY "public"."current_accounts"."id";


--
-- Name: depots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."depots" (
    "id" integer NOT NULL,
    "kod" "text" NOT NULL,
    "ad" "text" NOT NULL,
    "adres" "text",
    "sorumlu" "text",
    "telefon" "text",
    "aktif_mi" integer DEFAULT 1,
    "search_tags" "text",
    "created_by" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: depots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."depots_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: depots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."depots_id_seq" OWNED BY "public"."depots"."id";


--
-- Name: expense_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."expense_items" (
    "id" integer NOT NULL,
    "expense_id" integer NOT NULL,
    "aciklama" "text" DEFAULT ''::"text",
    "tutar" numeric DEFAULT 0,
    "not_metni" "text" DEFAULT ''::"text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: expense_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."expense_items_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expense_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."expense_items_id_seq" OWNED BY "public"."expense_items"."id";


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."expenses" (
    "id" integer NOT NULL,
    "kod" "text" NOT NULL,
    "baslik" "text" NOT NULL,
    "tutar" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "odeme_durumu" "text" DEFAULT 'Beklemede'::"text",
    "kategori" "text" DEFAULT ''::"text",
    "aciklama" "text" DEFAULT ''::"text",
    "not_metni" "text" DEFAULT ''::"text",
    "resimler" "jsonb" DEFAULT '[]'::"jsonb",
    "ai_islenmis_mi" boolean DEFAULT false,
    "ai_verileri" "jsonb",
    "aktif_mi" integer DEFAULT 1,
    "search_tags" "text",
    "kullanici" "text" DEFAULT ''::"text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."expenses_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."expenses_id_seq" OWNED BY "public"."expenses"."id";


--
-- Name: general_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."general_settings" (
    "key" "text" NOT NULL,
    "value" "text"
);


--
-- Name: hidden_descriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."hidden_descriptions" (
    "category" "text" NOT NULL,
    "content" "text" NOT NULL
);


--
-- Name: installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."installments" (
    "id" integer NOT NULL,
    "integration_ref" "text" NOT NULL,
    "cari_id" integer NOT NULL,
    "vade_tarihi" timestamp without time zone NOT NULL,
    "tutar" numeric NOT NULL,
    "durum" "text" DEFAULT 'Bekliyor'::"text",
    "aciklama" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "hareket_id" integer
);


--
-- Name: installments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."installments_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: installments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."installments_id_seq" OWNED BY "public"."installments"."id";


--
-- Name: note_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."note_transactions" (
    "id" integer NOT NULL,
    "company_id" "text",
    "note_id" integer,
    "date" timestamp without time zone,
    "description" "text",
    "amount" numeric(15,2) DEFAULT 0,
    "type" "text",
    "source_dest" "text",
    "user_name" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "search_tags" "text",
    "integration_ref" "text"
);


--
-- Name: note_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."note_transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."note_transactions_id_seq" OWNED BY "public"."note_transactions"."id";


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."order_items" (
    "id" integer NOT NULL,
    "order_id" integer NOT NULL,
    "urun_id" integer,
    "urun_kodu" "text" NOT NULL,
    "urun_adi" "text" NOT NULL,
    "barkod" "text",
    "depo_id" integer,
    "depo_adi" "text",
    "kdv_orani" numeric DEFAULT 0,
    "miktar" numeric DEFAULT 0,
    "birim" "text" DEFAULT 'Adet'::"text",
    "birim_fiyati" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kdv_durumu" "text" DEFAULT 'excluded'::"text",
    "iskonto" numeric DEFAULT 0,
    "toplam_fiyati" numeric DEFAULT 0,
    "delivered_quantity" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."order_items_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."order_items_id_seq" OWNED BY "public"."order_items"."id";


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."orders" (
    "id" integer NOT NULL,
    "integration_ref" "text",
    "order_no" "text",
    "tur" "text" DEFAULT 'Satış Siparişi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "sales_ref" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
)
PARTITION BY RANGE ("tarih");


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."orders_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."orders_id_seq" OWNED BY "public"."orders"."id";


--
-- Name: orders_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."orders_default" (
    "id" integer DEFAULT "nextval"('"public"."orders_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "order_no" "text",
    "tur" "text" DEFAULT 'Satış Siparişi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "sales_ref" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: orders_y2026_m02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."orders_y2026_m02" (
    "id" integer DEFAULT "nextval"('"public"."orders_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "order_no" "text",
    "tur" "text" DEFAULT 'Satış Siparişi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "sales_ref" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: orders_y2026_m03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."orders_y2026_m03" (
    "id" integer DEFAULT "nextval"('"public"."orders_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "order_no" "text",
    "tur" "text" DEFAULT 'Satış Siparişi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "sales_ref" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: print_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."print_templates" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL,
    "doc_type" "text" NOT NULL,
    "paper_size" "text",
    "custom_width" real,
    "custom_height" real,
    "item_row_spacing" real DEFAULT 1.0,
    "background_image" "text",
    "background_opacity" real DEFAULT 0.5,
    "background_x" real DEFAULT 0.0,
    "background_y" real DEFAULT 0.0,
    "background_width" real,
    "background_height" real,
    "layout_json" "text",
    "is_default" integer DEFAULT 0,
    "is_landscape" integer DEFAULT 0,
    "view_matrix" "text"
);


--
-- Name: print_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."print_templates_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: print_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."print_templates_id_seq" OWNED BY "public"."print_templates"."id";


--
-- Name: product_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."product_devices" (
    "id" integer NOT NULL,
    "product_id" integer,
    "identity_type" "text" NOT NULL,
    "identity_value" "text" NOT NULL,
    "condition" "text" DEFAULT 'Sıfır'::"text",
    "color" "text",
    "capacity" "text",
    "warranty_end_date" timestamp without time zone,
    "has_box" integer DEFAULT 0,
    "has_invoice" integer DEFAULT 0,
    "has_original_charger" integer DEFAULT 0,
    "is_sold" integer DEFAULT 0,
    "sale_ref" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: product_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."product_devices_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."product_devices_id_seq" OWNED BY "public"."product_devices"."id";


--
-- Name: product_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."product_metadata" (
    "type" "text" NOT NULL,
    "value" "text" NOT NULL,
    "frequency" bigint DEFAULT 1
);


--
-- Name: production_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_metadata" (
    "type" "text" NOT NULL,
    "value" "text" NOT NULL,
    "frequency" bigint DEFAULT 1
);


--
-- Name: production_recipe_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_recipe_items" (
    "id" integer NOT NULL,
    "production_id" integer NOT NULL,
    "product_code" "text" NOT NULL,
    "product_name" "text" NOT NULL,
    "unit" "text" NOT NULL,
    "quantity" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."production_recipe_items_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."production_recipe_items_id_seq" OWNED BY "public"."production_recipe_items"."id";


--
-- Name: production_stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements" (
    "id" integer NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE ("created_at");


--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."production_stock_movements_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."production_stock_movements_id_seq" OWNED BY "public"."production_stock_movements"."id";


--
-- Name: production_stock_movements_2020; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2020" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2021; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2021" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2022; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2022" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2023; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2023" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2024" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2025" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2026" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2027" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2028" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2029" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2030" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2031" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2032; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2032" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2033; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2033" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2034; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2034" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2035; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2035" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_2036; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_2036" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: production_stock_movements_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."production_stock_movements_default" (
    "id" integer DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass") NOT NULL,
    "production_id" integer NOT NULL,
    "warehouse_id" integer NOT NULL,
    "quantity" numeric DEFAULT 0,
    "unit_price" numeric DEFAULT 0,
    "currency" "text" DEFAULT 'TRY'::"text",
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "consumed_items" "jsonb",
    "related_shipment_ids" "jsonb",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: productions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."productions" (
    "id" integer NOT NULL,
    "kod" "text" NOT NULL,
    "ad" "text" NOT NULL,
    "birim" "text" DEFAULT 'Adet'::"text",
    "alis_fiyati" numeric DEFAULT 0,
    "satis_fiyati_1" numeric DEFAULT 0,
    "satis_fiyati_2" numeric DEFAULT 0,
    "satis_fiyati_3" numeric DEFAULT 0,
    "kdv_orani" numeric DEFAULT 18,
    "stok" numeric DEFAULT 0,
    "erken_uyari_miktari" numeric DEFAULT 0,
    "grubu" "text",
    "ozellikler" "text",
    "barkod" "text",
    "kullanici" "text",
    "resim_url" "text",
    "resimler" "jsonb" DEFAULT '[]'::"jsonb",
    "aktif_mi" integer DEFAULT 1,
    "search_tags" "text",
    "created_by" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: productions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."productions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: productions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."productions_id_seq" OWNED BY "public"."productions"."id";


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."products" (
    "id" integer NOT NULL,
    "kod" "text" NOT NULL,
    "ad" "text" NOT NULL,
    "birim" "text" DEFAULT 'Adet'::"text",
    "alis_fiyati" numeric DEFAULT 0,
    "satis_fiyati_1" numeric DEFAULT 0,
    "satis_fiyati_2" numeric DEFAULT 0,
    "satis_fiyati_3" numeric DEFAULT 0,
    "kdv_orani" numeric DEFAULT 18,
    "stok" numeric DEFAULT 0,
    "erken_uyari_miktari" numeric DEFAULT 0,
    "grubu" "text",
    "ozellikler" "text",
    "barkod" "text",
    "kullanici" "text",
    "resim_url" "text",
    "resimler" "jsonb" DEFAULT '[]'::"jsonb",
    "aktif_mi" integer DEFAULT 1,
    "search_tags" "text",
    "created_by" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."products_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."products_id_seq" OWNED BY "public"."products"."id";


--
-- Name: promissory_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."promissory_notes" (
    "id" integer NOT NULL,
    "company_id" "text",
    "type" "text",
    "collection_status" "text",
    "customer_code" "text",
    "customer_name" "text",
    "issue_date" timestamp without time zone,
    "due_date" timestamp without time zone,
    "amount" numeric(15,2) DEFAULT 0,
    "currency" "text",
    "note_no" "text",
    "bank" "text",
    "description" "text",
    "user_name" "text",
    "is_active" integer DEFAULT 1,
    "search_tags" "text",
    "matched_in_hidden" integer DEFAULT 0,
    "integration_ref" "text"
);


--
-- Name: promissory_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."promissory_notes_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: promissory_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."promissory_notes_id_seq" OWNED BY "public"."promissory_notes"."id";


--
-- Name: quick_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quick_products" (
    "id" integer NOT NULL,
    "product_id" integer,
    "display_order" integer DEFAULT 0
);


--
-- Name: quick_products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."quick_products_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quick_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."quick_products_id_seq" OWNED BY "public"."quick_products"."id";


--
-- Name: quote_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quote_items" (
    "id" integer NOT NULL,
    "quote_id" integer NOT NULL,
    "urun_id" integer,
    "urun_kodu" "text" NOT NULL,
    "urun_adi" "text" NOT NULL,
    "barkod" "text",
    "depo_id" integer,
    "depo_adi" "text",
    "kdv_orani" numeric DEFAULT 0,
    "miktar" numeric DEFAULT 0,
    "birim" "text" DEFAULT 'Adet'::"text",
    "birim_fiyati" numeric DEFAULT 0,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kdv_durumu" "text" DEFAULT 'excluded'::"text",
    "iskonto" numeric DEFAULT 0,
    "toplam_fiyati" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: quote_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."quote_items_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."quote_items_id_seq" OWNED BY "public"."quote_items"."id";


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quotes" (
    "id" integer NOT NULL,
    "integration_ref" "text",
    "quote_no" "text",
    "tur" "text" DEFAULT 'Satış Teklifi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
)
PARTITION BY RANGE ("tarih");


--
-- Name: quotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."quotes_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."quotes_id_seq" OWNED BY "public"."quotes"."id";


--
-- Name: quotes_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quotes_default" (
    "id" integer DEFAULT "nextval"('"public"."quotes_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "quote_no" "text",
    "tur" "text" DEFAULT 'Satış Teklifi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: quotes_y2026_m02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quotes_y2026_m02" (
    "id" integer DEFAULT "nextval"('"public"."quotes_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "quote_no" "text",
    "tur" "text" DEFAULT 'Satış Teklifi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: quotes_y2026_m03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."quotes_y2026_m03" (
    "id" integer DEFAULT "nextval"('"public"."quotes_id_seq"'::"regclass") NOT NULL,
    "integration_ref" "text",
    "quote_no" "text",
    "tur" "text" DEFAULT 'Satış Teklifi'::"text" NOT NULL,
    "durum" "text" DEFAULT 'Beklemede'::"text" NOT NULL,
    "tarih" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cari_id" integer,
    "cari_kod" "text",
    "cari_adi" "text",
    "ilgili_hesap_adi" "text",
    "tutar" numeric DEFAULT 0,
    "kur" numeric DEFAULT 1,
    "aciklama" "text",
    "aciklama2" "text",
    "gecerlilik_tarihi" timestamp without time zone,
    "para_birimi" "text" DEFAULT 'TRY'::"text",
    "kullanici" "text",
    "search_tags" "text",
    "stok_rezerve_mi" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."roles" (
    "id" "text" NOT NULL,
    "name" "text",
    "permissions" "text",
    "is_system" integer,
    "is_active" integer
);


--
-- Name: saved_descriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."saved_descriptions" (
    "id" integer NOT NULL,
    "category" "text" NOT NULL,
    "content" "text" NOT NULL,
    "usage_count" integer DEFAULT 1,
    "last_used" "text"
);


--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."saved_descriptions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."saved_descriptions_id_seq" OWNED BY "public"."saved_descriptions"."id";


--
-- Name: sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."sequences" (
    "name" "text" NOT NULL,
    "current_value" bigint DEFAULT 0
);


--
-- Name: shipments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."shipments" (
    "id" integer NOT NULL,
    "source_warehouse_id" integer,
    "dest_warehouse_id" integer,
    "date" timestamp without time zone,
    "description" "text",
    "items" "jsonb",
    "integration_ref" "text",
    "created_by" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: shipments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."shipments_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shipments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."shipments_id_seq" OWNED BY "public"."shipments"."id";


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements" (
    "id" integer NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE ("created_at");


--
-- Name: stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."stock_movements_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."stock_movements_id_seq" OWNED BY "public"."stock_movements"."id";


--
-- Name: stock_movements_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2025" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2026" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2027" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2028" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2029" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2030" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_2031" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stock_movements_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."stock_movements_default" (
    "id" integer DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass") NOT NULL,
    "product_id" integer,
    "warehouse_id" integer,
    "shipment_id" integer,
    "quantity" numeric DEFAULT 0,
    "is_giris" boolean DEFAULT true NOT NULL,
    "unit_price" numeric DEFAULT 0,
    "currency_code" "text" DEFAULT 'TRY'::"text",
    "currency_rate" numeric DEFAULT 1,
    "vat_status" "text" DEFAULT 'excluded'::"text",
    "movement_date" timestamp without time zone NOT NULL,
    "description" "text",
    "movement_type" "text",
    "created_by" "text",
    "integration_ref" "text",
    "running_cost" numeric DEFAULT 0,
    "running_stock" numeric DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sync_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."sync_outbox" (
    "id" integer NOT NULL,
    "target_db" "text",
    "operation" "text",
    "payload" "jsonb",
    "status" "text" DEFAULT 'pending'::"text",
    "retry_count" integer DEFAULT 0,
    "last_error" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone
);


--
-- Name: sync_outbox_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "public"."sync_outbox_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sync_outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "public"."sync_outbox_id_seq" OWNED BY "public"."sync_outbox"."id";


--
-- Name: table_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."table_counts" (
    "table_name" "text" NOT NULL,
    "row_count" bigint DEFAULT 0
);


--
-- Name: user_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
)
PARTITION BY RANGE ("date");


--
-- Name: user_transactions_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2024" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2025; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2025" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2026; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2026" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2027; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2027" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2028; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2028" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2029; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2029" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2030; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2030" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_2031; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_2031" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: user_transactions_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."user_transactions_default" (
    "id" "text" NOT NULL,
    "company_id" "text",
    "user_id" "text",
    "date" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "description" "text",
    "debt" numeric(15,2) DEFAULT 0,
    "credit" numeric(15,2) DEFAULT 0,
    "type" "text"
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."users" (
    "id" "text" NOT NULL,
    "username" "text",
    "name" "text",
    "surname" "text",
    "email" "text",
    "role" "text",
    "is_active" integer,
    "phone" "text",
    "profile_image" "text",
    "password" "text",
    "hire_date" "text",
    "position" "text",
    "salary" real,
    "salary_currency" "text",
    "address" "text",
    "info1" "text",
    "info2" "text",
    "balance_debt" real DEFAULT 0,
    "balance_credit" real DEFAULT 0
);


--
-- Name: warehouse_stocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."warehouse_stocks" (
    "warehouse_id" integer NOT NULL,
    "product_code" "text" NOT NULL,
    "quantity" numeric DEFAULT 0,
    "reserved_quantity" numeric DEFAULT 0,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE "realtime"."messages" (
    "topic" "text" NOT NULL,
    "extension" "text" NOT NULL,
    "payload" "jsonb",
    "event" "text",
    "private" boolean DEFAULT false,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "inserted_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
)
PARTITION BY RANGE ("inserted_at");


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE "realtime"."schema_migrations" (
    "version" bigint NOT NULL,
    "inserted_at" timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE "realtime"."subscription" (
    "id" bigint NOT NULL,
    "subscription_id" "uuid" NOT NULL,
    "entity" "regclass" NOT NULL,
    "filters" "realtime"."user_defined_filter"[] DEFAULT '{}'::"realtime"."user_defined_filter"[] NOT NULL,
    "claims" "jsonb" NOT NULL,
    "claims_role" "regrole" GENERATED ALWAYS AS ("realtime"."to_regrole"(("claims" ->> 'role'::"text"))) STORED NOT NULL,
    "created_at" timestamp without time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "action_filter" "text" DEFAULT '*'::"text",
    CONSTRAINT "subscription_action_filter_check" CHECK (("action_filter" = ANY (ARRAY['*'::"text", 'INSERT'::"text", 'UPDATE'::"text", 'DELETE'::"text"])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE "realtime"."subscription" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "realtime"."subscription_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."buckets" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "public" boolean DEFAULT false,
    "avif_autodetection" boolean DEFAULT false,
    "file_size_limit" bigint,
    "allowed_mime_types" "text"[],
    "owner_id" "text",
    "type" "storage"."buckettype" DEFAULT 'STANDARD'::"storage"."buckettype" NOT NULL
);


--
-- Name: COLUMN "buckets"."owner"; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN "storage"."buckets"."owner" IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."buckets_analytics" (
    "name" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'ANALYTICS'::"storage"."buckettype" NOT NULL,
    "format" "text" DEFAULT 'ICEBERG'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deleted_at" timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."buckets_vectors" (
    "id" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'VECTOR'::"storage"."buckettype" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."migrations" (
    "id" integer NOT NULL,
    "name" character varying(100) NOT NULL,
    "hash" character varying(40) NOT NULL,
    "executed_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."objects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bucket_id" "text",
    "name" "text",
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_accessed_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb",
    "path_tokens" "text"[] GENERATED ALWAYS AS ("string_to_array"("name", '/'::"text")) STORED,
    "version" "text",
    "owner_id" "text",
    "user_metadata" "jsonb"
);


--
-- Name: COLUMN "objects"."owner"; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN "storage"."objects"."owner" IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."s3_multipart_uploads" (
    "id" "text" NOT NULL,
    "in_progress_size" bigint DEFAULT 0 NOT NULL,
    "upload_signature" "text" NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "version" "text" NOT NULL,
    "owner_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_metadata" "jsonb"
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."s3_multipart_uploads_parts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "upload_id" "text" NOT NULL,
    "size" bigint DEFAULT 0 NOT NULL,
    "part_number" integer NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "etag" "text" NOT NULL,
    "owner_id" "text",
    "version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE "storage"."vector_indexes" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL COLLATE "pg_catalog"."C",
    "bucket_id" "text" NOT NULL,
    "data_type" "text" NOT NULL,
    "dimension" integer NOT NULL,
    "distance_metric" "text" NOT NULL,
    "metadata_configuration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: bank_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2024" FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: bank_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: bank_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: bank_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: bank_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: bank_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: bank_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: bank_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: bank_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ATTACH PARTITION "public"."bank_transactions_default" DEFAULT;


--
-- Name: cash_register_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2024" FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: cash_register_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: cash_register_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: cash_register_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: cash_register_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: cash_register_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: cash_register_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: cash_register_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: cash_register_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ATTACH PARTITION "public"."cash_register_transactions_default" DEFAULT;


--
-- Name: cat_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions" ATTACH PARTITION "public"."cat_y2026_m02" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: cat_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions" ATTACH PARTITION "public"."cat_y2026_m03" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: credit_card_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2024" FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: credit_card_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: credit_card_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: credit_card_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: credit_card_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: credit_card_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: credit_card_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: credit_card_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: credit_card_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ATTACH PARTITION "public"."credit_card_transactions_default" DEFAULT;


--
-- Name: current_account_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions" ATTACH PARTITION "public"."current_account_transactions_default" DEFAULT;


--
-- Name: orders_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders" ATTACH PARTITION "public"."orders_default" DEFAULT;


--
-- Name: orders_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders" ATTACH PARTITION "public"."orders_y2026_m02" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: orders_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders" ATTACH PARTITION "public"."orders_y2026_m03" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: production_stock_movements_2020; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2020" FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2021-01-01 00:00:00');


--
-- Name: production_stock_movements_2021; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2021" FOR VALUES FROM ('2021-01-01 00:00:00') TO ('2022-01-01 00:00:00');


--
-- Name: production_stock_movements_2022; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2022" FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2023-01-01 00:00:00');


--
-- Name: production_stock_movements_2023; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2023" FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2024-01-01 00:00:00');


--
-- Name: production_stock_movements_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2024" FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: production_stock_movements_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: production_stock_movements_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: production_stock_movements_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: production_stock_movements_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: production_stock_movements_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: production_stock_movements_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: production_stock_movements_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: production_stock_movements_2032; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2032" FOR VALUES FROM ('2032-01-01 00:00:00') TO ('2033-01-01 00:00:00');


--
-- Name: production_stock_movements_2033; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2033" FOR VALUES FROM ('2033-01-01 00:00:00') TO ('2034-01-01 00:00:00');


--
-- Name: production_stock_movements_2034; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2034" FOR VALUES FROM ('2034-01-01 00:00:00') TO ('2035-01-01 00:00:00');


--
-- Name: production_stock_movements_2035; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2035" FOR VALUES FROM ('2035-01-01 00:00:00') TO ('2036-01-01 00:00:00');


--
-- Name: production_stock_movements_2036; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_2036" FOR VALUES FROM ('2036-01-01 00:00:00') TO ('2037-01-01 00:00:00');


--
-- Name: production_stock_movements_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ATTACH PARTITION "public"."production_stock_movements_default" DEFAULT;


--
-- Name: quotes_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes" ATTACH PARTITION "public"."quotes_default" DEFAULT;


--
-- Name: quotes_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes" ATTACH PARTITION "public"."quotes_y2026_m02" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: quotes_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes" ATTACH PARTITION "public"."quotes_y2026_m03" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: stock_movements_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: stock_movements_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: stock_movements_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: stock_movements_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: stock_movements_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: stock_movements_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: stock_movements_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: stock_movements_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ATTACH PARTITION "public"."stock_movements_default" DEFAULT;


--
-- Name: user_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2024" FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: user_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2025" FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: user_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2026" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: user_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2027" FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: user_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2028" FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: user_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2029" FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: user_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2030" FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: user_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_2031" FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: user_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions" ATTACH PARTITION "public"."user_transactions_default" DEFAULT;


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."refresh_tokens" ALTER COLUMN "id" SET DEFAULT "nextval"('"auth"."refresh_tokens_id_seq"'::"regclass");


--
-- Name: bank_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."bank_transactions_id_seq"'::"regclass");


--
-- Name: banks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."banks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."banks_id_seq"'::"regclass");


--
-- Name: cash_register_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cash_register_transactions_id_seq"'::"regclass");


--
-- Name: cash_registers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_registers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cash_registers_id_seq"'::"regclass");


--
-- Name: cheque_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cheque_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cheque_transactions_id_seq"'::"regclass");


--
-- Name: cheques id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cheques" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cheques_id_seq"'::"regclass");


--
-- Name: company_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."company_settings" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."company_settings_id_seq"'::"regclass");


--
-- Name: credit_card_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."credit_card_transactions_id_seq"'::"regclass");


--
-- Name: credit_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_cards" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."credit_cards_id_seq"'::"regclass");


--
-- Name: currency_rates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."currency_rates" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."currency_rates_id_seq"'::"regclass");


--
-- Name: current_account_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."current_account_transactions_id_seq"'::"regclass");


--
-- Name: current_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_accounts" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."current_accounts_id_seq"'::"regclass");


--
-- Name: depots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."depots" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."depots_id_seq"'::"regclass");


--
-- Name: expense_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."expense_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."expense_items_id_seq"'::"regclass");


--
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."expenses" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."expenses_id_seq"'::"regclass");


--
-- Name: installments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."installments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."installments_id_seq"'::"regclass");


--
-- Name: note_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."note_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."note_transactions_id_seq"'::"regclass");


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."order_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."order_items_id_seq"'::"regclass");


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."orders_id_seq"'::"regclass");


--
-- Name: print_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."print_templates" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."print_templates_id_seq"'::"regclass");


--
-- Name: product_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."product_devices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_devices_id_seq"'::"regclass");


--
-- Name: production_recipe_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_recipe_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."production_recipe_items_id_seq"'::"regclass");


--
-- Name: production_stock_movements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."production_stock_movements_id_seq"'::"regclass");


--
-- Name: productions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."productions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."productions_id_seq"'::"regclass");


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."products" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."products_id_seq"'::"regclass");


--
-- Name: promissory_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."promissory_notes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."promissory_notes_id_seq"'::"regclass");


--
-- Name: quick_products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quick_products" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."quick_products_id_seq"'::"regclass");


--
-- Name: quote_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quote_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."quote_items_id_seq"'::"regclass");


--
-- Name: quotes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."quotes_id_seq"'::"regclass");


--
-- Name: saved_descriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."saved_descriptions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."saved_descriptions_id_seq"'::"regclass");


--
-- Name: shipments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."shipments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipments_id_seq"'::"regclass");


--
-- Name: stock_movements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass");


--
-- Name: sync_outbox id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."sync_outbox" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."sync_outbox_id_seq"'::"regclass");


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."audit_log_entries" ("instance_id", "id", "payload", "created_at", "ip_address") FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."flow_state" ("id", "user_id", "auth_code", "code_challenge_method", "code_challenge", "provider_type", "provider_access_token", "provider_refresh_token", "created_at", "updated_at", "authentication_method", "auth_code_issued_at", "invite_token", "referrer", "oauth_client_state_id", "linking_target_id", "email_optional") FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."instances" ("id", "uuid", "raw_base_config", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."mfa_challenges" ("id", "factor_id", "created_at", "verified_at", "ip_address", "otp_code", "web_authn_session_data") FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."mfa_factors" ("id", "user_id", "friendly_name", "factor_type", "status", "created_at", "updated_at", "secret", "phone", "last_challenged_at", "web_authn_credential", "web_authn_aaguid", "last_webauthn_challenge_data") FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."oauth_authorizations" ("id", "authorization_id", "client_id", "user_id", "redirect_uri", "scope", "state", "resource", "code_challenge", "code_challenge_method", "response_type", "status", "authorization_code", "created_at", "expires_at", "approved_at", "nonce") FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."oauth_client_states" ("id", "provider_type", "code_verifier", "created_at") FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."oauth_clients" ("id", "client_secret_hash", "registration_type", "redirect_uris", "grant_types", "client_name", "client_uri", "logo_uri", "created_at", "updated_at", "deleted_at", "client_type", "token_endpoint_auth_method") FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."oauth_consents" ("id", "user_id", "client_id", "scopes", "granted_at", "revoked_at") FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."one_time_tokens" ("id", "user_id", "token_type", "token_hash", "relates_to", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."saml_providers" ("id", "sso_provider_id", "entity_id", "metadata_xml", "metadata_url", "attribute_mapping", "created_at", "updated_at", "name_id_format") FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."saml_relay_states" ("id", "sso_provider_id", "request_id", "for_email", "redirect_to", "created_at", "updated_at", "flow_state_id") FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."schema_migrations" ("version") FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter", "scopes") FROM stdin;
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."sso_domains" ("id", "sso_provider_id", "domain", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."sso_providers" ("id", "resource_id", "created_at", "updated_at", "disabled") FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") FROM stdin;
\.


--
-- Data for Name: account_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."account_metadata" ("type", "value", "frequency") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2024; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2024" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2025" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2026" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2027" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2028" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2029" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2030" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_2031" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: bank_transactions_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."bank_transactions_default" ("id", "company_id", "bank_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."banks" ("id", "company_id", "code", "name", "balance", "currency", "branch_code", "branch_name", "account_no", "iban", "info1", "info2", "is_active", "is_default", "search_tags", "matched_in_hidden") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2024; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2024" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2025" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2026" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2027" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2028" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2029" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2030" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_2031" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_register_transactions_default" ("id", "company_id", "cash_register_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: cash_registers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cash_registers" ("id", "company_id", "code", "name", "balance", "currency", "info1", "info2", "is_active", "is_default", "search_tags", "matched_in_hidden") FROM stdin;
\.


--
-- Data for Name: cat_y2026_m02; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cat_y2026_m02" ("id", "current_account_id", "date", "description", "amount", "type", "source_type", "source_id", "user_name", "source_name", "source_code", "integration_ref", "urun_adi", "miktar", "birim", "birim_fiyat", "para_birimi", "kur", "e_belge", "irsaliye_no", "fatura_no", "aciklama2", "vade_tarihi", "ham_fiyat", "iskonto", "bakiye_borc", "bakiye_alacak", "belge", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: cat_y2026_m03; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cat_y2026_m03" ("id", "current_account_id", "date", "description", "amount", "type", "source_type", "source_id", "user_name", "source_name", "source_code", "integration_ref", "urun_adi", "miktar", "birim", "birim_fiyat", "para_birimi", "kur", "e_belge", "irsaliye_no", "fatura_no", "aciklama2", "vade_tarihi", "ham_fiyat", "iskonto", "bakiye_borc", "bakiye_alacak", "belge", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: cheque_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cheque_transactions" ("id", "company_id", "cheque_id", "date", "description", "amount", "type", "source_dest", "user_name", "created_at", "search_tags", "integration_ref") FROM stdin;
\.


--
-- Data for Name: cheques; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."cheques" ("id", "company_id", "type", "collection_status", "customer_code", "customer_name", "issue_date", "due_date", "amount", "currency", "check_no", "bank", "description", "user_name", "is_active", "search_tags", "matched_in_hidden", "integration_ref") FROM stdin;
\.


--
-- Data for Name: company_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."company_settings" ("id", "kod", "ad", "basliklar", "logolar", "adres", "vergi_dairesi", "vergi_no", "telefon", "eposta", "web_adresi", "aktif_mi", "varsayilan_mi", "duzenlenebilir_mi", "ust_bilgi_logosu", "ust_bilgi_satirlari") FROM stdin;
1	postgres	postgres	[]	[]							1	1	1	\N	[]
\.


--
-- Data for Name: credit_card_transactions_2024; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2024" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2025" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2026" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2027" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2028" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2029" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2030" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_2031" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_card_transactions_default" ("id", "company_id", "credit_card_id", "date", "description", "amount", "type", "location", "location_code", "location_name", "user_name", "integration_ref", "created_at") FROM stdin;
\.


--
-- Data for Name: credit_cards; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."credit_cards" ("id", "company_id", "code", "name", "balance", "currency", "branch_code", "branch_name", "account_no", "iban", "info1", "info2", "is_active", "is_default", "search_tags", "matched_in_hidden") FROM stdin;
\.


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."currency_rates" ("id", "from_code", "to_code", "rate", "update_time") FROM stdin;
1	TRY	USD	0.022873	2026-02-14T14:18:51.672230
2	TRY	EUR	0.019277	2026-02-14T14:18:51.672230
3	TRY	GBP	0.016763	2026-02-14T14:18:51.672230
4	USD	TRY	43.71947	2026-02-14T14:18:52.647813
5	USD	EUR	0.84271	2026-02-14T14:18:52.647813
6	USD	GBP	0.733327	2026-02-14T14:18:52.647813
7	EUR	TRY	51.87408	2026-02-14T14:18:53.529647
8	EUR	USD	1.186648	2026-02-14T14:18:53.529647
9	EUR	GBP	0.870116	2026-02-14T14:18:53.529647
10	GBP	TRY	59.654617	2026-02-14T14:18:54.425259
11	GBP	USD	1.36365	2026-02-14T14:18:54.425259
12	GBP	EUR	1.149273	2026-02-14T14:18:54.425259
\.


--
-- Data for Name: current_account_transactions_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."current_account_transactions_default" ("id", "current_account_id", "date", "description", "amount", "type", "source_type", "source_id", "user_name", "source_name", "source_code", "integration_ref", "urun_adi", "miktar", "birim", "birim_fiyat", "para_birimi", "kur", "e_belge", "irsaliye_no", "fatura_no", "aciklama2", "vade_tarihi", "ham_fiyat", "iskonto", "bakiye_borc", "bakiye_alacak", "belge", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: current_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."current_accounts" ("id", "kod_no", "adi", "hesap_turu", "para_birimi", "bakiye_borc", "bakiye_alacak", "bakiye_durumu", "telefon1", "fat_sehir", "aktif_mi", "fat_unvani", "fat_adresi", "fat_ilce", "posta_kodu", "v_dairesi", "v_numarasi", "sf_grubu", "s_iskonto", "vade_gun", "risk_limiti", "telefon2", "eposta", "web_adresi", "bilgi1", "bilgi2", "bilgi3", "bilgi4", "bilgi5", "sevk_adresleri", "resimler", "renk", "search_tags", "created_by", "created_at", "updated_at") FROM stdin;
1	1	meri bijuteri	Alıcı	TRY	0	0	Borç			1							Satış Fiyatı 1	0.0	0	0.0									[]	[]	\N	v2 1 meri bijuteri alici 1 aktif 0 0        satis fiyati 1 0.0 0 0.0 try borc          []  admin 	admin	2026-02-14 11:20:47.159067	\N
\.


--
-- Data for Name: depots; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."depots" ("id", "kod", "ad", "adres", "sorumlu", "telefon", "aktif_mi", "search_tags", "created_by", "created_at") FROM stdin;
1	1	merkez depo				1	1 merkez depo    1 aktif giriş stok giriş 14.02.2026 14:17  admin 1 domates adet 1500.0 2.0 1500.0 1	admin	2026-02-14 14:17:50.378532
\.


--
-- Data for Name: expense_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."expense_items" ("id", "expense_id", "aciklama", "tutar", "not_metni", "created_at") FROM stdin;
\.


--
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."expenses" ("id", "kod", "baslik", "tutar", "para_birimi", "tarih", "odeme_durumu", "kategori", "aciklama", "not_metni", "resimler", "ai_islenmis_mi", "ai_verileri", "aktif_mi", "search_tags", "kullanici", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: general_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."general_settings" ("key", "value") FROM stdin;
\.


--
-- Data for Name: hidden_descriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."hidden_descriptions" ("category", "content") FROM stdin;
\.


--
-- Data for Name: installments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."installments" ("id", "integration_ref", "cari_id", "vade_tarihi", "tutar", "durum", "aciklama", "created_at", "updated_at", "hareket_id") FROM stdin;
\.


--
-- Data for Name: note_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."note_transactions" ("id", "company_id", "note_id", "date", "description", "amount", "type", "source_dest", "user_name", "created_at", "search_tags", "integration_ref") FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."order_items" ("id", "order_id", "urun_id", "urun_kodu", "urun_adi", "barkod", "depo_id", "depo_adi", "kdv_orani", "miktar", "birim", "birim_fiyati", "para_birimi", "kdv_durumu", "iskonto", "toplam_fiyati", "delivered_quantity", "created_at") FROM stdin;
\.


--
-- Data for Name: orders_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."orders_default" ("id", "integration_ref", "order_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "sales_ref", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: orders_y2026_m02; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."orders_y2026_m02" ("id", "integration_ref", "order_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "sales_ref", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: orders_y2026_m03; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."orders_y2026_m03" ("id", "integration_ref", "order_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "sales_ref", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: print_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."print_templates" ("id", "name", "doc_type", "paper_size", "custom_width", "custom_height", "item_row_spacing", "background_image", "background_opacity", "background_x", "background_y", "background_width", "background_height", "layout_json", "is_default", "is_landscape", "view_matrix") FROM stdin;
\.


--
-- Data for Name: product_devices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."product_devices" ("id", "product_id", "identity_type", "identity_value", "condition", "color", "capacity", "warranty_end_date", "has_box", "has_invoice", "has_original_charger", "is_sold", "sale_ref", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: product_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."product_metadata" ("type", "value", "frequency") FROM stdin;
group		1
unit	Adet	1
vat	18.0	1
\.


--
-- Data for Name: production_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_metadata" ("type", "value", "frequency") FROM stdin;
\.


--
-- Data for Name: production_recipe_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_recipe_items" ("id", "production_id", "product_code", "product_name", "unit", "quantity", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2020; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2020" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2021; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2021" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2022; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2022" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2023; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2023" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2024; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2024" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2025" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2026" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2027" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2028" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2029" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2030" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2031" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2032; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2032" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2033; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2033" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2034; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2034" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2035; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2035" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2036; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_2036" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: production_stock_movements_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."production_stock_movements_default" ("id", "production_id", "warehouse_id", "quantity", "unit_price", "currency", "vat_status", "movement_date", "description", "movement_type", "created_by", "consumed_items", "related_shipment_ids", "created_at") FROM stdin;
\.


--
-- Data for Name: productions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."productions" ("id", "kod", "ad", "birim", "alis_fiyati", "satis_fiyati_1", "satis_fiyati_2", "satis_fiyati_3", "kdv_orani", "stok", "erken_uyari_miktari", "grubu", "ozellikler", "barkod", "kullanici", "resim_url", "resimler", "aktif_mi", "search_tags", "created_by", "created_at") FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."products" ("id", "kod", "ad", "birim", "alis_fiyati", "satis_fiyati_1", "satis_fiyati_2", "satis_fiyati_3", "kdv_orani", "stok", "erken_uyari_miktari", "grubu", "ozellikler", "barkod", "kullanici", "resim_url", "resimler", "aktif_mi", "search_tags", "created_by", "created_at", "updated_at") FROM stdin;
1	1	domates	Adet	0.0	0.0	0.0	0.0	18.0	1500.0	0.0		[]		admin	\N	[]	1	1 domates admin [] adet 0 0.0 0.0 0.0 0.0 0.0 0.0 18.0 aktif admin  devir girdi admin 14.2.2026  merkez depo 1500.0 2.0 2.36	admin	2026-02-14 14:17:37.243395	2026-02-14 11:18:09.069494
\.


--
-- Data for Name: promissory_notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."promissory_notes" ("id", "company_id", "type", "collection_status", "customer_code", "customer_name", "issue_date", "due_date", "amount", "currency", "note_no", "bank", "description", "user_name", "is_active", "search_tags", "matched_in_hidden", "integration_ref") FROM stdin;
\.


--
-- Data for Name: quick_products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."quick_products" ("id", "product_id", "display_order") FROM stdin;
\.


--
-- Data for Name: quote_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."quote_items" ("id", "quote_id", "urun_id", "urun_kodu", "urun_adi", "barkod", "depo_id", "depo_adi", "kdv_orani", "miktar", "birim", "birim_fiyati", "para_birimi", "kdv_durumu", "iskonto", "toplam_fiyati", "created_at") FROM stdin;
\.


--
-- Data for Name: quotes_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."quotes_default" ("id", "integration_ref", "quote_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: quotes_y2026_m02; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."quotes_y2026_m02" ("id", "integration_ref", "quote_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: quotes_y2026_m03; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."quotes_y2026_m03" ("id", "integration_ref", "quote_no", "tur", "durum", "tarih", "cari_id", "cari_kod", "cari_adi", "ilgili_hesap_adi", "tutar", "kur", "aciklama", "aciklama2", "gecerlilik_tarihi", "para_birimi", "kullanici", "search_tags", "stok_rezerve_mi", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."roles" ("id", "name", "permissions", "is_system", "is_active") FROM stdin;
admin	Yönetici	["home","trading_operations","trading_operations.fast_sale","trading_operations.make_purchase","trading_operations.make_sale","trading_operations.retail_sale","orders_quotes","orders_quotes.orders","orders_quotes.quotes","products_warehouses","products_warehouses.products","products_warehouses.productions","products_warehouses.warehouses","accounts","cash_bank","cash_bank.cash","cash_bank.banks","cash_bank.credit_cards","checks_notes","checks_notes.checks","checks_notes.notes","personnel_user","expenses","print_settings","settings","settings.roles","settings.company","settings.modules","settings.general","settings.ai","settings.database_backup","settings.language"]	1	1
user	Kullanıcı	[]	1	1
cashier	Kasiyer	[]	1	1
waiter	Garson	[]	1	1
\.


--
-- Data for Name: saved_descriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."saved_descriptions" ("id", "category", "content", "usage_count", "last_used") FROM stdin;
\.


--
-- Data for Name: sequences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."sequences" ("name", "current_value") FROM stdin;
product_code	1
\.


--
-- Data for Name: shipments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."shipments" ("id", "source_warehouse_id", "dest_warehouse_id", "date", "description", "items", "integration_ref", "created_by", "created_at") FROM stdin;
1	\N	1	2026-02-14 14:17:59.900906		[{"code": "1", "name": "domates", "unit": "Adet", "devices": [], "quantity": 1500.0, "unitCost": 2.0}]	\N	admin	2026-02-14 14:18:09.525858
\.


--
-- Data for Name: stock_movements_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2025" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2026" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
1	1	1	1	1500.0	t	2.0	TRY	1	excluded	2026-02-14 14:17:59.900906		giris	admin	\N	0	0	2026-02-14 14:18:11.128456
\.


--
-- Data for Name: stock_movements_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2027" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2028" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2029" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2030" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_2031" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: stock_movements_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."stock_movements_default" ("id", "product_id", "warehouse_id", "shipment_id", "quantity", "is_giris", "unit_price", "currency_code", "currency_rate", "vat_status", "movement_date", "description", "movement_type", "created_by", "integration_ref", "running_cost", "running_stock", "created_at") FROM stdin;
\.


--
-- Data for Name: sync_outbox; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."sync_outbox" ("id", "target_db", "operation", "payload", "status", "retry_count", "last_error", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: table_counts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."table_counts" ("table_name", "row_count") FROM stdin;
productions	0
products	1
\.


--
-- Data for Name: user_transactions_2024; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2024" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2025; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2025" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2026; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2026" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2027; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2027" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2028; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2028" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2029; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2029" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2030; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2030" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_2031; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_2031" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: user_transactions_default; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."user_transactions_default" ("id", "company_id", "user_id", "date", "description", "debt", "credit", "type") FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."users" ("id", "username", "name", "surname", "email", "role", "is_active", "phone", "profile_image", "password", "hire_date", "position", "salary", "salary_currency", "address", "info1", "info2", "balance_debt", "balance_credit") FROM stdin;
1	admin	Sistem	Yöneticisi	admin@patisyo.com	admin	1		\N	8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918	\N	\N	\N	\N	\N	\N	\N	0	0
\.


--
-- Data for Name: warehouse_stocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "public"."warehouse_stocks" ("warehouse_id", "product_code", "quantity", "reserved_quantity", "updated_at") FROM stdin;
1	1	1500.0	0	2026-02-14 11:18:41.217778
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY "realtime"."schema_migrations" ("version", "inserted_at") FROM stdin;
20211116024918	2026-02-14 07:06:13
20211116045059	2026-02-14 07:06:13
20211116050929	2026-02-14 07:06:13
20211116051442	2026-02-14 07:06:14
20211116212300	2026-02-14 07:06:14
20211116213355	2026-02-14 07:06:14
20211116213934	2026-02-14 07:06:14
20211116214523	2026-02-14 07:06:14
20211122062447	2026-02-14 07:06:14
20211124070109	2026-02-14 07:06:14
20211202204204	2026-02-14 07:06:14
20211202204605	2026-02-14 07:06:15
20211210212804	2026-02-14 07:06:15
20211228014915	2026-02-14 07:06:15
20220107221237	2026-02-14 07:06:15
20220228202821	2026-02-14 07:06:15
20220312004840	2026-02-14 07:06:16
20220603231003	2026-02-14 07:06:16
20220603232444	2026-02-14 07:06:16
20220615214548	2026-02-14 07:06:16
20220712093339	2026-02-14 07:06:16
20220908172859	2026-02-14 07:06:16
20220916233421	2026-02-14 07:06:16
20230119133233	2026-02-14 07:06:17
20230128025114	2026-02-14 07:06:17
20230128025212	2026-02-14 07:06:17
20230227211149	2026-02-14 07:06:17
20230228184745	2026-02-14 07:06:17
20230308225145	2026-02-14 07:06:17
20230328144023	2026-02-14 07:06:17
20231018144023	2026-02-14 07:06:17
20231204144023	2026-02-14 07:06:18
20231204144024	2026-02-14 07:06:18
20231204144025	2026-02-14 07:06:18
20240108234812	2026-02-14 07:06:18
20240109165339	2026-02-14 07:06:18
20240227174441	2026-02-14 07:06:18
20240311171622	2026-02-14 07:06:19
20240321100241	2026-02-14 07:06:19
20240401105812	2026-02-14 07:06:19
20240418121054	2026-02-14 07:06:19
20240523004032	2026-02-14 07:06:20
20240618124746	2026-02-14 07:06:20
20240801235015	2026-02-14 07:06:20
20240805133720	2026-02-14 07:06:20
20240827160934	2026-02-14 07:06:20
20240919163303	2026-02-14 07:06:21
20240919163305	2026-02-14 07:06:21
20241019105805	2026-02-14 07:06:21
20241030150047	2026-02-14 07:06:21
20241108114728	2026-02-14 07:06:21
20241121104152	2026-02-14 07:06:22
20241130184212	2026-02-14 07:08:17
20241220035512	2026-02-14 07:08:17
20241220123912	2026-02-14 07:08:18
20241224161212	2026-02-14 07:08:18
20250107150512	2026-02-14 07:08:18
20250110162412	2026-02-14 07:08:18
20250123174212	2026-02-14 07:08:18
20250128220012	2026-02-14 07:08:18
20250506224012	2026-02-14 07:08:18
20250523164012	2026-02-14 07:08:18
20250714121412	2026-02-14 07:08:19
20250905041441	2026-02-14 07:08:19
20251103001201	2026-02-14 07:08:19
20251120212548	2026-02-14 07:08:19
20251120215549	2026-02-14 07:08:19
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY "realtime"."subscription" ("id", "subscription_id", "entity", "filters", "claims", "created_at", "action_filter") FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."buckets" ("id", "name", "owner", "created_at", "updated_at", "public", "avif_autodetection", "file_size_limit", "allowed_mime_types", "owner_id", "type") FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."buckets_analytics" ("name", "type", "format", "created_at", "updated_at", "id", "deleted_at") FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."buckets_vectors" ("id", "type", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."migrations" ("id", "name", "hash", "executed_at") FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-02-14 07:06:14.236776
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-02-14 07:06:14.245846
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2026-02-14 07:06:14.252696
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-02-14 07:06:14.268746
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-02-14 07:06:14.325137
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-02-14 07:06:14.330463
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2026-02-14 07:06:14.336301
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-02-14 07:06:14.342854
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-02-14 07:06:14.348752
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2026-02-14 07:06:14.35535
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2026-02-14 07:06:14.361171
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-02-14 07:06:14.368574
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-02-14 07:06:14.374861
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-02-14 07:06:14.380273
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-02-14 07:06:14.385878
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-02-14 07:06:14.406516
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-02-14 07:06:14.412977
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-02-14 07:06:14.419468
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-02-14 07:06:14.424472
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-02-14 07:06:14.431124
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-02-14 07:06:14.436515
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-02-14 07:06:14.443554
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-02-14 07:06:14.456187
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-02-14 07:06:14.467283
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-02-14 07:06:14.472843
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-02-14 07:06:14.477861
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2026-02-14 07:06:14.483091
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2026-02-14 07:06:14.48809
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2026-02-14 07:06:14.4929
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2026-02-14 07:06:14.497674
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2026-02-14 07:06:14.502347
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2026-02-14 07:06:14.507296
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2026-02-14 07:06:14.511994
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2026-02-14 07:06:14.516533
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2026-02-14 07:06:14.521134
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2026-02-14 07:06:14.525759
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2026-02-14 07:06:14.530495
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-02-14 07:06:14.535211
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2026-02-14 07:06:14.540977
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2026-02-14 07:06:14.549594
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2026-02-14 07:06:14.554627
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2026-02-14 07:06:14.559124
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2026-02-14 07:06:14.563612
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2026-02-14 07:06:14.568434
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-02-14 07:06:14.572852
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-02-14 07:06:14.578108
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-02-14 07:06:14.587773
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-02-14 07:06:14.595689
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2026-02-14 07:06:14.60042
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-02-14 07:06:14.615138
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-02-14 07:06:14.621395
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-02-14 07:06:14.733132
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-02-14 07:06:14.735981
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-02-14 07:06:14.747405
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-02-14 07:06:14.750578
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-02-14 07:06:14.752585
56	fix-optimized-search-function	cb58526ebc23048049fd5bf2fd148d18b04a2073	2026-02-14 07:06:14.758701
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."objects" ("id", "bucket_id", "name", "owner", "created_at", "updated_at", "last_accessed_at", "metadata", "version", "owner_id", "user_metadata") FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."s3_multipart_uploads" ("id", "in_progress_size", "upload_signature", "bucket_id", "key", "version", "owner_id", "created_at", "user_metadata") FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."s3_multipart_uploads_parts" ("id", "upload_id", "size", "part_number", "bucket_id", "key", "etag", "owner_id", "version", "created_at") FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY "storage"."vector_indexes" ("id", "name", "bucket_id", "data_type", "dimension", "distance_metric", "metadata_configuration", "created_at", "updated_at") FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY "vault"."secrets" ("id", "name", "description", "secret", "key_id", "nonce", "created_at", "updated_at") FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, false);


--
-- Name: bank_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."bank_transactions_id_seq"', 1, false);


--
-- Name: banks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."banks_id_seq"', 1, false);


--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."cash_register_transactions_id_seq"', 1, false);


--
-- Name: cash_registers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."cash_registers_id_seq"', 1, false);


--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."cheque_transactions_id_seq"', 1, false);


--
-- Name: cheques_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."cheques_id_seq"', 1, false);


--
-- Name: company_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."company_settings_id_seq"', 1, true);


--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."credit_card_transactions_id_seq"', 1, false);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."credit_cards_id_seq"', 1, false);


--
-- Name: currency_rates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."currency_rates_id_seq"', 36, true);


--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."current_account_transactions_id_seq"', 1, false);


--
-- Name: current_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."current_accounts_id_seq"', 1, true);


--
-- Name: depots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."depots_id_seq"', 1, true);


--
-- Name: expense_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."expense_items_id_seq"', 1, false);


--
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."expenses_id_seq"', 1, false);


--
-- Name: installments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."installments_id_seq"', 1, false);


--
-- Name: note_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."note_transactions_id_seq"', 1, false);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."order_items_id_seq"', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."orders_id_seq"', 1, false);


--
-- Name: print_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."print_templates_id_seq"', 1, false);


--
-- Name: product_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."product_devices_id_seq"', 1, false);


--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."production_recipe_items_id_seq"', 1, false);


--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."production_stock_movements_id_seq"', 1, false);


--
-- Name: productions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."productions_id_seq"', 1, false);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."products_id_seq"', 1, true);


--
-- Name: promissory_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."promissory_notes_id_seq"', 1, false);


--
-- Name: quick_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."quick_products_id_seq"', 1, false);


--
-- Name: quote_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."quote_items_id_seq"', 1, false);


--
-- Name: quotes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."quotes_id_seq"', 1, false);


--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."saved_descriptions_id_seq"', 1, false);


--
-- Name: shipments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."shipments_id_seq"', 1, true);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."stock_movements_id_seq"', 1, true);


--
-- Name: sync_outbox_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('"public"."sync_outbox_id_seq"', 1, false);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('"realtime"."subscription_id_seq"', 1, false);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "amr_id_pk" PRIMARY KEY ("id");


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."audit_log_entries"
    ADD CONSTRAINT "audit_log_entries_pkey" PRIMARY KEY ("id");


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."flow_state"
    ADD CONSTRAINT "flow_state_pkey" PRIMARY KEY ("id");


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_pkey" PRIMARY KEY ("id");


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_provider_id_provider_unique" UNIQUE ("provider_id", "provider");


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."instances"
    ADD CONSTRAINT "instances_pkey" PRIMARY KEY ("id");


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_authentication_method_pkey" UNIQUE ("session_id", "authentication_method");


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_pkey" PRIMARY KEY ("id");


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_last_challenged_at_key" UNIQUE ("last_challenged_at");


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_pkey" PRIMARY KEY ("id");


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_code_key" UNIQUE ("authorization_code");


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_id_key" UNIQUE ("authorization_id");


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_pkey" PRIMARY KEY ("id");


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_client_states"
    ADD CONSTRAINT "oauth_client_states_pkey" PRIMARY KEY ("id");


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_clients"
    ADD CONSTRAINT "oauth_clients_pkey" PRIMARY KEY ("id");


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_pkey" PRIMARY KEY ("id");


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_client_unique" UNIQUE ("user_id", "client_id");


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_pkey" PRIMARY KEY ("id");


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id");


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_token_unique" UNIQUE ("token");


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_entity_id_key" UNIQUE ("entity_id");


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_pkey" PRIMARY KEY ("id");


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_pkey" PRIMARY KEY ("id");


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."schema_migrations"
    ADD CONSTRAINT "schema_migrations_pkey" PRIMARY KEY ("version");


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_pkey" PRIMARY KEY ("id");


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sso_providers"
    ADD CONSTRAINT "sso_providers_pkey" PRIMARY KEY ("id");


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_phone_key" UNIQUE ("phone");


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- Name: account_metadata account_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."account_metadata"
    ADD CONSTRAINT "account_metadata_pkey" PRIMARY KEY ("type", "value");


--
-- Name: bank_transactions bank_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions"
    ADD CONSTRAINT "bank_transactions_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2024 bank_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2024"
    ADD CONSTRAINT "bank_transactions_2024_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2025 bank_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2025"
    ADD CONSTRAINT "bank_transactions_2025_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2026 bank_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2026"
    ADD CONSTRAINT "bank_transactions_2026_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2027 bank_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2027"
    ADD CONSTRAINT "bank_transactions_2027_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2028 bank_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2028"
    ADD CONSTRAINT "bank_transactions_2028_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2029 bank_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2029"
    ADD CONSTRAINT "bank_transactions_2029_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2030 bank_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2030"
    ADD CONSTRAINT "bank_transactions_2030_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_2031 bank_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_2031"
    ADD CONSTRAINT "bank_transactions_2031_pkey" PRIMARY KEY ("id", "date");


--
-- Name: bank_transactions_default bank_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."bank_transactions_default"
    ADD CONSTRAINT "bank_transactions_default_pkey" PRIMARY KEY ("id", "date");


--
-- Name: banks banks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."banks"
    ADD CONSTRAINT "banks_pkey" PRIMARY KEY ("id");


--
-- Name: cash_register_transactions cash_register_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions"
    ADD CONSTRAINT "cash_register_transactions_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2024 cash_register_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2024"
    ADD CONSTRAINT "cash_register_transactions_2024_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2025 cash_register_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2025"
    ADD CONSTRAINT "cash_register_transactions_2025_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2026 cash_register_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2026"
    ADD CONSTRAINT "cash_register_transactions_2026_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2027 cash_register_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2027"
    ADD CONSTRAINT "cash_register_transactions_2027_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2028 cash_register_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2028"
    ADD CONSTRAINT "cash_register_transactions_2028_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2029 cash_register_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2029"
    ADD CONSTRAINT "cash_register_transactions_2029_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2030 cash_register_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2030"
    ADD CONSTRAINT "cash_register_transactions_2030_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_2031 cash_register_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_2031"
    ADD CONSTRAINT "cash_register_transactions_2031_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_register_transactions_default cash_register_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_register_transactions_default"
    ADD CONSTRAINT "cash_register_transactions_default_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cash_registers cash_registers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cash_registers"
    ADD CONSTRAINT "cash_registers_pkey" PRIMARY KEY ("id");


--
-- Name: current_account_transactions current_account_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions"
    ADD CONSTRAINT "current_account_transactions_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cat_y2026_m02 cat_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cat_y2026_m02"
    ADD CONSTRAINT "cat_y2026_m02_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cat_y2026_m03 cat_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cat_y2026_m03"
    ADD CONSTRAINT "cat_y2026_m03_pkey" PRIMARY KEY ("id", "date");


--
-- Name: cheque_transactions cheque_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cheque_transactions"
    ADD CONSTRAINT "cheque_transactions_pkey" PRIMARY KEY ("id");


--
-- Name: cheques cheques_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."cheques"
    ADD CONSTRAINT "cheques_pkey" PRIMARY KEY ("id");


--
-- Name: company_settings company_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."company_settings"
    ADD CONSTRAINT "company_settings_pkey" PRIMARY KEY ("id");


--
-- Name: credit_card_transactions credit_card_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions"
    ADD CONSTRAINT "credit_card_transactions_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2024 credit_card_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2024"
    ADD CONSTRAINT "credit_card_transactions_2024_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2025 credit_card_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2025"
    ADD CONSTRAINT "credit_card_transactions_2025_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2026 credit_card_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2026"
    ADD CONSTRAINT "credit_card_transactions_2026_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2027 credit_card_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2027"
    ADD CONSTRAINT "credit_card_transactions_2027_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2028 credit_card_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2028"
    ADD CONSTRAINT "credit_card_transactions_2028_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2029 credit_card_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2029"
    ADD CONSTRAINT "credit_card_transactions_2029_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2030 credit_card_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2030"
    ADD CONSTRAINT "credit_card_transactions_2030_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_2031 credit_card_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_2031"
    ADD CONSTRAINT "credit_card_transactions_2031_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_card_transactions_default credit_card_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_card_transactions_default"
    ADD CONSTRAINT "credit_card_transactions_default_pkey" PRIMARY KEY ("id", "date");


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."credit_cards"
    ADD CONSTRAINT "credit_cards_pkey" PRIMARY KEY ("id");


--
-- Name: currency_rates currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."currency_rates"
    ADD CONSTRAINT "currency_rates_pkey" PRIMARY KEY ("id");


--
-- Name: current_account_transactions_default current_account_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_account_transactions_default"
    ADD CONSTRAINT "current_account_transactions_default_pkey" PRIMARY KEY ("id", "date");


--
-- Name: current_accounts current_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."current_accounts"
    ADD CONSTRAINT "current_accounts_pkey" PRIMARY KEY ("id");


--
-- Name: depots depots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."depots"
    ADD CONSTRAINT "depots_pkey" PRIMARY KEY ("id");


--
-- Name: expense_items expense_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_pkey" PRIMARY KEY ("id");


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");


--
-- Name: general_settings general_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."general_settings"
    ADD CONSTRAINT "general_settings_pkey" PRIMARY KEY ("key");


--
-- Name: hidden_descriptions hidden_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."hidden_descriptions"
    ADD CONSTRAINT "hidden_descriptions_pkey" PRIMARY KEY ("category", "content");


--
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."installments"
    ADD CONSTRAINT "installments_pkey" PRIMARY KEY ("id");


--
-- Name: note_transactions note_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."note_transactions"
    ADD CONSTRAINT "note_transactions_pkey" PRIMARY KEY ("id");


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: orders_default orders_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders_default"
    ADD CONSTRAINT "orders_default_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: orders_y2026_m02 orders_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders_y2026_m02"
    ADD CONSTRAINT "orders_y2026_m02_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: orders_y2026_m03 orders_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."orders_y2026_m03"
    ADD CONSTRAINT "orders_y2026_m03_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: print_templates print_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."print_templates"
    ADD CONSTRAINT "print_templates_pkey" PRIMARY KEY ("id");


--
-- Name: product_devices product_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."product_devices"
    ADD CONSTRAINT "product_devices_pkey" PRIMARY KEY ("id");


--
-- Name: product_metadata product_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."product_metadata"
    ADD CONSTRAINT "product_metadata_pkey" PRIMARY KEY ("type", "value");


--
-- Name: production_metadata production_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_metadata"
    ADD CONSTRAINT "production_metadata_pkey" PRIMARY KEY ("type", "value");


--
-- Name: production_recipe_items production_recipe_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_recipe_items"
    ADD CONSTRAINT "production_recipe_items_pkey" PRIMARY KEY ("id");


--
-- Name: production_stock_movements production_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements"
    ADD CONSTRAINT "production_stock_movements_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2020 production_stock_movements_2020_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2020"
    ADD CONSTRAINT "production_stock_movements_2020_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2021 production_stock_movements_2021_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2021"
    ADD CONSTRAINT "production_stock_movements_2021_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2022 production_stock_movements_2022_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2022"
    ADD CONSTRAINT "production_stock_movements_2022_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2023 production_stock_movements_2023_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2023"
    ADD CONSTRAINT "production_stock_movements_2023_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2024 production_stock_movements_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2024"
    ADD CONSTRAINT "production_stock_movements_2024_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2025 production_stock_movements_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2025"
    ADD CONSTRAINT "production_stock_movements_2025_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2026 production_stock_movements_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2026"
    ADD CONSTRAINT "production_stock_movements_2026_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2027 production_stock_movements_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2027"
    ADD CONSTRAINT "production_stock_movements_2027_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2028 production_stock_movements_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2028"
    ADD CONSTRAINT "production_stock_movements_2028_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2029 production_stock_movements_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2029"
    ADD CONSTRAINT "production_stock_movements_2029_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2030 production_stock_movements_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2030"
    ADD CONSTRAINT "production_stock_movements_2030_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2031 production_stock_movements_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2031"
    ADD CONSTRAINT "production_stock_movements_2031_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2032 production_stock_movements_2032_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2032"
    ADD CONSTRAINT "production_stock_movements_2032_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2033 production_stock_movements_2033_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2033"
    ADD CONSTRAINT "production_stock_movements_2033_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2034 production_stock_movements_2034_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2034"
    ADD CONSTRAINT "production_stock_movements_2034_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2035 production_stock_movements_2035_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2035"
    ADD CONSTRAINT "production_stock_movements_2035_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_2036 production_stock_movements_2036_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_2036"
    ADD CONSTRAINT "production_stock_movements_2036_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: production_stock_movements_default production_stock_movements_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_stock_movements_default"
    ADD CONSTRAINT "production_stock_movements_default_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: productions productions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."productions"
    ADD CONSTRAINT "productions_pkey" PRIMARY KEY ("id");


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");


--
-- Name: promissory_notes promissory_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."promissory_notes"
    ADD CONSTRAINT "promissory_notes_pkey" PRIMARY KEY ("id");


--
-- Name: quick_products quick_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quick_products"
    ADD CONSTRAINT "quick_products_pkey" PRIMARY KEY ("id");


--
-- Name: quick_products quick_products_product_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quick_products"
    ADD CONSTRAINT "quick_products_product_id_key" UNIQUE ("product_id");


--
-- Name: quote_items quote_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quote_items"
    ADD CONSTRAINT "quote_items_pkey" PRIMARY KEY ("id");


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes"
    ADD CONSTRAINT "quotes_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: quotes_default quotes_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes_default"
    ADD CONSTRAINT "quotes_default_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: quotes_y2026_m02 quotes_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes_y2026_m02"
    ADD CONSTRAINT "quotes_y2026_m02_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: quotes_y2026_m03 quotes_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quotes_y2026_m03"
    ADD CONSTRAINT "quotes_y2026_m03_pkey" PRIMARY KEY ("id", "tarih");


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");


--
-- Name: saved_descriptions saved_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."saved_descriptions"
    ADD CONSTRAINT "saved_descriptions_pkey" PRIMARY KEY ("id");


--
-- Name: sequences sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."sequences"
    ADD CONSTRAINT "sequences_pkey" PRIMARY KEY ("name");


--
-- Name: shipments shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."shipments"
    ADD CONSTRAINT "shipments_pkey" PRIMARY KEY ("id");


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2025 stock_movements_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2025"
    ADD CONSTRAINT "stock_movements_2025_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2026 stock_movements_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2026"
    ADD CONSTRAINT "stock_movements_2026_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2027 stock_movements_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2027"
    ADD CONSTRAINT "stock_movements_2027_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2028 stock_movements_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2028"
    ADD CONSTRAINT "stock_movements_2028_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2029 stock_movements_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2029"
    ADD CONSTRAINT "stock_movements_2029_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2030 stock_movements_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2030"
    ADD CONSTRAINT "stock_movements_2030_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_2031 stock_movements_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_2031"
    ADD CONSTRAINT "stock_movements_2031_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: stock_movements_default stock_movements_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."stock_movements_default"
    ADD CONSTRAINT "stock_movements_default_pkey" PRIMARY KEY ("id", "created_at");


--
-- Name: sync_outbox sync_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."sync_outbox"
    ADD CONSTRAINT "sync_outbox_pkey" PRIMARY KEY ("id");


--
-- Name: table_counts table_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."table_counts"
    ADD CONSTRAINT "table_counts_pkey" PRIMARY KEY ("table_name");


--
-- Name: saved_descriptions unique_category_content; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."saved_descriptions"
    ADD CONSTRAINT "unique_category_content" UNIQUE ("category", "content");


--
-- Name: user_transactions user_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions"
    ADD CONSTRAINT "user_transactions_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2024 user_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2024"
    ADD CONSTRAINT "user_transactions_2024_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2025 user_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2025"
    ADD CONSTRAINT "user_transactions_2025_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2026 user_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2026"
    ADD CONSTRAINT "user_transactions_2026_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2027 user_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2027"
    ADD CONSTRAINT "user_transactions_2027_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2028 user_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2028"
    ADD CONSTRAINT "user_transactions_2028_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2029 user_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2029"
    ADD CONSTRAINT "user_transactions_2029_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2030 user_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2030"
    ADD CONSTRAINT "user_transactions_2030_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_2031 user_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_2031"
    ADD CONSTRAINT "user_transactions_2031_pkey" PRIMARY KEY ("id", "date");


--
-- Name: user_transactions_default user_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."user_transactions_default"
    ADD CONSTRAINT "user_transactions_default_pkey" PRIMARY KEY ("id", "date");


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- Name: warehouse_stocks warehouse_stocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."warehouse_stocks"
    ADD CONSTRAINT "warehouse_stocks_pkey" PRIMARY KEY ("warehouse_id", "product_code");


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY "realtime"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id", "inserted_at");


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY "realtime"."subscription"
    ADD CONSTRAINT "pk_subscription" PRIMARY KEY ("id");


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY "realtime"."schema_migrations"
    ADD CONSTRAINT "schema_migrations_pkey" PRIMARY KEY ("version");


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."buckets_analytics"
    ADD CONSTRAINT "buckets_analytics_pkey" PRIMARY KEY ("id");


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."buckets"
    ADD CONSTRAINT "buckets_pkey" PRIMARY KEY ("id");


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."buckets_vectors"
    ADD CONSTRAINT "buckets_vectors_pkey" PRIMARY KEY ("id");


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_name_key" UNIQUE ("name");


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_pkey" PRIMARY KEY ("id");


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_pkey" PRIMARY KEY ("id");


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_pkey" PRIMARY KEY ("id");


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_pkey" PRIMARY KEY ("id");


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_pkey" PRIMARY KEY ("id");


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "audit_logs_instance_id_idx" ON "auth"."audit_log_entries" USING "btree" ("instance_id");


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "confirmation_token_idx" ON "auth"."users" USING "btree" ("confirmation_token") WHERE (("confirmation_token")::"text" !~ '^[0-9 ]*$'::"text");


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "email_change_token_current_idx" ON "auth"."users" USING "btree" ("email_change_token_current") WHERE (("email_change_token_current")::"text" !~ '^[0-9 ]*$'::"text");


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "email_change_token_new_idx" ON "auth"."users" USING "btree" ("email_change_token_new") WHERE (("email_change_token_new")::"text" !~ '^[0-9 ]*$'::"text");


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "factor_id_created_at_idx" ON "auth"."mfa_factors" USING "btree" ("user_id", "created_at");


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "flow_state_created_at_idx" ON "auth"."flow_state" USING "btree" ("created_at" DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "identities_email_idx" ON "auth"."identities" USING "btree" ("email" "text_pattern_ops");


--
-- Name: INDEX "identities_email_idx"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX "auth"."identities_email_idx" IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "identities_user_id_idx" ON "auth"."identities" USING "btree" ("user_id");


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "idx_auth_code" ON "auth"."flow_state" USING "btree" ("auth_code");


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "idx_oauth_client_states_created_at" ON "auth"."oauth_client_states" USING "btree" ("created_at");


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "idx_user_id_auth_method" ON "auth"."flow_state" USING "btree" ("user_id", "authentication_method");


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "mfa_challenge_created_at_idx" ON "auth"."mfa_challenges" USING "btree" ("created_at" DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "mfa_factors_user_friendly_name_unique" ON "auth"."mfa_factors" USING "btree" ("friendly_name", "user_id") WHERE (TRIM(BOTH FROM "friendly_name") <> ''::"text");


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "mfa_factors_user_id_idx" ON "auth"."mfa_factors" USING "btree" ("user_id");


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "oauth_auth_pending_exp_idx" ON "auth"."oauth_authorizations" USING "btree" ("expires_at") WHERE ("status" = 'pending'::"auth"."oauth_authorization_status");


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "oauth_clients_deleted_at_idx" ON "auth"."oauth_clients" USING "btree" ("deleted_at");


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "oauth_consents_active_client_idx" ON "auth"."oauth_consents" USING "btree" ("client_id") WHERE ("revoked_at" IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "oauth_consents_active_user_client_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "client_id") WHERE ("revoked_at" IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "oauth_consents_user_order_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "granted_at" DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "one_time_tokens_relates_to_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("relates_to");


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "one_time_tokens_token_hash_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("token_hash");


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "one_time_tokens_user_id_token_type_key" ON "auth"."one_time_tokens" USING "btree" ("user_id", "token_type");


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "reauthentication_token_idx" ON "auth"."users" USING "btree" ("reauthentication_token") WHERE (("reauthentication_token")::"text" !~ '^[0-9 ]*$'::"text");


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "recovery_token_idx" ON "auth"."users" USING "btree" ("recovery_token") WHERE (("recovery_token")::"text" !~ '^[0-9 ]*$'::"text");


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "refresh_tokens_instance_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id");


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "refresh_tokens_instance_id_user_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id", "user_id");


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "refresh_tokens_parent_idx" ON "auth"."refresh_tokens" USING "btree" ("parent");


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "refresh_tokens_session_id_revoked_idx" ON "auth"."refresh_tokens" USING "btree" ("session_id", "revoked");


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "refresh_tokens_updated_at_idx" ON "auth"."refresh_tokens" USING "btree" ("updated_at" DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "saml_providers_sso_provider_id_idx" ON "auth"."saml_providers" USING "btree" ("sso_provider_id");


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "saml_relay_states_created_at_idx" ON "auth"."saml_relay_states" USING "btree" ("created_at" DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "saml_relay_states_for_email_idx" ON "auth"."saml_relay_states" USING "btree" ("for_email");


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "saml_relay_states_sso_provider_id_idx" ON "auth"."saml_relay_states" USING "btree" ("sso_provider_id");


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "sessions_not_after_idx" ON "auth"."sessions" USING "btree" ("not_after" DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "sessions_oauth_client_id_idx" ON "auth"."sessions" USING "btree" ("oauth_client_id");


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "sessions_user_id_idx" ON "auth"."sessions" USING "btree" ("user_id");


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "sso_domains_domain_idx" ON "auth"."sso_domains" USING "btree" ("lower"("domain"));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "sso_domains_sso_provider_id_idx" ON "auth"."sso_domains" USING "btree" ("sso_provider_id");


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "sso_providers_resource_id_idx" ON "auth"."sso_providers" USING "btree" ("lower"("resource_id"));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "sso_providers_resource_id_pattern_idx" ON "auth"."sso_providers" USING "btree" ("resource_id" "text_pattern_ops");


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "unique_phone_factor_per_user" ON "auth"."mfa_factors" USING "btree" ("user_id", "phone");


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "user_id_created_at_idx" ON "auth"."sessions" USING "btree" ("user_id", "created_at");


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX "users_email_partial_key" ON "auth"."users" USING "btree" ("email") WHERE ("is_sso_user" = false);


--
-- Name: INDEX "users_email_partial_key"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX "auth"."users_email_partial_key" IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "users_instance_id_email_idx" ON "auth"."users" USING "btree" ("instance_id", "lower"(("email")::"text"));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "users_instance_id_idx" ON "auth"."users" USING "btree" ("instance_id");


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX "users_is_anonymous_idx" ON "auth"."users" USING "btree" ("is_anonymous");


--
-- Name: idx_bt_bank_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_bank_id" ON ONLY "public"."bank_transactions" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2024_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_bank_id_idx" ON "public"."bank_transactions_2024" USING "btree" ("bank_id");


--
-- Name: idx_bt_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_created_at" ON ONLY "public"."bank_transactions" USING "btree" ("created_at");


--
-- Name: bank_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_created_at_idx" ON "public"."bank_transactions_2024" USING "btree" ("created_at");


--
-- Name: idx_bt_created_at_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_created_at_brin" ON ONLY "public"."bank_transactions" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2024_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_created_at_idx1" ON "public"."bank_transactions_2024" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: idx_bt_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_date" ON ONLY "public"."bank_transactions" USING "btree" ("date");


--
-- Name: bank_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_date_idx" ON "public"."bank_transactions_2024" USING "btree" ("date");


--
-- Name: idx_bt_integration_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_integration_ref" ON ONLY "public"."bank_transactions" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_integration_ref_idx" ON "public"."bank_transactions_2024" USING "btree" ("integration_ref");


--
-- Name: idx_bt_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_bt_type" ON ONLY "public"."bank_transactions" USING "btree" ("type");


--
-- Name: bank_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2024_type_idx" ON "public"."bank_transactions_2024" USING "btree" ("type");


--
-- Name: bank_transactions_2025_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_bank_id_idx" ON "public"."bank_transactions_2025" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_created_at_idx" ON "public"."bank_transactions_2025" USING "btree" ("created_at");


--
-- Name: bank_transactions_2025_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_created_at_idx1" ON "public"."bank_transactions_2025" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_date_idx" ON "public"."bank_transactions_2025" USING "btree" ("date");


--
-- Name: bank_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_integration_ref_idx" ON "public"."bank_transactions_2025" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2025_type_idx" ON "public"."bank_transactions_2025" USING "btree" ("type");


--
-- Name: bank_transactions_2026_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_bank_id_idx" ON "public"."bank_transactions_2026" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_created_at_idx" ON "public"."bank_transactions_2026" USING "btree" ("created_at");


--
-- Name: bank_transactions_2026_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_created_at_idx1" ON "public"."bank_transactions_2026" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_date_idx" ON "public"."bank_transactions_2026" USING "btree" ("date");


--
-- Name: bank_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_integration_ref_idx" ON "public"."bank_transactions_2026" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2026_type_idx" ON "public"."bank_transactions_2026" USING "btree" ("type");


--
-- Name: bank_transactions_2027_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_bank_id_idx" ON "public"."bank_transactions_2027" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_created_at_idx" ON "public"."bank_transactions_2027" USING "btree" ("created_at");


--
-- Name: bank_transactions_2027_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_created_at_idx1" ON "public"."bank_transactions_2027" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_date_idx" ON "public"."bank_transactions_2027" USING "btree" ("date");


--
-- Name: bank_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_integration_ref_idx" ON "public"."bank_transactions_2027" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2027_type_idx" ON "public"."bank_transactions_2027" USING "btree" ("type");


--
-- Name: bank_transactions_2028_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_bank_id_idx" ON "public"."bank_transactions_2028" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_created_at_idx" ON "public"."bank_transactions_2028" USING "btree" ("created_at");


--
-- Name: bank_transactions_2028_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_created_at_idx1" ON "public"."bank_transactions_2028" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_date_idx" ON "public"."bank_transactions_2028" USING "btree" ("date");


--
-- Name: bank_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_integration_ref_idx" ON "public"."bank_transactions_2028" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2028_type_idx" ON "public"."bank_transactions_2028" USING "btree" ("type");


--
-- Name: bank_transactions_2029_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_bank_id_idx" ON "public"."bank_transactions_2029" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_created_at_idx" ON "public"."bank_transactions_2029" USING "btree" ("created_at");


--
-- Name: bank_transactions_2029_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_created_at_idx1" ON "public"."bank_transactions_2029" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_date_idx" ON "public"."bank_transactions_2029" USING "btree" ("date");


--
-- Name: bank_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_integration_ref_idx" ON "public"."bank_transactions_2029" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2029_type_idx" ON "public"."bank_transactions_2029" USING "btree" ("type");


--
-- Name: bank_transactions_2030_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_bank_id_idx" ON "public"."bank_transactions_2030" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_created_at_idx" ON "public"."bank_transactions_2030" USING "btree" ("created_at");


--
-- Name: bank_transactions_2030_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_created_at_idx1" ON "public"."bank_transactions_2030" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_date_idx" ON "public"."bank_transactions_2030" USING "btree" ("date");


--
-- Name: bank_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_integration_ref_idx" ON "public"."bank_transactions_2030" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2030_type_idx" ON "public"."bank_transactions_2030" USING "btree" ("type");


--
-- Name: bank_transactions_2031_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_bank_id_idx" ON "public"."bank_transactions_2031" USING "btree" ("bank_id");


--
-- Name: bank_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_created_at_idx" ON "public"."bank_transactions_2031" USING "btree" ("created_at");


--
-- Name: bank_transactions_2031_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_created_at_idx1" ON "public"."bank_transactions_2031" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_date_idx" ON "public"."bank_transactions_2031" USING "btree" ("date");


--
-- Name: bank_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_integration_ref_idx" ON "public"."bank_transactions_2031" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_2031_type_idx" ON "public"."bank_transactions_2031" USING "btree" ("type");


--
-- Name: bank_transactions_default_bank_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_bank_id_idx" ON "public"."bank_transactions_default" USING "btree" ("bank_id");


--
-- Name: bank_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_created_at_idx" ON "public"."bank_transactions_default" USING "btree" ("created_at");


--
-- Name: bank_transactions_default_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_created_at_idx1" ON "public"."bank_transactions_default" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: bank_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_date_idx" ON "public"."bank_transactions_default" USING "btree" ("date");


--
-- Name: bank_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_integration_ref_idx" ON "public"."bank_transactions_default" USING "btree" ("integration_ref");


--
-- Name: bank_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "bank_transactions_default_type_idx" ON "public"."bank_transactions_default" USING "btree" ("type");


--
-- Name: idx_crt_cash_register_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_cash_register_id" ON ONLY "public"."cash_register_transactions" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2024_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_cash_register_id_idx" ON "public"."cash_register_transactions_2024" USING "btree" ("cash_register_id");


--
-- Name: idx_crt_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_created_at" ON ONLY "public"."cash_register_transactions" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_created_at_idx" ON "public"."cash_register_transactions_2024" USING "btree" ("created_at");


--
-- Name: idx_crt_created_at_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_created_at_brin" ON ONLY "public"."cash_register_transactions" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2024_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_created_at_idx1" ON "public"."cash_register_transactions_2024" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: idx_crt_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_date" ON ONLY "public"."cash_register_transactions" USING "btree" ("date");


--
-- Name: cash_register_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_date_idx" ON "public"."cash_register_transactions_2024" USING "btree" ("date");


--
-- Name: idx_crt_integration_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_integration_ref" ON ONLY "public"."cash_register_transactions" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_integration_ref_idx" ON "public"."cash_register_transactions_2024" USING "btree" ("integration_ref");


--
-- Name: idx_crt_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_crt_type" ON ONLY "public"."cash_register_transactions" USING "btree" ("type");


--
-- Name: cash_register_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2024_type_idx" ON "public"."cash_register_transactions_2024" USING "btree" ("type");


--
-- Name: cash_register_transactions_2025_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_cash_register_id_idx" ON "public"."cash_register_transactions_2025" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_created_at_idx" ON "public"."cash_register_transactions_2025" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2025_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_created_at_idx1" ON "public"."cash_register_transactions_2025" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_date_idx" ON "public"."cash_register_transactions_2025" USING "btree" ("date");


--
-- Name: cash_register_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_integration_ref_idx" ON "public"."cash_register_transactions_2025" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2025_type_idx" ON "public"."cash_register_transactions_2025" USING "btree" ("type");


--
-- Name: cash_register_transactions_2026_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_cash_register_id_idx" ON "public"."cash_register_transactions_2026" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_created_at_idx" ON "public"."cash_register_transactions_2026" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2026_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_created_at_idx1" ON "public"."cash_register_transactions_2026" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_date_idx" ON "public"."cash_register_transactions_2026" USING "btree" ("date");


--
-- Name: cash_register_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_integration_ref_idx" ON "public"."cash_register_transactions_2026" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2026_type_idx" ON "public"."cash_register_transactions_2026" USING "btree" ("type");


--
-- Name: cash_register_transactions_2027_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_cash_register_id_idx" ON "public"."cash_register_transactions_2027" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_created_at_idx" ON "public"."cash_register_transactions_2027" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2027_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_created_at_idx1" ON "public"."cash_register_transactions_2027" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_date_idx" ON "public"."cash_register_transactions_2027" USING "btree" ("date");


--
-- Name: cash_register_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_integration_ref_idx" ON "public"."cash_register_transactions_2027" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2027_type_idx" ON "public"."cash_register_transactions_2027" USING "btree" ("type");


--
-- Name: cash_register_transactions_2028_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_cash_register_id_idx" ON "public"."cash_register_transactions_2028" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_created_at_idx" ON "public"."cash_register_transactions_2028" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2028_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_created_at_idx1" ON "public"."cash_register_transactions_2028" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_date_idx" ON "public"."cash_register_transactions_2028" USING "btree" ("date");


--
-- Name: cash_register_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_integration_ref_idx" ON "public"."cash_register_transactions_2028" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2028_type_idx" ON "public"."cash_register_transactions_2028" USING "btree" ("type");


--
-- Name: cash_register_transactions_2029_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_cash_register_id_idx" ON "public"."cash_register_transactions_2029" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_created_at_idx" ON "public"."cash_register_transactions_2029" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2029_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_created_at_idx1" ON "public"."cash_register_transactions_2029" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_date_idx" ON "public"."cash_register_transactions_2029" USING "btree" ("date");


--
-- Name: cash_register_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_integration_ref_idx" ON "public"."cash_register_transactions_2029" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2029_type_idx" ON "public"."cash_register_transactions_2029" USING "btree" ("type");


--
-- Name: cash_register_transactions_2030_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_cash_register_id_idx" ON "public"."cash_register_transactions_2030" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_created_at_idx" ON "public"."cash_register_transactions_2030" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2030_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_created_at_idx1" ON "public"."cash_register_transactions_2030" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_date_idx" ON "public"."cash_register_transactions_2030" USING "btree" ("date");


--
-- Name: cash_register_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_integration_ref_idx" ON "public"."cash_register_transactions_2030" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2030_type_idx" ON "public"."cash_register_transactions_2030" USING "btree" ("type");


--
-- Name: cash_register_transactions_2031_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_cash_register_id_idx" ON "public"."cash_register_transactions_2031" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_created_at_idx" ON "public"."cash_register_transactions_2031" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_2031_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_created_at_idx1" ON "public"."cash_register_transactions_2031" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_date_idx" ON "public"."cash_register_transactions_2031" USING "btree" ("date");


--
-- Name: cash_register_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_integration_ref_idx" ON "public"."cash_register_transactions_2031" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_2031_type_idx" ON "public"."cash_register_transactions_2031" USING "btree" ("type");


--
-- Name: cash_register_transactions_default_cash_register_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_cash_register_id_idx" ON "public"."cash_register_transactions_default" USING "btree" ("cash_register_id");


--
-- Name: cash_register_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_created_at_idx" ON "public"."cash_register_transactions_default" USING "btree" ("created_at");


--
-- Name: cash_register_transactions_default_created_at_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_created_at_idx1" ON "public"."cash_register_transactions_default" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: cash_register_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_date_idx" ON "public"."cash_register_transactions_default" USING "btree" ("date");


--
-- Name: cash_register_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_integration_ref_idx" ON "public"."cash_register_transactions_default" USING "btree" ("integration_ref");


--
-- Name: cash_register_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cash_register_transactions_default_type_idx" ON "public"."cash_register_transactions_default" USING "btree" ("type");


--
-- Name: idx_cat_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cat_account_id" ON ONLY "public"."current_account_transactions" USING "btree" ("current_account_id");


--
-- Name: cat_y2026_m02_current_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m02_current_account_id_idx" ON "public"."cat_y2026_m02" USING "btree" ("current_account_id");


--
-- Name: idx_cat_date_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cat_date_btree" ON ONLY "public"."current_account_transactions" USING "btree" ("date" DESC);


--
-- Name: cat_y2026_m02_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m02_date_idx" ON "public"."cat_y2026_m02" USING "btree" ("date" DESC);


--
-- Name: idx_cat_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cat_date_brin" ON ONLY "public"."current_account_transactions" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: cat_y2026_m02_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m02_date_idx1" ON "public"."cat_y2026_m02" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: idx_cat_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cat_ref" ON ONLY "public"."current_account_transactions" USING "btree" ("integration_ref");


--
-- Name: cat_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m02_integration_ref_idx" ON "public"."cat_y2026_m02" USING "btree" ("integration_ref");


--
-- Name: cat_y2026_m03_current_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m03_current_account_id_idx" ON "public"."cat_y2026_m03" USING "btree" ("current_account_id");


--
-- Name: cat_y2026_m03_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m03_date_idx" ON "public"."cat_y2026_m03" USING "btree" ("date" DESC);


--
-- Name: cat_y2026_m03_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m03_date_idx1" ON "public"."cat_y2026_m03" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: cat_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "cat_y2026_m03_integration_ref_idx" ON "public"."cat_y2026_m03" USING "btree" ("integration_ref");


--
-- Name: idx_cct_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cct_created_at" ON ONLY "public"."credit_card_transactions" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2024_created_at_idx" ON "public"."credit_card_transactions_2024" USING "btree" ("created_at");


--
-- Name: idx_cct_credit_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cct_credit_card_id" ON ONLY "public"."credit_card_transactions" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2024_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2024_credit_card_id_idx" ON "public"."credit_card_transactions_2024" USING "btree" ("credit_card_id");


--
-- Name: idx_cct_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cct_date" ON ONLY "public"."credit_card_transactions" USING "btree" ("date");


--
-- Name: credit_card_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2024_date_idx" ON "public"."credit_card_transactions_2024" USING "btree" ("date");


--
-- Name: idx_cct_integration_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cct_integration_ref" ON ONLY "public"."credit_card_transactions" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2024_integration_ref_idx" ON "public"."credit_card_transactions_2024" USING "btree" ("integration_ref");


--
-- Name: idx_cct_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cct_type" ON ONLY "public"."credit_card_transactions" USING "btree" ("type");


--
-- Name: credit_card_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2024_type_idx" ON "public"."credit_card_transactions_2024" USING "btree" ("type");


--
-- Name: credit_card_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2025_created_at_idx" ON "public"."credit_card_transactions_2025" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2025_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2025_credit_card_id_idx" ON "public"."credit_card_transactions_2025" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2025_date_idx" ON "public"."credit_card_transactions_2025" USING "btree" ("date");


--
-- Name: credit_card_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2025_integration_ref_idx" ON "public"."credit_card_transactions_2025" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2025_type_idx" ON "public"."credit_card_transactions_2025" USING "btree" ("type");


--
-- Name: credit_card_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2026_created_at_idx" ON "public"."credit_card_transactions_2026" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2026_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2026_credit_card_id_idx" ON "public"."credit_card_transactions_2026" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2026_date_idx" ON "public"."credit_card_transactions_2026" USING "btree" ("date");


--
-- Name: credit_card_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2026_integration_ref_idx" ON "public"."credit_card_transactions_2026" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2026_type_idx" ON "public"."credit_card_transactions_2026" USING "btree" ("type");


--
-- Name: credit_card_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2027_created_at_idx" ON "public"."credit_card_transactions_2027" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2027_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2027_credit_card_id_idx" ON "public"."credit_card_transactions_2027" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2027_date_idx" ON "public"."credit_card_transactions_2027" USING "btree" ("date");


--
-- Name: credit_card_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2027_integration_ref_idx" ON "public"."credit_card_transactions_2027" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2027_type_idx" ON "public"."credit_card_transactions_2027" USING "btree" ("type");


--
-- Name: credit_card_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2028_created_at_idx" ON "public"."credit_card_transactions_2028" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2028_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2028_credit_card_id_idx" ON "public"."credit_card_transactions_2028" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2028_date_idx" ON "public"."credit_card_transactions_2028" USING "btree" ("date");


--
-- Name: credit_card_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2028_integration_ref_idx" ON "public"."credit_card_transactions_2028" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2028_type_idx" ON "public"."credit_card_transactions_2028" USING "btree" ("type");


--
-- Name: credit_card_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2029_created_at_idx" ON "public"."credit_card_transactions_2029" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2029_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2029_credit_card_id_idx" ON "public"."credit_card_transactions_2029" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2029_date_idx" ON "public"."credit_card_transactions_2029" USING "btree" ("date");


--
-- Name: credit_card_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2029_integration_ref_idx" ON "public"."credit_card_transactions_2029" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2029_type_idx" ON "public"."credit_card_transactions_2029" USING "btree" ("type");


--
-- Name: credit_card_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2030_created_at_idx" ON "public"."credit_card_transactions_2030" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2030_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2030_credit_card_id_idx" ON "public"."credit_card_transactions_2030" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2030_date_idx" ON "public"."credit_card_transactions_2030" USING "btree" ("date");


--
-- Name: credit_card_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2030_integration_ref_idx" ON "public"."credit_card_transactions_2030" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2030_type_idx" ON "public"."credit_card_transactions_2030" USING "btree" ("type");


--
-- Name: credit_card_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2031_created_at_idx" ON "public"."credit_card_transactions_2031" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_2031_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2031_credit_card_id_idx" ON "public"."credit_card_transactions_2031" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2031_date_idx" ON "public"."credit_card_transactions_2031" USING "btree" ("date");


--
-- Name: credit_card_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2031_integration_ref_idx" ON "public"."credit_card_transactions_2031" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_2031_type_idx" ON "public"."credit_card_transactions_2031" USING "btree" ("type");


--
-- Name: credit_card_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_default_created_at_idx" ON "public"."credit_card_transactions_default" USING "btree" ("created_at");


--
-- Name: credit_card_transactions_default_credit_card_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_default_credit_card_id_idx" ON "public"."credit_card_transactions_default" USING "btree" ("credit_card_id");


--
-- Name: credit_card_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_default_date_idx" ON "public"."credit_card_transactions_default" USING "btree" ("date");


--
-- Name: credit_card_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_default_integration_ref_idx" ON "public"."credit_card_transactions_default" USING "btree" ("integration_ref");


--
-- Name: credit_card_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "credit_card_transactions_default_type_idx" ON "public"."credit_card_transactions_default" USING "btree" ("type");


--
-- Name: current_account_transactions_default_current_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "current_account_transactions_default_current_account_id_idx" ON "public"."current_account_transactions_default" USING "btree" ("current_account_id");


--
-- Name: current_account_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "current_account_transactions_default_date_idx" ON "public"."current_account_transactions_default" USING "btree" ("date" DESC);


--
-- Name: current_account_transactions_default_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "current_account_transactions_default_date_idx1" ON "public"."current_account_transactions_default" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: current_account_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "current_account_transactions_default_integration_ref_idx" ON "public"."current_account_transactions_default" USING "btree" ("integration_ref");


--
-- Name: idx_accounts_ad_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_ad_trgm" ON "public"."current_accounts" USING "gin" ("adi" "public"."gin_trgm_ops");


--
-- Name: idx_accounts_aktif_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_aktif_btree" ON "public"."current_accounts" USING "btree" ("aktif_mi");


--
-- Name: idx_accounts_city_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_city_btree" ON "public"."current_accounts" USING "btree" ("fat_sehir");


--
-- Name: idx_accounts_created_at_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_created_at_btree" ON "public"."current_accounts" USING "btree" ("created_at" DESC);


--
-- Name: idx_accounts_created_at_covering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_created_at_covering" ON "public"."current_accounts" USING "btree" ("created_at" DESC) INCLUDE ("id", "kod_no", "adi", "bakiye_borc", "bakiye_alacak");


--
-- Name: idx_accounts_kod_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_kod_btree" ON "public"."current_accounts" USING "btree" ("kod_no");


--
-- Name: idx_accounts_kod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_kod_trgm" ON "public"."current_accounts" USING "gin" ("kod_no" "public"."gin_trgm_ops");


--
-- Name: idx_accounts_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_search_tags_gin" ON "public"."current_accounts" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_accounts_type_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_accounts_type_btree" ON "public"."current_accounts" USING "btree" ("hesap_turu");


--
-- Name: idx_banks_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_banks_search_tags_gin" ON "public"."banks" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_cash_registers_code_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cash_registers_code_trgm" ON "public"."cash_registers" USING "gin" ("code" "public"."gin_trgm_ops");


--
-- Name: idx_cash_registers_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cash_registers_name_trgm" ON "public"."cash_registers" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_cash_registers_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cash_registers_search_tags_gin" ON "public"."cash_registers" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_cheque_transactions_cheque_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheque_transactions_cheque_id" ON "public"."cheque_transactions" USING "btree" ("cheque_id");


--
-- Name: idx_cheque_transactions_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheque_transactions_search_tags_gin" ON "public"."cheque_transactions" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_cheques_check_no_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_check_no_trgm" ON "public"."cheques" USING "gin" ("check_no" "public"."gin_trgm_ops");


--
-- Name: idx_cheques_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_company_id" ON "public"."cheques" USING "btree" ("company_id");


--
-- Name: idx_cheques_customer_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_customer_name_trgm" ON "public"."cheques" USING "gin" ("customer_name" "public"."gin_trgm_ops");


--
-- Name: idx_cheques_due_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_due_date_brin" ON "public"."cheques" USING "brin" ("due_date") WITH ("pages_per_range"='128');


--
-- Name: idx_cheques_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_is_active" ON "public"."cheques" USING "btree" ("is_active");


--
-- Name: idx_cheques_issue_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_issue_date_brin" ON "public"."cheques" USING "brin" ("issue_date") WITH ("pages_per_range"='128');


--
-- Name: idx_cheques_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_ref" ON "public"."cheques" USING "btree" ("integration_ref");


--
-- Name: idx_cheques_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_search_tags_gin" ON "public"."cheques" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_cheques_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_cheques_type" ON "public"."cheques" USING "btree" ("type");


--
-- Name: idx_credit_cards_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_credit_cards_search_tags_gin" ON "public"."credit_cards" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_currency_rates_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "idx_currency_rates_pair" ON "public"."currency_rates" USING "btree" ("from_code", "to_code");


--
-- Name: idx_depots_ad_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_depots_ad_trgm" ON "public"."depots" USING "gin" ("ad" "public"."gin_trgm_ops");


--
-- Name: idx_depots_kod_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_depots_kod_btree" ON "public"."depots" USING "btree" ("kod");


--
-- Name: idx_depots_kod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_depots_kod_trgm" ON "public"."depots" USING "gin" ("kod" "public"."gin_trgm_ops");


--
-- Name: idx_depots_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_depots_search_tags_gin" ON "public"."depots" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_expense_items_expense_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expense_items_expense_id" ON "public"."expense_items" USING "btree" ("expense_id");


--
-- Name: idx_expenses_aktif_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_aktif_btree" ON "public"."expenses" USING "btree" ("aktif_mi");


--
-- Name: idx_expenses_baslik_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_baslik_trgm" ON "public"."expenses" USING "gin" ("baslik" "public"."gin_trgm_ops");


--
-- Name: idx_expenses_kategori_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_kategori_btree" ON "public"."expenses" USING "btree" ("kategori");


--
-- Name: idx_expenses_kod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_kod_trgm" ON "public"."expenses" USING "gin" ("kod" "public"."gin_trgm_ops");


--
-- Name: idx_expenses_kullanici_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_kullanici_btree" ON "public"."expenses" USING "btree" ("kullanici");


--
-- Name: idx_expenses_odeme_durumu_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_odeme_durumu_btree" ON "public"."expenses" USING "btree" ("odeme_durumu");


--
-- Name: idx_expenses_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_search_tags_gin" ON "public"."expenses" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_expenses_tarih_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_expenses_tarih_brin" ON "public"."expenses" USING "brin" ("tarih") WITH ("pages_per_range"='64');


--
-- Name: idx_installments_cari; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_installments_cari" ON "public"."installments" USING "btree" ("cari_id");


--
-- Name: idx_installments_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_installments_ref" ON "public"."installments" USING "btree" ("integration_ref");


--
-- Name: idx_kasa_trans_2024_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2024_basic" ON "public"."cash_register_transactions_2024" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2025_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2025_basic" ON "public"."cash_register_transactions_2025" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2026_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2026_basic" ON "public"."cash_register_transactions_2026" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2027_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2027_basic" ON "public"."cash_register_transactions_2027" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2028_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2028_basic" ON "public"."cash_register_transactions_2028" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2029_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2029_basic" ON "public"."cash_register_transactions_2029" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2030_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2030_basic" ON "public"."cash_register_transactions_2030" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_2031_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_2031_basic" ON "public"."cash_register_transactions_2031" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_kasa_trans_default_basic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_kasa_trans_default_basic" ON "public"."cash_register_transactions_default" USING "btree" ("cash_register_id", "date");


--
-- Name: idx_note_transactions_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_note_transactions_note_id" ON "public"."note_transactions" USING "btree" ("note_id");


--
-- Name: idx_note_transactions_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_note_transactions_search_tags_gin" ON "public"."note_transactions" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_notes_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_company_id" ON "public"."promissory_notes" USING "btree" ("company_id");


--
-- Name: idx_notes_customer_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_customer_name_trgm" ON "public"."promissory_notes" USING "gin" ("customer_name" "public"."gin_trgm_ops");


--
-- Name: idx_notes_due_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_due_date_brin" ON "public"."promissory_notes" USING "brin" ("due_date") WITH ("pages_per_range"='128');


--
-- Name: idx_notes_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_is_active" ON "public"."promissory_notes" USING "btree" ("is_active");


--
-- Name: idx_notes_issue_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_issue_date_brin" ON "public"."promissory_notes" USING "brin" ("issue_date") WITH ("pages_per_range"='128');


--
-- Name: idx_notes_note_no_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_note_no_trgm" ON "public"."promissory_notes" USING "gin" ("note_no" "public"."gin_trgm_ops");


--
-- Name: idx_notes_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_ref" ON "public"."promissory_notes" USING "btree" ("integration_ref");


--
-- Name: idx_notes_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_search_tags_gin" ON "public"."promissory_notes" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_notes_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_notes_type" ON "public"."promissory_notes" USING "btree" ("type");


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");


--
-- Name: idx_orders_integration_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_orders_integration_ref" ON ONLY "public"."orders" USING "btree" ("integration_ref");


--
-- Name: idx_orders_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_orders_tarih" ON ONLY "public"."orders" USING "btree" ("tarih" DESC);


--
-- Name: idx_pd_identity_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_pd_identity_value" ON "public"."product_devices" USING "btree" ("identity_value");


--
-- Name: idx_pd_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_pd_product_id" ON "public"."product_devices" USING "btree" ("product_id");


--
-- Name: idx_productions_ad_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_ad_trgm" ON "public"."productions" USING "gin" ("ad" "public"."gin_trgm_ops");


--
-- Name: idx_productions_aktif_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_aktif_btree" ON "public"."productions" USING "btree" ("aktif_mi");


--
-- Name: idx_productions_barkod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_barkod_trgm" ON "public"."productions" USING "gin" ("barkod" "public"."gin_trgm_ops");


--
-- Name: idx_productions_birim_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_birim_btree" ON "public"."productions" USING "btree" ("birim");


--
-- Name: idx_productions_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_created_by" ON "public"."productions" USING "btree" ("created_by");


--
-- Name: idx_productions_grubu_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_grubu_btree" ON "public"."productions" USING "btree" ("grubu");


--
-- Name: idx_productions_kdv_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_kdv_btree" ON "public"."productions" USING "btree" ("kdv_orani");


--
-- Name: idx_productions_kod_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_kod_btree" ON "public"."productions" USING "btree" ("kod");


--
-- Name: idx_productions_kod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_kod_trgm" ON "public"."productions" USING "gin" ("kod" "public"."gin_trgm_ops");


--
-- Name: idx_productions_kullanici_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_kullanici_trgm" ON "public"."productions" USING "gin" ("kullanici" "public"."gin_trgm_ops");


--
-- Name: idx_productions_ozellikler_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_ozellikler_trgm" ON "public"."productions" USING "gin" ("ozellikler" "public"."gin_trgm_ops");


--
-- Name: idx_productions_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_productions_search_tags_gin" ON "public"."productions" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_products_ad_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_ad_trgm" ON "public"."products" USING "gin" ("ad" "public"."gin_trgm_ops");


--
-- Name: idx_products_aktif_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_aktif_btree" ON "public"."products" USING "btree" ("aktif_mi");


--
-- Name: idx_products_barkod_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_barkod_btree" ON "public"."products" USING "btree" ("barkod") WHERE ("barkod" IS NOT NULL);


--
-- Name: idx_products_barkod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_barkod_trgm" ON "public"."products" USING "gin" ("barkod" "public"."gin_trgm_ops");


--
-- Name: idx_products_birim_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_birim_btree" ON "public"."products" USING "btree" ("birim");


--
-- Name: idx_products_created_at_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_created_at_brin" ON "public"."products" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: idx_products_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_created_by" ON "public"."products" USING "btree" ("created_by");


--
-- Name: idx_products_grubu_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_grubu_btree" ON "public"."products" USING "btree" ("grubu");


--
-- Name: idx_products_kdv_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_kdv_btree" ON "public"."products" USING "btree" ("kdv_orani");


--
-- Name: idx_products_kod_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_kod_btree" ON "public"."products" USING "btree" ("kod");


--
-- Name: idx_products_kod_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_kod_trgm" ON "public"."products" USING "gin" ("kod" "public"."gin_trgm_ops");


--
-- Name: idx_products_search_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_products_search_tags_gin" ON "public"."products" USING "gin" ("search_tags" "public"."gin_trgm_ops");


--
-- Name: idx_psm_created_at_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_psm_created_at_brin" ON ONLY "public"."production_stock_movements" USING "brin" ("created_at");


--
-- Name: idx_psm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_psm_date" ON ONLY "public"."production_stock_movements" USING "btree" ("movement_date");


--
-- Name: idx_psm_production_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_psm_production_id" ON ONLY "public"."production_stock_movements" USING "btree" ("production_id");


--
-- Name: idx_psm_related_shipments_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_psm_related_shipments_gin" ON ONLY "public"."production_stock_movements" USING "gin" ("related_shipment_ids");


--
-- Name: idx_psm_warehouse_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_psm_warehouse_id" ON ONLY "public"."production_stock_movements" USING "btree" ("warehouse_id");


--
-- Name: idx_quote_items_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_quote_items_quote_id" ON "public"."quote_items" USING "btree" ("quote_id");


--
-- Name: idx_quotes_integration_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_quotes_integration_ref" ON ONLY "public"."quotes" USING "btree" ("integration_ref");


--
-- Name: idx_quotes_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_quotes_tarih" ON ONLY "public"."quotes" USING "btree" ("tarih" DESC);


--
-- Name: idx_recipe_product_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_recipe_product_code" ON "public"."production_recipe_items" USING "btree" ("product_code");


--
-- Name: idx_recipe_production_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_recipe_production_id" ON "public"."production_recipe_items" USING "btree" ("production_id");


--
-- Name: idx_saved_descriptions_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_saved_descriptions_search" ON "public"."saved_descriptions" USING "btree" ("category", "content");


--
-- Name: idx_shipments_created_by_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_created_by_trgm" ON "public"."shipments" USING "gin" ("created_by" "public"."gin_trgm_ops");


--
-- Name: idx_shipments_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_date" ON "public"."shipments" USING "btree" ("date");


--
-- Name: idx_shipments_description_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_description_trgm" ON "public"."shipments" USING "gin" ("description" "public"."gin_trgm_ops");


--
-- Name: idx_shipments_dest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_dest_id" ON "public"."shipments" USING "btree" ("dest_warehouse_id");


--
-- Name: idx_shipments_items_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_items_gin" ON "public"."shipments" USING "gin" ("items");


--
-- Name: idx_shipments_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_shipments_source_id" ON "public"."shipments" USING "btree" ("source_warehouse_id");


--
-- Name: idx_sm_created_at_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_created_at_brin" ON ONLY "public"."stock_movements" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: idx_sm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_date" ON ONLY "public"."stock_movements" USING "btree" ("movement_date");


--
-- Name: idx_sm_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_date_brin" ON ONLY "public"."stock_movements" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: idx_sm_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_product_id" ON ONLY "public"."stock_movements" USING "btree" ("product_id");


--
-- Name: idx_sm_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_ref" ON ONLY "public"."stock_movements" USING "btree" ("integration_ref");


--
-- Name: idx_sm_shipment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_shipment_id" ON ONLY "public"."stock_movements" USING "btree" ("shipment_id");


--
-- Name: idx_sm_warehouse_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sm_warehouse_id" ON ONLY "public"."stock_movements" USING "btree" ("warehouse_id");


--
-- Name: idx_sync_outbox_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_sync_outbox_status" ON "public"."sync_outbox" USING "btree" ("status");


--
-- Name: idx_ut_date_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_ut_date_brin" ON ONLY "public"."user_transactions" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: idx_ut_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_ut_type" ON ONLY "public"."user_transactions" USING "btree" ("type");


--
-- Name: idx_ut_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_ut_user_id" ON ONLY "public"."user_transactions" USING "btree" ("user_id");


--
-- Name: idx_warehouse_stocks_pcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_warehouse_stocks_pcode" ON "public"."warehouse_stocks" USING "btree" ("product_code");


--
-- Name: idx_warehouse_stocks_wid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_warehouse_stocks_wid" ON "public"."warehouse_stocks" USING "btree" ("warehouse_id");


--
-- Name: orders_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_default_integration_ref_idx" ON "public"."orders_default" USING "btree" ("integration_ref");


--
-- Name: orders_default_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_default_tarih_idx" ON "public"."orders_default" USING "btree" ("tarih" DESC);


--
-- Name: orders_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_y2026_m02_integration_ref_idx" ON "public"."orders_y2026_m02" USING "btree" ("integration_ref");


--
-- Name: orders_y2026_m02_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_y2026_m02_tarih_idx" ON "public"."orders_y2026_m02" USING "btree" ("tarih" DESC);


--
-- Name: orders_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_y2026_m03_integration_ref_idx" ON "public"."orders_y2026_m03" USING "btree" ("integration_ref");


--
-- Name: orders_y2026_m03_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "orders_y2026_m03_tarih_idx" ON "public"."orders_y2026_m03" USING "btree" ("tarih" DESC);


--
-- Name: production_stock_movements_2020_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2020_created_at_idx" ON "public"."production_stock_movements_2020" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2020_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2020_movement_date_idx" ON "public"."production_stock_movements_2020" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2020_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2020_production_id_idx" ON "public"."production_stock_movements_2020" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2020_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2020_related_shipment_ids_idx" ON "public"."production_stock_movements_2020" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2020_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2020_warehouse_id_idx" ON "public"."production_stock_movements_2020" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2021_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2021_created_at_idx" ON "public"."production_stock_movements_2021" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2021_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2021_movement_date_idx" ON "public"."production_stock_movements_2021" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2021_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2021_production_id_idx" ON "public"."production_stock_movements_2021" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2021_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2021_related_shipment_ids_idx" ON "public"."production_stock_movements_2021" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2021_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2021_warehouse_id_idx" ON "public"."production_stock_movements_2021" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2022_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2022_created_at_idx" ON "public"."production_stock_movements_2022" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2022_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2022_movement_date_idx" ON "public"."production_stock_movements_2022" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2022_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2022_production_id_idx" ON "public"."production_stock_movements_2022" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2022_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2022_related_shipment_ids_idx" ON "public"."production_stock_movements_2022" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2022_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2022_warehouse_id_idx" ON "public"."production_stock_movements_2022" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2023_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2023_created_at_idx" ON "public"."production_stock_movements_2023" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2023_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2023_movement_date_idx" ON "public"."production_stock_movements_2023" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2023_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2023_production_id_idx" ON "public"."production_stock_movements_2023" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2023_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2023_related_shipment_ids_idx" ON "public"."production_stock_movements_2023" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2023_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2023_warehouse_id_idx" ON "public"."production_stock_movements_2023" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2024_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2024_created_at_idx" ON "public"."production_stock_movements_2024" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2024_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2024_movement_date_idx" ON "public"."production_stock_movements_2024" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2024_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2024_production_id_idx" ON "public"."production_stock_movements_2024" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2024_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2024_related_shipment_ids_idx" ON "public"."production_stock_movements_2024" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2024_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2024_warehouse_id_idx" ON "public"."production_stock_movements_2024" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2025_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2025_created_at_idx" ON "public"."production_stock_movements_2025" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2025_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2025_movement_date_idx" ON "public"."production_stock_movements_2025" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2025_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2025_production_id_idx" ON "public"."production_stock_movements_2025" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2025_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2025_related_shipment_ids_idx" ON "public"."production_stock_movements_2025" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2025_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2025_warehouse_id_idx" ON "public"."production_stock_movements_2025" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2026_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2026_created_at_idx" ON "public"."production_stock_movements_2026" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2026_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2026_movement_date_idx" ON "public"."production_stock_movements_2026" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2026_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2026_production_id_idx" ON "public"."production_stock_movements_2026" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2026_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2026_related_shipment_ids_idx" ON "public"."production_stock_movements_2026" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2026_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2026_warehouse_id_idx" ON "public"."production_stock_movements_2026" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2027_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2027_created_at_idx" ON "public"."production_stock_movements_2027" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2027_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2027_movement_date_idx" ON "public"."production_stock_movements_2027" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2027_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2027_production_id_idx" ON "public"."production_stock_movements_2027" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2027_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2027_related_shipment_ids_idx" ON "public"."production_stock_movements_2027" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2027_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2027_warehouse_id_idx" ON "public"."production_stock_movements_2027" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2028_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2028_created_at_idx" ON "public"."production_stock_movements_2028" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2028_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2028_movement_date_idx" ON "public"."production_stock_movements_2028" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2028_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2028_production_id_idx" ON "public"."production_stock_movements_2028" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2028_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2028_related_shipment_ids_idx" ON "public"."production_stock_movements_2028" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2028_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2028_warehouse_id_idx" ON "public"."production_stock_movements_2028" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2029_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2029_created_at_idx" ON "public"."production_stock_movements_2029" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2029_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2029_movement_date_idx" ON "public"."production_stock_movements_2029" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2029_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2029_production_id_idx" ON "public"."production_stock_movements_2029" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2029_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2029_related_shipment_ids_idx" ON "public"."production_stock_movements_2029" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2029_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2029_warehouse_id_idx" ON "public"."production_stock_movements_2029" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2030_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2030_created_at_idx" ON "public"."production_stock_movements_2030" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2030_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2030_movement_date_idx" ON "public"."production_stock_movements_2030" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2030_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2030_production_id_idx" ON "public"."production_stock_movements_2030" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2030_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2030_related_shipment_ids_idx" ON "public"."production_stock_movements_2030" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2030_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2030_warehouse_id_idx" ON "public"."production_stock_movements_2030" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2031_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2031_created_at_idx" ON "public"."production_stock_movements_2031" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2031_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2031_movement_date_idx" ON "public"."production_stock_movements_2031" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2031_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2031_production_id_idx" ON "public"."production_stock_movements_2031" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2031_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2031_related_shipment_ids_idx" ON "public"."production_stock_movements_2031" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2031_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2031_warehouse_id_idx" ON "public"."production_stock_movements_2031" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2032_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2032_created_at_idx" ON "public"."production_stock_movements_2032" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2032_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2032_movement_date_idx" ON "public"."production_stock_movements_2032" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2032_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2032_production_id_idx" ON "public"."production_stock_movements_2032" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2032_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2032_related_shipment_ids_idx" ON "public"."production_stock_movements_2032" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2032_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2032_warehouse_id_idx" ON "public"."production_stock_movements_2032" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2033_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2033_created_at_idx" ON "public"."production_stock_movements_2033" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2033_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2033_movement_date_idx" ON "public"."production_stock_movements_2033" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2033_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2033_production_id_idx" ON "public"."production_stock_movements_2033" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2033_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2033_related_shipment_ids_idx" ON "public"."production_stock_movements_2033" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2033_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2033_warehouse_id_idx" ON "public"."production_stock_movements_2033" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2034_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2034_created_at_idx" ON "public"."production_stock_movements_2034" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2034_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2034_movement_date_idx" ON "public"."production_stock_movements_2034" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2034_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2034_production_id_idx" ON "public"."production_stock_movements_2034" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2034_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2034_related_shipment_ids_idx" ON "public"."production_stock_movements_2034" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2034_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2034_warehouse_id_idx" ON "public"."production_stock_movements_2034" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2035_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2035_created_at_idx" ON "public"."production_stock_movements_2035" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2035_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2035_movement_date_idx" ON "public"."production_stock_movements_2035" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2035_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2035_production_id_idx" ON "public"."production_stock_movements_2035" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2035_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2035_related_shipment_ids_idx" ON "public"."production_stock_movements_2035" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2035_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2035_warehouse_id_idx" ON "public"."production_stock_movements_2035" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_2036_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2036_created_at_idx" ON "public"."production_stock_movements_2036" USING "brin" ("created_at");


--
-- Name: production_stock_movements_2036_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2036_movement_date_idx" ON "public"."production_stock_movements_2036" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_2036_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2036_production_id_idx" ON "public"."production_stock_movements_2036" USING "btree" ("production_id");


--
-- Name: production_stock_movements_2036_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2036_related_shipment_ids_idx" ON "public"."production_stock_movements_2036" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_2036_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_2036_warehouse_id_idx" ON "public"."production_stock_movements_2036" USING "btree" ("warehouse_id");


--
-- Name: production_stock_movements_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_default_created_at_idx" ON "public"."production_stock_movements_default" USING "brin" ("created_at");


--
-- Name: production_stock_movements_default_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_default_movement_date_idx" ON "public"."production_stock_movements_default" USING "btree" ("movement_date");


--
-- Name: production_stock_movements_default_production_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_default_production_id_idx" ON "public"."production_stock_movements_default" USING "btree" ("production_id");


--
-- Name: production_stock_movements_default_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_default_related_shipment_ids_idx" ON "public"."production_stock_movements_default" USING "gin" ("related_shipment_ids");


--
-- Name: production_stock_movements_default_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "production_stock_movements_default_warehouse_id_idx" ON "public"."production_stock_movements_default" USING "btree" ("warehouse_id");


--
-- Name: quotes_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_default_integration_ref_idx" ON "public"."quotes_default" USING "btree" ("integration_ref");


--
-- Name: quotes_default_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_default_tarih_idx" ON "public"."quotes_default" USING "btree" ("tarih" DESC);


--
-- Name: quotes_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_y2026_m02_integration_ref_idx" ON "public"."quotes_y2026_m02" USING "btree" ("integration_ref");


--
-- Name: quotes_y2026_m02_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_y2026_m02_tarih_idx" ON "public"."quotes_y2026_m02" USING "btree" ("tarih" DESC);


--
-- Name: quotes_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_y2026_m03_integration_ref_idx" ON "public"."quotes_y2026_m03" USING "btree" ("integration_ref");


--
-- Name: quotes_y2026_m03_tarih_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "quotes_y2026_m03_tarih_idx" ON "public"."quotes_y2026_m03" USING "btree" ("tarih" DESC);


--
-- Name: stock_movements_2025_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_created_at_idx" ON "public"."stock_movements_2025" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_integration_ref_idx" ON "public"."stock_movements_2025" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2025_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_movement_date_idx" ON "public"."stock_movements_2025" USING "btree" ("movement_date");


--
-- Name: stock_movements_2025_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_movement_date_idx1" ON "public"."stock_movements_2025" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2025_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_product_id_idx" ON "public"."stock_movements_2025" USING "btree" ("product_id");


--
-- Name: stock_movements_2025_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_shipment_id_idx" ON "public"."stock_movements_2025" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2025_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2025_warehouse_id_idx" ON "public"."stock_movements_2025" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2026_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_created_at_idx" ON "public"."stock_movements_2026" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_integration_ref_idx" ON "public"."stock_movements_2026" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2026_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_movement_date_idx" ON "public"."stock_movements_2026" USING "btree" ("movement_date");


--
-- Name: stock_movements_2026_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_movement_date_idx1" ON "public"."stock_movements_2026" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2026_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_product_id_idx" ON "public"."stock_movements_2026" USING "btree" ("product_id");


--
-- Name: stock_movements_2026_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_shipment_id_idx" ON "public"."stock_movements_2026" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2026_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2026_warehouse_id_idx" ON "public"."stock_movements_2026" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2027_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_created_at_idx" ON "public"."stock_movements_2027" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_integration_ref_idx" ON "public"."stock_movements_2027" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2027_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_movement_date_idx" ON "public"."stock_movements_2027" USING "btree" ("movement_date");


--
-- Name: stock_movements_2027_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_movement_date_idx1" ON "public"."stock_movements_2027" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2027_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_product_id_idx" ON "public"."stock_movements_2027" USING "btree" ("product_id");


--
-- Name: stock_movements_2027_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_shipment_id_idx" ON "public"."stock_movements_2027" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2027_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2027_warehouse_id_idx" ON "public"."stock_movements_2027" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2028_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_created_at_idx" ON "public"."stock_movements_2028" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_integration_ref_idx" ON "public"."stock_movements_2028" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2028_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_movement_date_idx" ON "public"."stock_movements_2028" USING "btree" ("movement_date");


--
-- Name: stock_movements_2028_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_movement_date_idx1" ON "public"."stock_movements_2028" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2028_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_product_id_idx" ON "public"."stock_movements_2028" USING "btree" ("product_id");


--
-- Name: stock_movements_2028_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_shipment_id_idx" ON "public"."stock_movements_2028" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2028_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2028_warehouse_id_idx" ON "public"."stock_movements_2028" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2029_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_created_at_idx" ON "public"."stock_movements_2029" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_integration_ref_idx" ON "public"."stock_movements_2029" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2029_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_movement_date_idx" ON "public"."stock_movements_2029" USING "btree" ("movement_date");


--
-- Name: stock_movements_2029_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_movement_date_idx1" ON "public"."stock_movements_2029" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2029_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_product_id_idx" ON "public"."stock_movements_2029" USING "btree" ("product_id");


--
-- Name: stock_movements_2029_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_shipment_id_idx" ON "public"."stock_movements_2029" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2029_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2029_warehouse_id_idx" ON "public"."stock_movements_2029" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2030_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_created_at_idx" ON "public"."stock_movements_2030" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_integration_ref_idx" ON "public"."stock_movements_2030" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2030_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_movement_date_idx" ON "public"."stock_movements_2030" USING "btree" ("movement_date");


--
-- Name: stock_movements_2030_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_movement_date_idx1" ON "public"."stock_movements_2030" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2030_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_product_id_idx" ON "public"."stock_movements_2030" USING "btree" ("product_id");


--
-- Name: stock_movements_2030_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_shipment_id_idx" ON "public"."stock_movements_2030" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2030_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2030_warehouse_id_idx" ON "public"."stock_movements_2030" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_2031_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_created_at_idx" ON "public"."stock_movements_2031" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_integration_ref_idx" ON "public"."stock_movements_2031" USING "btree" ("integration_ref");


--
-- Name: stock_movements_2031_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_movement_date_idx" ON "public"."stock_movements_2031" USING "btree" ("movement_date");


--
-- Name: stock_movements_2031_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_movement_date_idx1" ON "public"."stock_movements_2031" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_2031_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_product_id_idx" ON "public"."stock_movements_2031" USING "btree" ("product_id");


--
-- Name: stock_movements_2031_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_shipment_id_idx" ON "public"."stock_movements_2031" USING "btree" ("shipment_id");


--
-- Name: stock_movements_2031_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_2031_warehouse_id_idx" ON "public"."stock_movements_2031" USING "btree" ("warehouse_id");


--
-- Name: stock_movements_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_created_at_idx" ON "public"."stock_movements_default" USING "brin" ("created_at") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_integration_ref_idx" ON "public"."stock_movements_default" USING "btree" ("integration_ref");


--
-- Name: stock_movements_default_movement_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_movement_date_idx" ON "public"."stock_movements_default" USING "btree" ("movement_date");


--
-- Name: stock_movements_default_movement_date_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_movement_date_idx1" ON "public"."stock_movements_default" USING "brin" ("movement_date") WITH ("pages_per_range"='128');


--
-- Name: stock_movements_default_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_product_id_idx" ON "public"."stock_movements_default" USING "btree" ("product_id");


--
-- Name: stock_movements_default_shipment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_shipment_id_idx" ON "public"."stock_movements_default" USING "btree" ("shipment_id");


--
-- Name: stock_movements_default_warehouse_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "stock_movements_default_warehouse_id_idx" ON "public"."stock_movements_default" USING "btree" ("warehouse_id");


--
-- Name: user_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2024_date_idx" ON "public"."user_transactions_2024" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2024_type_idx" ON "public"."user_transactions_2024" USING "btree" ("type");


--
-- Name: user_transactions_2024_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2024_user_id_idx" ON "public"."user_transactions_2024" USING "btree" ("user_id");


--
-- Name: user_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2025_date_idx" ON "public"."user_transactions_2025" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2025_type_idx" ON "public"."user_transactions_2025" USING "btree" ("type");


--
-- Name: user_transactions_2025_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2025_user_id_idx" ON "public"."user_transactions_2025" USING "btree" ("user_id");


--
-- Name: user_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2026_date_idx" ON "public"."user_transactions_2026" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2026_type_idx" ON "public"."user_transactions_2026" USING "btree" ("type");


--
-- Name: user_transactions_2026_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2026_user_id_idx" ON "public"."user_transactions_2026" USING "btree" ("user_id");


--
-- Name: user_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2027_date_idx" ON "public"."user_transactions_2027" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2027_type_idx" ON "public"."user_transactions_2027" USING "btree" ("type");


--
-- Name: user_transactions_2027_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2027_user_id_idx" ON "public"."user_transactions_2027" USING "btree" ("user_id");


--
-- Name: user_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2028_date_idx" ON "public"."user_transactions_2028" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2028_type_idx" ON "public"."user_transactions_2028" USING "btree" ("type");


--
-- Name: user_transactions_2028_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2028_user_id_idx" ON "public"."user_transactions_2028" USING "btree" ("user_id");


--
-- Name: user_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2029_date_idx" ON "public"."user_transactions_2029" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2029_type_idx" ON "public"."user_transactions_2029" USING "btree" ("type");


--
-- Name: user_transactions_2029_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2029_user_id_idx" ON "public"."user_transactions_2029" USING "btree" ("user_id");


--
-- Name: user_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2030_date_idx" ON "public"."user_transactions_2030" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2030_type_idx" ON "public"."user_transactions_2030" USING "btree" ("type");


--
-- Name: user_transactions_2030_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2030_user_id_idx" ON "public"."user_transactions_2030" USING "btree" ("user_id");


--
-- Name: user_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2031_date_idx" ON "public"."user_transactions_2031" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2031_type_idx" ON "public"."user_transactions_2031" USING "btree" ("type");


--
-- Name: user_transactions_2031_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_2031_user_id_idx" ON "public"."user_transactions_2031" USING "btree" ("user_id");


--
-- Name: user_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_default_date_idx" ON "public"."user_transactions_default" USING "brin" ("date") WITH ("pages_per_range"='128');


--
-- Name: user_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_default_type_idx" ON "public"."user_transactions_default" USING "btree" ("type");


--
-- Name: user_transactions_default_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_transactions_default_user_id_idx" ON "public"."user_transactions_default" USING "btree" ("user_id");


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX "ix_realtime_subscription_entity" ON "realtime"."subscription" USING "btree" ("entity");


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX "messages_inserted_at_topic_index" ON ONLY "realtime"."messages" USING "btree" ("inserted_at" DESC, "topic") WHERE (("extension" = 'broadcast'::"text") AND ("private" IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX "subscription_subscription_id_entity_filters_action_filter_key" ON "realtime"."subscription" USING "btree" ("subscription_id", "entity", "filters", "action_filter");


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX "bname" ON "storage"."buckets" USING "btree" ("name");


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX "bucketid_objname" ON "storage"."objects" USING "btree" ("bucket_id", "name");


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX "buckets_analytics_unique_name_idx" ON "storage"."buckets_analytics" USING "btree" ("name") WHERE ("deleted_at" IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX "idx_multipart_uploads_list" ON "storage"."s3_multipart_uploads" USING "btree" ("bucket_id", "key", "created_at");


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX "idx_objects_bucket_id_name" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX "idx_objects_bucket_id_name_lower" ON "storage"."objects" USING "btree" ("bucket_id", "lower"("name") COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX "name_prefix_search" ON "storage"."objects" USING "btree" ("name" "text_pattern_ops");


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX "vector_indexes_name_bucket_id_idx" ON "storage"."vector_indexes" USING "btree" ("name", "bucket_id");


--
-- Name: bank_transactions_2024_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2024_bank_id_idx";


--
-- Name: bank_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2024_created_at_idx";


--
-- Name: bank_transactions_2024_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2024_created_at_idx1";


--
-- Name: bank_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2024_date_idx";


--
-- Name: bank_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2024_integration_ref_idx";


--
-- Name: bank_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2024_pkey";


--
-- Name: bank_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2024_type_idx";


--
-- Name: bank_transactions_2025_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2025_bank_id_idx";


--
-- Name: bank_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2025_created_at_idx";


--
-- Name: bank_transactions_2025_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2025_created_at_idx1";


--
-- Name: bank_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2025_date_idx";


--
-- Name: bank_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2025_integration_ref_idx";


--
-- Name: bank_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2025_pkey";


--
-- Name: bank_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2025_type_idx";


--
-- Name: bank_transactions_2026_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2026_bank_id_idx";


--
-- Name: bank_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2026_created_at_idx";


--
-- Name: bank_transactions_2026_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2026_created_at_idx1";


--
-- Name: bank_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2026_date_idx";


--
-- Name: bank_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2026_integration_ref_idx";


--
-- Name: bank_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2026_pkey";


--
-- Name: bank_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2026_type_idx";


--
-- Name: bank_transactions_2027_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2027_bank_id_idx";


--
-- Name: bank_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2027_created_at_idx";


--
-- Name: bank_transactions_2027_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2027_created_at_idx1";


--
-- Name: bank_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2027_date_idx";


--
-- Name: bank_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2027_integration_ref_idx";


--
-- Name: bank_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2027_pkey";


--
-- Name: bank_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2027_type_idx";


--
-- Name: bank_transactions_2028_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2028_bank_id_idx";


--
-- Name: bank_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2028_created_at_idx";


--
-- Name: bank_transactions_2028_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2028_created_at_idx1";


--
-- Name: bank_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2028_date_idx";


--
-- Name: bank_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2028_integration_ref_idx";


--
-- Name: bank_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2028_pkey";


--
-- Name: bank_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2028_type_idx";


--
-- Name: bank_transactions_2029_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2029_bank_id_idx";


--
-- Name: bank_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2029_created_at_idx";


--
-- Name: bank_transactions_2029_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2029_created_at_idx1";


--
-- Name: bank_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2029_date_idx";


--
-- Name: bank_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2029_integration_ref_idx";


--
-- Name: bank_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2029_pkey";


--
-- Name: bank_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2029_type_idx";


--
-- Name: bank_transactions_2030_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2030_bank_id_idx";


--
-- Name: bank_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2030_created_at_idx";


--
-- Name: bank_transactions_2030_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2030_created_at_idx1";


--
-- Name: bank_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2030_date_idx";


--
-- Name: bank_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2030_integration_ref_idx";


--
-- Name: bank_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2030_pkey";


--
-- Name: bank_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2030_type_idx";


--
-- Name: bank_transactions_2031_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_2031_bank_id_idx";


--
-- Name: bank_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_2031_created_at_idx";


--
-- Name: bank_transactions_2031_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_2031_created_at_idx1";


--
-- Name: bank_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_2031_date_idx";


--
-- Name: bank_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_2031_integration_ref_idx";


--
-- Name: bank_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_2031_pkey";


--
-- Name: bank_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_2031_type_idx";


--
-- Name: bank_transactions_default_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_bank_id" ATTACH PARTITION "public"."bank_transactions_default_bank_id_idx";


--
-- Name: bank_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at" ATTACH PARTITION "public"."bank_transactions_default_created_at_idx";


--
-- Name: bank_transactions_default_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_created_at_brin" ATTACH PARTITION "public"."bank_transactions_default_created_at_idx1";


--
-- Name: bank_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_date" ATTACH PARTITION "public"."bank_transactions_default_date_idx";


--
-- Name: bank_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_integration_ref" ATTACH PARTITION "public"."bank_transactions_default_integration_ref_idx";


--
-- Name: bank_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."bank_transactions_pkey" ATTACH PARTITION "public"."bank_transactions_default_pkey";


--
-- Name: bank_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_bt_type" ATTACH PARTITION "public"."bank_transactions_default_type_idx";


--
-- Name: cash_register_transactions_2024_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2024_cash_register_id_idx";


--
-- Name: cash_register_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2024_created_at_idx";


--
-- Name: cash_register_transactions_2024_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2024_created_at_idx1";


--
-- Name: cash_register_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2024_date_idx";


--
-- Name: cash_register_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2024_integration_ref_idx";


--
-- Name: cash_register_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2024_pkey";


--
-- Name: cash_register_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2024_type_idx";


--
-- Name: cash_register_transactions_2025_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2025_cash_register_id_idx";


--
-- Name: cash_register_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2025_created_at_idx";


--
-- Name: cash_register_transactions_2025_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2025_created_at_idx1";


--
-- Name: cash_register_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2025_date_idx";


--
-- Name: cash_register_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2025_integration_ref_idx";


--
-- Name: cash_register_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2025_pkey";


--
-- Name: cash_register_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2025_type_idx";


--
-- Name: cash_register_transactions_2026_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2026_cash_register_id_idx";


--
-- Name: cash_register_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2026_created_at_idx";


--
-- Name: cash_register_transactions_2026_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2026_created_at_idx1";


--
-- Name: cash_register_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2026_date_idx";


--
-- Name: cash_register_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2026_integration_ref_idx";


--
-- Name: cash_register_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2026_pkey";


--
-- Name: cash_register_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2026_type_idx";


--
-- Name: cash_register_transactions_2027_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2027_cash_register_id_idx";


--
-- Name: cash_register_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2027_created_at_idx";


--
-- Name: cash_register_transactions_2027_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2027_created_at_idx1";


--
-- Name: cash_register_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2027_date_idx";


--
-- Name: cash_register_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2027_integration_ref_idx";


--
-- Name: cash_register_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2027_pkey";


--
-- Name: cash_register_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2027_type_idx";


--
-- Name: cash_register_transactions_2028_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2028_cash_register_id_idx";


--
-- Name: cash_register_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2028_created_at_idx";


--
-- Name: cash_register_transactions_2028_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2028_created_at_idx1";


--
-- Name: cash_register_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2028_date_idx";


--
-- Name: cash_register_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2028_integration_ref_idx";


--
-- Name: cash_register_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2028_pkey";


--
-- Name: cash_register_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2028_type_idx";


--
-- Name: cash_register_transactions_2029_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2029_cash_register_id_idx";


--
-- Name: cash_register_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2029_created_at_idx";


--
-- Name: cash_register_transactions_2029_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2029_created_at_idx1";


--
-- Name: cash_register_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2029_date_idx";


--
-- Name: cash_register_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2029_integration_ref_idx";


--
-- Name: cash_register_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2029_pkey";


--
-- Name: cash_register_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2029_type_idx";


--
-- Name: cash_register_transactions_2030_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2030_cash_register_id_idx";


--
-- Name: cash_register_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2030_created_at_idx";


--
-- Name: cash_register_transactions_2030_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2030_created_at_idx1";


--
-- Name: cash_register_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2030_date_idx";


--
-- Name: cash_register_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2030_integration_ref_idx";


--
-- Name: cash_register_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2030_pkey";


--
-- Name: cash_register_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2030_type_idx";


--
-- Name: cash_register_transactions_2031_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_2031_cash_register_id_idx";


--
-- Name: cash_register_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_2031_created_at_idx";


--
-- Name: cash_register_transactions_2031_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_2031_created_at_idx1";


--
-- Name: cash_register_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_2031_date_idx";


--
-- Name: cash_register_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_2031_integration_ref_idx";


--
-- Name: cash_register_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_2031_pkey";


--
-- Name: cash_register_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_2031_type_idx";


--
-- Name: cash_register_transactions_default_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_cash_register_id" ATTACH PARTITION "public"."cash_register_transactions_default_cash_register_id_idx";


--
-- Name: cash_register_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at" ATTACH PARTITION "public"."cash_register_transactions_default_created_at_idx";


--
-- Name: cash_register_transactions_default_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_created_at_brin" ATTACH PARTITION "public"."cash_register_transactions_default_created_at_idx1";


--
-- Name: cash_register_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_date" ATTACH PARTITION "public"."cash_register_transactions_default_date_idx";


--
-- Name: cash_register_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_integration_ref" ATTACH PARTITION "public"."cash_register_transactions_default_integration_ref_idx";


--
-- Name: cash_register_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."cash_register_transactions_pkey" ATTACH PARTITION "public"."cash_register_transactions_default_pkey";


--
-- Name: cash_register_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_crt_type" ATTACH PARTITION "public"."cash_register_transactions_default_type_idx";


--
-- Name: cat_y2026_m02_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_account_id" ATTACH PARTITION "public"."cat_y2026_m02_current_account_id_idx";


--
-- Name: cat_y2026_m02_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_btree" ATTACH PARTITION "public"."cat_y2026_m02_date_idx";


--
-- Name: cat_y2026_m02_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_brin" ATTACH PARTITION "public"."cat_y2026_m02_date_idx1";


--
-- Name: cat_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_ref" ATTACH PARTITION "public"."cat_y2026_m02_integration_ref_idx";


--
-- Name: cat_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."current_account_transactions_pkey" ATTACH PARTITION "public"."cat_y2026_m02_pkey";


--
-- Name: cat_y2026_m03_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_account_id" ATTACH PARTITION "public"."cat_y2026_m03_current_account_id_idx";


--
-- Name: cat_y2026_m03_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_btree" ATTACH PARTITION "public"."cat_y2026_m03_date_idx";


--
-- Name: cat_y2026_m03_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_brin" ATTACH PARTITION "public"."cat_y2026_m03_date_idx1";


--
-- Name: cat_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_ref" ATTACH PARTITION "public"."cat_y2026_m03_integration_ref_idx";


--
-- Name: cat_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."current_account_transactions_pkey" ATTACH PARTITION "public"."cat_y2026_m03_pkey";


--
-- Name: credit_card_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2024_created_at_idx";


--
-- Name: credit_card_transactions_2024_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2024_credit_card_id_idx";


--
-- Name: credit_card_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2024_date_idx";


--
-- Name: credit_card_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2024_integration_ref_idx";


--
-- Name: credit_card_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2024_pkey";


--
-- Name: credit_card_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2024_type_idx";


--
-- Name: credit_card_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2025_created_at_idx";


--
-- Name: credit_card_transactions_2025_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2025_credit_card_id_idx";


--
-- Name: credit_card_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2025_date_idx";


--
-- Name: credit_card_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2025_integration_ref_idx";


--
-- Name: credit_card_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2025_pkey";


--
-- Name: credit_card_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2025_type_idx";


--
-- Name: credit_card_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2026_created_at_idx";


--
-- Name: credit_card_transactions_2026_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2026_credit_card_id_idx";


--
-- Name: credit_card_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2026_date_idx";


--
-- Name: credit_card_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2026_integration_ref_idx";


--
-- Name: credit_card_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2026_pkey";


--
-- Name: credit_card_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2026_type_idx";


--
-- Name: credit_card_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2027_created_at_idx";


--
-- Name: credit_card_transactions_2027_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2027_credit_card_id_idx";


--
-- Name: credit_card_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2027_date_idx";


--
-- Name: credit_card_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2027_integration_ref_idx";


--
-- Name: credit_card_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2027_pkey";


--
-- Name: credit_card_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2027_type_idx";


--
-- Name: credit_card_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2028_created_at_idx";


--
-- Name: credit_card_transactions_2028_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2028_credit_card_id_idx";


--
-- Name: credit_card_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2028_date_idx";


--
-- Name: credit_card_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2028_integration_ref_idx";


--
-- Name: credit_card_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2028_pkey";


--
-- Name: credit_card_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2028_type_idx";


--
-- Name: credit_card_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2029_created_at_idx";


--
-- Name: credit_card_transactions_2029_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2029_credit_card_id_idx";


--
-- Name: credit_card_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2029_date_idx";


--
-- Name: credit_card_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2029_integration_ref_idx";


--
-- Name: credit_card_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2029_pkey";


--
-- Name: credit_card_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2029_type_idx";


--
-- Name: credit_card_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2030_created_at_idx";


--
-- Name: credit_card_transactions_2030_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2030_credit_card_id_idx";


--
-- Name: credit_card_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2030_date_idx";


--
-- Name: credit_card_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2030_integration_ref_idx";


--
-- Name: credit_card_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2030_pkey";


--
-- Name: credit_card_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2030_type_idx";


--
-- Name: credit_card_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_2031_created_at_idx";


--
-- Name: credit_card_transactions_2031_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_2031_credit_card_id_idx";


--
-- Name: credit_card_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_2031_date_idx";


--
-- Name: credit_card_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_2031_integration_ref_idx";


--
-- Name: credit_card_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_2031_pkey";


--
-- Name: credit_card_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_2031_type_idx";


--
-- Name: credit_card_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_created_at" ATTACH PARTITION "public"."credit_card_transactions_default_created_at_idx";


--
-- Name: credit_card_transactions_default_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_credit_card_id" ATTACH PARTITION "public"."credit_card_transactions_default_credit_card_id_idx";


--
-- Name: credit_card_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_date" ATTACH PARTITION "public"."credit_card_transactions_default_date_idx";


--
-- Name: credit_card_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_integration_ref" ATTACH PARTITION "public"."credit_card_transactions_default_integration_ref_idx";


--
-- Name: credit_card_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."credit_card_transactions_pkey" ATTACH PARTITION "public"."credit_card_transactions_default_pkey";


--
-- Name: credit_card_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cct_type" ATTACH PARTITION "public"."credit_card_transactions_default_type_idx";


--
-- Name: current_account_transactions_default_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_account_id" ATTACH PARTITION "public"."current_account_transactions_default_current_account_id_idx";


--
-- Name: current_account_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_btree" ATTACH PARTITION "public"."current_account_transactions_default_date_idx";


--
-- Name: current_account_transactions_default_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_date_brin" ATTACH PARTITION "public"."current_account_transactions_default_date_idx1";


--
-- Name: current_account_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_cat_ref" ATTACH PARTITION "public"."current_account_transactions_default_integration_ref_idx";


--
-- Name: current_account_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."current_account_transactions_pkey" ATTACH PARTITION "public"."current_account_transactions_default_pkey";


--
-- Name: orders_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_integration_ref" ATTACH PARTITION "public"."orders_default_integration_ref_idx";


--
-- Name: orders_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."orders_pkey" ATTACH PARTITION "public"."orders_default_pkey";


--
-- Name: orders_default_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_tarih" ATTACH PARTITION "public"."orders_default_tarih_idx";


--
-- Name: orders_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_integration_ref" ATTACH PARTITION "public"."orders_y2026_m02_integration_ref_idx";


--
-- Name: orders_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."orders_pkey" ATTACH PARTITION "public"."orders_y2026_m02_pkey";


--
-- Name: orders_y2026_m02_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_tarih" ATTACH PARTITION "public"."orders_y2026_m02_tarih_idx";


--
-- Name: orders_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_integration_ref" ATTACH PARTITION "public"."orders_y2026_m03_integration_ref_idx";


--
-- Name: orders_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."orders_pkey" ATTACH PARTITION "public"."orders_y2026_m03_pkey";


--
-- Name: orders_y2026_m03_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_orders_tarih" ATTACH PARTITION "public"."orders_y2026_m03_tarih_idx";


--
-- Name: production_stock_movements_2020_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2020_created_at_idx";


--
-- Name: production_stock_movements_2020_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2020_movement_date_idx";


--
-- Name: production_stock_movements_2020_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2020_pkey";


--
-- Name: production_stock_movements_2020_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2020_production_id_idx";


--
-- Name: production_stock_movements_2020_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2020_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2020_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2020_warehouse_id_idx";


--
-- Name: production_stock_movements_2021_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2021_created_at_idx";


--
-- Name: production_stock_movements_2021_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2021_movement_date_idx";


--
-- Name: production_stock_movements_2021_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2021_pkey";


--
-- Name: production_stock_movements_2021_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2021_production_id_idx";


--
-- Name: production_stock_movements_2021_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2021_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2021_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2021_warehouse_id_idx";


--
-- Name: production_stock_movements_2022_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2022_created_at_idx";


--
-- Name: production_stock_movements_2022_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2022_movement_date_idx";


--
-- Name: production_stock_movements_2022_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2022_pkey";


--
-- Name: production_stock_movements_2022_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2022_production_id_idx";


--
-- Name: production_stock_movements_2022_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2022_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2022_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2022_warehouse_id_idx";


--
-- Name: production_stock_movements_2023_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2023_created_at_idx";


--
-- Name: production_stock_movements_2023_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2023_movement_date_idx";


--
-- Name: production_stock_movements_2023_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2023_pkey";


--
-- Name: production_stock_movements_2023_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2023_production_id_idx";


--
-- Name: production_stock_movements_2023_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2023_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2023_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2023_warehouse_id_idx";


--
-- Name: production_stock_movements_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2024_created_at_idx";


--
-- Name: production_stock_movements_2024_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2024_movement_date_idx";


--
-- Name: production_stock_movements_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2024_pkey";


--
-- Name: production_stock_movements_2024_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2024_production_id_idx";


--
-- Name: production_stock_movements_2024_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2024_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2024_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2024_warehouse_id_idx";


--
-- Name: production_stock_movements_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2025_created_at_idx";


--
-- Name: production_stock_movements_2025_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2025_movement_date_idx";


--
-- Name: production_stock_movements_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2025_pkey";


--
-- Name: production_stock_movements_2025_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2025_production_id_idx";


--
-- Name: production_stock_movements_2025_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2025_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2025_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2025_warehouse_id_idx";


--
-- Name: production_stock_movements_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2026_created_at_idx";


--
-- Name: production_stock_movements_2026_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2026_movement_date_idx";


--
-- Name: production_stock_movements_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2026_pkey";


--
-- Name: production_stock_movements_2026_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2026_production_id_idx";


--
-- Name: production_stock_movements_2026_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2026_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2026_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2026_warehouse_id_idx";


--
-- Name: production_stock_movements_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2027_created_at_idx";


--
-- Name: production_stock_movements_2027_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2027_movement_date_idx";


--
-- Name: production_stock_movements_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2027_pkey";


--
-- Name: production_stock_movements_2027_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2027_production_id_idx";


--
-- Name: production_stock_movements_2027_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2027_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2027_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2027_warehouse_id_idx";


--
-- Name: production_stock_movements_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2028_created_at_idx";


--
-- Name: production_stock_movements_2028_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2028_movement_date_idx";


--
-- Name: production_stock_movements_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2028_pkey";


--
-- Name: production_stock_movements_2028_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2028_production_id_idx";


--
-- Name: production_stock_movements_2028_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2028_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2028_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2028_warehouse_id_idx";


--
-- Name: production_stock_movements_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2029_created_at_idx";


--
-- Name: production_stock_movements_2029_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2029_movement_date_idx";


--
-- Name: production_stock_movements_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2029_pkey";


--
-- Name: production_stock_movements_2029_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2029_production_id_idx";


--
-- Name: production_stock_movements_2029_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2029_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2029_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2029_warehouse_id_idx";


--
-- Name: production_stock_movements_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2030_created_at_idx";


--
-- Name: production_stock_movements_2030_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2030_movement_date_idx";


--
-- Name: production_stock_movements_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2030_pkey";


--
-- Name: production_stock_movements_2030_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2030_production_id_idx";


--
-- Name: production_stock_movements_2030_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2030_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2030_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2030_warehouse_id_idx";


--
-- Name: production_stock_movements_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2031_created_at_idx";


--
-- Name: production_stock_movements_2031_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2031_movement_date_idx";


--
-- Name: production_stock_movements_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2031_pkey";


--
-- Name: production_stock_movements_2031_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2031_production_id_idx";


--
-- Name: production_stock_movements_2031_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2031_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2031_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2031_warehouse_id_idx";


--
-- Name: production_stock_movements_2032_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2032_created_at_idx";


--
-- Name: production_stock_movements_2032_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2032_movement_date_idx";


--
-- Name: production_stock_movements_2032_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2032_pkey";


--
-- Name: production_stock_movements_2032_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2032_production_id_idx";


--
-- Name: production_stock_movements_2032_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2032_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2032_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2032_warehouse_id_idx";


--
-- Name: production_stock_movements_2033_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2033_created_at_idx";


--
-- Name: production_stock_movements_2033_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2033_movement_date_idx";


--
-- Name: production_stock_movements_2033_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2033_pkey";


--
-- Name: production_stock_movements_2033_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2033_production_id_idx";


--
-- Name: production_stock_movements_2033_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2033_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2033_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2033_warehouse_id_idx";


--
-- Name: production_stock_movements_2034_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2034_created_at_idx";


--
-- Name: production_stock_movements_2034_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2034_movement_date_idx";


--
-- Name: production_stock_movements_2034_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2034_pkey";


--
-- Name: production_stock_movements_2034_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2034_production_id_idx";


--
-- Name: production_stock_movements_2034_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2034_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2034_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2034_warehouse_id_idx";


--
-- Name: production_stock_movements_2035_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2035_created_at_idx";


--
-- Name: production_stock_movements_2035_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2035_movement_date_idx";


--
-- Name: production_stock_movements_2035_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2035_pkey";


--
-- Name: production_stock_movements_2035_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2035_production_id_idx";


--
-- Name: production_stock_movements_2035_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2035_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2035_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2035_warehouse_id_idx";


--
-- Name: production_stock_movements_2036_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_2036_created_at_idx";


--
-- Name: production_stock_movements_2036_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_2036_movement_date_idx";


--
-- Name: production_stock_movements_2036_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_2036_pkey";


--
-- Name: production_stock_movements_2036_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_2036_production_id_idx";


--
-- Name: production_stock_movements_2036_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_2036_related_shipment_ids_idx";


--
-- Name: production_stock_movements_2036_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_2036_warehouse_id_idx";


--
-- Name: production_stock_movements_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_created_at_brin" ATTACH PARTITION "public"."production_stock_movements_default_created_at_idx";


--
-- Name: production_stock_movements_default_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_date" ATTACH PARTITION "public"."production_stock_movements_default_movement_date_idx";


--
-- Name: production_stock_movements_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."production_stock_movements_pkey" ATTACH PARTITION "public"."production_stock_movements_default_pkey";


--
-- Name: production_stock_movements_default_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_production_id" ATTACH PARTITION "public"."production_stock_movements_default_production_id_idx";


--
-- Name: production_stock_movements_default_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_related_shipments_gin" ATTACH PARTITION "public"."production_stock_movements_default_related_shipment_ids_idx";


--
-- Name: production_stock_movements_default_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_psm_warehouse_id" ATTACH PARTITION "public"."production_stock_movements_default_warehouse_id_idx";


--
-- Name: quotes_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_integration_ref" ATTACH PARTITION "public"."quotes_default_integration_ref_idx";


--
-- Name: quotes_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."quotes_pkey" ATTACH PARTITION "public"."quotes_default_pkey";


--
-- Name: quotes_default_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_tarih" ATTACH PARTITION "public"."quotes_default_tarih_idx";


--
-- Name: quotes_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_integration_ref" ATTACH PARTITION "public"."quotes_y2026_m02_integration_ref_idx";


--
-- Name: quotes_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."quotes_pkey" ATTACH PARTITION "public"."quotes_y2026_m02_pkey";


--
-- Name: quotes_y2026_m02_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_tarih" ATTACH PARTITION "public"."quotes_y2026_m02_tarih_idx";


--
-- Name: quotes_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_integration_ref" ATTACH PARTITION "public"."quotes_y2026_m03_integration_ref_idx";


--
-- Name: quotes_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."quotes_pkey" ATTACH PARTITION "public"."quotes_y2026_m03_pkey";


--
-- Name: quotes_y2026_m03_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_quotes_tarih" ATTACH PARTITION "public"."quotes_y2026_m03_tarih_idx";


--
-- Name: stock_movements_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2025_created_at_idx";


--
-- Name: stock_movements_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2025_integration_ref_idx";


--
-- Name: stock_movements_2025_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2025_movement_date_idx";


--
-- Name: stock_movements_2025_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2025_movement_date_idx1";


--
-- Name: stock_movements_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2025_pkey";


--
-- Name: stock_movements_2025_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2025_product_id_idx";


--
-- Name: stock_movements_2025_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2025_shipment_id_idx";


--
-- Name: stock_movements_2025_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2025_warehouse_id_idx";


--
-- Name: stock_movements_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2026_created_at_idx";


--
-- Name: stock_movements_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2026_integration_ref_idx";


--
-- Name: stock_movements_2026_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2026_movement_date_idx";


--
-- Name: stock_movements_2026_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2026_movement_date_idx1";


--
-- Name: stock_movements_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2026_pkey";


--
-- Name: stock_movements_2026_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2026_product_id_idx";


--
-- Name: stock_movements_2026_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2026_shipment_id_idx";


--
-- Name: stock_movements_2026_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2026_warehouse_id_idx";


--
-- Name: stock_movements_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2027_created_at_idx";


--
-- Name: stock_movements_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2027_integration_ref_idx";


--
-- Name: stock_movements_2027_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2027_movement_date_idx";


--
-- Name: stock_movements_2027_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2027_movement_date_idx1";


--
-- Name: stock_movements_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2027_pkey";


--
-- Name: stock_movements_2027_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2027_product_id_idx";


--
-- Name: stock_movements_2027_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2027_shipment_id_idx";


--
-- Name: stock_movements_2027_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2027_warehouse_id_idx";


--
-- Name: stock_movements_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2028_created_at_idx";


--
-- Name: stock_movements_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2028_integration_ref_idx";


--
-- Name: stock_movements_2028_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2028_movement_date_idx";


--
-- Name: stock_movements_2028_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2028_movement_date_idx1";


--
-- Name: stock_movements_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2028_pkey";


--
-- Name: stock_movements_2028_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2028_product_id_idx";


--
-- Name: stock_movements_2028_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2028_shipment_id_idx";


--
-- Name: stock_movements_2028_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2028_warehouse_id_idx";


--
-- Name: stock_movements_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2029_created_at_idx";


--
-- Name: stock_movements_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2029_integration_ref_idx";


--
-- Name: stock_movements_2029_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2029_movement_date_idx";


--
-- Name: stock_movements_2029_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2029_movement_date_idx1";


--
-- Name: stock_movements_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2029_pkey";


--
-- Name: stock_movements_2029_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2029_product_id_idx";


--
-- Name: stock_movements_2029_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2029_shipment_id_idx";


--
-- Name: stock_movements_2029_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2029_warehouse_id_idx";


--
-- Name: stock_movements_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2030_created_at_idx";


--
-- Name: stock_movements_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2030_integration_ref_idx";


--
-- Name: stock_movements_2030_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2030_movement_date_idx";


--
-- Name: stock_movements_2030_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2030_movement_date_idx1";


--
-- Name: stock_movements_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2030_pkey";


--
-- Name: stock_movements_2030_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2030_product_id_idx";


--
-- Name: stock_movements_2030_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2030_shipment_id_idx";


--
-- Name: stock_movements_2030_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2030_warehouse_id_idx";


--
-- Name: stock_movements_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_2031_created_at_idx";


--
-- Name: stock_movements_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_2031_integration_ref_idx";


--
-- Name: stock_movements_2031_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_2031_movement_date_idx";


--
-- Name: stock_movements_2031_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_2031_movement_date_idx1";


--
-- Name: stock_movements_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_2031_pkey";


--
-- Name: stock_movements_2031_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_2031_product_id_idx";


--
-- Name: stock_movements_2031_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_2031_shipment_id_idx";


--
-- Name: stock_movements_2031_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_2031_warehouse_id_idx";


--
-- Name: stock_movements_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_created_at_brin" ATTACH PARTITION "public"."stock_movements_default_created_at_idx";


--
-- Name: stock_movements_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_ref" ATTACH PARTITION "public"."stock_movements_default_integration_ref_idx";


--
-- Name: stock_movements_default_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date" ATTACH PARTITION "public"."stock_movements_default_movement_date_idx";


--
-- Name: stock_movements_default_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_date_brin" ATTACH PARTITION "public"."stock_movements_default_movement_date_idx1";


--
-- Name: stock_movements_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."stock_movements_pkey" ATTACH PARTITION "public"."stock_movements_default_pkey";


--
-- Name: stock_movements_default_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_product_id" ATTACH PARTITION "public"."stock_movements_default_product_id_idx";


--
-- Name: stock_movements_default_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_shipment_id" ATTACH PARTITION "public"."stock_movements_default_shipment_id_idx";


--
-- Name: stock_movements_default_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_sm_warehouse_id" ATTACH PARTITION "public"."stock_movements_default_warehouse_id_idx";


--
-- Name: user_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2024_date_idx";


--
-- Name: user_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2024_pkey";


--
-- Name: user_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2024_type_idx";


--
-- Name: user_transactions_2024_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2024_user_id_idx";


--
-- Name: user_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2025_date_idx";


--
-- Name: user_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2025_pkey";


--
-- Name: user_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2025_type_idx";


--
-- Name: user_transactions_2025_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2025_user_id_idx";


--
-- Name: user_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2026_date_idx";


--
-- Name: user_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2026_pkey";


--
-- Name: user_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2026_type_idx";


--
-- Name: user_transactions_2026_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2026_user_id_idx";


--
-- Name: user_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2027_date_idx";


--
-- Name: user_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2027_pkey";


--
-- Name: user_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2027_type_idx";


--
-- Name: user_transactions_2027_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2027_user_id_idx";


--
-- Name: user_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2028_date_idx";


--
-- Name: user_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2028_pkey";


--
-- Name: user_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2028_type_idx";


--
-- Name: user_transactions_2028_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2028_user_id_idx";


--
-- Name: user_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2029_date_idx";


--
-- Name: user_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2029_pkey";


--
-- Name: user_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2029_type_idx";


--
-- Name: user_transactions_2029_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2029_user_id_idx";


--
-- Name: user_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2030_date_idx";


--
-- Name: user_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2030_pkey";


--
-- Name: user_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2030_type_idx";


--
-- Name: user_transactions_2030_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2030_user_id_idx";


--
-- Name: user_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_2031_date_idx";


--
-- Name: user_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_2031_pkey";


--
-- Name: user_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_2031_type_idx";


--
-- Name: user_transactions_2031_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_2031_user_id_idx";


--
-- Name: user_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_date_brin" ATTACH PARTITION "public"."user_transactions_default_date_idx";


--
-- Name: user_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."user_transactions_pkey" ATTACH PARTITION "public"."user_transactions_default_pkey";


--
-- Name: user_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_type" ATTACH PARTITION "public"."user_transactions_default_type_idx";


--
-- Name: user_transactions_default_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX "public"."idx_ut_user_id" ATTACH PARTITION "public"."user_transactions_default_user_id_idx";


--
-- Name: current_account_transactions trg_cat_refresh_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_cat_refresh_search_tags" AFTER INSERT OR DELETE OR UPDATE ON "public"."current_account_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_refresh_account_search_tags"();


--
-- Name: current_accounts trg_update_account_metadata; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_account_metadata" AFTER INSERT OR DELETE OR UPDATE ON "public"."current_accounts" FOR EACH ROW EXECUTE FUNCTION "public"."update_account_metadata"();


--
-- Name: bank_transactions trg_update_bank_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_bank_search_tags" AFTER INSERT OR DELETE ON "public"."bank_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_bank_search_tags"();


--
-- Name: cash_register_transactions trg_update_cash_register_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_cash_register_search_tags" AFTER INSERT OR DELETE ON "public"."cash_register_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_cash_register_search_tags"();


--
-- Name: credit_card_transactions trg_update_credit_card_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_credit_card_search_tags" AFTER INSERT OR DELETE ON "public"."credit_card_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_credit_card_search_tags"();


--
-- Name: depots trg_update_depots_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_depots_search_tags" BEFORE INSERT OR UPDATE ON "public"."depots" FOR EACH ROW EXECUTE FUNCTION "public"."update_depots_search_tags"();


--
-- Name: productions trg_update_productions_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_productions_count" AFTER INSERT OR DELETE ON "public"."productions" FOR EACH ROW EXECUTE FUNCTION "public"."update_table_counts"();


--
-- Name: productions trg_update_productions_metadata; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_productions_metadata" AFTER INSERT OR DELETE OR UPDATE ON "public"."productions" FOR EACH ROW EXECUTE FUNCTION "public"."update_production_metadata"();


--
-- Name: productions trg_update_productions_search_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_productions_search_tags" BEFORE INSERT OR UPDATE ON "public"."productions" FOR EACH ROW EXECUTE FUNCTION "public"."update_productions_search_tags"();


--
-- Name: products trg_update_products_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_products_count" AFTER INSERT OR DELETE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_table_counts"();


--
-- Name: products trg_update_products_metadata; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_update_products_metadata" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_product_metadata"();


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER "tr_check_filters" BEFORE INSERT OR UPDATE ON "realtime"."subscription" FOR EACH ROW EXECUTE FUNCTION "realtime"."subscription_check_filters"();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER "enforce_bucket_name_length_trigger" BEFORE INSERT OR UPDATE OF "name" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."enforce_bucket_name_length"();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER "protect_buckets_delete" BEFORE DELETE ON "storage"."buckets" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER "protect_objects_delete" BEFORE DELETE ON "storage"."objects" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER "update_objects_updated_at" BEFORE UPDATE ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."update_updated_at_column"();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_auth_factor_id_fkey" FOREIGN KEY ("factor_id") REFERENCES "auth"."mfa_factors"("id") ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_flow_state_id_fkey" FOREIGN KEY ("flow_state_id") REFERENCES "auth"."flow_state"("id") ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_oauth_client_id_fkey" FOREIGN KEY ("oauth_client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;


--
-- Name: expense_items expense_items_expense_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE;


--
-- Name: production_recipe_items fk_production; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."production_recipe_items"
    ADD CONSTRAINT "fk_production" FOREIGN KEY ("production_id") REFERENCES "public"."productions"("id") ON DELETE CASCADE;


--
-- Name: product_devices product_devices_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."product_devices"
    ADD CONSTRAINT "product_devices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


--
-- Name: quick_products quick_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."quick_products"
    ADD CONSTRAINT "quick_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_upload_id_fkey" FOREIGN KEY ("upload_id") REFERENCES "storage"."s3_multipart_uploads"("id") ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets_vectors"("id");


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."audit_log_entries" ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."flow_state" ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."identities" ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."instances" ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."mfa_amr_claims" ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."mfa_challenges" ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."mfa_factors" ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."one_time_tokens" ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."refresh_tokens" ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."saml_providers" ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."saml_relay_states" ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."schema_migrations" ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."sessions" ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."sso_domains" ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."sso_providers" ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE "auth"."users" ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE "realtime"."messages" ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."buckets" ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."buckets_analytics" ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."buckets_vectors" ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."migrations" ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."s3_multipart_uploads" ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."s3_multipart_uploads_parts" ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE "storage"."vector_indexes" ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION "supabase_realtime" WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "issue_graphql_placeholder" ON "sql_drop"
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION "extensions"."set_graphql_placeholder"();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "issue_pg_cron_access" ON "ddl_command_end"
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION "extensions"."grant_pg_cron_access"();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "issue_pg_graphql_access" ON "ddl_command_end"
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION "extensions"."grant_pg_graphql_access"();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "issue_pg_net_access" ON "ddl_command_end"
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION "extensions"."grant_pg_net_access"();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "pgrst_ddl_watch" ON "ddl_command_end"
   EXECUTE FUNCTION "extensions"."pgrst_ddl_watch"();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "pgrst_drop_watch" ON "sql_drop"
   EXECUTE FUNCTION "extensions"."pgrst_drop_watch"();


--
-- PostgreSQL database dump complete
--

\unrestrict iJoqUHvkf7KrWlgQ76nNvmdmm23ycghBbsJesV1Mr3Xuzzn8ZhZwWGHPjx2X3KQ

