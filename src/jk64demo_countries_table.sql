create table jk64demo_countries
( country varchar2(255) not null
, iso_a2 varchar2(2)
, iso_a3 varchar2(3)
, lat number
, lng number
, geometry clob
, constraint jk64demo_country_name_uk unique (country)
, constraint jk64demo_iso_a2_uk unique (iso_a2)
, constraint jk64demo_iso_a3_uk unique (iso_a3)
, constraint jk64demo_geometry_is_json check (geometry is json)
) compress;
