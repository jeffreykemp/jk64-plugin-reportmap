/**********************************************************
create or replace package jk64reportmap_r1_pkg as
-- jk64 ReportMap v1.4 Aug 2020
-- https://github.com/jeffreykemp/jk64-plugin-reportmap
-- Copyright (c) 2016 - 2020 Jeffrey Kemp
-- Released under the MIT licence: http://opensource.org/licenses/mit-license

-- If you compile this on your database, make sure to edit the plugin to clear
-- out the Source PL/SQL Code. This will improve the performance of the plugin.

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result;

function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ) return apex_plugin.t_region_ajax_result;

end jk64reportmap_r1_pkg;
/

create or replace package body jk64reportmap_r1_pkg as
**********************************************************/
-- jk64 ReportMap v1.4 Aug 2020
-- https://github.com/jeffreykemp/jk64-plugin-reportmap
-- Copyright (c) 2016 - 2020 Jeffrey Kemp
-- Released under the MIT licence: http://opensource.org/licenses/mit-license

-- format to use to convert a lat/lng number to string for passing via javascript
-- 0.0000001 is enough precision for the practical limit of commercial surveying, error up to +/- 11.132 mm at the equator
g_tochar_format                constant varchar2(100) := 'fm990.0999999';
g_coord_precision              constant number := 6;

-- if only one row is returned by the query, add this +/- to the latitude extents so it
-- shows the neighbourhood instead of zooming to the max
g_single_row_lat_margin        constant number := 0.005;

g_visualisation_pins           constant varchar2(10) := 'PINS';               -- default
g_visualisation_cluster        constant varchar2(10) := 'CLUSTER';
g_visualisation_spiderfier     constant varchar2(10) := 'SPIDERFIER';
g_visualisation_heatmap        constant varchar2(10) := 'HEATMAP';
g_visualisation_directions     constant varchar2(10) := 'DIRECTIONS';
g_visualisation_geojson        constant varchar2(10) := 'GEOJSON';

g_maptype_roadmap              constant varchar2(10) := 'ROADMAP';            -- default
g_maptype_satellite	           constant varchar2(10) := 'SATELLITE';
g_maptype_hybrid               constant varchar2(10) := 'HYBRID';
g_maptype_terrain              constant varchar2(10) := 'TERRAIN';

g_travelmode_driving           constant varchar2(10) := 'DRIVING';            -- default
g_travelmode_walking           constant varchar2(10) := 'WALKING';
g_travelmode_bicycling         constant varchar2(10) := 'BICYCLING';
g_travelmode_transit           constant varchar2(10) := 'TRANSIT';

g_option_pan_on_click          constant varchar2(30) := ':PAN_ON_CLICK:';     -- default
g_option_draggable             constant varchar2(30) := ':DRAGGABLE:';
g_option_pan_allowed           constant varchar2(30) := ':PAN_ALLOWED:';      -- default
g_option_zoom_allowed          constant varchar2(30) := ':ZOOM_ALLOWED:';     -- default
g_option_drag_drop_geojson     constant varchar2(30) := ':GEOJSON_DRAGDROP:';
g_option_disable_autofit       constant varchar2(30) := ':DISABLEFITBOUNDS:';
g_option_spinner               constant varchar2(30) := ':SPINNER:';          -- default

subtype plugin_attr is varchar2(32767);

function latlng_literal (lat in number, lng in number) return varchar2 is
begin
    return case when lat is not null and lng is not null then
        '{'
        || apex_javascript.add_attribute('lat', round(lat,g_coord_precision))
        || apex_javascript.add_attribute('lng', round(lng,g_coord_precision)
           , false, false)
        || '}'
        end;
end latlng_literal;

function bounds_literal (south in number, west in number, north in number, east in number) return varchar2 is
begin
    return case when south is not null and west is not null and north is not null and east is not null then
        '{'
        || apex_javascript.add_attribute('south', round(south, g_coord_precision))
        || apex_javascript.add_attribute('west',  round(west,  g_coord_precision))
        || apex_javascript.add_attribute('north', round(north, g_coord_precision))
        || apex_javascript.add_attribute('east',  round(east,  g_coord_precision)
           , false, false)
        || '}'
        end;
