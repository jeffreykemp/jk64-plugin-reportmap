create or replace package jk64reportmap_pkg as
-- jk64 ReportMap v0.10

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
show err

create or replace package body jk64reportmap_pkg as
-- jk64 ReportMap v0.10

g_num_format    constant varchar2(100) := '99999999999999.999999999999999999999999999999';
g_tochar_format constant varchar2(100) := 'fm99999999999990.099999999999999999999999999999';

g_attr1_label   constant varchar2(10)  := 'LABEL';

procedure set_map_extents
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
end set_map_extents;

function latlng2ch (lat in number, lng in number) return varchar2 is
begin
  return '"lat":'
      || to_char(lat, g_tochar_format)
      || ',"lng":'
      || to_char(lng, g_tochar_format);
end latlng2ch;

function get_markers
    (p_region     in apex_plugin.t_region
    ,p_lat_min    in out number
    ,p_lat_max    in out number
    ,p_lng_min    in out number
    ,p_lng_max    in out number
    ,p_attribute1 in varchar2
    ) return apex_application_global.vc_arr2 is
    
    l_data           apex_application_global.vc_arr2;
    l_lat            number;
    l_lng            number;
    l_info           varchar2(4000);
    l_icon           varchar2(4000);
    l_radius_km      number;
    l_circle_color   varchar2(100);
    l_circle_transp  number;
    l_flex_fields    varchar2(32767);
    l_marker_label   varchar2(1);
     
    l_column_value_list  apex_plugin_util.t_column_value_list;

