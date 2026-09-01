# supabase-rls-check

Two SQL queries and one pgTAP test template for checking whether your Supabase
tables are actually closed.

No signup, no account access, no scanner. Paste the queries into the SQL
Editor and read the output yourself.

## Why this exists

You can have RLS enabled, a policy in place, and a Security Advisor reporting
zero errors, while an anon key reads every row in the table.

That happens when the policy is written as:

```sql
create policy "Notes are viewable by everyone"
on public.notes for select
to anon, authenticated
using ( true );
```

The advisor does not flag it. Lint `0024_permissive_rls_policy` deliberately
excludes `SELECT` policies with `using (true)`, because public read is often
intentional. Its own SQL says so:

> Note: SELECT with (true) is often intentional and documented, so we only
> flag UPDATE/DELETE

That exclusion is correct for an announcements feed. It is not correct for a
notes table, and nothing in the dashboard tells you which one you have.

## The queries

**`check.sql`** lists every `SELECT` or `ALL` policy whose `USING` clause is
literally true. Any table in the result that is not meant to be public is
readable by anyone holding your anon key.

**`grants.sql`** lists what `anon` and `authenticated` can still reach, next to
whether RLS is on and how many policies exist. Policies do not take grants
back. Adding a policy narrows which rows a role sees; it does not remove the
privilege that let the role touch the table.

Read them together:

| rls_enabled | policy_count | grant to anon | meaning |
| --- | --- | --- | --- |
| false | any | yes | open, policies are not enforced |
| true | 0 | yes | closed, and your app is probably broken |
| true | >0 | yes | depends entirely on the policy body, run `check.sql` |
| true | >0 | no | the grant is gone, requests stop at `42501` |

## The test file

`tests/notes_rls.test.sql` is the shape the Supabase docs ask for: one pgTAP
file per table, asserting allow and deny for `select`, `insert`, `update` and
`delete`, for both `anon` and `authenticated`.

```
supabase test new notes_rls.test
supabase test db
```

Copy it, rename the table, adjust the owner column. Until the suite passes you
do not know whether the policies do what you intended.

One detail that trips people up: a denied write raises `42501` when a grant is
missing or a `WITH CHECK` fails, and raises nothing at all when a `USING`
clause simply filters the row out. `throws_ok` for the first case, `is_empty`
plus a follow-up read for the second. Never prove an allowed write with
`lives_ok`, because it passes on zero rows.

## What this does not do

- It does not scan your app, your endpoints, or your storage buckets.
- It does not check column-level exposure, views, or `security definer`
  functions.
- It does not tell you which tables are *supposed* to be public. Only you know
  that.

## A note on new projects

Since April 28 2026 Supabase has been rolling out a change where new tables in
the `public` schema are no longer granted to `anon` and `authenticated`
automatically. It became the default for new projects on May 30 2026, and is
scheduled to apply to all existing projects on October 30 2026.

If your project predates that rollout, the grants are still there. Run
`grants.sql` rather than assuming either way.

Source: https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically

## References

- Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Database advisors: https://supabase.com/docs/guides/database/database-advisors
- Splinter, the linter behind the advisors: https://github.com/supabase/splinter

## License

MIT
