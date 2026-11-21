-- Add public per-job click totals and an atomic RPC to record each "View role" click.
alter table public.jobs add column if not exists view_count integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'jobs_view_count_nonnegative'
      and conrelid = 'public.jobs'::regclass
  ) then
    alter table public.jobs
      add constraint jobs_view_count_nonnegative check (view_count >= 0);
  end if;
end;
$$;

create or replace function public.record_job_view(target_job_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_view_count integer;
begin
  update public.jobs as job
  set view_count = job.view_count + 1
  where job.id = target_job_id
  returning job.view_count into updated_view_count;

  if updated_view_count is null then
    raise exception 'Job listing not found.';
  end if;

  return updated_view_count;
end;
$$;

revoke all on function public.record_job_view(uuid) from public;
grant execute on function public.record_job_view(uuid) to anon, authenticated;