begin

    l_column_value_list := apex_plugin_util.get_data
        (p_sql_statement  => p_region.source
        ,p_min_columns    => 4
        ,p_max_columns    => 19
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
        l_icon          := null;
        l_radius_km     := null;
        l_circle_color  := '#0000cc';
        l_circle_transp := 0.3;
        l_flex_fields   := null;
        l_marker_label  := null;
        
        if l_column_value_list.exists(5) then
          l_info := l_column_value_list(5)(i);
          if l_column_value_list.exists(6) then
            l_icon := l_column_value_list(6)(i);
            if l_column_value_list.exists(7) then
              l_radius_km := to_number(l_column_value_list(7)(i),g_num_format);
              if l_column_value_list.exists(8) then
                l_circle_color := l_column_value_list(8)(i);
                if l_column_value_list.exists(9) then
                  l_circle_transp := to_number(l_column_value_list(9)(i),g_num_format);
                end if;
              end if;
            end if;
          end if;
        end if;
        
        -- The remaining columns are up to 10 "flex" fields.
        -- If one of them is equal to a special attribute ("label"), the very next
        -- field is interpreted as the label.
        for j in 10..19 loop
            if l_column_value_list.exists(j) then
  
                if j = 10 and upper(p_attribute1) = g_attr1_label then
    
                    l_marker_label := substr(l_column_value_list(j)(i), 1, 1);
    
                else
    
                    l_flex_fields := l_flex_fields
                                  || ',"attr'
                                  || to_char(j-9,'fm00')
                                  || '":'
                                  || apex_escape.js_literal(l_column_value_list(j)(i),'"');
    
                end if;
  
            end if;
        end loop;
		
        l_data(nvl(l_data.last,0)+1) :=
               '{"id":'  || apex_escape.js_literal(l_column_value_list(4)(i),'"')
            || ',"name":'|| apex_escape.js_literal(l_column_value_list(3)(i),'"')
            || ','       || latlng2ch(l_lat,l_lng)
            || case when l_info is not null then
               ',"info":'|| apex_escape.js_literal(l_info,'"')
               end
            || ',"icon":'|| apex_escape.js_literal(l_icon,'"')
            || ',"label":'|| apex_escape.js_literal(l_marker_label,'"') 
            || case when l_radius_km is not null then
               ',"rad":' || to_char(l_radius_km,g_tochar_format)
            || ',"col":' || apex_escape.js_literal(l_circle_color,'"')
            ||   case when l_circle_transp is not null then
               ',"trns":'|| to_char(l_circle_transp,'fm990.099')
                 end
               end
            || l_flex_fields
            || '}';
    
        set_map_extents
            (p_lat     => l_lat
            ,p_lng     => l_lng
            ,p_lat_min => p_lat_min
            ,p_lat_max => p_lat_max
            ,p_lng_min => p_lng_min
            ,p_lng_max => p_lng_max
            );
      
    end loop;

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

    subtype plugin_attr is varchar2(32767);
    
    l_result       apex_plugin.t_region_render_result;

    l_lat          number;
    l_lng          number;
    l_region       varchar2(100);
    l_script       varchar2(32767);
    l_data         apex_application_global.vc_arr2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;
    l_zoom_enabled varchar2(1000) := 'true';
    l_pan_enabled  varchar2(1000) := 'true';

    -- Plugin attributes (application level)
    l_api_key           plugin_attr := p_plugin.attribute_01;

    -- Component attributes
    l_map_height        plugin_attr := p_region.attribute_01;
    l_id_item           plugin_attr := p_region.attribute_02;
    l_click_zoom        plugin_attr := p_region.attribute_03;    
    l_sync_item         plugin_attr := p_region.attribute_04;
    l_markericon        plugin_attr := p_region.attribute_05;
    l_latlong           plugin_attr := p_region.attribute_06;
    l_dist_item         plugin_attr := p_region.attribute_07;
    l_pan_on_click      plugin_attr := p_region.attribute_08;
    l_geocode_item      plugin_attr := p_region.attribute_09;
    l_country           plugin_attr := p_region.attribute_10;
    l_mapstyle          plugin_attr := p_region.attribute_11;
    l_address_item      plugin_attr := p_region.attribute_12;
    l_geolocate         plugin_attr := p_region.attribute_13;
    l_geoloc_zoom       plugin_attr := p_region.attribute_14;
    l_directions        plugin_attr := p_region.attribute_15;
    l_origin_item       plugin_attr := p_region.attribute_16;
    l_dest_item         plugin_attr := p_region.attribute_17;
    l_dirdist_item      plugin_attr := p_region.attribute_18;
    l_dirdur_item       plugin_attr := p_region.attribute_19;
    l_attribute1        plugin_attr := p_region.attribute_20;
    l_optimizewaypoints plugin_attr := p_region.attribute_21;
    l_maptype           plugin_attr := p_region.attribute_22;
    l_zoom_expr         plugin_attr := p_region.attribute_23;
    l_pan_expr          plugin_attr := p_region.attribute_24;
    l_gesture_handling  plugin_attr := p_region.attribute_25;
    
begin
    -- debug information will be included
    if apex_application.g_debug then
        apex_plugin_util.debug_region
            (p_plugin => p_plugin
            ,p_region => p_region
            ,p_is_printer_friendly => p_is_printer_friendly);
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
        ,p_directory      => 'https://maps.googleapis.com/maps/api/'
        ,p_skip_extension => true);

    apex_javascript.add_library
        (p_name                  => 'jk64reportmap'
        ,p_directory             => p_plugin.file_prefix
        ,p_check_to_add_minified => true);

    l_region := case
                when p_region.static_id is not null
                then p_region.static_id
                else 'R'||p_region.id
                end;
    
    if p_region.source is not null then

        l_data := get_markers
            (p_region     => p_region
            ,p_lat_min    => l_lat_min
            ,p_lat_max    => l_lat_max
            ,p_lng_min    => l_lng_min
            ,p_lng_max    => l_lng_max
            ,p_attribute1 => l_attribute1
            );
        
    end if;
    
    -- if sync item is set, include its position in the initial map extent
    if l_sync_item is not null then
        l_latlong := nvl(v(l_sync_item),l_latlong);
    end if;
    
    if l_latlong is not null then
        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,',')-1),g_num_format);
        l_lng := to_number(substr(l_latlong,instr(l_latlong,',')+1),g_num_format);
    end if;
    
    if l_lat is not null and l_data.count > 0 then
        set_map_extents
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
    
    l_maptype           := lower(l_maptype);
    l_click_zoom        := nvl(l_click_zoom,'null');
    l_pan_on_click      := case l_pan_on_click when 'N' then 'false' else 'true' end;
    l_optimizewaypoints := case when l_optimizewaypoints = 'Y' then 'true' else 'false' end;
    l_gesture_handling  := nvl(l_gesture_handling,'auto');
        
    l_script := '<script>
