create or replace package reportmap_pkg as
FUNCTION render_map
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ,p_is_printer_friendly IN BOOLEAN
    ) RETURN APEX_PLUGIN.t_region_render_result;
FUNCTION ajax
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ) RETURN APEX_PLUGIN.t_region_ajax_result;
end;
/
show err

create or replace package body reportmap_pkg as
-- jk64 ReportMap v0.9
g_num_format constant varchar2(100) := '99999999999999.999999999999999999999999999999';
g_tochar_format constant varchar2(100) := 'fm99999999999990.099999999999999999999999999999';

g_attr1_label constant varchar2(10) := 'LABEL';

PROCEDURE set_map_extents
    (p_lat     IN NUMBER
    ,p_lng     IN NUMBER
    ,p_lat_min IN OUT NUMBER
    ,p_lat_max IN OUT NUMBER
    ,p_lng_min IN OUT NUMBER
    ,p_lng_max IN OUT NUMBER
    ) IS
BEGIN
    p_lat_min := LEAST   (NVL(p_lat_min, p_lat), p_lat);
    p_lat_max := GREATEST(NVL(p_lat_max, p_lat), p_lat);
    p_lng_min := LEAST   (NVL(p_lng_min, p_lng), p_lng);
    p_lng_max := GREATEST(NVL(p_lng_max, p_lng), p_lng);
END set_map_extents;

FUNCTION latlng2ch (lat IN NUMBER, lng IN NUMBER) RETURN VARCHAR2 IS
BEGIN
  RETURN '"lat":'
      || TO_CHAR(lat, g_tochar_format)
      || ',"lng":'
      || TO_CHAR(lng, g_tochar_format);
END latlng2ch;

FUNCTION get_markers
    (p_region     IN APEX_PLUGIN.t_region
    ,p_lat_min    IN OUT NUMBER
    ,p_lat_max    IN OUT NUMBER
    ,p_lng_min    IN OUT NUMBER
    ,p_lng_max    IN OUT NUMBER
    ,p_attribute1 IN VARCHAR2
    ) RETURN APEX_APPLICATION_GLOBAL.VC_ARR2 IS
    
    l_data           APEX_APPLICATION_GLOBAL.VC_ARR2;
    l_lat            NUMBER;
    l_lng            NUMBER;
    l_info           VARCHAR2(4000);
    l_icon           VARCHAR2(4000);
    l_radius_km      NUMBER;
    l_circle_color   VARCHAR2(100);
    l_circle_transp  NUMBER;
    l_flex_fields    VARCHAR2(32767);
    l_marker_label   VARCHAR2(1);
     
    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;