end bounds_literal;

procedure parse_latlng (p_val in varchar2, p_label in varchar2, p_lat out number, p_lng out number) is
    delim_pos number;
begin
    -- allow space as the delimiter; this should be used in locales which use comma (,) as decimal separator
    if instr(trim(p_val),' ') > 0 then
        delim_pos := instr(p_val,' ');
    else
        delim_pos := instr(p_val,',');
    end if;
    p_lat := apex_plugin_util.get_attribute_as_number(substr(p_val,1,delim_pos-1), p_label || ' latitude');
    p_lng := apex_plugin_util.get_attribute_as_number(substr(p_val,delim_pos+1),   p_label || ' longitude');
end parse_latlng;

function valid_zoom_level (p_attr in varchar2, p_label in varchar2) return number is
    n number;
begin
    n := apex_plugin_util.get_attribute_as_number(p_attr, p_label);
    -- note: this validation is not perfect because not all map areas necessarily have coverage at high zoom
    -- levels; the map will only zoom as far as it can
    if not n between 0 and 23 then
        raise_application_error(-20000, p_label || ': must be in range 0..23 ("' || p_attr || '")');
    end if;
    return n;
end valid_zoom_level;

function get_source (p_region in apex_plugin.t_region) return varchar2 is
    l_region                apex_application_page_regions%rowtype;
    l_visualisation         plugin_attr := p_region.attribute_02;
    l_result                varchar2(32767);
begin
    select r.*
    into   l_region
    from   apex_application_page_regions r
    where  r.region_id = p_region.id;

    apex_debug.message('source type: ' || l_region.query_type_code || ' (' || l_region.location || ' - ' || l_region.query_type || ')');
    
    if l_region.location_code = 'LOCAL' then
        
        l_result := case l_region.query_type_code
                    when 'SQL'
                        then p_region.source
                    when 'FUNC_BODY_RETURNING_SQL'
                        then apex_plugin_util.get_plsql_function_result(p_region.source)
                    when 'TABLE'
                        then 'select '
                          || case l_visualisation
                             when g_visualisation_heatmap then 'lat,lng,weight'
                             when g_visualisation_geojson then 'geojson'
                             else case when l_region.include_rowid_column = 'Yes'
                                  then 'lat,lng,name,rowid as id'
                                  else 'lat,lng,name,id'
                                  end
                             end
                          || ' from '
                          || case when l_region.table_owner is not null then '"' || l_region.table_owner || '".' end
                          || '"' || l_region.table_name || '" "' || l_region.table_name || '"'
                          || case when l_region.where_clause is not null then ' where (' || l_region.where_clause || ')' end
                          || case when l_region.order_by_clause is not null then ' order by ' || l_region.order_by_clause end
                    end;
        
        if l_result is null then
            raise_application_error(-20001, 'Unsupported region source (' || l_region.query_type || '); must be Table/View, SQL Query or PL/SQL Function Body returning SQL');
        end if;

    elsif l_region.location is not null then
        raise_application_error(-20001, 'Unsupported source location (' || l_region.location || '); must be Local Database');
    end if;

    apex_debug.message('source: ' || l_result);

    return l_result;
end get_source;

