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

-- format to use to convert a string to a number
g_num_format constant varchar2(100) := '99999999999999.999999999999999999999999999999';

-- format to use to convert a lat/lng number to string for passing via javascript
-- 0.0000001 is enough precision for the practical limit of commercial surveying, error up to +/- 11.132 mm at the equator
g_tochar_format constant varchar2(100) := 'fm990.0999999';

-- if only one row is returned by the query, add this +/- to the latitude extents so it
-- shows the neighbourhood instead of zooming to the max
g_single_row_lat_margin constant number := 0.005;

g_visualisation_pins       constant varchar2(10) := 'PINS';
g_visualisation_cluster    constant varchar2(10) := 'CLUSTER';
g_visualisation_heatmap    constant varchar2(10) := 'HEATMAP';
g_visualisation_directions constant varchar2(10) := 'DIRECTIONS';

g_maptype_roadmap    constant varchar2(10) := 'ROADMAP';
g_maptype_satellite	 constant varchar2(10) := 'SATELLITE';
g_maptype_hybrid	   constant varchar2(10) := 'HYBRID';
g_maptype_terrain	   constant varchar2(10) := 'TERRAIN';

g_travelmode_driving constant varchar2(10) := 'DRIVING';

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
    (p_region  in apex_plugin.t_region
    ,p_lat_min in out number
    ,p_lat_max in out number
    ,p_lng_min in out number
    ,p_lng_max in out number
    ) return apex_application_global.vc_arr2 is
    
    l_data           apex_application_global.vc_arr2;
    l_lat            number;
    l_lng            number;
    l_info           varchar2(4000);
    l_icon           varchar2(4000);
    l_marker_label   varchar2(1);
    l_weight         number;
     
    l_column_value_list apex_plugin_util.t_column_value_list;
    l_visualisation     plugin_attr := p_region.attribute_02;

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
    
    if l_visualisation = g_visualisation_heatmap then

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
                   '{"x":' || to_char(l_lat, g_tochar_format)
                || ',"y":' || to_char(l_lng, g_tochar_format)
                || ',"d":' || to_char(l_weight, 'fm9999990')
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
                   '{"d":'  || apex_escape.js_literal(l_column_value_list(4)(i),'"')
                || ',"n":' || apex_escape.js_literal(l_column_value_list(3)(i),'"')
                || ',"x":' || to_char(l_lat,g_tochar_format)
                || ',"y":' || to_char(l_lng,g_tochar_format)
                || case when l_info is not null then
                   ',"i":' || apex_escape.js_literal(l_info,'"')
                   end
                || ',"c":' || apex_escape.js_literal(l_icon,'"')
                || ',"l":' || apex_escape.js_literal(l_marker_label,'"')
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

procedure val_integer (p_val in varchar2, p_min in number, p_max in number, p_label in varchar2) is
    n number;
begin
    n := to_number(p_val);
    if not p_val between p_min and p_max then
        raise_application_error(-20000, p_label || ': must be in range 0..23 ("' || p_val || '")');
    end if;
exception
    when value_error then
        raise_application_error(-20000, p_label || ': invalid number ("' || p_val || '")');
end val_integer;

procedure parse_latlng (p_val in varchar2, p_lat out number, p_lng out number) is
begin
    p_lat := to_number(substr(p_val,1,instr(p_val,',')-1),g_num_format);
    p_lng := to_number(substr(p_val,instr(p_val,',')+1),g_num_format);