BEGIN

    l_column_value_list := APEX_PLUGIN_UTIL.get_data
        (p_sql_statement  => p_region.source
        ,p_min_columns    => 4
        ,p_max_columns    => 19
        ,p_component_name => p_region.name
        ,p_max_rows       => p_region.fetched_rows);
    
    FOR i IN 1..l_column_value_list(1).count LOOP
    
        IF NOT l_column_value_list.EXISTS(1)
        OR NOT l_column_value_list.EXISTS(2)
        OR NOT l_column_value_list.EXISTS(3)
        OR NOT l_column_value_list.EXISTS(4) THEN
          RAISE_APPLICATION_ERROR(-20000, 'Report Map Query must have at least 4 columns (lat, lng, name, id)');
        END IF;
  
        l_lat  := TO_NUMBER(l_column_value_list(1)(i),g_num_format);
        l_lng  := TO_NUMBER(l_column_value_list(2)(i),g_num_format);
        
        -- default values if not supplied in query
        l_icon          := NULL;
        l_radius_km     := NULL;
        l_circle_color  := '#0000cc';
        l_circle_transp := 0.3;
        l_flex_fields   := NULL;
        l_marker_label  := NULL;
        
        IF l_column_value_list.EXISTS(5) THEN
          l_info := l_column_value_list(5)(i);
        IF l_column_value_list.EXISTS(6) THEN
          l_icon := l_column_value_list(6)(i);
        IF l_column_value_list.EXISTS(7) THEN
          l_radius_km := TO_NUMBER(l_column_value_list(7)(i),g_num_format);
        IF l_column_value_list.EXISTS(8) THEN
          l_circle_color := l_column_value_list(8)(i);
        IF l_column_value_list.EXISTS(9) THEN
          l_circle_transp := TO_NUMBER(l_column_value_list(9)(i),g_num_format);
        END IF; END IF; END IF; END IF; END IF;
        
        -- The remaining columns are up to 10 "flex" fields.
        -- If one of them is equal to a special attribute ("label"), the very next
        -- field is interpreted as the label.
        FOR j IN 10..19 LOOP
          IF l_column_value_list.EXISTS(j) THEN

            if j = 10 and UPPER(p_attribute1) = g_attr1_label then

              l_marker_label := substr(l_column_value_list(j)(i), 1, 1);

            else

              l_flex_fields := l_flex_fields
                            || ',"attr'
                            || TO_CHAR(j-9,'fm00')
                            || '":'
                            || APEX_ESCAPE.js_literal(l_column_value_list(j)(i),'"');

            end if;

          END IF;
        END LOOP;
		
        l_data(NVL(l_data.LAST,0)+1) :=
             '{"id":'  || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),'"')
          || ',"name":'|| APEX_ESCAPE.js_literal(l_column_value_list(3)(i),'"')
          || ','       || latlng2ch(l_lat,l_lng)
          || CASE WHEN l_info IS NOT NULL THEN
             ',"info":'|| APEX_ESCAPE.js_literal(l_info,'"')
             END
          || ',"icon":'|| APEX_ESCAPE.js_literal(l_icon,'"')
          || ',"label":'|| APEX_ESCAPE.js_literal(l_marker_label,'"') 
          || CASE WHEN l_radius_km IS NOT NULL THEN
             ',"rad":' || TO_CHAR(l_radius_km,g_tochar_format)
		      || ',"col":' || APEX_ESCAPE.js_literal(l_circle_color,'"')
		      ||   CASE WHEN l_circle_transp IS NOT NULL THEN
             ',"trns":'|| TO_CHAR(l_circle_transp,'fm990.099')
               END
             END
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
      
    END LOOP;

    RETURN l_data;
END get_markers;

PROCEDURE htp_arr (arr IN APEX_APPLICATION_GLOBAL.VC_ARR2) IS
BEGIN
    FOR i IN 1..arr.COUNT LOOP
        -- use prn to avoid loading a whole lot of unnecessary \n characters
        sys.htp.prn(CASE WHEN i > 1 THEN ',' END || arr(i));
    END LOOP;
END htp_arr;

FUNCTION render_map
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ,p_is_printer_friendly IN BOOLEAN
    ) RETURN APEX_PLUGIN.t_region_render_result IS

    SUBTYPE plugin_attr is VARCHAR2(32767);
    
    l_result       APEX_PLUGIN.t_region_render_result;

    l_lat          number;
    l_lng          number;
    l_region       varchar2(100);
    l_script       varchar2(32767);
    l_data         APEX_APPLICATION_GLOBAL.VC_ARR2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;
    l_js_params    varchar2(1000);
    l_zoom_enabled varchar2(1000) := 'true';
    l_pan_enabled  varchar2(1000) := 'true';

    -- Plugin attributes (application level)
    l_api_key       plugin_attr := p_plugin.attribute_01;

    -- Component attributes
    l_map_height        plugin_attr := p_region.attribute_01;
    l_id_item           plugin_attr := p_region.attribute_02;
    l_click_zoom        plugin_attr := p_region.attribute_03;    
    l_sync_item         plugin_attr := p_region.attribute_04;
    l_markericon        plugin_attr := p_region.attribute_05;
    l_latlong           plugin_attr := p_region.attribute_06;
    l_dist_item         plugin_attr := p_region.attribute_07;
    --l_unused            plugin_attr := p_region.attribute_08; --attribute not used in this version
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
    
BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region
          ,p_is_printer_friendly => p_is_printer_friendly);
    END IF;

    IF l_api_key IS NULL THEN
        -- these features require a Google API Key to work
        l_geocode_item := NULL;
        l_country      := NULL;
        l_address_item := NULL;
        l_directions   := NULL;
        l_origin_item  := NULL;
        l_dest_item    := NULL;
        l_dirdist_item := NULL;
        l_dirdur_item  := NULL;
    ELSE
        l_js_params := '?key=' || l_api_key;
    END IF;
    
    if l_zoom_expr is not null then
      l_zoom_enabled := apex_plugin_util.get_plsql_expression_result (
        'case when (' || l_zoom_expr
        || ') then ''true'' else ''false'' end');
      if l_zoom_enabled not in ('true','false') then
        raise_application_error(-20000, 'Zoom attribute must evaluate to true or false.');
      end if;
    end if;

    if l_pan_expr is not null then
      l_pan_enabled := apex_plugin_util.get_plsql_expression_result (
        'case when (' || l_pan_expr
        || ') then ''true'' else ''false'' end');
      if l_pan_enabled not in ('true','false') then
        raise_application_error(-20000, 'Pan attribute must evaluate to true or false.');
      end if;
    end if;

    APEX_JAVASCRIPT.add_library
      (p_name           => 'js' || l_js_params
      ,p_directory      => 'https://maps.googleapis.com/maps/api/'
      ,p_skip_extension => true);

    APEX_JAVASCRIPT.add_library
      (p_name                  => 'jk64reportmap'
      ,p_directory             => p_plugin.file_prefix
      ,p_check_to_add_minified => TRUE);

    l_region := CASE
                WHEN p_region.static_id IS NOT NULL
                THEN p_region.static_id
                ELSE 'R'||p_region.id
                END;
    
    IF p_region.source IS NOT NULL THEN

      l_data := get_markers
        (p_region     => p_region
        ,p_lat_min    => l_lat_min
        ,p_lat_max    => l_lat_max
        ,p_lng_min    => l_lng_min
        ,p_lng_max    => l_lng_max
        ,p_attribute1 => l_attribute1
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1),g_num_format);
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1),g_num_format);
    END IF;
    
    IF l_lat IS NOT NULL AND l_data.COUNT > 0 THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

    ELSIF l_data.COUNT = 0 AND l_lat IS NOT NULL THEN
      l_lat_min := GREATEST(l_lat - 10, -80);
      l_lat_max := LEAST(l_lat + 10, 80);
      l_lng_min := GREATEST(l_lng - 10, -180);
      l_lng_max := LEAST(l_lng + 10, 180);

    -- show entire map if no points to show
    ELSIF l_data.COUNT = 0 THEN
      l_latlong := '0,0';
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;

    END IF;
        
    l_script := '<script>
var opt_#REGION#=
{container:"map_#REGION#_container"
,regionId:"#REGION#"
,ajaxIdentifier:"'||APEX_PLUGIN.get_ajax_identifier||'"
,ajaxItems:"'||APEX_PLUGIN_UTIL.page_item_names_to_jquery(p_region.ajax_items_to_submit)||'"
,maptype:"'||lower(l_maptype)||'"
,latlng:"'||l_latlong||'"
,markerZoom:'||NVL(l_click_zoom,'null')||'
,icon:"'||l_markericon||'"
,idItem:"'||l_id_item||'"
,syncItem:"'||l_sync_item||'"
,distItem:"'||l_dist_item||'"
,geocodeItem:"'||l_geocode_item||'"
,country:"'||l_country||'"
,southwest:{'||latlng2ch(l_lat_min,l_lng_min)||'}
,northeast:{'||latlng2ch(l_lat_max,l_lng_max)||'}'||
  CASE WHEN l_mapstyle IS NOT NULL THEN '
,mapstyle:'||l_mapstyle END || '
,addressItem:"'||l_address_item||'"'||
  CASE WHEN l_geolocate = 'Y' THEN '
,geolocate:true' ||
    CASE WHEN l_geoloc_zoom IS NOT NULL THEN '
,geolocateZoom:'||l_geoloc_zoom
    END
  END || '
,noDataMessage:"'||p_region.no_data_found_message||'"'||
  CASE WHEN p_region.source IS NOT NULL THEN '
,expectData:true'
  END ||
  CASE WHEN l_directions IS NOT NULL THEN '
,directions:"' || l_directions || '"' ||
    CASE WHEN l_origin_item IS NOT NULL THEN '
,originItem:"' || l_origin_item || '"'
    END ||
    CASE WHEN l_dest_item IS NOT NULL THEN '
,destItem:"' || l_dest_item || '"'
    END ||
    CASE WHEN l_dirdist_item IS NOT NULL THEN '
,dirdistItem:"' || l_dirdist_item || '"'
    END ||
    CASE WHEN l_dirdur_item IS NOT NULL THEN '
,dirdurItem:"' || l_dirdur_item || '"'
    END || '
,optimizeWaypoints:' || case when l_optimizewaypoints = 'Y' then 'true' else 'false' end
  END || '
  ,zoom: '||l_zoom_enabled||'
  ,pan: '||l_pan_enabled||'
  ,gestureHandling: "'||nvl(l_gesture_handling,'auto')||'"
};
function click_#REGION#(id){jk64reportmap_click(opt_#REGION#,id);}
function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}
r_#REGION#(function(){
opt_#REGION#.mapdata = [';
    sys.htp.p(REPLACE(l_script,'#REGION#',l_region));
    htp_arr(l_data);
    l_script := '];
