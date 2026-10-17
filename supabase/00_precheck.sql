-- 6-migratsiyadan OLDIN ishga tushiring va natijani tekshiring (hech narsani o'zgartirmaydi).
select table_name from information_schema.tables where table_schema='public' order by 1;
select column_name, data_type from information_schema.columns where table_schema='public' and table_name='products' order by ordinal_position;
select conname from pg_constraint where conrelid='public.products'::regclass;   -- products_category_check bo'lishi kerak
select policyname from pg_policies where schemaname='public' and tablename='products';
select count(*) as products_rows from public.products;
