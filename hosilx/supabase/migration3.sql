-- 3-qism: bot bildirishnomalari va narx dinamikasi
alter table public.inquiries add column if not exists notified boolean not null default false;
alter table public.storage_requests add column if not exists notified boolean not null default false;

create or replace function public.price_trend(p_type text, p_region text default null)
returns table (period date, unit text, currency text, observations bigint, median_price numeric)
language sql stable security definer set search_path = public as $$
  select date_trunc('month', created_at)::date, unit, currency, count(*),
         percentile_cont(0.5) within group (order by price)::numeric
  from products
  where status in ('active','sold') and product_type = p_type
    and (p_region is null or region = p_region)
  group by 1, 2, 3 order by 1;
$$;
