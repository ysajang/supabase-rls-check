-- 2. What anon and authenticated can still reach.
--
-- Policies do not take grants back. On projects created before the Data API
-- change, every table in the public schema starts with select, insert, update
-- and delete granted to anon and authenticated. Adding a policy narrows the
-- rows, not the privilege.
--
-- Read this together with rls_enabled. A table with rowsecurity = false and a
-- grant to anon is open regardless of any policy that exists on it.

select
    t.schemaname,
    t.tablename,
    t.rowsecurity as rls_enabled,
    g.grantee,
    string_agg(g.privilege_type, ', ' order by g.privilege_type) as privileges,
    (
        select count(*)
        from pg_policies p
        where p.schemaname = t.schemaname
            and p.tablename = t.tablename
    ) as policy_count
from
    pg_tables t
    left join information_schema.role_table_grants g
        on g.table_schema = t.schemaname
        and g.table_name = t.tablename
        and g.grantee in ('anon', 'authenticated')
where
    t.schemaname not in ('pg_catalog', 'information_schema', 'auth', 'storage', 'realtime', 'vault', 'extensions')
    and g.grantee is not null
group by
    t.schemaname, t.tablename, t.rowsecurity, g.grantee
order by
    t.rowsecurity,
    t.schemaname,
    t.tablename,
    g.grantee;