procedure prn_mapdata (p_region in apex_plugin.t_region) is
    
    l_source                varchar2(32767);
    l_flex                  varchar2(32767);
    l_buf                   varchar2(32767);
    l_column_list           apex_plugin_util.t_column_value_list2;
    l_visualisation         plugin_attr := p_region.attribute_02;
    l_escape_special_chars  plugin_attr := p_region.attribute_24;
    l_first_row             number;
    l_max_rows              number;
    l_geojson_clob          clob;
    l_chunk_size            number := 32767;
    l_rows_emitted          number := 0;

    function varchar2_field (attr_no in number, i in number) return varchar2 is
        r varchar2(4000);
    begin
        if l_column_list.exists(attr_no) then
            -- whatever data type was in the original source, get it as a string
            r := sys.htf.escape_sc(
                apex_plugin_util.get_value_as_varchar2 (
                    p_data_type => l_column_list(attr_no).data_type,
                    p_value     => l_column_list(attr_no).value_list(i)
                    ));
        end if;
        return r;
    end varchar2_field;
    
    function number_field (attr_no in number, i in number) return number is
        r number;
    begin
        if l_column_list(attr_no).data_type = apex_plugin_util.c_data_type_number then
            r := l_column_list(attr_no).value_list(i).number_value;
        else
            r := to_number(varchar2_field(attr_no, i));
        end if;
        return r;
    exception
        when value_error then
            raise_application_error(-20000, 'Unable to convert data to number [' || varchar2_field(attr_no, i) || ']');
    end number_field;
    
    -- return a latitude or longitude as a number formatted as a string suitable for embedding in json
    function lat_or_lng_field (attr_no in number, i in number) return varchar2 is
        r number;
    begin
        if l_column_list(attr_no).data_type = apex_plugin_util.c_data_type_number then
            r := l_column_list(attr_no).value_list(i).number_value;
        else
            r := to_number(varchar2_field(attr_no, i));
        end if;
        return to_char(r, g_tochar_format);
    exception
        when value_error then
            raise_application_error(-20000, 'Unable to convert data to '
                || case attr_no when 1 then 'latitude' when 2 then 'longitude' else 'lat/lng' end
                || ' [' || varchar2_field(attr_no, i) || ']');
    end lat_or_lng_field;

    function flex_field (attr_no in number, i in number, offset in number) return varchar2 is
      d varchar2(4000);
    begin
        if l_column_list.exists(attr_no+offset) then
            d := apex_plugin_util.get_value_as_varchar2 (
                p_data_type => l_column_list(attr_no+offset).data_type,
                p_value     => l_column_list(attr_no+offset).value_list(i)
                );
            if l_escape_special_chars='Y' then
                d := sys.htf.escape_sc(d);
            end if;
        end if;
        return apex_javascript.add_attribute('a'||attr_no,d);
    end flex_field;
    