var opt_#REGION#=
{container:"map_#REGION#_container"
,regionId:"#REGION#"
,ajaxIdentifier:"' || apex_plugin.get_ajax_identifier || '"
,ajaxItems:"' || apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit) || '"
,maptype:"' || l_maptype || '"
,latlng:"' || l_latlong || '"
,markerZoom:' || l_click_zoom || '
,markerPan:' || l_pan_on_click || '
,icon:"' || l_markericon || '"
,idItem:"' || l_id_item || '"
,syncItem:"' || l_sync_item || '"
,distItem:"' || l_dist_item || '"
,geocodeItem:"' || l_geocode_item || '"
,country:"' || l_country || '"
,southwest:{' || latlng2ch(l_lat_min,l_lng_min) || '}
,northeast:{' || latlng2ch(l_lat_max,l_lng_max) || '}'
||   case when l_mapstyle is not null then '
,mapstyle:' || l_mapstyle
     end
|| '
,addressItem:"' || l_address_item || '"'
||   case when l_geolocate = 'Y' then '
,geolocate:true'
     ||   case when l_geoloc_zoom is not null then '
,geolocateZoom:' || l_geoloc_zoom
          end
     end
|| '
,noDataMessage:"' || p_region.no_data_found_message || '"'
||   case when p_region.source is not null then '
,expectData:true'
     end
||   case when l_directions is not null then '
,directions:"' || l_directions || '"'
     ||   case when l_origin_item is not null then '
,originItem:"' || l_origin_item || '"'
          end
     ||   case when l_dest_item is not null then '
,destItem:"' || l_dest_item || '"'
          end
     ||   case when l_dirdist_item is not null then '
,dirdistItem:"' || l_dirdist_item || '"'
          end
     ||   case when l_dirdur_item is not null then '
,dirdurItem:"' || l_dirdur_item || '"'
          end
     || '
,optimizeWaypoints:' || l_optimizewaypoints
     end
|| '
,zoom:' || l_zoom_enabled || '
,pan:' || l_pan_enabled || '
,gestureHandling:"' || l_gesture_handling || '"
};
function click_#REGION#(id){reportmap.click(opt_#REGION#,id);}
function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}
r_#REGION#(function(){
opt_#REGION#.mapdata = [';

    sys.htp.p(replace(l_script,'#REGION#',l_region));
    
    htp_arr(l_data);

    l_script := '];
reportmap.init(opt_#REGION#);
apex.jQuery("##REGION#").bind("apexrefresh", function(){reportmap.refresh(opt_#REGION#);});
});</script>
<div id="map_#REGION#_container" style="min-height:' || l_map_height || 'px"></div>';

    sys.htp.p(replace(l_script,'#REGION#',l_region));
  
    return l_result;
end render;

function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ) return apex_plugin.t_region_ajax_result is

    subtype plugin_attr is varchar2(32767);

    l_result apex_plugin.t_region_ajax_result;

    l_lat          number;
    l_lng          number;
    l_data         apex_application_global.vc_arr2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;

    -- Component attributes
    l_sync_item    plugin_attr := p_region.attribute_04;
    l_latlong      plugin_attr := p_region.attribute_06;
    l_attribute1   plugin_attr := p_region.attribute_20;

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
            ,p_attribute1 => l_attribute1
            );
        
    end if;
    
    -- if sync item is set, include its position in the initial map extent
    if l_sync_item is not null then
        l_latlong := nvl(v(l_sync_item),l_latlong);
    end if;
    
    if l_latlong is not null then
        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,',')-1),g_num_format);
        l_lng := to_number(substr(l_latlong,instr(l_latlong,',')+1),g_num_format);
    end if;
    
    if l_lat is not null and l_data.count > 0 then
        set_map_extents
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

    apex_debug.message('l_lat_min='||l_lat_min||' data='||l_data.count);
    
    sys.htp.p(
           '{"southwest":{'
        || latlng2ch(l_lat_min,l_lng_min)
        || '},"northeast":{'
        || latlng2ch(l_lat_max,l_lng_max)
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

end jk64reportmap_pkg;
/
show err