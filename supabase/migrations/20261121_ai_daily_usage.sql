-- VISION AI v2.0 — Daily Free AI Tier Usage Table & Atomic Quota RPC
-- Enforces 30 free requests/day per signed-in Supabase user (UTC day).

create table if not exists public.ai_daily_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  usage_date date not null default (now() at time zone 'utc')::date,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

alter table public.ai_daily_usage enable row level security;

drop policy if exists "Users read own ai daily usage" on public.ai_daily_usage;
create policy "Users read own ai daily usage"
  on public.ai_daily_usage
  for select
  using (auth.uid() = user_id);

create or replace function public.consume_ai_quota(p_daily_limit integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_reset_at timestamptz := ((v_today + 1)::timestamp at time zone 'utc');
  v_current integer := 0;
  v_allowed boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  insert into public.ai_daily_usage (user_id, usage_date, request_count, updated_at)
  values (v_uid, v_today, 0, now())
  on conflict (user_id, usage_date) do nothing;

  select request_count
    into v_current
    from public.ai_daily_usage
   where user_id = v_uid
     and usage_date = v_today
   for update;

  if v_current < p_daily_limit then
    v_current := v_current + 1;
    v_allowed := true;
    update public.ai_daily_usage
       set request_count = v_current,
           updated_at = now()
     where user_id = v_uid
       and usage_date = v_today;
  end if;

  return jsonb_build_object(
    'allowed', v_allowed,
    'used', v_current,
    'remaining', greatest(p_daily_limit - v_current, 0),
    'daily_limit', p_daily_limit,
    'reset_at', v_reset_at
  );
end;
$$;

grant execute on function public.consume_ai_quota(integer) to authenticated;
