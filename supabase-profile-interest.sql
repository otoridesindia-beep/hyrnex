-- Add job-role interest to existing profiles and include it on new signups.
alter table public.profiles add column if not exists interested_role text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_interested_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_interested_role_check
      check (interested_role is null or interested_role in ('Data Analyst', 'Power BI Developer', 'SQL Developer', 'Data Engineer', 'Azure Data Engineer', 'Tableau Developer', 'BI Developer', 'Informatica Developer', 'ETL Developer', 'Snowflake Developer', 'Databricks Developer', 'Python Data Engineer', 'Analytics Engineer', 'Data Scientist', 'Microsoft Fabric Developer', 'Software Developer', 'Full Stack Developer', 'Frontend Developer', 'Backend Developer', 'Java Developer', 'Python Developer', '.NET Developer', 'React Developer', 'Node.js Developer', 'Mobile App Developer', 'DevOps Engineer', 'QA / Test Engineer', 'Other IT', 'HR Executive', 'Sales Executive', 'Marketing Executive', 'Accountant', 'Customer Support', 'Operations Executive', 'Business Development', 'Admin / Back Office', 'Other Non-IT'));
  end if;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, mobile, interested_role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.raw_user_meta_data ->> 'email', ''),
    coalesce(new.raw_user_meta_data ->> 'mobile', ''),
    new.raw_user_meta_data ->> 'interested_role'
  );
  return new;
end;
$$;
