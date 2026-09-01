-- 1. Always-true read policies.
--
-- Finds SELECT and ALL policies whose USING clause is literally true.
-- Supabase's own linter (0024 permissive_rls_policy) skips these on purpose,
-- because public read is often deliberate. So a table can be fully readable
-- by anon while the Security Advisor reports zero issues.
--
-- Any row returned here for a table that is not meant to be public is
-- readable by anyone holding your anon key.

select
    pol.schemaname,
    pol.tablename,
    pol.policyname,
    pol.cmd,
    pol.roles,
    pol.qual
from
    pg_policies pol
where
    pol.schemaname not in ('pg_catalog', 'information_schema', 'auth', 'storage', 'realtime', 'vault', 'extensions')
    and pol.cmd in ('SELECT', 'ALL')
    and replace(replace(replace(lower(coalesce(pol.qual, '')), ' ', ''), E'\n', ''), E'\t', '')
        in ('true', '(true)', '1=1', '(1=1)')
order by
    pol.schemaname,
    pol.tablename,
    pol.policyname;
