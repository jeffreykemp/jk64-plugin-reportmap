create or replace force view jk64demo_countries_vw as
select lat, lng, country as name, rowid as id
from jk64demo_countries sample(10)
where lat is not null and lng is not null;