end parse_latlng;

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result is
    
    l_result       apex_plugin.t_region_render_result;

    l_lat          number;
    l_lng          number;
    l_region_id    varchar2(100);
    l_data         apex_application_global.vc_arr2;
    l_lat_min      number;
    l_lat_max      number;
    l_lng_min      number;
    l_lng_max      number;

    -- Plugin attributes (application level)
    l_api_key                      plugin_attr := p_plugin.attribute_01;
    l_no_address_results_msg       plugin_attr := p_plugin.attribute_02;
    l_directions_not_found_msg     plugin_attr := p_plugin.attribute_03;
    l_directions_zero_results_msg  plugin_attr := p_plugin.attribute_04;

    -- Component attributes
    l_map_height        plugin_attr := p_region.attribute_01;
    l_visualisation     plugin_attr := p_region.attribute_02;
    l_click_zoom_level  plugin_attr := p_region.attribute_03;
    l_options           plugin_attr := p_region.attribute_04;
    l_default_latlng    plugin_attr := p_region.attribute_06;
    l_restrict_country  plugin_attr := p_region.attribute_10;
    l_mapstyle          plugin_attr := p_region.attribute_11;
    l_travel_mode       plugin_attr := p_region.attribute_15;
    l_origin_item       plugin_attr := p_region.attribute_16;
    l_dest_item         plugin_attr := p_region.attribute_17;
    l_optimizewaypoints plugin_attr := p_region.attribute_21;
    l_maptype           plugin_attr := p_region.attribute_22;
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
    
    val_integer(l_click_zoom_level, p_min=>0, p_max=>23, p_label=>'Zoom Level on Click');
    
    apex_javascript.add_library
        (p_name           => 'js?key=' || l_api_key
                          || case when l_visualisation = g_visualisation_heatmap then
                               '&libraries=visualization'
                             end
        ,p_directory      => 'https://maps.googleapis.com/maps/api/'
        ,p_skip_extension => true);
    
    apex_javascript.add_library
        (p_name                  => 'jk64reportmap'
        ,p_directory             => p_plugin.file_prefix
        ,p_check_to_add_minified => true);

    if l_visualisation = g_visualisation_cluster then
        apex_javascript.add_library
            (p_name                  => 'markerclusterer'
            ,p_directory             => p_plugin.file_prefix
            ,p_check_to_add_minified => true);
    end if;

    l_region_id := case
                   when p_region.static_id is not null
                   then p_region.static_id
                   else 'R'||p_region.id
                   end;
    apex_debug.message('map region: ' || l_region_id);
    
--    if p_region.source is not null then
--
--        l_data := get_markers
--            (p_region  => p_region
--            ,p_lat_min => l_lat_min
--            ,p_lat_max => l_lat_max
--            ,p_lng_min => l_lng_min
--            ,p_lng_max => l_lng_max
--            );
--        
--    end if;
    
    if l_default_latlng is not null then
        parse_latlng(l_default_latlng, p_lat=>l_lat, p_lng=>l_lng);
    end if;
    
--    if l_lat is not null and l_data.count > 0 then
--
--        get_map_bounds
--            (p_lat     => l_lat
--            ,p_lng     => l_lng
--            ,p_lat_min => l_lat_min
--            ,p_lat_max => l_lat_max
--            ,p_lng_min => l_lng_min
--            ,p_lng_max => l_lng_max
--            );
--
--    elsif l_data.count = 0 and l_lat is not null then
      if l_lat is not null then

          l_lat_min := greatest(l_lat - 10, -80);
          l_lat_max := least(l_lat + 10, 80);
          l_lng_min := greatest(l_lng - 10, -180);
          l_lng_max := least(l_lng + 10, 180);

--    -- show entire map if no points to show
--    elsif l_data.count = 0 then
--
--        l_latlong := '0,0';
--        l_lat_min := -90;
--        l_lat_max := 90;
--        l_lng_min := -180;
--        l_lng_max := 180;

    end if;
    
    l_opt := 'regionId:"' || l_region_id || '"'
          || ',ajaxIdentifier:"' || apex_plugin.get_ajax_identifier || '"'
          || ',ajaxItems:"' || apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit) || '"'
          || ',pluginFilePrefix:"' || p_plugin.file_prefix || '"';
    if p_region.source is null then
        l_opt := l_opt || ',expectData:false';
    end if;
    if nvl(l_visualisation,g_visualisation_pins) != g_visualisation_pins then
        l_opt := l_opt || ',visualisation:' || apex_escape.js_literal(lower(l_visualisation),'"');
    end if;
    if nvl(l_maptype,g_maptype_roadmap) != g_maptype_roadmap then
        l_opt := l_opt || ',mapType:' || apex_escape.js_literal(lower(l_maptype),'"');
    end if;
    if l_default_latlng is not null then
        l_opt := l_opt || ',defaultLatLng:"' || l_default_latlng || '"';
    end if;
    if l_click_zoom_level is not null then
        l_opt := l_opt || ',clickZoomLevel:' || l_click_zoom_level;
    end if;
    if instr(':'||l_options||':',':DRAGGABLE:')>0 then
        l_opt := l_opt || ',isDraggable:true';
    end if;
