-- pgTAP policy test, one file per table.
--
-- Create:  supabase test new notes_rls.test
-- Run:     supabase test db
--
-- Replace `notes` with your table and adjust the owner column. The point of
-- this file is that it asserts both directions: what each role may do, and
-- what it may not. A policy you never tested is a policy you are guessing at.
--
-- Assertion choice matters. A denied write raises 42501 when a grant is
-- missing or a WITH CHECK fails, and raises nothing at all when a USING
-- clause simply filters the row out. Use throws_ok for the first, and
-- is_empty plus a follow-up read for the second.

begin;
select plan(11);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'other@example.com');

insert into public.notes (id, user_id, title, body)
values (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  'owned',
  'belongs to the owner'
);

-- anon holds no grant, so the request stops before any policy runs.
set local role anon;
select throws_ok(
  $$select * from public.notes$$,
  '42501', null,
  'anon cannot read notes'
);
select throws_ok(
  $$insert into public.notes (user_id, title, body)
    values ('11111111-1111-1111-1111-111111111111', 'x', 'y')$$,
  '42501', null,
  'anon cannot insert notes'
);
select throws_ok(
  $$update public.notes set title = 'x'$$,
  '42501', null,
  'anon cannot update notes'
);
select throws_ok(
  $$delete from public.notes$$,
  '42501', null,
  'anon cannot delete notes'
);

-- The owner reads and writes their own row.
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select results_eq(
  $$select title from public.notes
    where id = '33333333-3333-3333-3333-333333333333'$$,
  array['owned'],
  'the owner reads their own note'
);
select results_eq(
  $$update public.notes set title = 'updated'
    where id = '33333333-3333-3333-3333-333333333333'
    returning title$$,
  array['updated'],
  'the owner updates their own note'
);

-- A signed-in stranger holds the grant, so the policy is what stops them.
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select is_empty(
  $$select * from public.notes$$,
  'another user reads no notes'
);
select is_empty(
  $$update public.notes set title = 'stolen' returning title$$,
  'another user updates no notes'
);
select is_empty(
  $$delete from public.notes returning title$$,
  'another user deletes no notes'
);

-- Matching zero rows is not proof on its own. Confirm the target row survived.
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select results_eq(
  $$select title from public.notes
    where id = '33333333-3333-3333-3333-333333333333'$$,
  array['updated'],
  'the denied writes left the owner row intact'
);
select results_eq(
  $$delete from public.notes
    where id = '33333333-3333-3333-3333-333333333333'
    returning title$$,
  array['updated'],
  'the owner deletes their own note'
);

select * from finish();
rollback;
