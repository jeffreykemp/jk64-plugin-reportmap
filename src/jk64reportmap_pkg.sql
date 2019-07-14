/**********************************************************
create or replace package jk64reportmap_pkg as
-- jk64 ReportMap v1.0 Jul 2019

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result;

function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ) return apex_plugin.t_region_ajax_result;

end jk64reportmap_pkg;
/

create or replace package body jk64reportmap_pkg as
**********************************************************/
-- jk64 ReportMap v1.0 Jul 2019

g_num_format    constant varchar2(100) := '99999999999999.999999999999999999999999999999';
g_tochar_format constant varchar2(100) := 'fm99999999999990.099999999999999999999999999999';

-- if only one row is returned by the query, add this +/- to the latitude extents so it
-- shows the neighbourhood instead of zooming to the max
g_single_row_lat_margin constant number := 0.005;

subtype plugin_attr is varchar2(32767);

procedure get_map_bounds
    (p_lat     in number
    ,p_lng     in number
    ,p_lat_min in out number
    ,p_lat_max in out number
    ,p_lng_min in out number
    ,p_lng_max in out number
    ) is
begin
    p_lat_min := least   (nvl(p_lat_min, p_lat), p_lat);
    p_lat_max := greatest(nvl(p_lat_max, p_lat), p_lat);
    p_lng_min := least   (nvl(p_lng_min, p_lng), p_lng);
    p_lng_max := greatest(nvl(p_lng_max, p_lng), p_lng);
end get_map_bounds;

function latlng_to_char (lat in number, lng in number) return varchar2 is
begin
  return '"lat":'
      || to_char(lat, g_tochar_format)
      || ',"lng":'
      || to_char(lng, g_tochar_format);
end latlng_to_char;

function get_markers
    (p_region     in apex_plugin.t_region
    ,p_lat_min    in out number
    ,p_lat_max    in out number
    ,p_lng_min    in out number
    ,p_lng_max    in out number
    ) return apex_application_global.vc_arr2 is
    
    l_options        plugin_attr := p_region.attribute_02;
    
    l_data           apex_application_global.vc_arr2;
    l_lat            number;
    l_lng            number;
    l_info           varchar2(4000);
    l_icon           varchar2(4000);
    l_marker_label   varchar2(1);
    l_weight         number;
     
    l_column_value_list  apex_plugin_util.t_column_value_list;

begin

