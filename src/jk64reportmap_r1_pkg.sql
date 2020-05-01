/**********************************************************
create or replace package jk64reportmap_r1_pkg as
-- jk64 ReportMap v1.2 May 2020

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
-- jk64 ReportMap v1.2 May 2020

-- format to use to convert a lat/lng number to string for passing via javascript
-- 0.0000001 is enough precision for the practical limit of commercial surveying, error up to +/- 11.132 mm at the equator
g_tochar_format            constant varchar2(100) := 'fm990.0999999';
g_coord_precision          constant number := 6;

-- if only one row is returned by the query, add this +/- to the latitude extents so it
-- shows the neighbourhood instead of zooming to the max
g_single_row_lat_margin    constant number := 0.005;

g_visualisation_pins       constant varchar2(10) := 'PINS'; -- default
g_visualisation_cluster    constant varchar2(10) := 'CLUSTER';
g_visualisation_spiderfier constant varchar2(10) := 'SPIDERFIER';
g_visualisation_heatmap    constant varchar2(10) := 'HEATMAP';
g_visualisation_directions constant varchar2(10) := 'DIRECTIONS';

g_maptype_roadmap          constant varchar2(10) := 'ROADMAP'; -- default
g_maptype_satellite	       constant varchar2(10) := 'SATELLITE';
g_maptype_hybrid           constant varchar2(10) := 'HYBRID';
g_maptype_terrain          constant varchar2(10) := 'TERRAIN';

g_travelmode_driving       constant varchar2(10) := 'DRIVING'; -- default
g_travelmode_walking       constant varchar2(10) := 'WALKING';
g_travelmode_bicycling     constant varchar2(10) := 'BICYCLING';
g_travelmode_transit       constant varchar2(10) := 'TRANSIT';

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
    p_lng := apex_plugin_util.get_attribute_as_number(substr(p_val,delim_pos+1), p_label || ' longitude');
end parse_latlng;

function valid_zoom_level (p_attr in varchar2, p_label in varchar2) return number is
    n number;
begin
    n := apex_plugin_util.get_attribute_as_number(p_attr, p_label);
    if not n between 0 and 23 then
        raise_application_error(-20000, p_label || ': must be in range 0..23 ("' || p_attr || '")');
    end if;
    return n;
end valid_zoom_level;

procedure get_lat_lng_attr
    (lat_val   in varchar2
    ,lng_val   in varchar2
    ,record_no in number
    ,p_lat     out number
    ,p_lng     out number
    ) is
begin
    p_lat := round(apex_plugin_util.get_attribute_as_number(lat_val,'Latitude (#'||record_no||')')
                  ,g_coord_precision);
    p_lng := round(apex_plugin_util.get_attribute_as_number(lng_val,'Longitude (#'||record_no||')')
                  ,g_coord_precision);
end get_lat_lng_attr;

function get_markers
    (p_plugin  in apex_plugin.t_plugin
    ,p_region  in apex_plugin.t_region
    ,p_lat_min in out number
    ,p_lat_max in out number
    ,p_lng_min in out number
    ,p_lng_max in out number
    ) return apex_application_global.vc_arr2 is
    
    l_data                  apex_application_global.vc_arr2;
    l_flex                  varchar2(32767);
    l_buf                   varchar2(32767);
    l_lat                   number;
    l_lng                   number;
    l_weight                number;     
    l_column_value_list     apex_plugin_util.t_column_value_list;
    l_max_rows              number; --p_plugin.attribute_07;
    l_visualisation         plugin_attr := p_region.attribute_02;
    l_escape_special_chars  plugin_attr := p_region.attribute_24;

    function flex_field (attr_no in number, i in number) return varchar2 is
      d varchar2(4000);
    begin
      if l_column_value_list.exists(attr_no+7) then
        d := l_column_value_list(attr_no+7)(i);
        if l_escape_special_chars='Y' then
          d := sys.htf.escape_sc(d);
        end if;
      end if;
      return apex_javascript.add_attribute('a'||attr_no,d);
    end flex_field;
    
    function varchar2_field (attr_no in number, i in number) return varchar2 is
      r varchar2(4000);
    begin
      if l_column_value_list.exists(attr_no) then
        r := sys.htf.escape_sc(l_column_value_list(attr_no)(i));
      end if;
      return r;
    end varchar2_field;
        
begin

    /*
       For most cases, column list is as follows:
    
       1.     lat,   - required
       2.     lng,   - required
       3.     name,  - required
       4.     id,    - required
       5.     info,  - optional
       6.     icon,  - optional
       7.     label  - optional
       8-17.  col01..col10 - optional flex fields
       
       If the "Heatmap" option is chosen, the column list is as follows:
       
       1.  lat,   - required
       2.  lng,   - required
       3.  weight - required
    
    */
    
    l_max_rows := apex_plugin_util.get_attribute_as_number(p_plugin.attribute_07, 'Maximum Records');
    
    if l_visualisation = g_visualisation_heatmap then

        l_column_value_list := apex_plugin_util.get_data
            (p_sql_statement  => p_region.source
            ,p_min_columns    => 3
            ,p_max_columns    => 3
            ,p_component_name => p_region.name
            ,p_max_rows       => l_max_rows);
  
        for i in 1..l_column_value_list(1).count loop
        
            get_lat_lng_attr
                (lat_val   => l_column_value_list(1)(i)
                ,lng_val   => l_column_value_list(2)(i)
                ,record_no => i
                ,p_lat     => l_lat
                ,p_lng     => l_lng);

            l_weight := nvl(round(
                          apex_plugin_util.get_attribute_as_number(l_column_value_list(3)(i),'Weight (#'||i||')')
                          ),1);
            
            -- minimise size of data to be sent by encoding it as an array of arrays
            l_buf := '[' || to_char(l_lat,g_tochar_format)
                  || ',' || to_char(l_lng,g_tochar_format)
                  || ',' || to_char(greatest(l_weight,1))
                  || ']';
            if i < 8 /*don't send the whole dataset to debug log*/ then
                apex_debug.message('#' || i || ': ' || l_buf);
            end if;
            l_data(nvl(l_data.last,0)+1) := l_buf;

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
            ,p_max_columns    => 17
            ,p_component_name => p_region.name
            ,p_max_rows       => l_max_rows);
    
        for i in 1..l_column_value_list(1).count loop

            get_lat_lng_attr
                (lat_val   => l_column_value_list(1)(i)
                ,lng_val   => l_column_value_list(2)(i)
                ,record_no => i
                ,p_lat     => l_lat
                ,p_lng     => l_lng);
        
            -- get flex fields, if any
            l_flex := null;
            for attr_no in 1..10 loop
                l_flex := l_flex || flex_field(attr_no,i);
            end loop;

            l_buf := apex_javascript.add_attribute('x',l_lat)
                  || apex_javascript.add_attribute('y',l_lng)
                  || apex_javascript.add_attribute('n',varchar2_field(3,i))
                  || apex_javascript.add_attribute('d',varchar2_field(4,i))
                  || apex_javascript.add_attribute('i',varchar2_field(5,i))
                  || apex_javascript.add_attribute('c',varchar2_field(6,i))
                  || apex_javascript.add_attribute('l',substr(varchar2_field(7,i),1,1))
                  || case when l_flex is not null then
                       '"f":{' || rtrim(l_flex,',') || '}'
                     end;
            
            if i < 8 /*don't send the whole dataset to debug log*/ then
                apex_debug.message('#' || i || ': ' || l_buf);
            end if;
            l_data(nvl(l_data.last,0)+1) := '{' || rtrim(l_buf,',') || '}';

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
    
    apex_debug.message('data.count='||l_data.count);

    -- handle edge case when there is exactly one row from query
    -- (otherwise the map zooms to maximum)
    if l_data.count = 1 then
        p_lat_min := p_lat_min - g_single_row_lat_margin;
        p_lat_max := p_lat_max + g_single_row_lat_margin;
    end if;
        
    return l_data;