jk64reportmap_initMap(opt_#REGION#);
apex.jQuery("##REGION#").bind("apexrefresh", function(){jk64reportmap_refreshMap(opt_#REGION#);});
});</script>';
    sys.htp.p(REPLACE(l_script,'#REGION#',l_region));
    sys.htp.p('<div id="map_'||l_region||'_container" style="min-height:'||l_map_height||'px"></div>');
  
    RETURN l_result;
END render_map;

FUNCTION ajax
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ) RETURN APEX_PLUGIN.t_region_ajax_result IS

    SUBTYPE plugin_attr is VARCHAR2(32767);

    l_result APEX_PLUGIN.t_region_ajax_result;

    l_lat          NUMBER;
    l_lng          NUMBER;
    l_data         APEX_APPLICATION_GLOBAL.VC_ARR2;
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;

    -- Component attributes
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_latlong       plugin_attr := p_region.attribute_06;
    l_attribute1    plugin_attr := p_region.attribute_20;

BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region);
    END IF;
    APEX_DEBUG.message('ajax');

    IF p_region.source IS NOT NULL THEN

      l_data := get_markers
        (p_region     => p_region
        ,p_lat_min    => l_lat_min
        ,p_lat_max    => l_lat_max
        ,p_lng_min    => l_lng_min
        ,p_lng_max    => l_lng_max
        ,p_attribute1 => l_attribute1
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1),g_num_format);
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1),g_num_format);
    END IF;
    
    IF l_lat IS NOT NULL AND l_data.COUNT > 0 THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

    ELSIF l_data.COUNT = 0 AND l_lat IS NOT NULL THEN
      l_lat_min := GREATEST(l_lat - 10, -180);
      l_lat_max := LEAST(l_lat + 10, 80);
      l_lng_min := GREATEST(l_lng - 10, -180);
      l_lng_max := LEAST(l_lng + 10, 180);

    -- show entire map if no points to show
    ELSIF l_data.COUNT = 0 THEN
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;

    END IF;

    sys.owa_util.mime_header('text/plain', false);
    sys.htp.p('Cache-Control: no-cache');
    sys.htp.p('Pragma: no-cache');
    sys.owa_util.http_header_close;

    APEX_DEBUG.message('l_lat_min='||l_lat_min||' data='||l_data.COUNT);
    
    sys.htp.p('{"southwest":{'
      || latlng2ch(l_lat_min,l_lng_min)
      || '},"northeast":{'
      || latlng2ch(l_lat_max,l_lng_max)
      || '},"mapdata":[');
    htp_arr(l_data);
    sys.htp.p(']}');

    APEX_DEBUG.message('ajax finished');
    RETURN l_result;
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.error(SQLERRM);
        sys.htp.p('{"error":"'||sqlerrm||'"}');
END ajax;

end reportmap_pkg;
/
show err