begin
    apex_debug.message('reportmap x01 (first row): ' || apex_application.g_x01);
    apex_debug.message('reportmap x02 (max rows): ' || apex_application.g_x02);
    
    l_first_row := to_number(apex_application.g_x01);
    l_max_rows := to_number(apex_application.g_x02);

    l_source := get_source(p_region);
    
    if l_source is not null then
        
        /*
           For the "pin" type visualisations, column list is as follows:
        
           1.     lat            -- required
           2.     lng            -- required
           3.     name           -- required
           4.     id             -- required
           5.     info           -- optional
           6.     icon           -- optional
           7.     label          -- optional
           8-17.  flex01..flex10 -- optional flex fields
           
           For the "Heatmap" visualisation:
           
           1.     lat            -- required
           2.     lng            -- required
           3.     weight         -- required
           
           For the "GeoJson" visualisation:
           
           1.     geojson        -- required
           2.     name           -- optional
           3.     id             -- optional
           4-13.  flex01..flex10 -- optional flex fields
        
        */
        
        case
        when l_visualisation = g_visualisation_heatmap then

            l_column_list := apex_plugin_util.get_data2
                (p_sql_statement  => l_source
                ,p_min_columns    => 3
                ,p_max_columns    => 3
                ,p_component_name => p_region.name
                ,p_max_rows       => l_max_rows);
      
            for i in 1 .. l_column_list(1).value_list.count loop
            
                -- minimise size of data to be sent by encoding it as an array of arrays
                l_buf := '[' || lat_or_lng_field(1,i)
                      || ',' || lat_or_lng_field(2,i)
                      || ',' || greatest( nvl( round( number_field(3,i) ), 1), 1)
                      || ']';

                if i < 8 /*don't send the whole dataset to debug log*/ then
                    apex_debug.message('#' || i || ': ' || l_buf);
                end if;
                
                if i>1 then
                    sys.htp.prn(',');
                end if;

                sys.htp.prn(l_buf);
                
                l_rows_emitted := l_rows_emitted + 1;
              
            end loop;

        when l_visualisation = g_visualisation_geojson then
        
            l_column_list := apex_plugin_util.get_data2
                (p_sql_statement  => l_source
                ,p_min_columns    => 1
                ,p_max_columns    => 12
                ,p_component_name => p_region.name
                ,p_first_row      => l_first_row
                ,p_max_rows       => l_max_rows
                );

            for i in 1 .. l_column_list(1).value_list.count loop
            
                if i>1 then
                    sys.htp.prn(',');
                end if;
                
                sys.htp.prn('{"geojson":');

                if l_column_list(1).data_type = apex_plugin_util.c_data_type_clob then

                    l_geojson_clob := l_column_list(1).value_list(i).clob_value;
                    
                    -- send the clob down in chunks

                    for j in 0 .. floor(length(l_geojson_clob)/l_chunk_size) loop

                        l_buf := substr(l_geojson_clob, j * l_chunk_size + 1, l_chunk_size);

                        if i < 8 and j = 0 /*don't send the whole dataset to debug log*/ then
                            apex_debug.message('#' || i || ': ' || substr(l_buf,1,1000));
                        end if;

                        sys.htp.prn(l_buf);

                    end loop;
                
                else
                
                    l_buf := varchar2_field(1,i);
                
                    if i < 8 /*don't send the whole dataset to debug log*/ then
                        apex_debug.message('#' || i || ': ' || substr(l_buf,1,1000));
                    end if;
                    
                    sys.htp.prn(l_buf);

                end if;

                -- get flex fields, if any
                l_flex := null;
                for attr_no in 1..10 loop
                    l_flex := l_flex || flex_field(attr_no, i, offset => 3);
                end loop;
                
                l_buf := ','
                      || apex_javascript.add_attribute('n',varchar2_field(2,i)) /*name*/
                      || apex_javascript.add_attribute('d',varchar2_field(3,i)) /*id*/
                      || case when l_flex is not null then
                           '"f":{' || rtrim(l_flex,',') || '}'
                         end;
                
                l_buf := rtrim(l_buf, ',');
                
                sys.htp.prn(l_buf || '}');

                l_rows_emitted := l_rows_emitted + 1;

            end loop;
            
        else
            -- "pin" type visualisations
      
            l_column_list := apex_plugin_util.get_data2
                (p_sql_statement  => l_source
                ,p_min_columns    => 4
                ,p_max_columns    => 17
                ,p_component_name => p_region.name
                ,p_first_row      => l_first_row
                ,p_max_rows       => l_max_rows);
        
            for i in 1..l_column_list(1).value_list.count loop

                -- get flex fields, if any
                l_flex := null;
                for attr_no in 1..10 loop
                    l_flex := l_flex || flex_field(attr_no, i, offset => 7);
                end loop;

                l_buf := '"x":' || lat_or_lng_field(1,i) || ',' /*lat*/
                      || '"y":' || lat_or_lng_field(2,i) || ',' /*lng*/
                      || apex_javascript.add_attribute('n',varchar2_field(3,i)) /*name*/
                      || apex_javascript.add_attribute('d',varchar2_field(4,i)) /*id*/
                      || apex_javascript.add_attribute('i',varchar2_field(5,i)) /*info*/
                      || apex_javascript.add_attribute('c',varchar2_field(6,i)) /*icon*/
                      || apex_javascript.add_attribute('l',substr(varchar2_field(7,i),1,1)) /*label*/
                      || case when l_flex is not null then
                           '"f":{' || rtrim(l_flex,',') || '}'
                         end;
                
                l_buf := '{' || rtrim(l_buf,',') || '}';

                if i < 8 /*don't send the whole dataset to debug log*/ then
                    apex_debug.message('#' || i || ': ' || substr(l_buf,1,1000));
                end if;

                if i>1 then
                    sys.htp.prn(',');
                end if;

                sys.htp.prn(l_buf);

                l_rows_emitted := l_rows_emitted + 1;
              
            end loop;

        end case;
    
    end if;
    
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        sys.htp.p(case when l_rows_emitted>0 then ',' end
            || '{"error":' || apex_escape.js_literal(sqlerrm,'"') || '}');
