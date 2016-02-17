function render_map (
    p_region in apex_plugin.t_region,
    p_plugin in apex_plugin.t_plugin,
    p_is_printer_friendly in boolean )
return apex_plugin.t_region_render_result
as
    subtype plugin_attr is varchar2(32767);
    
    -- Variables
    l_result       apex_plugin.t_region_render_result;
    l_lat          NUMBER;
    l_lng          NUMBER;
    l_html         VARCHAR2(32767);
    l_markers_data VARCHAR2(32767);
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;
    l_southwest    VARCHAR2(200);
    l_northeast    VARCHAR2(200);

    l_column_value_list  apex_plugin_util.t_column_value_list;

    -- Component attributes
    l_map_height    plugin_attr := p_region.attribute_01;
    l_item_name     plugin_attr := p_region.attribute_02;
    l_click_zoom    plugin_attr := p_region.attribute_03;    
BEGIN
    -- debug information will be included
    if apex_application.g_debug then
        apex_plugin_util.debug_region (
            p_plugin => p_plugin,
            p_region => p_region,
            p_is_printer_friendly => p_is_printer_friendly);
    end if;
    
    IF p_region.source IS NOT NULL THEN

        l_column_value_list := apex_plugin_util.get_data
            (p_sql_statement  => p_region.source
            ,p_min_columns    => 5
            ,p_max_columns    => 5
            ,p_component_name => p_region.name
            ,p_max_rows       => 1000);

        FOR i IN 1..l_column_value_list(1).count LOOP
    
            IF l_markers_data IS NOT NULL THEN
                l_markers_data := l_markers_data || ',';
            END IF;
            
            l_lat  := TO_NUMBER(l_column_value_list(1)(i));
            l_lng  := TO_NUMBER(l_column_value_list(2)(i));
    
            l_markers_data := l_markers_data
              || '{id:'   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i))
              || ',name:' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i))
              || ',info:' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i))
              || ',lat:'  || APEX_ESCAPE.js_literal(l_lat)
              || ',lng:'  || APEX_ESCAPE.js_literal(l_lng)
              || '}';
        
            l_lat_min := LEAST   (NVL(l_lat_min, l_lat), l_lat);
            l_lat_max := GREATEST(NVL(l_lat_max, l_lat), l_lat);
            l_lng_min := LEAST   (NVL(l_lng_min, l_lng), l_lng);
            l_lng_max := GREATEST(NVL(l_lng_max, l_lng), l_lng);
          
        END LOOP;
        
    END IF;
    
    -- show entire map if no points to show
    IF l_markers_data IS NULL THEN
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;
    END IF;
    
    l_southwest := '{lat:'||TO_CHAR(l_lat_min)||',lng:'||TO_CHAR(l_lng_min)||'}';
    l_northeast := '{lat:'||TO_CHAR(l_lat_max)||',lng:'||TO_CHAR(l_lng_max)||'}';
    
    l_html := q'[
<script>
var map, iw, marker, mapdata;
function addMarker(map,pData) {
  marker = new google.maps.Marker({
                map: map,
                position: new google.maps.LatLng(pData.lat, pData.lng),
                title: pData.name
            });
 
  google.maps.event.addListener(marker, 'click', function () {
    if (iw) {
      iw.close();
    } else {
      iw = new google.maps.InfoWindow();
    }
    iw.setOptions({
       content: pData.info
      });
    iw.open(map, this);
    map.panTo(this.getPosition());
    if ("#CLICKZOOM#" != "") {
      map.setZoom(#CLICKZOOM#);
    }
    if ("#ITEMNAME#" !== "") {
      $s("#ITEMNAME#",pData.id);
    }
    apex.jQuery("##REGION_ID#").trigger("mapclick", {id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});
  });
}
function initMap() {
  var bounds = new google.maps.LatLngBounds(#SOUTHWEST#,#NORTHEAST#);
  var myOptions = {
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };
  map = new google.maps.Map(document.getElementById("#REGION_ID#_map"),myOptions);
  for (var i = 0; i < mapdata.length; i++) {
    addMarker(map,mapdata[i]);
  }
  map.fitBounds(bounds);
}
window.onload = function() {
  mapdata = [#MAPDATA#];
  initMap();
}
</script>
<div id="#REGION_ID#_map" style="min-height:#MAPHEIGHT#px"></div>]';

    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(l_html
      ,'#SOUTHWEST#', l_southwest)
      ,'#NORTHEAST#', l_northeast)
      ,'#MAPDATA#',   l_markers_data)
      ,'#MAPHEIGHT#', l_map_height)
      ,'#ITEMNAME#',  l_item_name)
      ,'#CLICKZOOM#', l_click_zoom)
      ,'#REGION_ID#', CASE
                      WHEN p_region.static_id IS NOT NULL
                      THEN p_region.static_id
                      ELSE 'R'||p_region.id
                      END);
      
    sys.htp.p(l_html);
  
    return l_result;
END render_map;    