/* For most cases, column list is as follows:

   lat,   - required
   lng,   - required
   name,  - required
   id,    - required
   info,  - optional
   icon,  - optional
   label  - optional
   
   If the "Heatmap" option is chosen, the column list is as follows:
   
   lat,   - required
   lng,   - required
   weight - required

*/
    
    if instr(':'||l_options||':',':HEATMAP:')>0 then

      l_column_value_list := apex_plugin_util.get_data
        (p_sql_statement  => p_region.source
        ,p_min_columns    => 3
        ,p_max_columns    => 3
        ,p_component_name => p_region.name
        ,p_max_rows       => p_region.fetched_rows);

      for i in 1..l_column_value_list(1).count loop
    
          if not l_column_value_list.exists(1)
          or not l_column_value_list.exists(2)
          or not l_column_value_list.exists(3) then
              raise_application_error(-20000, 'Report Map Query must have at least 3 columns (lat, lng, weight)');
          end if;

          l_lat    := to_number(l_column_value_list(1)(i));
          l_lng    := to_number(l_column_value_list(2)(i));
          l_weight := to_number(l_column_value_list(3)(i));
          
          -- minimise size of data to be sent
          l_data(nvl(l_data.last,0)+1) :=
               '{"a":' || to_char(l_lat, g_tochar_format)
            || ',"b":' || to_char(l_lng, g_tochar_format)
            || ',"c":'  || to_char(l_weight, 'fm9999990')
            || '}';
      
          get_map_bounds
            (p_lat     => l_lat
            ,p_lng     => l_lng
            ,p_lat_min => p_lat_min
            ,p_lat_max => p_lat_max
            ,p_lng_min => p_lng_min
            ,p_lng_max => p_lng_max
            );
        
      end loop;
    
    else
  
      l_column_value_list := apex_plugin_util.get_data
          (p_sql_statement  => p_region.source
          ,p_min_columns    => 4
          ,p_max_columns    => 7
          ,p_component_name => p_region.name
          ,p_max_rows       => p_region.fetched_rows);
  
      for i in 1..l_column_value_list(1).count loop
      
          if not l_column_value_list.exists(1)
          or not l_column_value_list.exists(2)
          or not l_column_value_list.exists(3)
          or not l_column_value_list.exists(4) then
              raise_application_error(-20000, 'Report Map Query must have at least 4 columns (lat, lng, name, id)');
          end if;
    
          l_lat  := to_number(l_column_value_list(1)(i),g_num_format);
          l_lng  := to_number(l_column_value_list(2)(i),g_num_format);
          
          -- default values if not supplied in query
          l_info         := null;
          l_icon         := null;
          l_marker_label := null;
          
          if l_column_value_list.exists(5) then
            l_info := l_column_value_list(5)(i);
            if l_column_value_list.exists(6) then
              l_icon := l_column_value_list(6)(i);
              if l_column_value_list.exists(7) then
                l_marker_label := substr(l_column_value_list(7)(i),1,1);
              end if;
            end if;
          end if;
      
          l_data(nvl(l_data.last,0)+1) :=
                 '{"id":'  || apex_escape.js_literal(l_column_value_list(4)(i),'"')
              || ',"name":'|| apex_escape.js_literal(l_column_value_list(3)(i),'"')
              || ','       || latlng_to_char(l_lat,l_lng)
              || case when l_info is not null then
                 ',"info":'|| apex_escape.js_literal(l_info,'"')
                 end
              || ',"icon":'|| apex_escape.js_literal(l_icon,'"')
              || ',"label":'|| apex_escape.js_literal(l_marker_label,'"')
              || '}';
      
          get_map_bounds
              (p_lat     => l_lat
              ,p_lng     => l_lng
              ,p_lat_min => p_lat_min
              ,p_lat_max => p_lat_max
              ,p_lng_min => p_lng_min
              ,p_lng_max => p_lng_max
              );
        
      end loop;

    end if;
    
    -- handle edge case when there is exactly one row from query
    -- (otherwise the map zooms to maximum)
    if l_data.count = 1 then
      p_lat_min := p_lat_min - g_single_row_lat_margin;
      p_lat_max := p_lat_max + g_single_row_lat_margin;
    end if;
    
    return l_data;
end get_markers;

procedure htp_arr (arr in apex_application_global.vc_arr2) is
begin
    for i in 1..arr.count loop
        -- use prn to avoid loading a whole lot of unnecessary \n characters
        sys.htp.prn(case when i > 1 then ',' end || arr(i));
    end loop;
end htp_arr;

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result is
    
    l_result       apex_plugin.t_region_render_result;

    l_lat          number;
    l_lng          number;
    l_region       varchar2(100);
    l_buffer       varchar2(32767);
    l_data         apex_application_global.vc_arr2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;
    l_zoom_enabled varchar2(10) := 'true';
    l_pan_enabled  varchar2(10) := 'true';

    -- Plugin attributes (application level)
    l_api_key           plugin_attr := p_plugin.attribute_01;

    -- Component attributes
    l_map_height        plugin_attr := p_region.attribute_01;
    l_visualisation     plugin_attr := p_region.attribute_02;
    l_click_zoom        plugin_attr := p_region.attribute_03;
    l_options           plugin_attr := p_region.attribute_04;
    l_latlong           plugin_attr := p_region.attribute_06;
    l_country           plugin_attr := p_region.attribute_10;
    l_mapstyle          plugin_attr := p_region.attribute_11;
    l_directions        plugin_attr := p_region.attribute_15;
    l_origin_item       plugin_attr := p_region.attribute_16;
    l_dest_item         plugin_attr := p_region.attribute_17;
    l_optimizewaypoints plugin_attr := p_region.attribute_21;
    l_maptype           plugin_attr := p_region.attribute_22;
    l_zoom_expr         plugin_attr := p_region.attribute_23;
    l_pan_expr          plugin_attr := p_region.attribute_24;
    l_gesture_handling  plugin_attr := p_region.attribute_25;
    
    l_opt varchar2(32767);
    