end prn_mapdata;

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result is
    
    l_result                       apex_plugin.t_region_render_result;

    -- Component settings
    l_api_key                      plugin_attr := p_plugin.attribute_01;
    l_no_address_results_msg       plugin_attr := p_plugin.attribute_02;
    l_directions_not_found_msg     plugin_attr := p_plugin.attribute_03;
    l_directions_zero_results_msg  plugin_attr := p_plugin.attribute_04;
    l_min_zoom                     number;      --p_plugin.attribute_05;
    l_max_zoom                     number;      --p_plugin.attribute_06;
    l_max_rows                     number;      --p_plugin.attribute_07;

    -- Plugin attributes
    l_map_height                   plugin_attr := p_region.attribute_01;
    l_visualisation                plugin_attr := p_region.attribute_02;
    l_click_zoom_level             number;      --p_region.attribute_03;
    l_options                      plugin_attr := p_region.attribute_04;
    l_initial_zoom_level           number;      --p_region.attribute_05;
    l_initial_center               plugin_attr := p_region.attribute_06;
    l_rows_per_batch               number;      --p_region.attribute_07;
    l_language                     plugin_attr := p_region.attribute_08;
    l_region                       plugin_attr := p_region.attribute_09;
    l_restrict_country             plugin_attr := p_region.attribute_10;
    l_mapstyle                     plugin_attr := p_region.attribute_11;
    l_heatmap_dissipating          plugin_attr := p_region.attribute_12;
    l_heatmap_opacity              number;      --p_region.attribute_13;
    l_heatmap_radius               number;      --p_region.attribute_14;
    l_travel_mode                  plugin_attr := p_region.attribute_15;
    l_drawing_modes                plugin_attr := p_region.attribute_16;
    -- unused                      plugin_attr := p_region.attribute_17;
    -- unused                      plugin_attr := p_region.attribute_18;
    -- unused                      plugin_attr := p_region.attribute_19;
    -- unused                      plugin_attr := p_region.attribute_20;
    l_optimizewaypoints            plugin_attr := p_region.attribute_21;
    l_maptype                      plugin_attr := p_region.attribute_22;
    -- unused                      plugin_attr := p_region.attribute_23;
    -- unused                      plugin_attr := p_region.attribute_24;
    l_gesture_handling             plugin_attr := p_region.attribute_25;
    
    l_source                       varchar2(32767);
    l_region_id                    varchar2(100);
    l_lat                          number;
    l_lng                          number;
    l_opt                          varchar2(32767);
    l_js_options                   varchar2(1000);
    l_dragdrop_geojson             boolean;
    l_init_js_code                 plugin_attr;
    
begin
    if apex_application.g_debug then
        apex_plugin_util.debug_region
            (p_plugin => p_plugin
            ,p_region => p_region
            ,p_is_printer_friendly => p_is_printer_friendly);
    end if;
    
    if l_api_key is null or instr(l_api_key,'(') > 0 then
      raise_application_error(-20000, 'Google Maps API Key is required (set in Component Settings)');
    end if;
    
    l_region_id := case
                   when p_region.static_id is not null
                   then p_region.static_id
                   else 'R'||p_region.id
                   end;
    apex_debug.message('map region: ' || l_region_id);
    
    l_source := get_source(p_region);

/*******************************************************************/
/* Remove this for apex 5.0 or earlier                             */
    l_init_js_code := p_region.init_javascript_code;