--    if l_visualisation = g_visualisation_heatmap then --TODO: make these options plugin attributes?
--        l_opt := l_opt
--             || ',heatmapDissipating:false'
--             || ',heatmapOpacity:0.6'
--             || ',heatmapRadius:5';
--    end if;
    if instr(':'||l_options||':',':PAN_ON_CLICK:')=0 then
        l_opt := l_opt || ',panOnClick:false';
    end if;
    if l_restrict_country is not null then
        l_opt := l_opt || ',l_search_country:' || apex_escape.js_literal(l_restrict_country,'"');
    end if;
    if l_lat_min is not null and l_lng_min is not null and l_lat_max is not null and l_lng_max is not null then
        l_opt := l_opt
              || ',southwest:{' || latlng_to_char(l_lat_min,l_lng_min) || '}'
              || ',northeast:{' || latlng_to_char(l_lat_max,l_lng_max) || '}';
    end if;
    if l_mapstyle is not null then
        l_opt := l_opt || ',mapStyle:' || l_mapstyle;
    end if;
    if l_visualisation = g_visualisation_directions then
        if nvl(l_travel_mode,g_travelmode_driving) != g_travelmode_driving then
            l_opt := l_opt || ',travelMode:' || apex_escape.js_literal(l_travel_mode,'"');
        end if;
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
    if instr(':'||l_options||':',':ZOOM_ALLOWED:')=0 then
        l_opt := l_opt || ',allowZoom:false';
    end if;
    if instr(':'||l_options||':',':PAN_ALLOWED:')=0 then    
        l_opt := l_opt || ',allowPan:false';
    end if;
    if l_gesture_handling is not null then
        l_opt := l_opt || ',gestureHandling:' || apex_escape.js_literal(l_gesture_handling,'"');
    end if;
    if p_region.no_data_found_message is not null then
        l_opt := l_opt || ',noDataMessage:' || apex_escape.js_literal(p_region.no_data_found_message,'"');
    end if;
    if l_no_address_results_msg is not null then
        l_opt := l_opt || ',noDataMessage:' || apex_escape.js_literal(l_no_address_results_msg,'"');
    end if;
    if l_directions_not_found_msg is not null then
        l_opt := l_opt || ',directionsNotFound:' || apex_escape.js_literal(l_directions_not_found_msg,'"');
    end if;
    if l_directions_zero_results_msg is not null then
        l_opt := l_opt || ',directionsZeroResults:' || apex_escape.js_literal(l_directions_zero_results_msg,'"');
    end if;
        
    -- we don't want the init to run until after the page is loaded including all resources; the r_ function
    -- method here waits until the document is ready before running the jquery plugin initialisation
    sys.htp.p('<script>');
    sys.htp.p('function r_' || l_region_id || '(f){/in/.test(document.readyState)?setTimeout("r_' || l_region_id || '("+f+")",9):f()}');
    sys.htp.p('r_' || l_region_id || '(function(){');
    sys.htp.p('$("#map_' || l_region_id || '").reportmap({');
    sys.htp.p(l_opt);
    sys.htp.p('});');
    if p_region.init_javascript_code is not null then
      -- make "this" point to the reportmap object; this.map will be the google map object
      sys.htp.p('var m=$("#map_' || l_region_id || '").reportmap("instance");');
      sys.htp.p('function i_' || l_region_id || '(){apex.debug("running init_javascript_code...");'
      || p_region.init_javascript_code
      || '};m.init=i_' || l_region_id || ';m.init();');
    end if;
    -- map apex refresh event to the jquery plugin refresh
    sys.htp.p('apex.jQuery("#' || l_region_id || '").bind("apexrefresh",function(){$("#map_' || l_region_id || '").reportmap("refresh");});');
    sys.htp.p('});</script>');
    sys.htp.p('<div id="map_' || l_region_id || '" style="min-height:' || l_map_height || 'px"></div>');
    
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
    l_visualisation     plugin_attr := p_region.attribute_02;
    l_default_latlng    plugin_attr := p_region.attribute_06;

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
            (p_region  => p_region
            ,p_lat_min => l_lat_min
            ,p_lat_max => l_lat_max
            ,p_lng_min => l_lng_min
            ,p_lng_max => l_lng_max
            );
        
        apex_debug.message('data.count='||l_data.count);

    end if;
        
    if l_default_latlng is not null then
        parse_latlng(l_default_latlng, p_lat=>l_lat, p_lng=>l_lng);
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