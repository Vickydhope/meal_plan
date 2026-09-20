insert into storage.buckets (id, name, public, file_size_limit)
values ('avatars', 'avatars', true, 512000)
on conflict (id) do nothing;

create policy "avatars_insert_own" on storage.objects
  for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_update_own" on storage.objects
  for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_delete_own" on storage.objects
  for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

alter table public.profiles
  add column avatar_path text;

comment on column public.profiles.avatar_path is
  'Storage path (not a full URL) within the public avatars bucket, e.g. "<user-id>/<timestamp>.jpg". Resolve to a displayable URL via AvatarRepository.publicUrlFor.';