/*******************************************************************/

    -- Component settings
    l_min_zoom           := valid_zoom_level(p_plugin.attribute_05, 'Min. Zoom');
    l_max_zoom           := valid_zoom_level(p_plugin.attribute_06, 'Max. Zoom');
    l_max_rows           := apex_plugin_util.get_attribute_as_number(p_plugin.attribute_07, 'Maximum Records');

    -- Plugin attributes
    l_click_zoom_level   := valid_zoom_level(p_region.attribute_03, 'Zoom Level on Click');
    l_initial_zoom_level := valid_zoom_level(p_region.attribute_05, 'Initial Zoom Level');
    l_heatmap_opacity    := apex_plugin_util.get_attribute_as_number(p_region.attribute_13, 'Heatmap Opacity');
    l_heatmap_radius     := apex_plugin_util.get_attribute_as_number(p_region.attribute_14, 'Heatmap Radius');
    l_dragdrop_geojson   := instr(':'||l_options||':',g_option_drag_drop_geojson)>0;
    
    if l_initial_center is not null then
        parse_latlng(l_initial_center, p_label=>'Initial Map Center', p_lat=>l_lat, p_lng=>l_lng);
    end if;

    if l_visualisation not in (g_visualisation_heatmap, g_visualisation_directions) then
        l_rows_per_batch := apex_plugin_util.get_attribute_as_number(p_region.attribute_07, 'Rows per Batch');
    end if;
    
    if l_drawing_modes is not null then
        -- convert colon-delimited list "marker:polygon:polyline:rectangle:circle"
        -- to a javascript array "'marker','polygon','polyline','rectangle','circle'"
        l_drawing_modes := '''' || replace(l_drawing_modes,':',''',''') || '''';
    end if;
        
    if l_visualisation = g_visualisation_heatmap then

        l_js_options := l_js_options || '&libraries=visualization';

    elsif l_drawing_modes is not null then

        l_js_options := l_js_options || '&libraries=drawing';

    end if;
    
    if l_language is not null then
        l_js_options := l_js_options || '&language=' || l_language;
    end if;

    if l_region is not null then
        l_js_options := l_js_options || '&region=' || l_region;
    end if;

    apex_javascript.add_library
        (p_name           => 'js?key=' || l_api_key || l_js_options
        ,p_directory      => 'https://maps.googleapis.com/maps/api/'
        ,p_skip_extension => true
        ,p_key            => 'https://maps.googleapis.com/maps/api/js' -- don't load multiple google maps APIs on same page
        );

    if l_visualisation = g_visualisation_cluster then

        -- MarkerClustererPlus for Google Maps V3
        apex_javascript.add_library
            (p_name      => 'markerclusterer.min'
            ,p_directory => p_plugin.file_prefix);

    elsif l_visualisation = g_visualisation_spiderfier then

        -- OverlappingMarkerSpiderfier
        apex_javascript.add_library
            (p_name      => 'oms.min'
            ,p_directory => p_plugin.file_prefix);

    end if;
    
    -- use nullif to convert default values to null; this reduces the footprint of the generated code
    l_opt := '{'
      || apex_javascript.add_attribute('regionId', l_region_id)
      || apex_javascript.add_attribute('expectData', nullif(l_source is not null,true))
      || apex_javascript.add_attribute('maximumRows', l_max_rows)
      || apex_javascript.add_attribute('rowsPerBatch', l_rows_per_batch)
      || apex_javascript.add_attribute('visualisation', lower(nullif(l_visualisation,g_visualisation_pins)))
      || apex_javascript.add_attribute('mapType', lower(nullif(l_maptype,g_maptype_roadmap)))
      || apex_javascript.add_attribute('minZoom', nullif(l_min_zoom,1))
      || apex_javascript.add_attribute('maxZoom', l_max_zoom)
      || apex_javascript.add_attribute('initialZoom', nullif(l_initial_zoom_level,2))
      || case when l_lat!=0 or l_lng!=0 then
            '"initialCenter":' || latlng_literal(l_lat,l_lng) || ','
         end
      || apex_javascript.add_attribute('clickZoomLevel', l_click_zoom_level)
      || apex_javascript.add_attribute('isDraggable', nullif(instr(':'||l_options||':',g_option_draggable)>0,false))
      || case when l_visualisation = g_visualisation_heatmap then
            apex_javascript.add_attribute('heatmapDissipating', nullif(l_heatmap_dissipating='Y',false))
         || apex_javascript.add_attribute('heatmapOpacity', nullif(l_heatmap_opacity,0.6))
         || apex_javascript.add_attribute('heatmapRadius', nullif(l_heatmap_radius,5))
         end
      || apex_javascript.add_attribute('panOnClick', nullif(instr(':'||l_options||':',g_option_pan_on_click)>0,true))
      || apex_javascript.add_attribute('restrictCountry', l_restrict_country)
      || case when l_mapstyle is not null then
         '"mapStyle":' || l_mapstyle || ','
         end
      || case when l_visualisation = g_visualisation_directions then
            apex_javascript.add_attribute('travelMode', nullif(l_travel_mode,g_travelmode_driving))
         || apex_javascript.add_attribute('optimizeWaypoints', nullif(l_optimizewaypoints='Y',false))
         end
      || apex_javascript.add_attribute('allowZoom', nullif(instr(':'||l_options||':',g_option_zoom_allowed)>0,true))
      || apex_javascript.add_attribute('allowPan', nullif(instr(':'||l_options||':',g_option_pan_allowed)>0,true))
      || apex_javascript.add_attribute('gestureHandling', nullif(l_gesture_handling,'auto'))
      || case when l_init_js_code is not null then
         '"initFn":function(){'
            || chr(13)
            || l_init_js_code
            || chr(13) /* this handles the case if developer ends their javascript with a line comment // */
            || '},'
         end
      || case when l_drawing_modes is not null then
         '"drawingModes":[' || l_drawing_modes || '],'
         end
      || apex_javascript.add_attribute('dragDropGeoJSON', nullif(l_dragdrop_geojson,false))
	  || apex_javascript.add_attribute('autoFitBounds', nullif(instr(':'||l_options||':',g_option_disable_autofit)=0,true))
      || apex_javascript.add_attribute('showSpinner', nullif(instr(':'||l_options||':',g_option_spinner)>0,true))
      || apex_javascript.add_attribute('noDataMessage', p_region.no_data_found_message)
      || apex_javascript.add_attribute('noAddressResults', l_no_address_results_msg)
      || apex_javascript.add_attribute('directionsNotFound', l_directions_not_found_msg)
      || apex_javascript.add_attribute('directionsZeroResults', l_directions_zero_results_msg)
      || apex_javascript.add_attribute('ajaxIdentifier', apex_plugin.get_ajax_identifier)
      || apex_javascript.add_attribute('ajaxItems', apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit))
      || apex_javascript.add_attribute('pluginFilePrefix', p_plugin.file_prefix
         ,false,false)
      || '}';

    apex_debug.message('map options: ' || l_opt);
  
    apex_javascript.add_onload_code(p_code =>
      '$("#map_' || l_region_id || '").reportmap(' || l_opt || ');'
      );
  
    sys.htp.p('<div id="map_' || l_region_id || '" class="reportmap" style="min-height:' || l_map_height || 'px"></div>');
    
    if l_dragdrop_geojson then
        sys.htp.p('<div id="drop_' || l_region_id || '" class="reportmap-drop-container"><div class="reportmap-drop-silhouette"></div></div>');
    end if;

    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        raise;
end render;

function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ) return apex_plugin.t_region_ajax_result is

    l_result apex_plugin.t_region_ajax_result;

begin
    if apex_application.g_debug then
        apex_plugin_util.debug_region
            (p_plugin => p_plugin
            ,p_region => p_region);
    end if;
    apex_debug.message('ajax');
    
    sys.owa_util.mime_header('text/plain', false);
    sys.htp.p('Cache-Control: no-cache');
    sys.htp.p('Pragma: no-cache');
    sys.owa_util.http_header_close;
    
    sys.htp.p('{"mapdata":[');

    prn_mapdata(p_region => p_region);

    sys.htp.p(']}');

    apex_debug.message('ajax finished');
    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        raise;
end ajax;

/**********************************************************
end jk64reportmap_r1_pkg;
/
**********************************************************/