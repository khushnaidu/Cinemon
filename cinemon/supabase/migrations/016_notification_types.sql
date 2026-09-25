-- ADR 0004 Phase 4 and the Activity pass: new notification types. Run this on
-- its own, before 017 and 018: Postgres won't let a new enum value be used in
-- the same transaction that adds it. Safe to re-run.
alter type notification_type add value if not exists 'follow';        -- started following you
alter type notification_type add value if not exists 'vote';          -- agreed / disagreed with your take
alter type notification_type add value if not exists 'exploreComment'; -- replied to your Explore post
alter type notification_type add value if not exists 'exploreReply';  -- replied to your reply
alter type notification_type add value if not exists 'listSave';      -- saved your playlist