begin
    -- debug information will be included
    if apex_application.g_debug then
        apex_plugin_util.debug_region
            (p_plugin => p_plugin
            ,p_region => p_region
            ,p_is_printer_friendly => p_is_printer_friendly);
    end if;
    
    if l_api_key is null then
      raise_application_error(-20000, 'Google Maps API Key is required (set in Component Settings)');
    end if;
    
    if l_zoom_expr is not null then
        l_zoom_enabled := apex_plugin_util.get_plsql_expression_result (
               'case when ('
            || l_zoom_expr
            || ') then ''true'' else ''false'' end');
        if l_zoom_enabled not in ('true','false') then
            raise_application_error(-20000, 'Zoom attribute must evaluate to true or false.');
        end if;
    end if;

    if l_pan_expr is not null then
        l_pan_enabled := apex_plugin_util.get_plsql_expression_result (
               'case when ('
            || l_pan_expr
            || ') then ''true'' else ''false'' end');
        if l_pan_enabled not in ('true','false') then
            raise_application_error(-20000, 'Pan attribute must evaluate to true or false.');
        end if;
    end if;
    
    apex_javascript.add_library
        (p_name           => 'js?key=' || l_api_key
                          || case when l_visualisation='HEATMAP' then '&libraries=visualization' end
        ,p_directory      => 'https://maps.googleapis.com/maps/api/'
        ,p_skip_extension => true);
    
    apex_javascript.add_library
        (p_name                  => 'jk64reportmap'
        ,p_directory             => p_plugin.file_prefix
        ,p_check_to_add_minified => true);

    if l_visualisation = 'CLUSTER' then
        apex_javascript.add_library
            (p_name                  => 'markerclusterer'
            ,p_directory             => p_plugin.file_prefix
            ,p_check_to_add_minified => true);
    end if;

    l_region := case
                when p_region.static_id is not null
                then p_region.static_id
                else 'R'||p_region.id
                end;
    apex_debug.message('map region: ' || l_region);
    
    if p_region.source is not null then

        l_data := get_markers
            (p_region     => p_region
            ,p_lat_min    => l_lat_min
            ,p_lat_max    => l_lat_max
            ,p_lng_min    => l_lng_min
            ,p_lng_max    => l_lng_max
            );
        
    end if;
    
    if l_latlong is not null then
        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,',')-1),g_num_format);
        l_lng := to_number(substr(l_latlong,instr(l_latlong,',')+1),g_num_format);
    end if;
    
    if l_lat is not null and l_data.count > 0 then

        get_map_bounds
            (p_lat     => l_lat
            ,p_lng     => l_lng
            ,p_lat_min => l_lat_min
            ,p_lat_max => l_lat_max
            ,p_lng_min => l_lng_min
            ,p_lng_max => l_lng_max
            );

    elsif l_data.count = 0 and l_lat is not null then

        l_lat_min := greatest(l_lat - 10, -80);
        l_lat_max := least(l_lat + 10, 80);
        l_lng_min := greatest(l_lng - 10, -180);
        l_lng_max := least(l_lng + 10, 180);

    -- show entire map if no points to show
    elsif l_data.count = 0 then

        l_latlong := '0,0';
        l_lat_min := -90;
        l_lat_max := 90;
        l_lng_min := -180;
        l_lng_max := 180;

    end if;
    
    l_opt := 'regionId:"'||l_region||'"'
          || ',ajaxIdentifier:"' || apex_plugin.get_ajax_identifier || '"'
          || ',ajaxItems:"' || apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit) || '"'
          || ',pluginFilePrefix:"' || p_plugin.file_prefix || '"';
    if p_region.source is null then
      l_opt := l_opt || ',expectData:false';
    end if;
    l_opt := l_opt
          || ',visualisation:"' || lower(l_visualisation) || '"'
          || ',maptype:"' || lower(l_maptype) || '"'
          || ',latlng:"' || l_latlong || '"';
    if l_click_zoom is not null then
      l_opt := l_opt || ',markerZoom:' || l_click_zoom;
    end if;
    if instr(':'||l_options||':',':DRAGGABLE:')>0 then
      l_opt := l_opt || ',isDraggable:true';
    end if;
    if l_visualisation = 'HEATMAP' then
      l_opt := l_opt
            || ',dissipating:false'
            || ',opacity:0.6'
            || ',radius:5';
    end if;
    if instr(':'||l_options||':',':PAN_ON_CLICK:')>0 then
      l_opt := l_opt || ',panOnClick:true';
    end if;
    if l_country is not null then
      l_opt := l_opt || ',country:"' || l_country || '"';
    end if;
    l_opt := l_opt
          || ',southwest:{' || latlng_to_char(l_lat_min,l_lng_min) || '}'
          || ',northeast:{' || latlng_to_char(l_lat_max,l_lng_max) || '}';
    if l_mapstyle is not null then
      l_opt := l_opt || ',mapstyle:' || l_mapstyle;
    end if;
    if p_region.no_data_found_message is not null then
      l_opt := l_opt || ',noDataMessage:"' || p_region.no_data_found_message || '"';
    end if;
    if l_directions is not null then
      l_opt := l_opt || ',directions:"' || l_directions || '"';
      if l_optimizewaypoints='Y' then
        l_opt := l_opt || ',optimizeWaypoints:true';
      end if;
      if l_origin_item is not null then
        l_opt := l_opt || ',originItem:"' || l_origin_item || '"';
      end if;
      if l_dest_item is not null then
        l_opt := l_opt || ',destItem:"' || l_dest_item || '"';
      end if;
    end if;
    l_opt := l_opt
          || ',zoom:' || l_zoom_enabled
          || ',pan:' || l_pan_enabled;
    if l_gesture_handling is not null then
      l_opt := l_opt || ',gestureHandling:"' || l_gesture_handling || '"';
    end if;
        
    sys.htp.p('<script>
function r_'||l_region||'(f){/in/.test(document.readyState)?setTimeout("r_'||l_region||'("+f+")",9):f()}
r_'||l_region||'(function(){ $("#map_'||l_region||'").reportmap({'||l_opt||'}); });
</script>
<div id="map_'||l_region||'" style="min-height:'||l_map_height||'px"></div>');
    
    return l_result;
end render;

function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ) return apex_plugin.t_region_ajax_result is

    l_result apex_plugin.t_region_ajax_result;

    l_lat          number;
    l_lng          number;
    l_data         apex_application_global.vc_arr2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;

    -- Component attributes
    l_latlong      plugin_attr := p_region.attribute_06;

