-- ViralForge Experimental: schema, indexes, row level security, job-claim function.
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP POLICY IF EXISTS.

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  description text check (char_length(description) <= 500),
  platform text check (platform in ('instagram_reels','tiktok','youtube_shorts')),
  niche text check (char_length(niche) <= 100),
  target_audience text check (char_length(target_audience) <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists projects_user_updated_idx on public.projects (user_id, updated_at desc);

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null check (mime_type in ('video/mp4','video/webm','video/quicktime')),
  size_bytes bigint not null check (size_bytes > 0),
  duration_seconds numeric(8,2),
  created_at timestamptz not null default now()
);
create index if not exists videos_project_idx on public.videos (project_id, created_at desc);
create index if not exists videos_user_idx on public.videos (user_id);

create table if not exists public.analysis_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  video_id uuid references public.videos(id) on delete set null,
  input_type text not null default 'video' check (input_type in ('video','script')),
  script_text text check (char_length(script_text) <= 8000),
  platform text not null check (platform in ('instagram_reels','tiktok','youtube_shorts')),
  niche text not null check (char_length(niche) between 1 and 100),
  target_audience text not null check (char_length(target_audience) between 1 and 200),
  caption text check (char_length(caption) <= 2200),
  status text not null default 'queued' check (status in ('queued','processing','completed','failed')),
  stage text not null default 'queued',
  progress int not null default 0 check (progress between 0 and 100),
  attempts int not null default 0,
  max_attempts int not null default 3,
  error_code text,
  error_message text,
  run_after timestamptz not null default now(),
  locked_at timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);
-- Duplicate-submission guard: at most one active job per video, enforced by the database.
create unique index if not exists analysis_jobs_one_active_per_video
  on public.analysis_jobs (video_id) where video_id is not null and status in ('queued','processing');
create index if not exists analysis_jobs_user_idx on public.analysis_jobs (user_id, created_at desc);
create index if not exists analysis_jobs_project_idx on public.analysis_jobs (project_id, created_at desc);
create index if not exists analysis_jobs_queue_idx on public.analysis_jobs (status, run_after)
  where status in ('queued','processing');

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.analysis_jobs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  scores jsonb not null,
  report jsonb not null,
  model text not null,
  created_at timestamptz not null default now()
);
create index if not exists reports_user_idx on public.reports (user_id, created_at desc);

-- updated_at maintenance
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_projects_updated on public.projects;
create trigger trg_projects_updated before update on public.projects
  for each row execute function public.set_updated_at();
drop trigger if exists trg_jobs_updated on public.analysis_jobs;
create trigger trg_jobs_updated before update on public.analysis_jobs
  for each row execute function public.set_updated_at();

-- Row level security. The FastAPI backend uses the service-role key (bypasses RLS) and
-- enforces ownership itself; these policies protect against any direct client access.
alter table public.projects enable row level security;
alter table public.videos enable row level security;
alter table public.analysis_jobs enable row level security;
alter table public.reports enable row level security;

drop policy if exists projects_select_own on public.projects;
drop policy if exists projects_insert_own on public.projects;
drop policy if exists projects_update_own on public.projects;
drop policy if exists projects_delete_own on public.projects;
create policy projects_select_own on public.projects for select to authenticated using (auth.uid() = user_id);
create policy projects_insert_own on public.projects for insert to authenticated with check (auth.uid() = user_id);
create policy projects_update_own on public.projects for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy projects_delete_own on public.projects for delete to authenticated using (auth.uid() = user_id);

-- Videos, jobs and reports are read-only for clients: all writes go through the backend,
-- which validates uploads, applies quotas and prevents forged reports.
drop policy if exists videos_select_own on public.videos;
create policy videos_select_own on public.videos for select to authenticated using (auth.uid() = user_id);
drop policy if exists jobs_select_own on public.analysis_jobs;
create policy jobs_select_own on public.analysis_jobs for select to authenticated using (auth.uid() = user_id);
drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports for select to authenticated using (auth.uid() = user_id);

-- Atomically claim the next runnable job (FOR UPDATE SKIP LOCKED), and recover jobs whose
-- worker died (lease expired). Jobs that exhausted their attempts are marked failed.
create or replace function public.claim_next_job(lease_seconds int default 900)
returns setof public.analysis_jobs
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  update public.analysis_jobs
     set status = 'failed', stage = 'failed', locked_at = null, completed_at = now(),
         error_code = 'worker_timeout',
         error_message = 'The analysis stopped unexpectedly. Retry the analysis.'
   where status = 'processing'
     and locked_at < now() - make_interval(secs => lease_seconds)
     and attempts >= max_attempts;

  select id into v_id from public.analysis_jobs
   where (status = 'queued' and run_after <= now())
      or (status = 'processing' and locked_at < now() - make_interval(secs => lease_seconds))
   order by created_at
   for update skip locked
   limit 1;

  if v_id is null then return; end if;

  return query
    update public.analysis_jobs
       set status = 'processing', stage = 'validating', progress = 5, attempts = attempts + 1,
           locked_at = now(), started_at = coalesce(started_at, now()),
           error_code = null, error_message = null
     where id = v_id
     returning *;
end $$;

revoke all on function public.claim_next_job(int) from public, anon, authenticated;
grant execute on function public.claim_next_job(int) to service_role;
-- Private bucket for uploaded videos. Files live at {user_id}/{project_id}/{video_id}.{ext}.
-- NOTE: Supabase's free plan caps single uploads at 50 MB regardless of this setting.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', false, 52428800, array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Clients may only read objects inside their own folder. They cannot upload, overwrite or delete:
-- uploads are validated and written by the backend with the service-role key.
drop policy if exists "videos_read_own_folder" on storage.objects;
create policy "videos_read_own_folder" on storage.objects for select to authenticated
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);
