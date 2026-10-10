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
