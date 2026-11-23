-- Apply this migration to existing Supabase projects to enable the candidate directory.
-- New projects receive the same schema from supabase-setup.sql.

create table if not exists public.candidate_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 100),
  role text not null check (role in ('Data Analyst', 'Power BI Developer', 'SQL Developer', 'Data Engineer', 'Azure Data Engineer', 'Tableau Developer', 'BI Developer', 'Informatica Developer', 'ETL Developer', 'Snowflake Developer', 'Databricks Developer', 'Python Data Engineer', 'Analytics Engineer', 'Data Scientist', 'Microsoft Fabric Developer', 'Software Developer', 'Full Stack Developer', 'Frontend Developer', 'Backend Developer', 'Java Developer', 'Python Developer', '.NET Developer', 'React Developer', 'Node.js Developer', 'Mobile App Developer', 'DevOps Engineer', 'QA / Test Engineer', 'Other IT', 'HR Executive', 'Sales Executive', 'Marketing Executive', 'Accountant', 'Customer Support', 'Operations Executive', 'Business Development', 'Admin / Back Office', 'Other Non-IT')),
  headline text not null check (char_length(headline) between 3 and 120),
  summary text not null default '' check (char_length(summary) <= 1000),
  skills text not null default '' check (char_length(skills) <= 300),
  location text not null default '' check (char_length(location) <= 100),
  experience text not null default '' check (char_length(experience) <= 80),
  contact_email text not null default '' check (contact_email = '' or contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  contact_mobile text not null default '',
  is_public boolean not null default false,
  publication_consent boolean not null default false,
  constraint candidate_profiles_creator_check check (
    (user_id is not null and created_by is null) or (user_id is null and created_by is not null)
  ),
  constraint candidate_profiles_public_contact check (not is_public or contact_email <> ''),
  constraint candidate_profiles_public_consent_check check (not is_public or publication_consent),
  constraint candidate_profiles_contact_mobile_check check (contact_mobile = '' or contact_mobile ~ '^[0-9]{10}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.candidate_profiles'::regclass
      and attname = 'id'
      and not attisdropped
  ) then
    alter table public.candidate_profiles add column id uuid default gen_random_uuid();
  end if;
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.candidate_profiles'::regclass
      and attname = 'created_by'
      and not attisdropped
  ) then
    alter table public.candidate_profiles
      add column created_by uuid references public.profiles (id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.candidate_profiles'::regclass
      and attname = 'publication_consent'
      and not attisdropped
  ) then
    alter table public.candidate_profiles
      add column publication_consent boolean not null default false;
  end if;
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.candidate_profiles'::regclass
      and attname = 'contact_mobile'
      and not attisdropped
  ) then
    alter table public.candidate_profiles
      add column contact_mobile text not null default '';
  end if;
end;
$$;
update public.candidate_profiles set id = gen_random_uuid() where id is null;
alter table public.candidate_profiles alter column id set default gen_random_uuid();
alter table public.candidate_profiles alter column id set not null;
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'candidate_profiles_pkey'
      and conrelid = 'public.candidate_profiles'::regclass
  ) then
    alter table public.candidate_profiles drop constraint candidate_profiles_pkey;
  end if;
end;
$$;
alter table public.candidate_profiles alter column user_id drop not null;
update public.candidate_profiles set publication_consent = true where is_public and not publication_consent;
alter table public.candidate_profiles add constraint candidate_profiles_pkey primary key (id);
create unique index if not exists candidate_profiles_user_id_key on public.candidate_profiles (user_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'candidate_profiles_creator_check'
      and conrelid = 'public.candidate_profiles'::regclass
  ) then
    alter table public.candidate_profiles
      add constraint candidate_profiles_creator_check
      check ((user_id is not null and created_by is null) or (user_id is null and created_by is not null));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'candidate_profiles_public_consent_check'
      and conrelid = 'public.candidate_profiles'::regclass
  ) then
    alter table public.candidate_profiles
      add constraint candidate_profiles_public_consent_check
      check (not is_public or publication_consent);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'candidate_profiles_contact_mobile_check'
      and conrelid = 'public.candidate_profiles'::regclass
  ) then
    alter table public.candidate_profiles
      add constraint candidate_profiles_contact_mobile_check
      check (contact_mobile = '' or contact_mobile ~ '^[0-9]{10}$');
  end if;
end;
$$;

alter table public.candidate_profiles enable row level security;

drop policy if exists "candidate_profiles_select_public_or_owner" on public.candidate_profiles;
create policy "candidate_profiles_select_public_or_owner" on public.candidate_profiles
  for select to anon, authenticated
  using (is_public or user_id = auth.uid() or public.is_admin());

drop policy if exists "candidate_profiles_insert_owner" on public.candidate_profiles;
create policy "candidate_profiles_insert_owner" on public.candidate_profiles
  for insert to authenticated
  with check (user_id = auth.uid() and created_by is null);

drop policy if exists "candidate_profiles_update_owner" on public.candidate_profiles;
create policy "candidate_profiles_update_owner" on public.candidate_profiles
  for update to authenticated
  using (user_id = auth.uid() and created_by is null)
  with check (user_id = auth.uid() and created_by is null);

drop policy if exists "candidate_profiles_insert_admin" on public.candidate_profiles;
create policy "candidate_profiles_insert_admin" on public.candidate_profiles
  for insert to authenticated
  with check (public.is_admin() and user_id is null and created_by = auth.uid());

drop policy if exists "candidate_profiles_update_admin" on public.candidate_profiles;
create policy "candidate_profiles_update_admin" on public.candidate_profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "candidate_profiles_delete_admin" on public.candidate_profiles;
create policy "candidate_profiles_delete_admin" on public.candidate_profiles
  for delete to authenticated
  using (public.is_admin());

grant select on public.candidate_profiles to anon, authenticated;
grant insert, update on public.candidate_profiles to authenticated;
grant delete on public.candidate_profiles to authenticated;

drop trigger if exists candidate_profiles_touch_updated_at on public.candidate_profiles;
create trigger candidate_profiles_touch_updated_at
  before update on public.candidate_profiles
  for each row execute function public.touch_updated_at();
