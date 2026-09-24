-- A new notification type for follows (ADR 0001 Phase 6). Run this on its
-- own, before 011: Postgres won't let a new enum value be used in the same
-- transaction that adds it. Safe to re-run.
alter type notification_type add value if not exists 'personNewCredit';