end get_markers;

function render
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin
    ,p_is_printer_friendly in boolean
    ) return apex_plugin.t_region_render_result is
    
    l_result     apex_plugin.t_region_render_result;
    l_lat        number;
    l_lng        number;
    l_region_id  varchar2(100);
    l_lat_min    number;
    l_lat_max    number;
    l_lng_min    number;
    l_lng_max    number;

    -- Component settings
    l_api_key                      plugin_attr := p_plugin.attribute_01;
    l_no_address_results_msg       plugin_attr := p_plugin.attribute_02;
    l_directions_not_found_msg     plugin_attr := p_plugin.attribute_03;
    l_directions_zero_results_msg  plugin_attr := p_plugin.attribute_04;
    l_min_zoom                     number;      --p_plugin.attribute_05;
    l_max_zoom                     number;      --p_plugin.attribute_06;

    -- Plugin attributes
    l_map_height           plugin_attr := p_region.attribute_01;
    l_visualisation        plugin_attr := p_region.attribute_02;
    l_click_zoom_level     number;      --p_region.attribute_03;
    l_options              plugin_attr := p_region.attribute_04;
    l_initial_zoom_level   number;      --p_region.attribute_05;
    l_initial_center       plugin_attr := p_region.attribute_06;
    l_language             plugin_attr := p_region.attribute_08;
    l_region               plugin_attr := p_region.attribute_09;
    l_restrict_country     plugin_attr := p_region.attribute_10;
    l_mapstyle             plugin_attr := p_region.attribute_11;
    l_heatmap_dissipating  plugin_attr := p_region.attribute_12;
    l_heatmap_opacity      number;      --p_region.attribute_13;
    l_heatmap_radius       number;      --p_region.attribute_14;
    l_travel_mode          plugin_attr := p_region.attribute_15;
    l_drawing_modes        plugin_attr := p_region.attribute_16;
    l_optimizewaypoints    plugin_attr := p_region.attribute_21;
    l_maptype              plugin_attr := p_region.attribute_22;
    l_gesture_handling     plugin_attr := p_region.attribute_25;
    
    l_opt                  varchar2(32767);
    l_dragdrop_geojson     boolean;
    
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
    
    l_region_id := case
                   when p_region.static_id is not null
                   then p_region.static_id
                   else 'R'||p_region.id
                   end;
    apex_debug.message('map region: ' || l_region_id);

    l_min_zoom           := valid_zoom_level(p_plugin.attribute_05, 'Min. Zoom');
    l_max_zoom           := valid_zoom_level(p_plugin.attribute_06, 'Max. Zoom');
    l_click_zoom_level   := valid_zoom_level(p_region.attribute_03, 'Zoom Level on Click');
    l_initial_zoom_level := valid_zoom_level(p_region.attribute_05, 'Initial Zoom Level');
    l_heatmap_opacity    := apex_plugin_util.get_attribute_as_number(p_region.attribute_13, 'Heatmap Opacity');
    l_heatmap_radius     := apex_plugin_util.get_attribute_as_number(p_region.attribute_14, 'Heatmap Radius');
    l_dragdrop_geojson   := instr(':'||l_options||':',':GEOJSON_DRAGDROP:')>0;

    apex_javascript.add_library
        (p_name           => 'js?key=' || l_api_key
                          || case
                             when l_visualisation = g_visualisation_heatmap then
                               '&libraries=visualization'
                             when l_drawing_modes is not null then
                               '&libraries=drawing'
                             end
                          || case when l_language is not null then
                               '&language=' || l_language
                             end
                          || case when l_region is not null then
                               '&region=' || l_region
                             end
        ,p_directory      => 'https://maps.googleapis.com/maps/api/'
        ,p_skip_extension => true);
    
    apex_javascript.add_library
        (p_name                  => 'jk64reportmap_r1'
        ,p_directory             => p_plugin.file_prefix
        ,p_check_to_add_minified => true );

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
    
    if l_dragdrop_geojson then
        apex_css.add_file
            (p_name      => 'jk64reportmap_r1'
            ,p_directory => p_plugin.file_prefix);
    end if;
    
    if l_initial_center is not null then
        parse_latlng(l_initial_center, p_label=>'Initial Map Center', p_lat=>l_lat, p_lng=>l_lng);
    end if;
    
    if l_drawing_modes is not null then
        -- convert colon-delimited list "marker:polygon:polyline:rectangle:circle"
        -- to a javascript array "'marker','polygon','polyline','rectangle','circle'"
        l_drawing_modes := '''' || replace(l_drawing_modes,':',''',''') || '''';
    end if;
    
    -- use nullif to convert default values to null; this reduces the footprint of the generated code
    l_opt := '{'
      || apex_javascript.add_attribute('regionId', l_region_id)
      || apex_javascript.add_attribute('expectData', nullif(p_region.source is not null,true))
      || apex_javascript.add_attribute('visualisation', lower(nullif(l_visualisation,g_visualisation_pins)))
      || apex_javascript.add_attribute('mapType', lower(nullif(l_maptype,g_maptype_roadmap)))
      || apex_javascript.add_attribute('minZoom', nullif(l_min_zoom,1))
      || apex_javascript.add_attribute('maxZoom', l_max_zoom)
      || apex_javascript.add_attribute('initialZoom', nullif(l_initial_zoom_level,2))
      || case when l_lat!=0 or l_lng!=0 then
            '"initialCenter":' || latlng_literal(l_lat,l_lng) || ','
         end
      || apex_javascript.add_attribute('clickZoomLevel', l_click_zoom_level)
      || apex_javascript.add_attribute('isDraggable', nullif(instr(':'||l_options||':',':DRAGGABLE:')>0,false))
      || case when l_visualisation = g_visualisation_heatmap then
            apex_javascript.add_attribute('heatmapDissipating', nullif(l_heatmap_dissipating='Y',false))
         || apex_javascript.add_attribute('heatmapOpacity', nullif(l_heatmap_opacity,0.6))
         || apex_javascript.add_attribute('heatmapRadius', nullif(l_heatmap_radius,5))
         end
      || apex_javascript.add_attribute('panOnClick', nullif(instr(':'||l_options||':',':PAN_ON_CLICK:')>0,true))
      || apex_javascript.add_attribute('restrictCountry', l_restrict_country)
      || case when l_lat_min is not null and l_lng_min is not null
               and l_lat_max is not null and l_lng_max is not null then
              '"southwest":' || latlng_literal(l_lat_min,l_lng_min) || ','
           || '"northeast":' || latlng_literal(l_lat_max,l_lng_max) || ','
         end
      || case when l_mapstyle is not null then
         '"mapStyle":' || l_mapstyle || ','
         end
      || case when l_visualisation = g_visualisation_directions then
            apex_javascript.add_attribute('travelMode', nullif(l_travel_mode,g_travelmode_driving))
         || apex_javascript.add_attribute('optimizeWaypoints', nullif(l_optimizewaypoints='Y',false))
         end
      || apex_javascript.add_attribute('allowZoom', nullif(instr(':'||l_options||':',':ZOOM_ALLOWED:')>0,true))
      || apex_javascript.add_attribute('allowPan', nullif(instr(':'||l_options||':',':PAN_ALLOWED:')>0,true))
      || apex_javascript.add_attribute('gestureHandling', nullif(l_gesture_handling,'auto'))
      || case when p_region.init_javascript_code is not null then
         '"initFn":function(){' || p_region.init_javascript_code || '},'
         end
      || case when l_drawing_modes is not null then
         '"drawingModes":[' || l_drawing_modes || '],'
         end
      || apex_javascript.add_attribute('dragDropGeoJSON', nullif(l_dragdrop_geojson,false))
	  || apex_javascript.add_attribute('autoFitBounds', nullif(instr(':'||l_options||':',':DISABLEFITBOUNDS:')=0,true))
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

    l_result   apex_plugin.t_region_ajax_result;
    l_lat      number;
    l_lng      number;
    l_data     apex_application_global.vc_arr2;
    l_lat_min  number;
    l_lat_max  number;
    l_lng_min  number;
    l_lng_max  number;

    -- Plugin attributes
    l_initial_center plugin_attr := p_region.attribute_06;

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
            (p_plugin  => p_plugin
            ,p_region  => p_region
            ,p_lat_min => l_lat_min
            ,p_lat_max => l_lat_max
            ,p_lng_min => l_lng_min
            ,p_lng_max => l_lng_max
            );

    end if;
        
    if l_initial_center is not null then
        parse_latlng(l_initial_center, p_label=>'Initial Map Center', p_lat=>l_lat, p_lng=>l_lng);
    end if;
    
    if l_lat is not null and l_data.count > 0 then
        get_map_bounds
            (p_lat     => l_lat
            ,p_lng     => l_lng
            ,p_lat_min => l_lat_min
            ,p_lat_max => l_lat_max
            ,p_lng_min => l_lng_min
            ,p_lng_max => l_lng_max);
    end if;

    sys.owa_util.mime_header('text/plain', false);
    sys.htp.p('Cache-Control: no-cache');
    sys.htp.p('Pragma: no-cache');
    sys.owa_util.http_header_close;
    
    sys.htp.p('{'
      || case when l_lat_min is not null then
            '"southwest":' || latlng_literal(l_lat_min,l_lng_min) || ','
         || '"northeast":' || latlng_literal(l_lat_max,l_lng_max) || ','
         end
      || '"mapdata":[');

    for i in 1..l_data.count loop
        -- use prn to avoid downloading a whole lot of unnecessary \n characters
        sys.htp.prn(case when i>1 then ',' end || l_data(i));
    end loop;

    sys.htp.p(']}');

    apex_debug.message('ajax finished');
    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        sys.htp.p('{"error":' || apex_escape.js_literal(sqlerrm,'"') || '}');
        return l_result;
end ajax;

/**********************************************************
end jk64reportmap_r1_pkg;
**********************************************************/
