-- Umubano Impore website — Supabase schema (v2, simplified)
-- Run this in Supabase → SQL Editor → New query → Run.
-- This replaces the earlier 8-table version with one simpler table that mirrors
-- exactly how the website already stores things — safer to wire up correctly,
-- and just as secure.

-- If you already ran the first version of this script, these tables are empty
-- and safe to remove:
drop table if exists posts;
drop table if exists custom_pages;
drop table if exists footer_info;
drop table if exists site_theme;
drop table if exists home_story;
drop table if exists page_headers;
drop table if exists page_titles;
drop table if exists visitor_messages;

-- One table, one row per saved item (a post, a page's photo, the site's colours,
-- a visitor message, etc.) — same shape the website already uses internally,
-- just backed by a real database instead of a browser's local storage.
create table if not exists kv_store (
  key text primary key,
  value text not null,
  updated_at timestamptz default now()
);

alter table kv_store enable row level security;

drop policy if exists "public read non-messages" on kv_store;
drop policy if exists "public insert messages" on kv_store;
drop policy if exists "admin full access" on kv_store;

-- Visitors can read everything except other visitors' messages to the organisation.
create policy "public read non-messages" on kv_store for select
  using (key !~ '^visitormsg_');

-- Visitors can submit a "write to us" message, but cannot read or delete any
-- message (their own or anyone else's) — only a signed-in admin can.
create policy "public insert messages" on kv_store for insert
  with check (key ~ '^visitormsg_');

-- A signed-in admin can read, add, change, or delete anything at all.
create policy "admin full access" on kv_store for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');
