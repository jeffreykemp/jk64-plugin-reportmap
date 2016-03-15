set define off

create or replace package plugin as
function render_map (
    p_region in apex_plugin.t_region,
    p_plugin in apex_plugin.t_plugin,
    p_is_printer_friendly in boolean )
return apex_plugin.t_region_render_result;
function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin )
return apex_plugin.t_region_ajax_result
end plugin;
/
show errors

create or replace package body plugin as
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
      || TO_CHAR(lat, 'fm999.9999999999999999')
      || ',"lng":'
      || TO_CHAR(lng, 'fm999.9999999999999999');
END latlng2ch;

FUNCTION get_markers
    (p_region  IN APEX_PLUGIN.t_region
    ,p_lat_min IN OUT NUMBER
    ,p_lat_max IN OUT NUMBER
    ,p_lng_min IN OUT NUMBER
    ,p_lng_max IN OUT NUMBER
    ) RETURN VARCHAR2 IS

    l_markers_data       VARCHAR2(32767);
    l_lat                NUMBER;
    l_lng                NUMBER;
    l_icon               VARCHAR2(4000);
    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;

BEGIN

    l_column_value_list := APEX_PLUGIN_UTIL.get_data
        (p_sql_statement  => p_region.source
        ,p_min_columns    => 5
        ,p_max_columns    => 6
        ,p_component_name => p_region.name
        ,p_max_rows       => 1000);
  
    FOR i IN 1..l_column_value_list(1).count LOOP
  
        IF l_markers_data IS NOT NULL THEN
            l_markers_data := l_markers_data || ',';
        END IF;
        
        l_lat  := TO_NUMBER(l_column_value_list(1)(i));
        l_lng  := TO_NUMBER(l_column_value_list(2)(i));
        
        IF l_column_value_list.EXISTS(6) THEN
          l_icon := l_column_value_list(6)(i);
        END IF;
  
        l_markers_data := l_markers_data
          || '{"id":'   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),'"')
          || ',"name":' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i),'"')
          || ',"info":' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i),'"')
          || ','        || latlng2ch(l_lat,l_lng)
          || ',"icon":' || APEX_ESCAPE.js_literal(l_icon,'"')
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

    RETURN l_markers_data;
END get_markers;

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
    l_markers_data varchar2(32767);
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;
    l_ajax_items   varchar2(1000);
    l_js_params    varchar2(1000);

    -- Plugin attributes (application level)
    l_api_key       plugin_attr := p_plugin.attribute_01;

    -- Component attributes
    l_map_height    plugin_attr := p_region.attribute_01;
    l_id_item       plugin_attr := p_region.attribute_02;
    l_click_zoom    plugin_attr := p_region.attribute_03;    
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_markericon    plugin_attr := p_region.attribute_05;
    l_latlong       plugin_attr := p_region.attribute_06;
    l_dist_item     plugin_attr := p_region.attribute_07;
    l_sign_in       plugin_attr := p_region.attribute_08;
    l_geocode_item  plugin_attr := p_region.attribute_09;
    l_country       plugin_attr := p_region.attribute_10;
    
BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region
          ,p_is_printer_friendly => p_is_printer_friendly);
    END IF;

    IF l_api_key IS NULL THEN
        l_sign_in      := 'N';
        l_geocode_item := NULL;
    ELSE
        l_js_params := '?key=' || l_api_key;
        IF l_sign_in = 'Y' THEN
            l_js_params := l_js_params || '&'||'signed_in=true';
        END IF;
    END IF;

    APEX_JAVASCRIPT.add_library
      (p_name           => 'js' || l_js_params
      ,p_directory      => 'https://maps.googleapis.com/maps/api/'
      ,p_skip_extension => true);

    APEX_JAVASCRIPT.add_library
      (p_name           => 'jk64plugin.min'
      ,p_directory      => p_plugin.file_prefix);

    l_region := CASE
                WHEN p_region.static_id IS NOT NULL
                THEN p_region.static_id
                ELSE 'R'||p_region.id
                END;
    
    IF p_region.source IS NOT NULL THEN

      l_markers_data := get_markers
        (p_region  => p_region
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1));
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1));
    END IF;
    
    IF l_lat IS NOT NULL THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

    -- show entire map if no points to show
    ELSIF l_markers_data IS NULL THEN
      l_lat := 0;
      l_lng := 0;
      l_latlong := '0,0';
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;

    END IF;
    
    IF l_sync_item IS NOT NULL THEN
      l_ajax_items := '#' || l_sync_item;
    END IF;
    IF l_dist_item IS NOT NULL THEN
      IF l_ajax_items IS NOT NULL THEN
        l_ajax_items := l_ajax_items || ',';
      END IF;
      l_ajax_items := l_ajax_items || '#' || l_dist_item;
    END IF;
    
    l_script := '
var opt_#REGION# = {
   container:      "map_#REGION#_container"
  ,regionId:       "#REGION#"
  ,ajaxIdentifier: "'||APEX_PLUGIN.get_ajax_identifier||'"
  ,ajaxItems:      "'||l_ajax_items||'"
  ,latlng:         "'||l_latlong||'"
  ,markerZoom:     '||l_click_zoom||'
  ,icon:           "'||l_markericon||'"
  ,idItem:         "'||l_id_item||'"
  ,syncItem:       "'||l_sync_item||'"
  ,distItem:       "'||l_dist_item||'"
  ,geocodeItem:    "'||l_geocode_item||'"
  ,country:        "'||l_country||'"
  ,southwest:      {'||latlng2ch(l_lat_min,l_lng_min)||'}
  ,northeast:      {'||latlng2ch(l_lat_max,l_lng_max)||'}
};
function click_#REGION#(id) {
  jk64plugin_click(opt_#REGION#,id);
}
function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}
r_#REGION#(function(){
  opt_#REGION#.mapdata = ['||l_markers_data||'];
  jk64plugin_initMap(opt_#REGION#);
  apex.jQuery("#"+opt_#REGION#.regionId).bind("apexrefresh", function(){jk64plugin_refreshMap(opt_#REGION#);});
});';

    l_script := REPLACE(l_script,'#REGION#',l_region);
      
    sys.htp.p('<script>'||l_script||'</script>');
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
    l_markers_data VARCHAR2(32767);
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;

    -- Component attributes
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_latlong       plugin_attr := p_region.attribute_06;

BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region);
    END IF;

    IF p_region.source IS NOT NULL THEN

      l_markers_data := get_markers
        (p_region  => p_region
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1));
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1));
    END IF;
    
    IF l_lat IS NOT NULL THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

    -- show entire map if no points to show
    ELSIF l_markers_data IS NULL THEN
      l_lat := 0;
      l_lng := 0;
      l_latlong := '0,0';
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;

    END IF;

    SYS.OWA_UTIL.mime_header('text/plain', false);
    SYS.HTP.p('Cache-Control: no-cache');
    SYS.HTP.p('Pragma: no-cache');
    SYS.OWA_UTIL.http_header_close;
    
    SYS.HTP.p('{"southwest":{'
      || latlng2ch(l_lat_min,l_lng_min)
      || '},"northeast":{'
      || latlng2ch(l_lat_max,l_lng_max)
      || '},"mapdata":['
      || l_markers_data
      || ']}');

    RETURN l_result;
END ajax;
end plugin;
/
show errors