begin
    -- debug information will be included
    if apex_application.g_debug then
        apex_plugin_util.debug_region
            (p_plugin => p_plugin
            ,p_region => p_region);
    end if;
    apex_debug.message('ajax');

    if p_region.source is not null then

        l_data := get_markers
            (p_region     => p_region
            ,p_lat_min    => l_lat_min
            ,p_lat_max    => l_lat_max
            ,p_lng_min    => l_lng_min
            ,p_lng_max    => l_lng_max
            );
        
      apex_debug.message('data.count='||l_data.count);

    end if;
        
    if l_latlong is not null then
        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,',')-1),g_num_format);
        l_lng := to_number(substr(l_latlong,instr(l_latlong,',')+1),g_num_format);
    end if;
    
    if l_lat is not null and l_data.count > 0 then
        get_map_bounds
            (p_lat     => l_lat
            ,p_lng     => l_lng
            ,p_lat_min => l_lat_min
            ,p_lat_max => l_lat_max
            ,p_lng_min => l_lng_min
            ,p_lng_max => l_lng_max
            );

    elsif l_data.count = 0 and l_lat is not null then
        l_lat_min := greatest(l_lat - 10, -180);
        l_lat_max := least(l_lat + 10, 80);
        l_lng_min := greatest(l_lng - 10, -180);
        l_lng_max := least(l_lng + 10, 180);

    -- show entire map if no points to show
    elsif l_data.count = 0 then
        l_lat_min := -90;
        l_lat_max := 90;
        l_lng_min := -180;
        l_lng_max := 180;

    end if;

    sys.owa_util.mime_header('text/plain', false);
    sys.htp.p('Cache-Control: no-cache');
    sys.htp.p('Pragma: no-cache');
    sys.owa_util.http_header_close;
    
    sys.htp.p(
           '{"southwest":{'
        || latlng_to_char(l_lat_min,l_lng_min)
        || '},"northeast":{'
        || latlng_to_char(l_lat_max,l_lng_max)
        || '},"mapdata":[');

    htp_arr(l_data);

    sys.htp.p(']}');

    apex_debug.message('ajax finished');
    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        sys.htp.p('{"error":"'||sqlerrm||'"}');
end ajax;

/**********************************************************
end jk64reportmap_pkg;
**********************************************************/