prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_180200 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2018.05.24'
,p_release=>'18.2.0.00.12'
,p_default_workspace_id=>20749515040658038
,p_default_application_id=>15181
,p_default_owner=>'SAMPLE'
);
end;
/
prompt --application/shared_components/plugins/region_type/com_jk64_report_google_map_r1
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(33032154349766695)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP_R1'
,p_display_name=>'JK64 Report Google Map R1'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'/**********************************************************',
'create or replace package jk64reportmap_r1_pkg as',
'-- jk64 ReportMap v1.0.1 Jul 2019',
'',
'function render',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ,p_is_printer_friendly in boolean',
'    ) return apex_plugin.t_region_render_result;',
'',
'function ajax',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ) return apex_plugin.t_region_ajax_result;',
'',
'end jk64reportmap_r1_pkg;',
'/',
'',
'create or replace package body jk64reportmap_r1_pkg as',
'**********************************************************/',
'-- jk64 ReportMap v1.0.1 Jul 2019',
'',
'-- format to use to convert a lat/lng number to string for passing via javascript',
'-- 0.0000001 is enough precision for the practical limit of commercial surveying, error up to +/- 11.132 mm at the equator',
'g_tochar_format            constant varchar2(100) := ''fm990.0999999'';',
'g_coord_precision          constant number := 6;',
'',
'-- if only one row is returned by the query, add this +/- to the latitude extents so it',
'-- shows the neighbourhood instead of zooming to the max',
'g_single_row_lat_margin    constant number := 0.005;',
'',
'g_visualisation_pins       constant varchar2(10) := ''PINS''; -- default',
'g_visualisation_cluster    constant varchar2(10) := ''CLUSTER'';',
'g_visualisation_heatmap    constant varchar2(10) := ''HEATMAP'';',
'g_visualisation_directions constant varchar2(10) := ''DIRECTIONS'';',
'',
'g_maptype_roadmap          constant varchar2(10) := ''ROADMAP''; -- default',
'g_maptype_satellite	       constant varchar2(10) := ''SATELLITE'';',
'g_maptype_hybrid	         constant varchar2(10) := ''HYBRID'';',
'g_maptype_terrain	         constant varchar2(10) := ''TERRAIN'';',
'',
'g_travelmode_driving       constant varchar2(10) := ''DRIVING''; -- default',
'g_travelmode_walking       constant varchar2(10) := ''WALKING'';',
'g_travelmode_bicycling     constant varchar2(10) := ''BICYCLING'';',
'g_travelmode_transit       constant varchar2(10) := ''TRANSIT'';',
'',
'subtype plugin_attr is varchar2(32767);',
'',
'procedure get_map_bounds',
'    (p_lat     in number',
'    ,p_lng     in number',
'    ,p_lat_min in out number',
'    ,p_lat_max in out number',
'    ,p_lng_min in out number',
'    ,p_lng_max in out number',
'    ) is',
'begin',
'    p_lat_min := least   (nvl(p_lat_min, p_lat), p_lat);',
'    p_lat_max := greatest(nvl(p_lat_max, p_lat), p_lat);',
'    p_lng_min := least   (nvl(p_lng_min, p_lng), p_lng);',
'    p_lng_max := greatest(nvl(p_lng_max, p_lng), p_lng);',
'end get_map_bounds;',
'',
'function latlng_literal (lat in number, lng in number) return varchar2 is',
'begin',
'    return case when lat is not null and lng is not null then',
'        ''{''',
'        || apex_javascript.add_attribute(''lat'', round(lat,g_coord_precision))',
'        || apex_javascript.add_attribute(''lng'', round(lng,g_coord_precision)',
'           , false, false)',
'        || ''}''',
'        end;',
'end latlng_literal;',
'',
'procedure parse_latlng (p_val in varchar2, p_label in varchar2, p_lat out number, p_lng out number) is',
'    delim_pos varchar2(1);',
'begin',
'    -- allow space as the delimiter; this should be used in locales which use comma (,) as decimal separator',
'    if instr(trim(p_val),'' '') > 0 then',
'        delim_pos := instr(p_val,'' '');',
'    else',
'        delim_pos := instr(p_val,'','');',
'    end if;',
'    p_lat := apex_plugin_util.get_attribute_as_number(substr(p_val,1,delim_pos-1), p_label || '' latitude'');',
'    p_lng := apex_plugin_util.get_attribute_as_number(substr(p_val,delim_pos+1), p_label || '' longitude'');',
'end parse_latlng;',
'',
'function get_markers',
'    (p_plugin  in apex_plugin.t_plugin',
'    ,p_region  in apex_plugin.t_region',
'    ,p_lat_min in out number',
'    ,p_lat_max in out number',
'    ,p_lng_min in out number',
'    ,p_lng_max in out number',
'    ) return apex_application_global.vc_arr2 is',
'    ',
'    l_data                  apex_application_global.vc_arr2;',
'    l_flex                  varchar2(32767);',
'    l_buf                   varchar2(32767);',
'    l_lat                   number;',
'    l_lng                   number;',
'    l_weight                number;     ',
'    l_column_value_list     apex_plugin_util.t_column_value_list;',
'    l_max_rows              number; --p_plugin.attribute_07;',
'    l_visualisation         plugin_attr := p_region.attribute_02;',
'    l_escape_special_chars  plugin_attr := p_region.attribute_24;',
'    ',
'    function flex_field (attr_no in number, i in number) return varchar2 is',
'      d varchar2(4000);',
'    begin',
'      if l_column_value_list.exists(attr_no+7) then',
'        d := l_column_value_list(attr_no+7)(i);',
'        if l_escape_special_chars=''Y'' then',
'          d := sys.htf.escape_sc(d);',
'        end if;',
'      end if;',
'      return apex_javascript.add_attribute(''a''||attr_no,d);',
'    end flex_field;',
'  ',
'    function varchar2_field (attr_no in number, i in number) return varchar2 is',
'      r varchar2(4000);',
'    begin',
'      if l_column_value_list.exists(attr_no) then',
'        r := sys.htf.escape_sc(l_column_value_list(attr_no)(i));',
'      end if;',
'      return r;',
'    end varchar2_field;',
'',
'begin',
'',
'    /*',
'       For most cases, column list is as follows:',
'    ',
'       1.     lat,   - required',
'       2.     lng,   - required',
'       3.     name,  - required',
'       4.     id,    - required',
'       5.     info,  - optional',
'       6.     icon,  - optional',
'       7.     label  - optional',
'       8-17.  col01..col10 - optional flex fields',
'       ',
'       If the "Heatmap" option is chosen, the column list is as follows:',
'       ',
'       1.  lat,   - required',
'       2.  lng,   - required',
'       3.  weight - required',
'    ',
'    */',
'    ',
'    l_max_rows := apex_plugin_util.get_attribute_as_number(p_plugin.attribute_07, ''Maximum Records'');',
'    ',
'    if l_visualisation = g_visualisation_heatmap then',
'',
'        l_column_value_list := apex_plugin_util.get_data',
'            (p_sql_statement  => p_region.source',
'            ,p_min_columns    => 3',
'            ,p_max_columns    => 3',
'            ,p_component_name => p_region.name',
'            ,p_max_rows       => l_max_rows);',
'  ',
'        for i in 1..l_column_value_list(1).count loop',
'        ',
'            l_lat := round(apex_plugin_util.get_attribute_as_number(l_column_value_list(1)(i),''Latitude (#''||i||'')''),g_coord_precision);',
'            l_lng := round(apex_plugin_util.get_attribute_as_number(l_column_value_list(2)(i),''Longitude (#''||i||'')''),g_coord_precision);',
'            l_weight := nvl(round(',
'                          apex_plugin_util.get_attribute_as_number(l_column_value_list(3)(i),''Weight (#''||i||'')'')',
'                          ),1);',
'            ',
'            -- minimise size of data to be sent',
'            l_buf := ''['' || to_char(l_lat,g_tochar_format)',
'                  || '','' || to_char(l_lng,g_tochar_format)',
'                  || '','' || to_char(greatest(l_weight,1))',
'                  || '']'';',
'            if i < 8 /*don''t send the whole dataset to debug log*/ then',
'              apex_debug.message(''#'' || i || '': '' || l_buf);',
'            end if;',
'            l_data(nvl(l_data.last,0)+1) := l_buf;',
'',
'            get_map_bounds',
'                (p_lat     => l_lat',
'                ,p_lng     => l_lng',
'                ,p_lat_min => p_lat_min',
'                ,p_lat_max => p_lat_max',
'                ,p_lng_min => p_lng_min',
'                ,p_lng_max => p_lng_max',
'                );',
'          ',
'        end loop;',
'    ',
'    else',
'  ',
'        l_column_value_list := apex_plugin_util.get_data',
'            (p_sql_statement  => p_region.source',
'            ,p_min_columns    => 4',
'            ,p_max_columns    => 17',
'            ,p_component_name => p_region.name',
'            ,p_max_rows       => l_max_rows);',
'    ',
'        for i in 1..l_column_value_list(1).count loop',
'',
'            l_lat := round(apex_plugin_util.get_attribute_as_number(l_column_value_list(1)(i),''Latitude (#''||i||'')''),g_coord_precision);',
'            l_lng := round(apex_plugin_util.get_attribute_as_number(l_column_value_list(2)(i),''Longitude (#''||i||'')''),g_coord_precision);',
'        ',
'            -- get flex fields, if any',
'            l_flex := null;',
'            for attr_no in 1..10 loop',
'              l_flex := l_flex || flex_field(attr_no,i);',
'            end loop;',
'',
'            l_buf := apex_javascript.add_attribute(''x'',l_lat)',
'                  || apex_javascript.add_attribute(''y'',l_lng)',
'                  || apex_javascript.add_attribute(''n'',varchar2_field(3,i))',
'                  || apex_javascript.add_attribute(''d'',varchar2_field(4,i))',
'                  || apex_javascript.add_attribute(''i'',varchar2_field(5,i))',
'                  || apex_javascript.add_attribute(''c'',varchar2_field(6,i))',
'                  || apex_javascript.add_attribute(''l'',substr(varchar2_field(7,i),1,1))',
'                  || case when l_flex is not null then',
'                       ''"f":{'' || rtrim(l_flex,'','') || ''}''',
'                     end;',
'            ',
'            if i < 8 /*don''t send the whole dataset to debug log*/ then',
'              apex_debug.message(''#'' || i || '': '' || l_buf);',
'            end if;',
'            l_data(nvl(l_data.last,0)+1) := ''{'' || rtrim(l_buf,'','') || ''}'';',
'',
'            get_map_bounds',
'                (p_lat     => l_lat',
'                ,p_lng     => l_lng',
'                ,p_lat_min => p_lat_min',
'                ,p_lat_max => p_lat_max',
'                ,p_lng_min => p_lng_min',
'                ,p_lng_max => p_lng_max',
'                );',
'          ',
'        end loop;',
'',
'    end if;',
'    ',
'    apex_debug.message(''data.count=''||l_data.count);',
'',
'    -- handle edge case when there is exactly one row from query',
'    -- (otherwise the map zooms to maximum)',
'    if l_data.count = 1 then',
'        p_lat_min := p_lat_min - g_single_row_lat_margin;',
'        p_lat_max := p_lat_max + g_single_row_lat_margin;',
'    end if;',
'        ',
'    return l_data;',
'end get_markers;',
'',
'function render',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ,p_is_printer_friendly in boolean',
'    ) return apex_plugin.t_region_render_result is',
'    ',
'    l_result     apex_plugin.t_region_render_result;',
'    l_lat        number;',
'    l_lng        number;',
'    l_region_id  varchar2(100);',
'    l_lat_min    number;',
'    l_lat_max    number;',
'    l_lng_min    number;',
'    l_lng_max    number;',
'',
'    -- Component settings',
'    l_api_key                      plugin_attr := p_plugin.attribute_01;',
'    l_no_address_results_msg       plugin_attr := p_plugin.attribute_02;',
'    l_directions_not_found_msg     plugin_attr := p_plugin.attribute_03;',
'    l_directions_zero_results_msg  plugin_attr := p_plugin.attribute_04;',
'    l_min_zoom                     number; --p_plugin.attribute_05;',
'    l_max_zoom                     number; --p_plugin.attribute_06;',
'',
'    -- Plugin attributes',
'    l_map_height           plugin_attr := p_region.attribute_01;',
'    l_visualisation        plugin_attr := p_region.attribute_02;',
'    l_click_zoom_level     number; --p_region.attribute_03;',
'    l_options              plugin_attr := p_region.attribute_04;',
'    l_initial_zoom_level   number; --p_region.attribute_05;',
'    l_initial_center       plugin_attr := p_region.attribute_06;',
'    l_restrict_country     plugin_attr := p_region.attribute_10;',
'    l_mapstyle             plugin_attr := p_region.attribute_11;',
'    l_heatmap_dissipating  plugin_attr := p_region.attribute_12;',
'    l_heatmap_opacity      number; --p_region.attribute_13;',
'    l_heatmap_radius       number; --p_region.attribute_14;',
'    l_travel_mode          plugin_attr := p_region.attribute_15;',
'    l_optimizewaypoints    plugin_attr := p_region.attribute_21;',
'    l_maptype              plugin_attr := p_region.attribute_22;',
'    l_gesture_handling     plugin_attr := p_region.attribute_25;',
'    ',
'    l_opt  varchar2(32767);',
'    l_buf  varchar2(32767);',
'    ',
'    function valid_zoom_level (p_attr in varchar2, p_label in varchar2) return number is',
'        n number;',
'    begin',
'        n := apex_plugin_util.get_attribute_as_number(p_attr, p_label);',
'        if not n between 0 and 23 then',
'            raise_application_error(-20000, p_label || '': must be in range 0..23 ("'' || p_attr || ''")'');',
'        end if;',
'        return n;',
'    end valid_zoom_level;',
'',
'begin',
'    -- debug information will be included',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region',
'            (p_plugin => p_plugin',
'            ,p_region => p_region',
'            ,p_is_printer_friendly => p_is_printer_friendly);',
'    end if;',
'    ',
'    if l_api_key is null then',
'      raise_application_error(-20000, ''Google Maps API Key is required (set in Component Settings)'');',
'    end if;',
'    ',
'    l_min_zoom           := valid_zoom_level(p_plugin.attribute_05, ''Min. Zoom'');',
'    l_max_zoom           := valid_zoom_level(p_plugin.attribute_06, ''Max. Zoom'');',
'    l_click_zoom_level   := valid_zoom_level(p_region.attribute_03, ''Zoom Level on Click'');',
'    l_initial_zoom_level := valid_zoom_level(p_region.attribute_05, ''Initial Zoom Level'');',
'    l_heatmap_opacity    := apex_plugin_util.get_attribute_as_number(p_region.attribute_13, ''Heatmap Opacity'');',
'    l_heatmap_radius     := apex_plugin_util.get_attribute_as_number(p_region.attribute_14, ''Heatmap Radius'');',
'    ',
'    apex_javascript.add_library',
'        (p_name           => ''js?key='' || l_api_key',
'                          || case when l_visualisation = g_visualisation_heatmap then',
'                               ''&libraries=visualization''',
'                             end',
'        ,p_directory      => ''https://maps.googleapis.com/maps/api/''',
'        ,p_skip_extension => true);',
'    ',
'    apex_javascript.add_library',
'        (p_name                  => ''jk64reportmap_r1''',
'        ,p_directory             => p_plugin.file_prefix',
'        ,p_check_to_add_minified => true);',
'',
'    if l_visualisation = g_visualisation_cluster then',
'        apex_javascript.add_library',
'            (p_name                  => ''markerclusterer''',
'            ,p_directory             => p_plugin.file_prefix',
'            ,p_check_to_add_minified => true);',
'    end if;',
'',
'    l_region_id := case',
'                   when p_region.static_id is not null',
'                   then p_region.static_id',
'                   else ''R''||p_region.id',
'                   end;',
'    apex_debug.message(''map region: '' || l_region_id);',
'    ',
'    if l_initial_center is not null then',
'        parse_latlng(l_initial_center, p_label=>''Initial Map Center'', p_lat=>l_lat, p_lng=>l_lng);',
'    end if;',
'    ',
'    l_opt := ''{''',
'      || apex_javascript.add_attribute(''regionId'', l_region_id)',
'      || apex_javascript.add_attribute(''expectData'', nullif(p_region.source is not null,true))',
'      || apex_javascript.add_attribute(''visualisation'', lower(nullif(l_visualisation,g_visualisation_pins)))',
'      || apex_javascript.add_attribute(''mapType'', lower(nullif(l_maptype,g_maptype_roadmap)))',
'      || apex_javascript.add_attribute(''minZoom'', nullif(l_min_zoom,1))',
'      || apex_javascript.add_attribute(''maxZoom'', l_max_zoom)',
'      || apex_javascript.add_attribute(''initialZoom'', nullif(l_initial_zoom_level,2))',
'      || case when l_lat!=0 or l_lng!=0 then',
'            ''"initialCenter":'' || latlng_literal(l_lat,l_lng) || '',''',
'         end',
'      || apex_javascript.add_attribute(''clickZoomLevel'', l_click_zoom_level)',
'      || apex_javascript.add_attribute(''isDraggable'', nullif(instr('':''||l_options||'':'','':DRAGGABLE:'')>0,false))',
'      || case when l_visualisation = g_visualisation_heatmap then',
'            apex_javascript.add_attribute(''heatmapDissipating'', nullif(l_heatmap_dissipating=''Y'',false))',
'         || apex_javascript.add_attribute(''heatmapOpacity'', nullif(l_heatmap_opacity,0.6))',
'         || apex_javascript.add_attribute(''heatmapRadius'', nullif(l_heatmap_radius,5))',
'         end',
'      || apex_javascript.add_attribute(''panOnClick'', nullif(instr('':''||l_options||'':'','':PAN_ON_CLICK:'')>0,true))',
'      || apex_javascript.add_attribute(''restrictCountry'', l_restrict_country)',
'      || case when l_lat_min is not null and l_lng_min is not null',
'               and l_lat_max is not null and l_lng_max is not null then',
'              ''"southwest":'' || latlng_literal(l_lat_min,l_lng_min) || '',''',
'           || ''"northeast":'' || latlng_literal(l_lat_max,l_lng_max) || '',''',
'         end',
'      || case when l_mapstyle is not null then',
'         ''"mapStyle":'' || l_mapstyle || '',''',
'         end',
'      || case when l_visualisation = g_visualisation_directions then',
'            apex_javascript.add_attribute(''travelMode'', nullif(l_travel_mode,g_travelmode_driving))',
'         || apex_javascript.add_attribute(''optimizeWaypoints'', nullif(l_optimizewaypoints=''Y'',false))',
'         end',
'      || apex_javascript.add_attribute(''allowZoom'', nullif(instr('':''||l_options||'':'','':ZOOM_ALLOWED:'')>0,true))',
'      || apex_javascript.add_attribute(''allowPan'', nullif(instr('':''||l_options||'':'','':PAN_ALLOWED:'')>0,true))',
'      || apex_javascript.add_attribute(''gestureHandling'', nullif(l_gesture_handling,''auto''))',
'      || apex_javascript.add_attribute(''noDataMessage'', p_region.no_data_found_message)',
'      || apex_javascript.add_attribute(''noAddressResults'', l_no_address_results_msg)',
'      || apex_javascript.add_attribute(''directionsNotFound'', l_directions_not_found_msg)',
'      || apex_javascript.add_attribute(''directionsZeroResults'', l_directions_zero_results_msg)',
'      || apex_javascript.add_attribute(''ajaxIdentifier'', apex_plugin.get_ajax_identifier)',
'      || apex_javascript.add_attribute(''ajaxItems'', apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit))',
'      || apex_javascript.add_attribute(''pluginFilePrefix'', p_plugin.file_prefix',
'         ,false,false)',
'      || ''}'';',
'        ',
'    -- we don''t want the init to run until after the page is loaded including all resources; the r_ function',
'    -- method here waits until the document is ready before running the jquery plugin initialisation',
'    l_buf := ''<script>''',
'          || ''function r_#REGION_ID#(f){/in/.test(document.readyState)?setTimeout("r_#REGION_ID#("+f+")",9):f()}''',
'          || ''r_#REGION_ID#(function(){''',
'          || ''$("#map_#REGION_ID#").reportmap(''',
'          || l_opt',
'          || '');'';',
'',
'    if p_region.init_javascript_code is not null then',
'      -- make "this" point to the reportmap object; this.map will be the google map object',
'      l_buf := l_buf',
'            || ''var m=$("#map_#REGION_ID#").reportmap("instance");''',
'            || ''function i_#REGION_ID#(){apex.debug("running init_javascript_code...");''',
'            || p_region.init_javascript_code',
'            || ''};m.init=i_#REGION_ID#;m.init();'';',
'    end if;',
'',
'    -- map apex refresh event to the jquery plugin refresh event',
'    l_buf := l_buf',
'          || ''apex.jQuery("##REGION_ID#").bind("apexrefresh",function(){$("#map_#REGION_ID#").reportmap("refresh");});''',
'          || ''});</script>''',
'          || ''<div id="map_#REGION_ID#" style="min-height:'' || l_map_height || ''px"></div>'';',
'    ',
'    sys.htp.p(replace(l_buf,''#REGION_ID#'',l_region_id));',
'    ',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        raise;',
'end render;',
'',
'function ajax',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ) return apex_plugin.t_region_ajax_result is',
'',
'    l_result   apex_plugin.t_region_ajax_result;',
'    l_lat      number;',
'    l_lng      number;',
'    l_data     apex_application_global.vc_arr2;',
'    l_lat_min  number;',
'    l_lat_max  number;',
'    l_lng_min  number;',
'    l_lng_max  number;',
'',
'    -- Plugin attributes',
'    l_initial_center plugin_attr := p_region.attribute_06;',
'',
'begin',
'    -- debug information will be included',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region',
'            (p_plugin => p_plugin',
'            ,p_region => p_region);',
'    end if;',
'    apex_debug.message(''ajax'');',
'',
'    if p_region.source is not null then',
'',
'        l_data := get_markers',
'            (p_plugin  => p_plugin',
'            ,p_region  => p_region',
'            ,p_lat_min => l_lat_min',
'            ,p_lat_max => l_lat_max',
'            ,p_lng_min => l_lng_min',
'            ,p_lng_max => l_lng_max',
'            );',
'',
'    end if;',
'        ',
'    if l_initial_center is not null then',
'        parse_latlng(l_initial_center, p_label=>''Initial Map Center'', p_lat=>l_lat, p_lng=>l_lng);',
'    end if;',
'    ',
'    if l_lat is not null and l_data.count > 0 then',
'        get_map_bounds',
'            (p_lat     => l_lat',
'            ,p_lng     => l_lng',
'            ,p_lat_min => l_lat_min',
'            ,p_lat_max => l_lat_max',
'            ,p_lng_min => l_lng_min',
'            ,p_lng_max => l_lng_max',
'            );',
'',
'    end if;',
'',
'    sys.owa_util.mime_header(''text/plain'', false);',
'    sys.htp.p(''Cache-Control: no-cache'');',
'    sys.htp.p(''Pragma: no-cache'');',
'    sys.owa_util.http_header_close;',
'    ',
'    sys.htp.p(''{''',
'      || case when l_lat_min is not null then',
'            ''"southwest":'' || latlng_literal(l_lat_min,l_lng_min) || '',''',
'         || ''"northeast":'' || latlng_literal(l_lat_max,l_lng_max) || '',''',
'         end',
'      || ''"mapdata":['');',
'',
'    for i in 1..l_data.count loop',
'        -- use prn to avoid downloading a whole lot of unnecessary \n characters',
'        sys.htp.prn(case when i>1 then '','' end || l_data(i));',
'    end loop;',
'',
'    sys.htp.p('']}'');',
'',
'    apex_debug.message(''ajax finished'');',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        sys.htp.p(''{"error":'' || apex_escape.js_literal(sqlerrm,''"'') || ''}'');',
'        return l_result;',
'end ajax;',
'',
'/**********************************************************',
'end jk64reportmap_r1_pkg;',
'**********************************************************/',
''))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_LOCATION:AJAX_ITEMS_TO_SUBMIT:NO_DATA_FOUND_MESSAGE:INIT_JAVASCRIPT_CODE'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id, and Info.',
'<p>',
'Refer to the wiki for documentation and examples:',
'<p>',
'<strong><a href="https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki" target=_blank>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki</a></strong>'))
,p_version_identifier=>'1.0.1'
,p_about_url=>'https://jeffreykemp.github.io/jk64-plugin-reportmap/'
,p_files_version=>226
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33032357089766730)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Google API Key'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_display_length=>60
,p_is_translatable=>false
,p_help_text=>'A Google Maps API Key is required. Refer: https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33032700900766731)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'No Address Results message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "Address not found"'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33033165678766731)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Directions Not Found message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "At least one of the origin, destination, or waypoints could not be geocoded."'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33033555567766732)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Directions Zero Results message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "No route could be found between the origin and destination."'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33083483503505997)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Min. Zoom'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_default_value=>'1'
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Minimum Zoom Level - must be 0 to 23. Set to 0 to allow zooming out to entire world map.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33084814811507920)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Max. Zoom'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Maximum Zoom Level - 0 to 23. Set to blank to allow zooming in to show maximum detail.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33225460614730815)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Maximum Records'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'10000'
,p_unit=>'rows'
,p_is_translatable=>false
,p_help_text=>'Maximum number of records to fetch from the SQL Query. Note that datasets that are very large (e.g. 10,000+) may perform poorly on the client''s machine. The Heatmap option is leaner and can support larger datasets.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33033918212766732)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Min. Map Height'
,p_attribute_type=>'NUMBER'
,p_is_required=>true
,p_show_in_wizard=>false
,p_default_value=>'400'
,p_unit=>'pixels'
,p_is_translatable=>false
,p_help_text=>'Desired height (in pixels) of the map region. Note: the width will adjust according to the available area of the containing window.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33034309319766732)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Visualisation'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'PINS'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Select how to represent the data retrieved from the query on the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33035208822766734)
,p_plugin_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_display_sequence=>10
,p_display_value=>'Pins'
,p_return_value=>'PINS'
,p_help_text=>'Show a pin for every data point. The pin may optionally use an alternative icon, or show a single-character label. Each pin can also have an information window showing text (most HTML allowed) when the user selects the pin.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33035791826766734)
,p_plugin_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_display_sequence=>20
,p_display_value=>'Marker Clustering'
,p_return_value=>'CLUSTER'
,p_help_text=>'Show a pin for every data point. Cluster pins where many pins are very close together.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33036261559766735)
,p_plugin_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_display_sequence=>30
,p_display_value=>'Heatmap'
,p_return_value=>'HEATMAP'
,p_help_text=>'Show the data as a heat map. Suitable for larger volume of data points. Note: a different query structure is required (i.e. no pin labels or icons are used).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33034776246766733)
,p_plugin_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_display_sequence=>40
,p_display_value=>'Directions'
,p_return_value=>'DIRECTIONS'
,p_help_text=>'Show a route using the data points from the query. Directions can be shown for Driving, Walking, Bicycling or Public Transport. A pin will also be shown at each point.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33036760657766735)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Zoom Level on Click'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'13'
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, or adds a new marker, zoom the map to this level. Set to blank to not zoom on click.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33037151641766735)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Options'
,p_attribute_type=>'CHECKBOXES'
,p_is_required=>false
,p_default_value=>'PAN_ON_CLICK:PAN_ALLOWED:ZOOM_ALLOWED'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33038504445766736)
,p_plugin_attribute_id=>wwv_flow_api.id(33037151641766735)
,p_display_sequence=>10
,p_display_value=>'Pan on click'
,p_return_value=>'PAN_ON_CLICK'
,p_help_text=>'When the user clicks a point on the map, pan the map to that location.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33039075688766736)
,p_plugin_attribute_id=>wwv_flow_api.id(33037151641766735)
,p_display_sequence=>20
,p_display_value=>'Draggable'
,p_return_value=>'DRAGGABLE'
,p_help_text=>'Allow user to move pins to new locations on the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33037582128766736)
,p_plugin_attribute_id=>wwv_flow_api.id(33037151641766735)
,p_display_sequence=>30
,p_display_value=>'Pan allowed'
,p_return_value=>'PAN_ALLOWED'
,p_help_text=>'Allow user to pan the map. If unset, the map will be fixed at one location.'
);
end;
/
begin
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33038059451766736)
,p_plugin_attribute_id=>wwv_flow_api.id(33037151641766735)
,p_display_sequence=>40
,p_display_value=>'Zoom Allowed'
,p_return_value=>'ZOOM_ALLOWED'
,p_help_text=>'Allow user to zoom in or out. If unset, the map scale will remain constant.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33039568715766737)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Initial Zoom Level'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Initial zoom level (0..23) if no data is loaded. Default is 2. If data is loaded, this attribute has no effect.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33039969756766737)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Initial Map Center'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_show_in_wizard=>false
,p_unit=>'lat,long'
,p_is_translatable=>false
,p_help_text=>'Set the latitude and longitude as a pair of numbers to be used to position the map on page load, if no data is loaded. Default is 0,0. If data is loaded, this attribute has no effect. NOTE: the numeric values must use the dot (.) as the decimal separ'
||'ator, and comma (,) as the delimiter between the lat and lng values.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33040367046766737)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_show_in_wizard=>false
,p_display_length=>10
,p_max_length=>40
,p_is_translatable=>false
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to 2-character country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country. You can set this to a subst'
||'ition variable (e.g. &P1_COUNTRY.) but note that this will only apply if the page is refreshed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33040771719766738)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Map Style'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Here is an example, a light greyscale style map:',
'<pre>',
'[{"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9e9e9"},{"lightness":17}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f5"},{"lightness":20}]},{"featureType":"road.highway","elementType":"geom'
||'etry.fill","stylers":[{"color":"#ffffff"},{"lightness":17}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffffff"},{"lightness":29},{"weight":0.2}]},{"featureType":"road.arterial","elementType":"geometry","style'
||'rs":[{"color":"#ffffff"},{"lightness":18}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#ffffff"},{"lightness":16}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#f5f5f5"},{"lightness":21}]},{"featu'
||'reType":"poi.park","elementType":"geometry","stylers":[{"color":"#dedede"},{"lightness":21}]},{"elementType":"labels.text.stroke","stylers":[{"visibility":"on"},{"color":"#ffffff"},{"lightness":16}]},{"elementType":"labels.text.fill","stylers":[{"sat'
||'uration":36},{"color":"#333333"},{"lightness":40}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#f2f2f2"},{"lightness":19}]},{"featureType":"administrative","el'
||'ementType":"geometry.fill","stylers":[{"color":"#fefefe"},{"lightness":20}]},{"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#fefefe"},{"lightness":17},{"weight":1.2}]}]',
'</pre>'))
,p_help_text=>'Easiest way is to copy one from a site like https://snazzymaps.com/'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33066308611994994)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_prompt=>'Dissipating'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'Specifies whether heatmaps dissipate on zoom. Yes means the radius of influence of a data point is specified by the radius option only. When dissipating is disabled, the radius option is interpreted as a radius at zoom level 0.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33067122787999891)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_prompt=>'Opacity'
,p_attribute_type=>'NUMBER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'0.6'
,p_display_length=>5
,p_unit=>'0 .. 1'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'The opacity of the heatmap, expressed as a number between 0 and 1.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33067649006003875)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>14
,p_display_sequence=>140
,p_prompt=>'Radius'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'5'
,p_display_length=>5
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'The radius of influence for each data point, in pixels.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33041157545766738)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>15
,p_display_sequence=>150
,p_prompt=>'Travel Mode'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'DRIVING'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'DIRECTIONS'
,p_lov_type=>'STATIC'
,p_help_text=>'Type of travel directions to calculate. The locations can be simple - between two locations according to two items on the page - or via the route indicated by waypoints from the report query. Google API Key required.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33041599182766738)
,p_plugin_attribute_id=>wwv_flow_api.id(33041157545766738)
,p_display_sequence=>10
,p_display_value=>'Driving'
,p_return_value=>'DRIVING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33042079973766738)
,p_plugin_attribute_id=>wwv_flow_api.id(33041157545766738)
,p_display_sequence=>20
,p_display_value=>'Walking'
,p_return_value=>'WALKING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33042594238766739)
,p_plugin_attribute_id=>wwv_flow_api.id(33041157545766738)
,p_display_sequence=>30
,p_display_value=>'Bicycling'
,p_return_value=>'BICYCLING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33043085494766739)
,p_plugin_attribute_id=>wwv_flow_api.id(33041157545766738)
,p_display_sequence=>40
,p_display_value=>'Transit'
,p_return_value=>'TRANSIT'
,p_help_text=>'Public transport'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33043528527766739)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>21
,p_display_sequence=>210
,p_prompt=>'Optimize Waypoints'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(33034309319766732)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'DIRECTIONS'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'If set to true, the Directions service will attempt to re-order the supplied intermediate waypoints to minimize overall cost of the route.',
'',
'Note: the first and last points supplied by the report query are always used as the starting and ending points for the journey.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33043910272766739)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>22
,p_display_sequence=>220
,p_prompt=>'Default Map Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'ROADMAP'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Default map type to show on page load. The user may change the map type if they wish to show a different type.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33044356646766740)
,p_plugin_attribute_id=>wwv_flow_api.id(33043910272766739)
,p_display_sequence=>10
,p_display_value=>'Roadmap'
,p_return_value=>'ROADMAP'
,p_help_text=>'(default) This map type displays a normal street map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33044844968766740)
,p_plugin_attribute_id=>wwv_flow_api.id(33043910272766739)
,p_display_sequence=>20
,p_display_value=>'Satellite'
,p_return_value=>'SATELLITE'
,p_help_text=>'This map type displays satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33045379682766740)
,p_plugin_attribute_id=>wwv_flow_api.id(33043910272766739)
,p_display_sequence=>30
,p_display_value=>'Hybrid'
,p_return_value=>'HYBRID'
,p_help_text=>'This map type displays a transparent layer of major streets on satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33045893103766741)
,p_plugin_attribute_id=>wwv_flow_api.id(33043910272766739)
,p_display_sequence=>40
,p_display_value=>'Terrain'
,p_return_value=>'TERRAIN'
,p_help_text=>'This map type displays maps with physical features such as terrain and vegetation.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33424378011478164)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>24
,p_display_sequence=>240
,p_prompt=>'Escape special characters'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'This is relevant only to the "flex fields", if supplied in the SQL Query. By default any special characters (such as < and >) will be escaped prior to sending to the client, in order to protect against XSS attacks and to allow the original data to be'
||' rendered exactly as entered. To disable this escaping, set this attribute to No.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(33046336939766741)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>25
,p_display_sequence=>250
,p_prompt=>'Gesture Handling'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'auto'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'This attribute allows you to select how the map responds to touch gestures on a mobile device. Mobile web users often get frustrated when trying to scroll the page, but an embedded map captures their swipe and pans the map instead. This can even lead'
||' to users getting stuck on the map and having to reload the page in order to get back to the rest of the page. This option allows you to make scrolling more intuitive and less frustrating map interaction experience on mobile browsers.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33046750503766741)
,p_plugin_attribute_id=>wwv_flow_api.id(33046336939766741)
,p_display_sequence=>10
,p_display_value=>'cooperative'
,p_return_value=>'cooperative'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
unistr('Scroll events and one-finger touch gestures scroll the page, and do not zoom or pan the map. Two-finger touch gestures pan and zoom the map. Scroll events with a ctrl key or \2318 key pressed zoom the map.'),
'In this mode the map cooperates with the page.'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33047255911766741)
,p_plugin_attribute_id=>wwv_flow_api.id(33046336939766741)
,p_display_sequence=>20
,p_display_value=>'greedy'
,p_return_value=>'greedy'
,p_help_text=>'All touch gestures and scroll events pan or zoom the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33047784709766742)
,p_plugin_attribute_id=>wwv_flow_api.id(33046336939766741)
,p_display_sequence=>30
,p_display_value=>'none'
,p_return_value=>'none'
,p_help_text=>'The map cannot be panned or zoomed by user gestures.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(33048225204766742)
,p_plugin_attribute_id=>wwv_flow_api.id(33046336939766741)
,p_display_sequence=>40
,p_display_value=>'auto'
,p_return_value=>'auto'
,p_help_text=>'(default) Gesture handling is either cooperative or greedy, depending on whether the page is scrollable.'
);
wwv_flow_api.create_plugin_std_attribute(
 p_id=>wwv_flow_api.id(33054354286766759)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'INIT_JAVASCRIPT_CODE'
,p_is_required=>false
);
wwv_flow_api.create_plugin_std_attribute(
 p_id=>wwv_flow_api.id(33065731252971474)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'SOURCE_LOCATION'
,p_is_required=>false
,p_depending_on_has_to_exist=>true
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>',
'<pre>SELECT lat, lng, name, id FROM mydata;</pre>',
'</p><p>',
'<em>Show a popup info window when a marker is clicked:</em>',
'</p><p>',
'<pre>SELECT lat, lng, name, id, info FROM mydata;</pre>',
'</p><p>',
'<em>Show each point with a selected icon:</em>',
'</p><p>',
'<pre>SELECT lat, lng, name, id, info, icon FROM mydata;</pre>',
'</p><p>',
'<em>Get only the data within a certain distance from a chosen point:</em>',
'</p><p>',
'<pre>',
'SELECT t.lat AS lat',
'      ,t.lng AS lng',
'      ,t.name',
'      ,t.id AS id',
'      ,t.info',
'      ,'''' AS icon',
'FROM   mytable t',
'WHERE  t.lat IS NOT NULL',
'AND    t.lng IS NOT NULL',
'AND    (:P1_LATLNG IS NULL',
'     OR :P1_RADIUS IS NULL',
'     OR SDO_GEOM.sdo_distance',
'          (geom1 => SDO_GEOMETRY',
'            (sdo_gtype     => 2001 /* 2-dimensional point */',
'            ,sdo_srid      => 8307 /* Longitude / Latitude (WGS 84) */',
'            ,sdo_point     => SDO_POINT_TYPE(t.lng, t.lat, NULL)',
'            ,sdo_elem_info => NULL',
'            ,sdo_ordinates => NULL)',
'          ,geom2 => SDO_GEOMETRY',
'            (sdo_gtype     => 2001 /* 2-dimensional point */',
'            ,sdo_srid      => 8307 /* Longitude / Latitude (WGS 84) */',
'            ,sdo_point     => SDO_POINT_TYPE',
'               (TO_NUMBER(SUBSTR(:P1_LATLNG,INSTR(:P1_LATLNG,'','')+1))',
'               ,TO_NUMBER(SUBSTR(:P1_LATLNG,1,INSTR(:P1_LATLNG,'','')-1)), NULL)',
'            ,sdo_elem_info => NULL',
'            ,sdo_ordinates => NULL)',
'          ,tol   => 0.0001 /*metres*/',
'          ,unit  => ''unit=KM'') < :P1_RADIUS)',
'</pre>',
'</p><p>',
'<em>Marker labels:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       label as lbl',
'FROM mydata;',
'</pre>',
'</p><p>',
'<em>Heatmap:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, count(*) as weight',
'FROM mydata',
'group by lat, lng;',
'</pre>'))
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33055102650766761)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'addressfound'
,p_display_name=>'addressFound'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33055507193766761)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'directions'
,p_display_name=>'directions'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33055943189766762)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'geolocate'
,p_display_name=>'geolocate'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33056391715766762)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33056793628766762)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33057141654766763)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(33057533664766763)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_name=>'markerdrag'
,p_display_name=>'markerDrag'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A2A0A202A20406E616D65204D61726B6572436C75737465726572506C757320666F7220476F6F676C65204D6170732056330A202A204076657273696F6E20322E312E31205B4E6F76656D62657220342C20323031335D0A202A2040617574686F7220';
wwv_flow_api.g_varchar2_table(2) := '47617279204C6974746C650A202A204066696C656F766572766965770A202A20546865206C696272617279206372656174657320616E64206D616E61676573207065722D7A6F6F6D2D6C6576656C20636C75737465727320666F72206C6172676520616D';
wwv_flow_api.g_varchar2_table(3) := '6F756E7473206F66206D61726B6572732E0A202A203C703E0A202A205468697320697320616E20656E68616E63656420563320696D706C656D656E746174696F6E206F66207468650A202A203C6120687265663D22687474703A2F2F676D6170732D7574';
wwv_flow_api.g_varchar2_table(4) := '696C6974792D6C6962726172792D6465762E676F6F676C65636F64652E636F6D2F73766E2F746167732F6D61726B6572636C757374657265722F220A202A203E5632204D61726B6572436C757374657265723C2F613E206279205869616F78692057752E';
wwv_flow_api.g_varchar2_table(5) := '204974206973206261736564206F6E207468650A202A203C6120687265663D22687474703A2F2F676F6F676C652D6D6170732D7574696C6974792D6C6962726172792D76332E676F6F676C65636F64652E636F6D2F73766E2F746167732F6D61726B6572';
wwv_flow_api.g_varchar2_table(6) := '636C757374657265722F220A202A203E5633204D61726B6572436C757374657265723C2F613E20706F7274206279204C756B65204D6168652E204D61726B6572436C75737465726572506C75732077617320637265617465642062792047617279204C69';
wwv_flow_api.g_varchar2_table(7) := '74746C652E0A202A203C703E0A202A2076322E302072656C656173653A204D61726B6572436C75737465726572506C75732076322E30206973206261636B7761726420636F6D70617469626C652077697468204D61726B6572436C757374657265722076';
wwv_flow_api.g_varchar2_table(8) := '312E302E2049740A202A20206164647320737570706F727420666F7220746865203C636F64653E69676E6F726548696464656E3C2F636F64653E2C203C636F64653E7469746C653C2F636F64653E2C203C636F64653E626174636853697A6549453C2F63';
wwv_flow_api.g_varchar2_table(9) := '6F64653E2C0A202A2020616E64203C636F64653E63616C63756C61746F723C2F636F64653E2070726F706572746965732061732077656C6C20617320737570706F727420666F7220666F7572206D6F7265206576656E74732E20497420616C736F20616C';
wwv_flow_api.g_varchar2_table(10) := '6C6F77730A202A20206772656174657220636F6E74726F6C206F76657220746865207374796C696E67206F6620746865207465787420746861742061707065617273206F6E2074686520636C7573746572206D61726B65722E205468650A202A2020646F';
wwv_flow_api.g_varchar2_table(11) := '63756D656E746174696F6E20686173206265656E207369676E69666963616E746C7920696D70726F76656420616E6420746865206F766572616C6C20636F646520686173206265656E2073696D706C696669656420616E640A202A2020706F6C69736865';
wwv_flow_api.g_varchar2_table(12) := '642E2056657279206C61726765206E756D62657273206F66206D61726B6572732063616E206E6F77206265206D616E6167656420776974686F75742063617573696E67204A6176617363726970742074696D656F75740A202A20206572726F7273206F6E';
wwv_flow_api.g_varchar2_table(13) := '20496E7465726E6574204578706C6F7265722E204E6F7465207468617420746865206E616D65206F6620746865203C636F64653E636C7573746572636C69636B3C2F636F64653E206576656E7420686173206265656E0A202A2020646570726563617465';
wwv_flow_api.g_varchar2_table(14) := '642E20546865206E6577206E616D65206973203C636F64653E636C69636B3C2F636F64653E2C20736F20706C65617365206368616E676520796F7572206170706C69636174696F6E20636F6465206E6F772E0A202A2F0A0A2F2A2A0A202A204C6963656E';
wwv_flow_api.g_varchar2_table(15) := '73656420756E6465722074686520417061636865204C6963656E73652C2056657273696F6E20322E30202874686520224C6963656E736522293B0A202A20796F75206D6179206E6F742075736520746869732066696C652065786365707420696E20636F';
wwv_flow_api.g_varchar2_table(16) := '6D706C69616E6365207769746820746865204C6963656E73652E0A202A20596F75206D6179206F627461696E206120636F7079206F6620746865204C6963656E73652061740A202A0A202A2020202020687474703A2F2F7777772E6170616368652E6F72';
wwv_flow_api.g_varchar2_table(17) := '672F6C6963656E7365732F4C4943454E53452D322E300A202A0A202A20556E6C657373207265717569726564206279206170706C696361626C65206C6177206F722061677265656420746F20696E2077726974696E672C20736F6674776172650A202A20';
wwv_flow_api.g_varchar2_table(18) := '646973747269627574656420756E64657220746865204C6963656E7365206973206469737472696275746564206F6E20616E20224153204953222042415349532C0A202A20574954484F55542057415252414E54494553204F5220434F4E444954494F4E';
wwv_flow_api.g_varchar2_table(19) := '53204F4620414E59204B494E442C206569746865722065787072657373206F7220696D706C6965642E0A202A2053656520746865204C6963656E736520666F7220746865207370656369666963206C616E677561676520676F7665726E696E6720706572';
wwv_flow_api.g_varchar2_table(20) := '6D697373696F6E7320616E640A202A206C696D69746174696F6E7320756E64657220746865204C6963656E73652E0A202A2F0A0A0A2F2A2A0A202A20406E616D6520436C757374657249636F6E5374796C650A202A2040636C617373205468697320636C';
wwv_flow_api.g_varchar2_table(21) := '61737320726570726573656E747320746865206F626A65637420666F722076616C75657320696E20746865203C636F64653E7374796C65733C2F636F64653E206172726179207061737365640A202A2020746F20746865207B406C696E6B204D61726B65';
wwv_flow_api.g_varchar2_table(22) := '72436C757374657265727D20636F6E7374727563746F722E2054686520656C656D656E7420696E20746869732061727261792074686174206973207573656420746F0A202A20207374796C652074686520636C75737465722069636F6E20697320646574';
wwv_flow_api.g_varchar2_table(23) := '65726D696E65642062792063616C6C696E6720746865203C636F64653E63616C63756C61746F723C2F636F64653E2066756E6374696F6E2E0A202A0A202A204070726F7065727479207B737472696E677D2075726C205468652055524C206F6620746865';
wwv_flow_api.g_varchar2_table(24) := '20636C75737465722069636F6E20696D6167652066696C652E2052657175697265642E0A202A204070726F7065727479207B6E756D6265727D206865696768742054686520646973706C6179206865696768742028696E20706978656C7329206F662074';
wwv_flow_api.g_varchar2_table(25) := '686520636C75737465722069636F6E2E2052657175697265642E0A202A204070726F7065727479207B6E756D6265727D2077696474682054686520646973706C61792077696474682028696E20706978656C7329206F662074686520636C757374657220';
wwv_flow_api.g_varchar2_table(26) := '69636F6E2E2052657175697265642E0A202A204070726F7065727479207B41727261797D205B616E63686F72546578745D2054686520706F736974696F6E2028696E20706978656C73292066726F6D207468652063656E746572206F662074686520636C';
wwv_flow_api.g_varchar2_table(27) := '75737465722069636F6E20746F0A202A20207768657265207468652074657874206C6162656C20697320746F2062652063656E746572656420616E6420647261776E2E2054686520666F726D6174206973203C636F64653E5B796F66667365742C20786F';
wwv_flow_api.g_varchar2_table(28) := '66667365745D3C2F636F64653E0A202A20207768657265203C636F64653E796F66667365743C2F636F64653E20696E6372656173657320617320796F7520676F20646F776E2066726F6D2063656E74657220616E64203C636F64653E786F66667365743C';
wwv_flow_api.g_varchar2_table(29) := '2F636F64653E0A202A2020696E6372656173657320746F20746865207269676874206F662063656E7465722E205468652064656661756C74206973203C636F64653E5B302C20305D3C2F636F64653E2E0A202A204070726F7065727479207B4172726179';
wwv_flow_api.g_varchar2_table(30) := '7D205B616E63686F7249636F6E5D2054686520616E63686F7220706F736974696F6E2028696E20706978656C7329206F662074686520636C75737465722069636F6E2E2054686973206973207468650A202A202073706F74206F6E2074686520636C7573';
wwv_flow_api.g_varchar2_table(31) := '7465722069636F6E207468617420697320746F20626520616C69676E656420776974682074686520636C757374657220706F736974696F6E2E2054686520666F726D61742069730A202A20203C636F64653E5B796F66667365742C20786F66667365745D';
wwv_flow_api.g_varchar2_table(32) := '3C2F636F64653E207768657265203C636F64653E796F66667365743C2F636F64653E20696E6372656173657320617320796F7520676F20646F776E20616E640A202A20203C636F64653E786F66667365743C2F636F64653E20696E637265617365732074';
wwv_flow_api.g_varchar2_table(33) := '6F20746865207269676874206F662074686520746F702D6C65667420636F726E6572206F66207468652069636F6E2E205468652064656661756C740A202A2020616E63686F7220706F736974696F6E206973207468652063656E746572206F6620746865';
wwv_flow_api.g_varchar2_table(34) := '20636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B74657874436F6C6F723D22626C61636B225D2054686520636F6C6F72206F6620746865206C6162656C20746578742073686F776E206F6E207468650A202A';
wwv_flow_api.g_varchar2_table(35) := '2020636C75737465722069636F6E2E0A202A204070726F7065727479207B6E756D6265727D205B7465787453697A653D31315D205468652073697A652028696E20706978656C7329206F6620746865206C6162656C20746578742073686F776E206F6E20';
wwv_flow_api.g_varchar2_table(36) := '7468650A202A2020636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B746578744465636F726174696F6E3D226E6F6E65225D205468652076616C7565206F662074686520435353203C636F64653E746578742D';
wwv_flow_api.g_varchar2_table(37) := '6465636F726174696F6E3C2F636F64653E0A202A202070726F706572747920666F7220746865206C6162656C20746578742073686F776E206F6E2074686520636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B';
wwv_flow_api.g_varchar2_table(38) := '666F6E745765696768743D22626F6C64225D205468652076616C7565206F662074686520435353203C636F64653E666F6E742D7765696768743C2F636F64653E0A202A202070726F706572747920666F7220746865206C6162656C20746578742073686F';
wwv_flow_api.g_varchar2_table(39) := '776E206F6E2074686520636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B666F6E745374796C653D226E6F726D616C225D205468652076616C7565206F662074686520435353203C636F64653E666F6E742D73';
wwv_flow_api.g_varchar2_table(40) := '74796C653C2F636F64653E0A202A202070726F706572747920666F7220746865206C6162656C20746578742073686F776E206F6E2074686520636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B666F6E744661';
wwv_flow_api.g_varchar2_table(41) := '6D696C793D22417269616C2C73616E732D7365726966225D205468652076616C7565206F662074686520435353203C636F64653E666F6E742D66616D696C793C2F636F64653E0A202A202070726F706572747920666F7220746865206C6162656C207465';
wwv_flow_api.g_varchar2_table(42) := '78742073686F776E206F6E2074686520636C75737465722069636F6E2E0A202A204070726F7065727479207B737472696E677D205B6261636B67726F756E64506F736974696F6E3D22302030225D2054686520706F736974696F6E206F66207468652063';
wwv_flow_api.g_varchar2_table(43) := '6C75737465722069636F6E20696D6167650A202A202077697468696E2074686520696D61676520646566696E6564206279203C636F64653E75726C3C2F636F64653E2E2054686520666F726D6174206973203C636F64653E2278706F732079706F73223C';
wwv_flow_api.g_varchar2_table(44) := '2F636F64653E0A202A2020287468652073616D6520666F726D617420617320666F722074686520435353203C636F64653E6261636B67726F756E642D706F736974696F6E3C2F636F64653E2070726F7065727479292E20596F75206D757374207365740A';
wwv_flow_api.g_varchar2_table(45) := '202A2020746869732070726F706572747920617070726F7072696174656C79207768656E2074686520696D61676520646566696E6564206279203C636F64653E75726C3C2F636F64653E20726570726573656E74732061207370726974650A202A202063';
wwv_flow_api.g_varchar2_table(46) := '6F6E7461696E696E67206D756C7469706C6520696D616765732E204E6F746520746861742074686520706F736974696F6E203C693E6D7573743C2F693E2062652073706563696669656420696E20707820756E6974732E0A202A2F0A2F2A2A0A202A2040';
wwv_flow_api.g_varchar2_table(47) := '6E616D6520436C757374657249636F6E496E666F0A202A2040636C617373205468697320636C61737320697320616E206F626A65637420636F6E7461696E696E672067656E6572616C20696E666F726D6174696F6E2061626F7574206120636C75737465';
wwv_flow_api.g_varchar2_table(48) := '722069636F6E2E20546869732069730A202A2020746865206F626A65637420746861742061203C636F64653E63616C63756C61746F723C2F636F64653E2066756E6374696F6E2072657475726E732E0A202A0A202A204070726F7065727479207B737472';
wwv_flow_api.g_varchar2_table(49) := '696E677D2074657874205468652074657874206F6620746865206C6162656C20746F2062652073686F776E206F6E2074686520636C75737465722069636F6E2E0A202A204070726F7065727479207B6E756D6265727D20696E6465782054686520696E64';
wwv_flow_api.g_varchar2_table(50) := '657820706C75732031206F662074686520656C656D656E7420696E20746865203C636F64653E7374796C65733C2F636F64653E0A202A2020617272617920746F206265207573656420746F207374796C652074686520636C75737465722069636F6E2E0A';
wwv_flow_api.g_varchar2_table(51) := '202A204070726F7065727479207B737472696E677D207469746C652054686520746F6F6C74697020746F20646973706C6179207768656E20746865206D6F757365206D6F766573206F7665722074686520636C75737465722069636F6E2E0A202A202049';
wwv_flow_api.g_varchar2_table(52) := '6620746869732076616C7565206973203C636F64653E756E646566696E65643C2F636F64653E206F72203C636F64653E22223C2F636F64653E2C203C636F64653E7469746C653C2F636F64653E2069732073657420746F207468650A202A202076616C75';
wwv_flow_api.g_varchar2_table(53) := '65206F6620746865203C636F64653E7469746C653C2F636F64653E2070726F70657274792070617373656420746F20746865204D61726B6572436C757374657265722E0A202A2F0A2F2A2A0A202A204120636C75737465722069636F6E2E0A202A0A202A';
wwv_flow_api.g_varchar2_table(54) := '2040636F6E7374727563746F720A202A2040657874656E647320676F6F676C652E6D6170732E4F7665726C6179566965770A202A2040706172616D207B436C75737465727D20636C75737465722054686520636C75737465722077697468207768696368';
wwv_flow_api.g_varchar2_table(55) := '207468652069636F6E20697320746F206265206173736F6369617465642E0A202A2040706172616D207B41727261797D205B7374796C65735D20416E206172726179206F66207B406C696E6B20436C757374657249636F6E5374796C657D20646566696E';
wwv_flow_api.g_varchar2_table(56) := '696E672074686520636C75737465722069636F6E730A202A2020746F2075736520666F7220766172696F757320636C75737465722073697A65732E0A202A2040707269766174650A202A2F0A66756E6374696F6E20436C757374657249636F6E28636C75';
wwv_flow_api.g_varchar2_table(57) := '737465722C207374796C657329207B0A2020636C75737465722E6765744D61726B6572436C7573746572657228292E657874656E6428436C757374657249636F6E2C20676F6F676C652E6D6170732E4F7665726C617956696577293B0A0A202074686973';
wwv_flow_api.g_varchar2_table(58) := '2E636C75737465725F203D20636C75737465723B0A2020746869732E636C6173734E616D655F203D20636C75737465722E6765744D61726B6572436C7573746572657228292E676574436C7573746572436C61737328293B0A2020746869732E7374796C';
wwv_flow_api.g_varchar2_table(59) := '65735F203D207374796C65733B0A2020746869732E63656E7465725F203D206E756C6C3B0A2020746869732E6469765F203D206E756C6C3B0A2020746869732E73756D735F203D206E756C6C3B0A2020746869732E76697369626C655F203D2066616C73';
wwv_flow_api.g_varchar2_table(60) := '653B0A0A2020746869732E7365744D617028636C75737465722E6765744D61702829293B202F2F204E6F74653A207468697320636175736573206F6E41646420746F2062652063616C6C65640A7D0A0A0A2F2A2A0A202A2041646473207468652069636F';
wwv_flow_api.g_varchar2_table(61) := '6E20746F2074686520444F4D2E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E6F6E416464203D2066756E6374696F6E202829207B0A20207661722063436C757374657249636F6E203D20746869733B0A202076617220634D6F7573';
wwv_flow_api.g_varchar2_table(62) := '65446F776E496E436C75737465723B0A202076617220634472616767696E674D61704279436C75737465723B0A0A2020746869732E6469765F203D20646F63756D656E742E637265617465456C656D656E74282264697622293B0A2020746869732E6469';
wwv_flow_api.g_varchar2_table(63) := '765F2E636C6173734E616D65203D20746869732E636C6173734E616D655F3B0A202069662028746869732E76697369626C655F29207B0A20202020746869732E73686F7728293B0A20207D0A0A2020746869732E67657450616E657328292E6F7665726C';
wwv_flow_api.g_varchar2_table(64) := '61794D6F7573655461726765742E617070656E644368696C6428746869732E6469765F293B0A0A20202F2F2046697820666F72204973737565203135370A2020746869732E626F756E64734368616E6765644C697374656E65725F203D20676F6F676C65';
wwv_flow_api.g_varchar2_table(65) := '2E6D6170732E6576656E742E6164644C697374656E657228746869732E6765744D617028292C2022626F756E64735F6368616E676564222C2066756E6374696F6E202829207B0A20202020634472616767696E674D61704279436C7573746572203D2063';
wwv_flow_api.g_varchar2_table(66) := '4D6F757365446F776E496E436C75737465723B0A20207D293B0A0A2020676F6F676C652E6D6170732E6576656E742E616464446F6D4C697374656E657228746869732E6469765F2C20226D6F757365646F776E222C2066756E6374696F6E202829207B0A';
wwv_flow_api.g_varchar2_table(67) := '20202020634D6F757365446F776E496E436C7573746572203D20747275653B0A20202020634472616767696E674D61704279436C7573746572203D2066616C73653B0A20207D293B0A0A2020676F6F676C652E6D6170732E6576656E742E616464446F6D';
wwv_flow_api.g_varchar2_table(68) := '4C697374656E657228746869732E6469765F2C2022636C69636B222C2066756E6374696F6E20286529207B0A20202020634D6F757365446F776E496E436C7573746572203D2066616C73653B0A202020206966202821634472616767696E674D61704279';
wwv_flow_api.g_varchar2_table(69) := '436C757374657229207B0A20202020202076617220746865426F756E64733B0A202020202020766172206D7A3B0A202020202020766172206D63203D2063436C757374657249636F6E2E636C75737465725F2E6765744D61726B6572436C757374657265';
wwv_flow_api.g_varchar2_table(70) := '7228293B0A2020202020202F2A2A0A202020202020202A2054686973206576656E74206973206669726564207768656E206120636C7573746572206D61726B657220697320636C69636B65642E0A202020202020202A20406E616D65204D61726B657243';
wwv_flow_api.g_varchar2_table(71) := '6C7573746572657223636C69636B0A202020202020202A2040706172616D207B436C75737465727D20632054686520636C757374657220746861742077617320636C69636B65642E0A202020202020202A20406576656E740A202020202020202A2F0A20';
wwv_flow_api.g_varchar2_table(72) := '2020202020676F6F676C652E6D6170732E6576656E742E74726967676572286D632C2022636C69636B222C2063436C757374657249636F6E2E636C75737465725F293B0A202020202020676F6F676C652E6D6170732E6576656E742E7472696767657228';
wwv_flow_api.g_varchar2_table(73) := '6D632C2022636C7573746572636C69636B222C2063436C757374657249636F6E2E636C75737465725F293B202F2F2064657072656361746564206E616D650A0A2020202020202F2F205468652064656661756C7420636C69636B2068616E646C65722066';
wwv_flow_api.g_varchar2_table(74) := '6F6C6C6F77732E2044697361626C652069742062792073657474696E670A2020202020202F2F20746865207A6F6F6D4F6E436C69636B2070726F706572747920746F2066616C73652E0A202020202020696620286D632E6765745A6F6F6D4F6E436C6963';
wwv_flow_api.g_varchar2_table(75) := '6B282929207B0A20202020202020202F2F205A6F6F6D20696E746F2074686520636C75737465722E0A20202020202020206D7A203D206D632E6765744D61785A6F6F6D28293B0A2020202020202020746865426F756E6473203D2063436C757374657249';
wwv_flow_api.g_varchar2_table(76) := '636F6E2E636C75737465725F2E676574426F756E647328293B0A20202020202020206D632E6765744D617028292E666974426F756E647328746865426F756E6473293B0A20202020202020202F2F20546865726520697320612066697820666F72204973';
wwv_flow_api.g_varchar2_table(77) := '7375652031373020686572653A0A202020202020202073657454696D656F75742866756E6374696F6E202829207B0A202020202020202020206D632E6765744D617028292E666974426F756E647328746865426F756E6473293B0A202020202020202020';
wwv_flow_api.g_varchar2_table(78) := '202F2F20446F6E2774207A6F6F6D206265796F6E6420746865206D6178207A6F6F6D206C6576656C0A20202020202020202020696620286D7A20213D3D206E756C6C20262620286D632E6765744D617028292E6765745A6F6F6D2829203E206D7A292920';
wwv_flow_api.g_varchar2_table(79) := '7B0A2020202020202020202020206D632E6765744D617028292E7365745A6F6F6D286D7A202B2031293B0A202020202020202020207D0A20202020202020207D2C20313030293B0A2020202020207D0A0A2020202020202F2F2050726576656E74206576';
wwv_flow_api.g_varchar2_table(80) := '656E742070726F7061676174696F6E20746F20746865206D61703A0A202020202020652E63616E63656C427562626C65203D20747275653B0A20202020202069662028652E73746F7050726F7061676174696F6E29207B0A2020202020202020652E7374';
wwv_flow_api.g_varchar2_table(81) := '6F7050726F7061676174696F6E28293B0A2020202020207D0A202020207D0A20207D293B0A0A2020676F6F676C652E6D6170732E6576656E742E616464446F6D4C697374656E657228746869732E6469765F2C20226D6F7573656F766572222C2066756E';
wwv_flow_api.g_varchar2_table(82) := '6374696F6E202829207B0A20202020766172206D63203D2063436C757374657249636F6E2E636C75737465725F2E6765744D61726B6572436C7573746572657228293B0A202020202F2A2A0A20202020202A2054686973206576656E7420697320666972';
wwv_flow_api.g_varchar2_table(83) := '6564207768656E20746865206D6F757365206D6F766573206F766572206120636C7573746572206D61726B65722E0A20202020202A20406E616D65204D61726B6572436C75737465726572236D6F7573656F7665720A20202020202A2040706172616D20';
wwv_flow_api.g_varchar2_table(84) := '7B436C75737465727D20632054686520636C7573746572207468617420746865206D6F757365206D6F766564206F7665722E0A20202020202A20406576656E740A20202020202A2F0A20202020676F6F676C652E6D6170732E6576656E742E7472696767';
wwv_flow_api.g_varchar2_table(85) := '6572286D632C20226D6F7573656F766572222C2063436C757374657249636F6E2E636C75737465725F293B0A20207D293B0A0A2020676F6F676C652E6D6170732E6576656E742E616464446F6D4C697374656E657228746869732E6469765F2C20226D6F';
wwv_flow_api.g_varchar2_table(86) := '7573656F7574222C2066756E6374696F6E202829207B0A20202020766172206D63203D2063436C757374657249636F6E2E636C75737465725F2E6765744D61726B6572436C7573746572657228293B0A202020202F2A2A0A20202020202A205468697320';
wwv_flow_api.g_varchar2_table(87) := '6576656E74206973206669726564207768656E20746865206D6F757365206D6F766573206F7574206F66206120636C7573746572206D61726B65722E0A20202020202A20406E616D65204D61726B6572436C75737465726572236D6F7573656F75740A20';
wwv_flow_api.g_varchar2_table(88) := '202020202A2040706172616D207B436C75737465727D20632054686520636C7573746572207468617420746865206D6F757365206D6F766564206F7574206F662E0A20202020202A20406576656E740A20202020202A2F0A20202020676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(89) := '6170732E6576656E742E74726967676572286D632C20226D6F7573656F7574222C2063436C757374657249636F6E2E636C75737465725F293B0A20207D293B0A7D3B0A0A0A2F2A2A0A202A2052656D6F766573207468652069636F6E2066726F6D207468';
wwv_flow_api.g_varchar2_table(90) := '6520444F4D2E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E6F6E52656D6F7665203D2066756E6374696F6E202829207B0A202069662028746869732E6469765F20262620746869732E6469765F2E706172656E744E6F646529207B';
wwv_flow_api.g_varchar2_table(91) := '0A20202020746869732E6869646528293B0A20202020676F6F676C652E6D6170732E6576656E742E72656D6F76654C697374656E657228746869732E626F756E64734368616E6765644C697374656E65725F293B0A20202020676F6F676C652E6D617073';
wwv_flow_api.g_varchar2_table(92) := '2E6576656E742E636C656172496E7374616E63654C697374656E65727328746869732E6469765F293B0A20202020746869732E6469765F2E706172656E744E6F64652E72656D6F76654368696C6428746869732E6469765F293B0A20202020746869732E';
wwv_flow_api.g_varchar2_table(93) := '6469765F203D206E756C6C3B0A20207D0A7D3B0A0A0A2F2A2A0A202A204472617773207468652069636F6E2E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E64726177203D2066756E6374696F6E202829207B0A2020696620287468';
wwv_flow_api.g_varchar2_table(94) := '69732E76697369626C655F29207B0A2020202076617220706F73203D20746869732E676574506F7346726F6D4C61744C6E675F28746869732E63656E7465725F293B0A20202020746869732E6469765F2E7374796C652E746F70203D20706F732E79202B';
wwv_flow_api.g_varchar2_table(95) := '20227078223B0A20202020746869732E6469765F2E7374796C652E6C656674203D20706F732E78202B20227078223B0A20207D0A7D3B0A0A0A2F2A2A0A202A204869646573207468652069636F6E2E0A202A2F0A436C757374657249636F6E2E70726F74';
wwv_flow_api.g_varchar2_table(96) := '6F747970652E68696465203D2066756E6374696F6E202829207B0A202069662028746869732E6469765F29207B0A20202020746869732E6469765F2E7374796C652E646973706C6179203D20226E6F6E65223B0A20207D0A2020746869732E7669736962';
wwv_flow_api.g_varchar2_table(97) := '6C655F203D2066616C73653B0A7D3B0A0A0A2F2A2A0A202A20506F736974696F6E7320616E642073686F7773207468652069636F6E2E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E73686F77203D2066756E6374696F6E20282920';
wwv_flow_api.g_varchar2_table(98) := '7B0A202069662028746869732E6469765F29207B0A2020202076617220696D67203D2022223B0A202020202F2F204E4F54453A2076616C756573206D7573742062652073706563696669656420696E20707820756E6974730A2020202076617220627020';
wwv_flow_api.g_varchar2_table(99) := '3D20746869732E6261636B67726F756E64506F736974696F6E5F2E73706C697428222022293B0A202020207661722073707269746548203D207061727365496E742862705B305D2E7472696D28292C203130293B0A202020207661722073707269746556';
wwv_flow_api.g_varchar2_table(100) := '203D207061727365496E742862705B315D2E7472696D28292C203130293B0A2020202076617220706F73203D20746869732E676574506F7346726F6D4C61744C6E675F28746869732E63656E7465725F293B0A20202020746869732E6469765F2E737479';
wwv_flow_api.g_varchar2_table(101) := '6C652E63737354657874203D20746869732E63726561746543737328706F73293B0A20202020696D67203D20223C696D67207372633D2722202B20746869732E75726C5F202B202227207374796C653D27706F736974696F6E3A206162736F6C7574653B';
wwv_flow_api.g_varchar2_table(102) := '20746F703A2022202B2073707269746556202B202270783B206C6566743A2022202B2073707269746548202B202270783B20223B0A202020206966202821746869732E636C75737465725F2E6765744D61726B6572436C7573746572657228292E656E61';
wwv_flow_api.g_varchar2_table(103) := '626C65526574696E6149636F6E735F29207B0A202020202020696D67202B3D2022636C69703A20726563742822202B20282D31202A207370726974655629202B202270782C2022202B2028282D31202A207370726974654829202B20746869732E776964';
wwv_flow_api.g_varchar2_table(104) := '74685F29202B202270782C2022202B0A2020202020202020202028282D31202A207370726974655629202B20746869732E6865696768745F29202B202270782C2022202B20282D31202A207370726974654829202B20227078293B223B0A202020207D0A';
wwv_flow_api.g_varchar2_table(105) := '20202020696D67202B3D2022273E223B0A20202020746869732E6469765F2E696E6E657248544D4C203D20696D67202B20223C646976207374796C653D2722202B0A202020202020202022706F736974696F6E3A206162736F6C7574653B22202B0A2020';
wwv_flow_api.g_varchar2_table(106) := '20202020202022746F703A2022202B20746869732E616E63686F72546578745F5B305D202B202270783B22202B0A2020202020202020226C6566743A2022202B20746869732E616E63686F72546578745F5B315D202B202270783B22202B0A2020202020';
wwv_flow_api.g_varchar2_table(107) := '20202022636F6C6F723A2022202B20746869732E74657874436F6C6F725F202B20223B22202B0A202020202020202022666F6E742D73697A653A2022202B20746869732E7465787453697A655F202B202270783B22202B0A202020202020202022666F6E';
wwv_flow_api.g_varchar2_table(108) := '742D66616D696C793A2022202B20746869732E666F6E7446616D696C795F202B20223B22202B0A202020202020202022666F6E742D7765696768743A2022202B20746869732E666F6E745765696768745F202B20223B22202B0A20202020202020202266';
wwv_flow_api.g_varchar2_table(109) := '6F6E742D7374796C653A2022202B20746869732E666F6E745374796C655F202B20223B22202B0A202020202020202022746578742D6465636F726174696F6E3A2022202B20746869732E746578744465636F726174696F6E5F202B20223B22202B0A2020';
wwv_flow_api.g_varchar2_table(110) := '20202020202022746578742D616C69676E3A2063656E7465723B22202B0A20202020202020202277696474683A2022202B20746869732E77696474685F202B202270783B22202B0A2020202020202020226C696E652D6865696768743A22202B20746869';
wwv_flow_api.g_varchar2_table(111) := '732E6865696768745F202B202270783B22202B0A202020202020202022273E22202B20746869732E73756D735F2E74657874202B20223C2F6469763E223B0A2020202069662028747970656F6620746869732E73756D735F2E7469746C65203D3D3D2022';
wwv_flow_api.g_varchar2_table(112) := '756E646566696E656422207C7C20746869732E73756D735F2E7469746C65203D3D3D20222229207B0A202020202020746869732E6469765F2E7469746C65203D20746869732E636C75737465725F2E6765744D61726B6572436C7573746572657228292E';
wwv_flow_api.g_varchar2_table(113) := '6765745469746C6528293B0A202020207D20656C7365207B0A202020202020746869732E6469765F2E7469746C65203D20746869732E73756D735F2E7469746C653B0A202020207D0A20202020746869732E6469765F2E7374796C652E646973706C6179';
wwv_flow_api.g_varchar2_table(114) := '203D2022223B0A20207D0A2020746869732E76697369626C655F203D20747275653B0A7D3B0A0A0A2F2A2A0A202A2053657473207468652069636F6E207374796C657320746F2074686520617070726F70726961746520656C656D656E7420696E207468';
wwv_flow_api.g_varchar2_table(115) := '65207374796C65732061727261792E0A202A0A202A2040706172616D207B436C757374657249636F6E496E666F7D2073756D73205468652069636F6E206C6162656C207465787420616E64207374796C657320696E6465782E0A202A2F0A436C75737465';
wwv_flow_api.g_varchar2_table(116) := '7249636F6E2E70726F746F747970652E7573655374796C65203D2066756E6374696F6E202873756D7329207B0A2020746869732E73756D735F203D2073756D733B0A202076617220696E646578203D204D6174682E6D617828302C2073756D732E696E64';
wwv_flow_api.g_varchar2_table(117) := '6578202D2031293B0A2020696E646578203D204D6174682E6D696E28746869732E7374796C65735F2E6C656E677468202D20312C20696E646578293B0A2020766172207374796C65203D20746869732E7374796C65735F5B696E6465785D3B0A20207468';
wwv_flow_api.g_varchar2_table(118) := '69732E75726C5F203D207374796C652E75726C3B0A2020746869732E6865696768745F203D207374796C652E6865696768743B0A2020746869732E77696474685F203D207374796C652E77696474683B0A2020746869732E616E63686F72546578745F20';
wwv_flow_api.g_varchar2_table(119) := '3D207374796C652E616E63686F7254657874207C7C205B302C20305D3B0A2020746869732E616E63686F7249636F6E5F203D207374796C652E616E63686F7249636F6E207C7C205B7061727365496E7428746869732E6865696768745F202F20322C2031';
wwv_flow_api.g_varchar2_table(120) := '30292C207061727365496E7428746869732E77696474685F202F20322C203130295D3B0A2020746869732E74657874436F6C6F725F203D207374796C652E74657874436F6C6F72207C7C2022626C61636B223B0A2020746869732E7465787453697A655F';
wwv_flow_api.g_varchar2_table(121) := '203D207374796C652E7465787453697A65207C7C2031313B0A2020746869732E746578744465636F726174696F6E5F203D207374796C652E746578744465636F726174696F6E207C7C20226E6F6E65223B0A2020746869732E666F6E745765696768745F';
wwv_flow_api.g_varchar2_table(122) := '203D207374796C652E666F6E74576569676874207C7C2022626F6C64223B0A2020746869732E666F6E745374796C655F203D207374796C652E666F6E745374796C65207C7C20226E6F726D616C223B0A2020746869732E666F6E7446616D696C795F203D';
wwv_flow_api.g_varchar2_table(123) := '207374796C652E666F6E7446616D696C79207C7C2022417269616C2C73616E732D7365726966223B0A2020746869732E6261636B67726F756E64506F736974696F6E5F203D207374796C652E6261636B67726F756E64506F736974696F6E207C7C202230';
wwv_flow_api.g_varchar2_table(124) := '2030223B0A7D3B0A0A0A2F2A2A0A202A20536574732074686520706F736974696F6E20617420776869636820746F2063656E746572207468652069636F6E2E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4C61744C6E677D206365';
wwv_flow_api.g_varchar2_table(125) := '6E74657220546865206C61746C6E6720746F20736574206173207468652063656E7465722E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E73657443656E746572203D2066756E6374696F6E202863656E74657229207B0A20207468';
wwv_flow_api.g_varchar2_table(126) := '69732E63656E7465725F203D2063656E7465723B0A7D3B0A0A0A2F2A2A0A202A2043726561746573207468652063737354657874207374796C6520706172616D65746572206261736564206F6E2074686520706F736974696F6E206F6620746865206963';
wwv_flow_api.g_varchar2_table(127) := '6F6E2E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E506F696E747D20706F732054686520706F736974696F6E206F66207468652069636F6E2E0A202A204072657475726E207B737472696E677D2054686520435353207374796C65';
wwv_flow_api.g_varchar2_table(128) := '20746578742E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E637265617465437373203D2066756E6374696F6E2028706F7329207B0A2020766172207374796C65203D205B5D3B0A20207374796C652E707573682822637572736F72';
wwv_flow_api.g_varchar2_table(129) := '3A20706F696E7465723B22293B0A20207374796C652E707573682822706F736974696F6E3A206162736F6C7574653B20746F703A2022202B20706F732E79202B202270783B206C6566743A2022202B20706F732E78202B202270783B22293B0A20207374';
wwv_flow_api.g_varchar2_table(130) := '796C652E70757368282277696474683A2022202B20746869732E77696474685F202B202270783B206865696768743A2022202B20746869732E6865696768745F202B202270783B22293B0A202072657475726E207374796C652E6A6F696E282222293B0A';
wwv_flow_api.g_varchar2_table(131) := '7D3B0A0A0A2F2A2A0A202A2052657475726E732074686520706F736974696F6E20617420776869636820746F20706C616365207468652044495620646570656E64696E67206F6E20746865206C61746C6E672E0A202A0A202A2040706172616D207B676F';
wwv_flow_api.g_varchar2_table(132) := '6F676C652E6D6170732E4C61744C6E677D206C61746C6E672054686520706F736974696F6E20696E206C61746C6E672E0A202A204072657475726E207B676F6F676C652E6D6170732E506F696E747D2054686520706F736974696F6E20696E2070697865';
wwv_flow_api.g_varchar2_table(133) := '6C732E0A202A2F0A436C757374657249636F6E2E70726F746F747970652E676574506F7346726F6D4C61744C6E675F203D2066756E6374696F6E20286C61746C6E6729207B0A202076617220706F73203D20746869732E67657450726F6A656374696F6E';
wwv_flow_api.g_varchar2_table(134) := '28292E66726F6D4C61744C6E67546F446976506978656C286C61746C6E67293B0A2020706F732E78202D3D20746869732E616E63686F7249636F6E5F5B315D3B0A2020706F732E79202D3D20746869732E616E63686F7249636F6E5F5B305D3B0A202070';
wwv_flow_api.g_varchar2_table(135) := '6F732E78203D207061727365496E7428706F732E782C203130293B0A2020706F732E79203D207061727365496E7428706F732E792C203130293B0A202072657475726E20706F733B0A7D3B0A0A0A2F2A2A0A202A204372656174657320612073696E676C';
wwv_flow_api.g_varchar2_table(136) := '6520636C75737465722074686174206D616E6167657320612067726F7570206F662070726F78696D617465206D61726B6572732E0A202A20205573656420696E7465726E616C6C792C20646F206E6F742063616C6C207468697320636F6E737472756374';
wwv_flow_api.g_varchar2_table(137) := '6F72206469726563746C792E0A202A2040636F6E7374727563746F720A202A2040706172616D207B4D61726B6572436C757374657265727D206D6320546865203C636F64653E4D61726B6572436C757374657265723C2F636F64653E206F626A65637420';
wwv_flow_api.g_varchar2_table(138) := '7769746820776869636820746869730A202A2020636C7573746572206973206173736F6369617465642E0A202A2F0A66756E6374696F6E20436C7573746572286D6329207B0A2020746869732E6D61726B6572436C757374657265725F203D206D633B0A';
wwv_flow_api.g_varchar2_table(139) := '2020746869732E6D61705F203D206D632E6765744D617028293B0A2020746869732E6772696453697A655F203D206D632E6765744772696453697A6528293B0A2020746869732E6D696E436C757374657253697A655F203D206D632E6765744D696E696D';
wwv_flow_api.g_varchar2_table(140) := '756D436C757374657253697A6528293B0A2020746869732E6176657261676543656E7465725F203D206D632E6765744176657261676543656E74657228293B0A2020746869732E6D61726B6572735F203D205B5D3B0A2020746869732E63656E7465725F';
wwv_flow_api.g_varchar2_table(141) := '203D206E756C6C3B0A2020746869732E626F756E64735F203D206E756C6C3B0A2020746869732E636C757374657249636F6E5F203D206E657720436C757374657249636F6E28746869732C206D632E6765745374796C65732829293B0A7D0A0A0A2F2A2A';
wwv_flow_api.g_varchar2_table(142) := '0A202A2052657475726E7320746865206E756D626572206F66206D61726B657273206D616E616765642062792074686520636C75737465722E20596F752063616E2063616C6C20746869732066726F6D0A202A2061203C636F64653E636C69636B3C2F63';
wwv_flow_api.g_varchar2_table(143) := '6F64653E2C203C636F64653E6D6F7573656F7665723C2F636F64653E2C206F72203C636F64653E6D6F7573656F75743C2F636F64653E206576656E742068616E646C65720A202A20666F7220746865203C636F64653E4D61726B6572436C757374657265';
wwv_flow_api.g_varchar2_table(144) := '723C2F636F64653E206F626A6563742E0A202A0A202A204072657475726E207B6E756D6265727D20546865206E756D626572206F66206D61726B65727320696E2074686520636C75737465722E0A202A2F0A436C75737465722E70726F746F747970652E';
wwv_flow_api.g_varchar2_table(145) := '67657453697A65203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D61726B6572735F2E6C656E6774683B0A7D3B0A0A0A2F2A2A0A202A2052657475726E7320746865206172726179206F66206D61726B657273206D616E61';
wwv_flow_api.g_varchar2_table(146) := '6765642062792074686520636C75737465722E20596F752063616E2063616C6C20746869732066726F6D0A202A2061203C636F64653E636C69636B3C2F636F64653E2C203C636F64653E6D6F7573656F7665723C2F636F64653E2C206F72203C636F6465';
wwv_flow_api.g_varchar2_table(147) := '3E6D6F7573656F75743C2F636F64653E206576656E742068616E646C65720A202A20666F7220746865203C636F64653E4D61726B6572436C757374657265723C2F636F64653E206F626A6563742E0A202A0A202A204072657475726E207B41727261797D';
wwv_flow_api.g_varchar2_table(148) := '20546865206172726179206F66206D61726B65727320696E2074686520636C75737465722E0A202A2F0A436C75737465722E70726F746F747970652E6765744D61726B657273203D2066756E6374696F6E202829207B0A202072657475726E2074686973';
wwv_flow_api.g_varchar2_table(149) := '2E6D61726B6572735F3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652063656E746572206F662074686520636C75737465722E20596F752063616E2063616C6C20746869732066726F6D0A202A2061203C636F64653E636C69636B3C2F63';
wwv_flow_api.g_varchar2_table(150) := '6F64653E2C203C636F64653E6D6F7573656F7665723C2F636F64653E2C206F72203C636F64653E6D6F7573656F75743C2F636F64653E206576656E742068616E646C65720A202A20666F7220746865203C636F64653E4D61726B6572436C757374657265';
wwv_flow_api.g_varchar2_table(151) := '723C2F636F64653E206F626A6563742E0A202A0A202A204072657475726E207B676F6F676C652E6D6170732E4C61744C6E677D205468652063656E746572206F662074686520636C75737465722E0A202A2F0A436C75737465722E70726F746F74797065';
wwv_flow_api.g_varchar2_table(152) := '2E67657443656E746572203D2066756E6374696F6E202829207B0A202072657475726E20746869732E63656E7465725F3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E7320746865206D617020776974682077686963682074686520636C7573746572';
wwv_flow_api.g_varchar2_table(153) := '206973206173736F6369617465642E0A202A0A202A204072657475726E207B676F6F676C652E6D6170732E4D61707D20546865206D61702E0A202A204069676E6F72650A202A2F0A436C75737465722E70726F746F747970652E6765744D6170203D2066';
wwv_flow_api.g_varchar2_table(154) := '756E6374696F6E202829207B0A202072657475726E20746869732E6D61705F3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E7320746865203C636F64653E4D61726B6572436C757374657265723C2F636F64653E206F626A6563742077697468207768';
wwv_flow_api.g_varchar2_table(155) := '6963682074686520636C7573746572206973206173736F6369617465642E0A202A0A202A204072657475726E207B4D61726B6572436C757374657265727D20546865206173736F636961746564206D61726B657220636C757374657265722E0A202A2040';
wwv_flow_api.g_varchar2_table(156) := '69676E6F72650A202A2F0A436C75737465722E70726F746F747970652E6765744D61726B6572436C75737465726572203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D61726B6572436C757374657265725F3B0A7D3B0A0A';
wwv_flow_api.g_varchar2_table(157) := '0A2F2A2A0A202A2052657475726E732074686520626F756E6473206F662074686520636C75737465722E0A202A0A202A204072657475726E207B676F6F676C652E6D6170732E4C61744C6E67426F756E64737D2074686520636C757374657220626F756E';
wwv_flow_api.g_varchar2_table(158) := '64732E0A202A204069676E6F72650A202A2F0A436C75737465722E70726F746F747970652E676574426F756E6473203D2066756E6374696F6E202829207B0A202076617220693B0A202076617220626F756E6473203D206E657720676F6F676C652E6D61';
wwv_flow_api.g_varchar2_table(159) := '70732E4C61744C6E67426F756E647328746869732E63656E7465725F2C20746869732E63656E7465725F293B0A2020766172206D61726B657273203D20746869732E6765744D61726B65727328293B0A2020666F72202869203D20303B2069203C206D61';
wwv_flow_api.g_varchar2_table(160) := '726B6572732E6C656E6774683B20692B2B29207B0A20202020626F756E64732E657874656E64286D61726B6572735B695D2E676574506F736974696F6E2829293B0A20207D0A202072657475726E20626F756E64733B0A7D3B0A0A0A2F2A2A0A202A2052';
wwv_flow_api.g_varchar2_table(161) := '656D6F7665732074686520636C75737465722066726F6D20746865206D61702E0A202A0A202A204069676E6F72650A202A2F0A436C75737465722E70726F746F747970652E72656D6F7665203D2066756E6374696F6E202829207B0A2020746869732E63';
wwv_flow_api.g_varchar2_table(162) := '6C757374657249636F6E5F2E7365744D6170286E756C6C293B0A2020746869732E6D61726B6572735F203D205B5D3B0A202064656C65746520746869732E6D61726B6572735F3B0A7D3B0A0A0A2F2A2A0A202A20416464732061206D61726B657220746F';
wwv_flow_api.g_varchar2_table(163) := '2074686520636C75737465722E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F2062652061646465642E0A202A204072657475726E207B626F6F6C65616E7D20';
wwv_flow_api.g_varchar2_table(164) := '5472756520696620746865206D61726B6572207761732061646465642E0A202A204069676E6F72650A202A2F0A436C75737465722E70726F746F747970652E6164644D61726B6572203D2066756E6374696F6E20286D61726B657229207B0A2020766172';
wwv_flow_api.g_varchar2_table(165) := '20693B0A2020766172206D436F756E743B0A2020766172206D7A3B0A0A202069662028746869732E69734D61726B6572416C726561647941646465645F286D61726B65722929207B0A2020202072657475726E2066616C73653B0A20207D0A0A20206966';
wwv_flow_api.g_varchar2_table(166) := '202821746869732E63656E7465725F29207B0A20202020746869732E63656E7465725F203D206D61726B65722E676574506F736974696F6E28293B0A20202020746869732E63616C63756C617465426F756E64735F28293B0A20207D20656C7365207B0A';
wwv_flow_api.g_varchar2_table(167) := '2020202069662028746869732E6176657261676543656E7465725F29207B0A202020202020766172206C203D20746869732E6D61726B6572735F2E6C656E677468202B20313B0A202020202020766172206C6174203D2028746869732E63656E7465725F';
wwv_flow_api.g_varchar2_table(168) := '2E6C61742829202A20286C202D203129202B206D61726B65722E676574506F736974696F6E28292E6C6174282929202F206C3B0A202020202020766172206C6E67203D2028746869732E63656E7465725F2E6C6E672829202A20286C202D203129202B20';
wwv_flow_api.g_varchar2_table(169) := '6D61726B65722E676574506F736974696F6E28292E6C6E67282929202F206C3B0A202020202020746869732E63656E7465725F203D206E657720676F6F676C652E6D6170732E4C61744C6E67286C61742C206C6E67293B0A202020202020746869732E63';
wwv_flow_api.g_varchar2_table(170) := '616C63756C617465426F756E64735F28293B0A202020207D0A20207D0A0A20206D61726B65722E69734164646564203D20747275653B0A2020746869732E6D61726B6572735F2E70757368286D61726B6572293B0A0A20206D436F756E74203D20746869';
wwv_flow_api.g_varchar2_table(171) := '732E6D61726B6572735F2E6C656E6774683B0A20206D7A203D20746869732E6D61726B6572436C757374657265725F2E6765744D61785A6F6F6D28293B0A2020696620286D7A20213D3D206E756C6C20262620746869732E6D61705F2E6765745A6F6F6D';
wwv_flow_api.g_varchar2_table(172) := '2829203E206D7A29207B0A202020202F2F205A6F6F6D656420696E2070617374206D6178207A6F6F6D2C20736F2073686F7720746865206D61726B65722E0A20202020696620286D61726B65722E6765744D6170282920213D3D20746869732E6D61705F';
wwv_flow_api.g_varchar2_table(173) := '29207B0A2020202020206D61726B65722E7365744D617028746869732E6D61705F293B0A202020207D0A20207D20656C736520696620286D436F756E74203C20746869732E6D696E436C757374657253697A655F29207B0A202020202F2F204D696E2063';
wwv_flow_api.g_varchar2_table(174) := '6C75737465722073697A65206E6F74207265616368656420736F2073686F7720746865206D61726B65722E0A20202020696620286D61726B65722E6765744D6170282920213D3D20746869732E6D61705F29207B0A2020202020206D61726B65722E7365';
wwv_flow_api.g_varchar2_table(175) := '744D617028746869732E6D61705F293B0A202020207D0A20207D20656C736520696620286D436F756E74203D3D3D20746869732E6D696E436C757374657253697A655F29207B0A202020202F2F204869646520746865206D61726B657273207468617420';
wwv_flow_api.g_varchar2_table(176) := '776572652073686F77696E672E0A20202020666F72202869203D20303B2069203C206D436F756E743B20692B2B29207B0A202020202020746869732E6D61726B6572735F5B695D2E7365744D6170286E756C6C293B0A202020207D0A20207D20656C7365';
wwv_flow_api.g_varchar2_table(177) := '207B0A202020206D61726B65722E7365744D6170286E756C6C293B0A20207D0A0A2020746869732E75706461746549636F6E5F28293B0A202072657475726E20747275653B0A7D3B0A0A0A2F2A2A0A202A2044657465726D696E65732069662061206D61';
wwv_flow_api.g_varchar2_table(178) := '726B6572206C6965732077697468696E2074686520636C7573746572277320626F756E64732E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F20636865636B2E';
wwv_flow_api.g_varchar2_table(179) := '0A202A204072657475726E207B626F6F6C65616E7D205472756520696620746865206D61726B6572206C69657320696E2074686520626F756E64732E0A202A204069676E6F72650A202A2F0A436C75737465722E70726F746F747970652E69734D61726B';
wwv_flow_api.g_varchar2_table(180) := '6572496E436C7573746572426F756E6473203D2066756E6374696F6E20286D61726B657229207B0A202072657475726E20746869732E626F756E64735F2E636F6E7461696E73286D61726B65722E676574506F736974696F6E2829293B0A7D3B0A0A0A2F';
wwv_flow_api.g_varchar2_table(181) := '2A2A0A202A2043616C63756C617465732074686520657874656E64656420626F756E6473206F662074686520636C757374657220776974682074686520677269642E0A202A2F0A436C75737465722E70726F746F747970652E63616C63756C617465426F';
wwv_flow_api.g_varchar2_table(182) := '756E64735F203D2066756E6374696F6E202829207B0A202076617220626F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E647328746869732E63656E7465725F2C20746869732E63656E7465725F293B0A2020746869';
wwv_flow_api.g_varchar2_table(183) := '732E626F756E64735F203D20746869732E6D61726B6572436C757374657265725F2E676574457874656E646564426F756E647328626F756E6473293B0A7D3B0A0A0A2F2A2A0A202A20557064617465732074686520636C75737465722069636F6E2E0A20';
wwv_flow_api.g_varchar2_table(184) := '2A2F0A436C75737465722E70726F746F747970652E75706461746549636F6E5F203D2066756E6374696F6E202829207B0A2020766172206D436F756E74203D20746869732E6D61726B6572735F2E6C656E6774683B0A2020766172206D7A203D20746869';
wwv_flow_api.g_varchar2_table(185) := '732E6D61726B6572436C757374657265725F2E6765744D61785A6F6F6D28293B0A0A2020696620286D7A20213D3D206E756C6C20262620746869732E6D61705F2E6765745A6F6F6D2829203E206D7A29207B0A20202020746869732E636C757374657249';
wwv_flow_api.g_varchar2_table(186) := '636F6E5F2E6869646528293B0A2020202072657475726E3B0A20207D0A0A2020696620286D436F756E74203C20746869732E6D696E436C757374657253697A655F29207B0A202020202F2F204D696E20636C75737465722073697A65206E6F7420796574';
wwv_flow_api.g_varchar2_table(187) := '20726561636865642E0A20202020746869732E636C757374657249636F6E5F2E6869646528293B0A2020202072657475726E3B0A20207D0A0A2020766172206E756D5374796C6573203D20746869732E6D61726B6572436C757374657265725F2E676574';
wwv_flow_api.g_varchar2_table(188) := '5374796C657328292E6C656E6774683B0A20207661722073756D73203D20746869732E6D61726B6572436C757374657265725F2E67657443616C63756C61746F72282928746869732E6D61726B6572735F2C206E756D5374796C6573293B0A2020746869';
wwv_flow_api.g_varchar2_table(189) := '732E636C757374657249636F6E5F2E73657443656E74657228746869732E63656E7465725F293B0A2020746869732E636C757374657249636F6E5F2E7573655374796C652873756D73293B0A2020746869732E636C757374657249636F6E5F2E73686F77';
wwv_flow_api.g_varchar2_table(190) := '28293B0A7D3B0A0A0A2F2A2A0A202A2044657465726D696E65732069662061206D61726B65722068617320616C7265616479206265656E20616464656420746F2074686520636C75737465722E0A202A0A202A2040706172616D207B676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(191) := '6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F20636865636B2E0A202A204072657475726E207B626F6F6C65616E7D205472756520696620746865206D61726B65722068617320616C7265616479206265656E20616464';
wwv_flow_api.g_varchar2_table(192) := '65642E0A202A2F0A436C75737465722E70726F746F747970652E69734D61726B6572416C726561647941646465645F203D2066756E6374696F6E20286D61726B657229207B0A202076617220693B0A202069662028746869732E6D61726B6572735F2E69';
wwv_flow_api.g_varchar2_table(193) := '6E6465784F6629207B0A2020202072657475726E20746869732E6D61726B6572735F2E696E6465784F66286D61726B65722920213D3D202D313B0A20207D20656C7365207B0A20202020666F72202869203D20303B2069203C20746869732E6D61726B65';
wwv_flow_api.g_varchar2_table(194) := '72735F2E6C656E6774683B20692B2B29207B0A202020202020696620286D61726B6572203D3D3D20746869732E6D61726B6572735F5B695D29207B0A202020202020202072657475726E20747275653B0A2020202020207D0A202020207D0A20207D0A20';
wwv_flow_api.g_varchar2_table(195) := '2072657475726E2066616C73653B0A7D3B0A0A0A2F2A2A0A202A20406E616D65204D61726B6572436C757374657265724F7074696F6E730A202A2040636C617373205468697320636C61737320726570726573656E747320746865206F7074696F6E616C';
wwv_flow_api.g_varchar2_table(196) := '20706172616D657465722070617373656420746F0A202A2020746865207B406C696E6B204D61726B6572436C757374657265727D20636F6E7374727563746F722E0A202A204070726F7065727479207B6E756D6265727D205B6772696453697A653D3630';
wwv_flow_api.g_varchar2_table(197) := '5D2054686520677269642073697A65206F66206120636C757374657220696E20706978656C732E2054686520677269642069732061207371756172652E0A202A204070726F7065727479207B6E756D6265727D205B6D61785A6F6F6D3D6E756C6C5D2054';
wwv_flow_api.g_varchar2_table(198) := '6865206D6178696D756D207A6F6F6D206C6576656C20617420776869636820636C7573746572696E6720697320656E61626C6564206F720A202A20203C636F64653E6E756C6C3C2F636F64653E20696620636C7573746572696E6720697320746F206265';
wwv_flow_api.g_varchar2_table(199) := '20656E61626C656420617420616C6C207A6F6F6D206C6576656C732E0A202A204070726F7065727479207B626F6F6C65616E7D205B7A6F6F6D4F6E436C69636B3D747275655D205768657468657220746F207A6F6F6D20746865206D6170207768656E20';
wwv_flow_api.g_varchar2_table(200) := '6120636C7573746572206D61726B65722069730A202A2020636C69636B65642E20596F75206D61792077616E7420746F20736574207468697320746F203C636F64653E66616C73653C2F636F64653E20696620796F75206861766520696E7374616C6C65';
wwv_flow_api.g_varchar2_table(201) := '6420612068616E646C65720A202A2020666F7220746865203C636F64653E636C69636B3C2F636F64653E206576656E7420616E64206974206465616C732077697468207A6F6F6D696E67206F6E20697473206F776E2E0A202A204070726F706572747920';
wwv_flow_api.g_varchar2_table(202) := '7B626F6F6C65616E7D205B6176657261676543656E7465723D66616C73655D20576865746865722074686520706F736974696F6E206F66206120636C7573746572206D61726B65722073686F756C642062650A202A202074686520617665726167652070';
wwv_flow_api.g_varchar2_table(203) := '6F736974696F6E206F6620616C6C206D61726B65727320696E2074686520636C75737465722E2049662073657420746F203C636F64653E66616C73653C2F636F64653E2C207468650A202A2020636C7573746572206D61726B657220697320706F736974';
wwv_flow_api.g_varchar2_table(204) := '696F6E656420617420746865206C6F636174696F6E206F6620746865206669727374206D61726B657220616464656420746F2074686520636C75737465722E0A202A204070726F7065727479207B6E756D6265727D205B6D696E696D756D436C75737465';
wwv_flow_api.g_varchar2_table(205) := '7253697A653D325D20546865206D696E696D756D206E756D626572206F66206D61726B657273206E656564656420696E206120636C75737465720A202A20206265666F726520746865206D61726B657273206172652068696464656E20616E6420612063';
wwv_flow_api.g_varchar2_table(206) := '6C7573746572206D61726B657220617070656172732E0A202A204070726F7065727479207B626F6F6C65616E7D205B69676E6F726548696464656E3D66616C73655D205768657468657220746F2069676E6F72652068696464656E206D61726B65727320';
wwv_flow_api.g_varchar2_table(207) := '696E20636C7573746572732E20596F750A202A20206D61792077616E7420746F20736574207468697320746F203C636F64653E747275653C2F636F64653E20746F20656E7375726520746861742068696464656E206D61726B65727320617265206E6F74';
wwv_flow_api.g_varchar2_table(208) := '20696E636C756465640A202A2020696E20746865206D61726B657220636F756E7420746861742061707065617273206F6E206120636C7573746572206D61726B657220287468697320636F756E74206973207468652076616C7565206F66207468650A20';
wwv_flow_api.g_varchar2_table(209) := '2A20203C636F64653E746578743C2F636F64653E2070726F7065727479206F662074686520726573756C742072657475726E6564206279207468652064656661756C74203C636F64653E63616C63756C61746F723C2F636F64653E292E0A202A20204966';
wwv_flow_api.g_varchar2_table(210) := '2073657420746F203C636F64653E747275653C2F636F64653E20616E6420796F75206368616E676520746865207669736962696C697479206F662061206D61726B6572206265696E6720636C757374657265642C2062650A202A20207375726520746F20';
wwv_flow_api.g_varchar2_table(211) := '616C736F2063616C6C203C636F64653E4D61726B6572436C757374657265722E72657061696E7428293C2F636F64653E2E0A202A204070726F7065727479207B737472696E677D205B7469746C653D22225D2054686520746F6F6C74697020746F206469';
wwv_flow_api.g_varchar2_table(212) := '73706C6179207768656E20746865206D6F757365206D6F766573206F766572206120636C75737465720A202A20206D61726B65722E2028416C7465726E61746976656C792C20796F752063616E20757365206120637573746F6D203C636F64653E63616C';
wwv_flow_api.g_varchar2_table(213) := '63756C61746F723C2F636F64653E2066756E6374696F6E20746F207370656369667920610A202A2020646966666572656E7420746F6F6C74697020666F72206561636820636C7573746572206D61726B65722E290A202A204070726F7065727479207B66';
wwv_flow_api.g_varchar2_table(214) := '756E6374696F6E7D205B63616C63756C61746F723D4D61726B6572436C757374657265722E43414C43554C41544F525D205468652066756E6374696F6E207573656420746F2064657465726D696E650A202A2020746865207465787420746F2062652064';
wwv_flow_api.g_varchar2_table(215) := '6973706C61796564206F6E206120636C7573746572206D61726B657220616E642074686520696E64657820696E6469636174696E67207768696368207374796C6520746F207573650A202A2020666F722074686520636C7573746572206D61726B65722E';
wwv_flow_api.g_varchar2_table(216) := '2054686520696E70757420706172616D657465727320666F72207468652066756E6374696F6E206172652028312920746865206172726179206F66206D61726B6572730A202A2020726570726573656E746564206279206120636C7573746572206D6172';
wwv_flow_api.g_varchar2_table(217) := '6B657220616E642028322920746865206E756D626572206F6620636C75737465722069636F6E207374796C65732E2049742072657475726E7320610A202A20207B406C696E6B20436C757374657249636F6E496E666F7D206F626A6563742E2054686520';
wwv_flow_api.g_varchar2_table(218) := '64656661756C74203C636F64653E63616C63756C61746F723C2F636F64653E2072657475726E7320610A202A20203C636F64653E746578743C2F636F64653E2070726F706572747920776869636820697320746865206E756D626572206F66206D61726B';
wwv_flow_api.g_varchar2_table(219) := '65727320696E2074686520636C757374657220616E6420616E0A202A20203C636F64653E696E6465783C2F636F64653E2070726F7065727479207768696368206973206F6E6520686967686572207468616E20746865206C6F7765737420696E74656765';
wwv_flow_api.g_varchar2_table(220) := '72207375636820746861740A202A20203C636F64653E31305E693C2F636F64653E206578636565647320746865206E756D626572206F66206D61726B65727320696E2074686520636C75737465722C206F72207468652073697A65206F66207468652073';
wwv_flow_api.g_varchar2_table(221) := '74796C65730A202A202061727261792C20776869636865766572206973206C6573732E20546865203C636F64653E7374796C65733C2F636F64653E20617272617920656C656D656E7420757365642068617320616E20696E646578206F660A202A20203C';
wwv_flow_api.g_varchar2_table(222) := '636F64653E696E6465783C2F636F64653E206D696E757320312E20466F72206578616D706C652C207468652064656661756C74203C636F64653E63616C63756C61746F723C2F636F64653E2072657475726E7320610A202A20203C636F64653E74657874';
wwv_flow_api.g_varchar2_table(223) := '3C2F636F64653E2076616C7565206F66203C636F64653E22313235223C2F636F64653E20616E6420616E203C636F64653E696E6465783C2F636F64653E206F66203C636F64653E333C2F636F64653E0A202A2020666F72206120636C7573746572206963';
wwv_flow_api.g_varchar2_table(224) := '6F6E20726570726573656E74696E6720313235206D61726B65727320736F2074686520656C656D656E74207573656420696E20746865203C636F64653E7374796C65733C2F636F64653E0A202A20206172726179206973203C636F64653E323C2F636F64';
wwv_flow_api.g_varchar2_table(225) := '653E2E2041203C636F64653E63616C63756C61746F723C2F636F64653E206D617920616C736F2072657475726E2061203C636F64653E7469746C653C2F636F64653E0A202A202070726F7065727479207468617420636F6E7461696E7320746865207465';
wwv_flow_api.g_varchar2_table(226) := '7874206F662074686520746F6F6C74697020746F206265207573656420666F722074686520636C7573746572206D61726B65722E2049660A202A2020203C636F64653E7469746C653C2F636F64653E206973206E6F7420646566696E65642C2074686520';
wwv_flow_api.g_varchar2_table(227) := '746F6F6C7469702069732073657420746F207468652076616C7565206F6620746865203C636F64653E7469746C653C2F636F64653E0A202A20202070726F706572747920666F7220746865204D61726B6572436C757374657265722E0A202A204070726F';
wwv_flow_api.g_varchar2_table(228) := '7065727479207B737472696E677D205B636C7573746572436C6173733D22636C7573746572225D20546865206E616D65206F66207468652043535320636C61737320646566696E696E672067656E6572616C207374796C65730A202A2020666F72207468';
wwv_flow_api.g_varchar2_table(229) := '6520636C7573746572206D61726B6572732E20557365207468697320636C61737320746F20646566696E6520435353207374796C6573207468617420617265206E6F74207365742075702062792074686520636F64650A202A2020746861742070726F63';
wwv_flow_api.g_varchar2_table(230) := '657373657320746865203C636F64653E7374796C65733C2F636F64653E2061727261792E0A202A204070726F7065727479207B41727261797D205B7374796C65735D20416E206172726179206F66207B406C696E6B20436C757374657249636F6E537479';
wwv_flow_api.g_varchar2_table(231) := '6C657D20656C656D656E747320646566696E696E6720746865207374796C65730A202A20206F662074686520636C7573746572206D61726B65727320746F20626520757365642E2054686520656C656D656E7420746F206265207573656420746F207374';
wwv_flow_api.g_varchar2_table(232) := '796C65206120676976656E20636C7573746572206D61726B65720A202A202069732064657465726D696E6564206279207468652066756E6374696F6E20646566696E656420627920746865203C636F64653E63616C63756C61746F723C2F636F64653E20';
wwv_flow_api.g_varchar2_table(233) := '70726F70657274792E0A202A20205468652064656661756C7420697320616E206172726179206F66207B406C696E6B20436C757374657249636F6E5374796C657D20656C656D656E74732077686F73652070726F70657274696573206172652064657269';
wwv_flow_api.g_varchar2_table(234) := '7665640A202A202066726F6D207468652076616C75657320666F72203C636F64653E696D616765506174683C2F636F64653E2C203C636F64653E696D616765457874656E73696F6E3C2F636F64653E2C20616E640A202A20203C636F64653E696D616765';
wwv_flow_api.g_varchar2_table(235) := '53697A65733C2F636F64653E2E0A202A204070726F7065727479207B626F6F6C65616E7D205B656E61626C65526574696E6149636F6E733D66616C73655D205768657468657220746F20616C6C6F772074686520757365206F6620636C75737465722069';
wwv_flow_api.g_varchar2_table(236) := '636F6E7320746861740A202A20686176652073697A657320746861742061726520736F6D65206D756C7469706C6520287479706963616C6C7920646F75626C6529206F662074686569722061637475616C20646973706C61792073697A652E2049636F6E';
wwv_flow_api.g_varchar2_table(237) := '7320737563680A202A206173207468657365206C6F6F6B20626574746572207768656E20766965776564206F6E20686967682D7265736F6C7574696F6E206D6F6E69746F72732073756368206173204170706C65277320526574696E6120646973706C61';
wwv_flow_api.g_varchar2_table(238) := '79732E0A202A204E6F74653A20696620746869732070726F7065727479206973203C636F64653E747275653C2F636F64653E2C20737072697465732063616E6E6F74206265207573656420617320636C75737465722069636F6E732E0A202A204070726F';
wwv_flow_api.g_varchar2_table(239) := '7065727479207B6E756D6265727D205B626174636853697A653D4D61726B6572436C757374657265722E42415443485F53495A455D2053657420746869732070726F706572747920746F207468650A202A20206E756D626572206F66206D61726B657273';
wwv_flow_api.g_varchar2_table(240) := '20746F2062652070726F63657373656420696E20612073696E676C65206261746368207768656E207573696E6720612062726F77736572206F74686572207468616E0A202A2020496E7465726E6574204578706C6F7265722028666F7220496E7465726E';
wwv_flow_api.g_varchar2_table(241) := '6574204578706C6F7265722C207573652074686520626174636853697A6549452070726F706572747920696E7374656164292E0A202A204070726F7065727479207B6E756D6265727D205B626174636853697A6549453D4D61726B6572436C7573746572';
wwv_flow_api.g_varchar2_table(242) := '65722E42415443485F53495A455F49455D205768656E20496E7465726E6574204578706C6F7265722069730A202A20206265696E6720757365642C206D61726B657273206172652070726F63657373656420696E207365766572616C2062617463686573';
wwv_flow_api.g_varchar2_table(243) := '2077697468206120736D616C6C2064656C617920696E736572746564206265747765656E0A202A20206561636820626174636820696E20616E20617474656D707420746F2061766F6964204A6176617363726970742074696D656F7574206572726F7273';
wwv_flow_api.g_varchar2_table(244) := '2E2053657420746869732070726F706572747920746F207468650A202A20206E756D626572206F66206D61726B65727320746F2062652070726F63657373656420696E20612073696E676C652062617463683B2073656C65637420617320686967682061';
wwv_flow_api.g_varchar2_table(245) := '206E756D62657220617320796F752063616E0A202A2020776974686F75742063617573696E6720612074696D656F7574206572726F7220696E207468652062726F777365722E2054686973206E756D626572206D69676874206E65656420746F20626520';
wwv_flow_api.g_varchar2_table(246) := '6173206C6F77206173203130300A202A202069662031352C303030206D61726B65727320617265206265696E67206D616E616765642C20666F72206578616D706C652E0A202A204070726F7065727479207B737472696E677D205B696D61676550617468';
wwv_flow_api.g_varchar2_table(247) := '3D4D61726B6572436C757374657265722E494D4147455F504154485D0A202A20205468652066756C6C2055524C206F662074686520726F6F74206E616D65206F66207468652067726F7570206F6620696D6167652066696C657320746F2075736520666F';
wwv_flow_api.g_varchar2_table(248) := '7220636C75737465722069636F6E732E0A202A202054686520636F6D706C6574652066696C65206E616D65206973206F662074686520666F726D203C636F64653E696D616765506174683C2F636F64653E6E2E3C636F64653E696D616765457874656E73';
wwv_flow_api.g_varchar2_table(249) := '696F6E3C2F636F64653E0A202A20207768657265206E2069732074686520696D6167652066696C65206E756D6265722028312C20322C206574632E292E0A202A204070726F7065727479207B737472696E677D205B696D616765457874656E73696F6E3D';
wwv_flow_api.g_varchar2_table(250) := '4D61726B6572436C757374657265722E494D4147455F455854454E53494F4E5D0A202A202054686520657874656E73696F6E206E616D6520666F722074686520636C75737465722069636F6E20696D6167652066696C65732028652E672E2C203C636F64';
wwv_flow_api.g_varchar2_table(251) := '653E22706E67223C2F636F64653E206F720A202A20203C636F64653E226A7067223C2F636F64653E292E0A202A204070726F7065727479207B41727261797D205B696D61676553697A65733D4D61726B6572436C757374657265722E494D4147455F5349';
wwv_flow_api.g_varchar2_table(252) := '5A45535D0A202A2020416E206172726179206F66206E756D6265727320636F6E7461696E696E672074686520776964746873206F66207468652067726F7570206F660A202A20203C636F64653E696D616765506174683C2F636F64653E6E2E3C636F6465';
wwv_flow_api.g_varchar2_table(253) := '3E696D616765457874656E73696F6E3C2F636F64653E20696D6167652066696C65732E0A202A20202854686520696D616765732061726520617373756D656420746F206265207371756172652E290A202A2F0A2F2A2A0A202A2043726561746573206120';
wwv_flow_api.g_varchar2_table(254) := '4D61726B6572436C75737465726572206F626A656374207769746820746865206F7074696F6E732073706563696669656420696E207B406C696E6B204D61726B6572436C757374657265724F7074696F6E737D2E0A202A2040636F6E7374727563746F72';
wwv_flow_api.g_varchar2_table(255) := '0A202A2040657874656E647320676F6F676C652E6D6170732E4F7665726C6179566965770A202A2040706172616D207B676F6F676C652E6D6170732E4D61707D206D61702054686520476F6F676C65206D617020746F2061747461636820746F2E0A202A';
wwv_flow_api.g_varchar2_table(256) := '2040706172616D207B41727261792E3C676F6F676C652E6D6170732E4D61726B65723E7D205B6F70745F6D61726B6572735D20546865206D61726B65727320746F20626520616464656420746F2074686520636C75737465722E0A202A2040706172616D';
wwv_flow_api.g_varchar2_table(257) := '207B4D61726B6572436C757374657265724F7074696F6E737D205B6F70745F6F7074696F6E735D20546865206F7074696F6E616C20706172616D65746572732E0A202A2F0A66756E6374696F6E204D61726B6572436C75737465726572286D61702C206F';
wwv_flow_api.g_varchar2_table(258) := '70745F6D61726B6572732C206F70745F6F7074696F6E7329207B0A20202F2F204D61726B6572436C7573746572657220696D706C656D656E747320676F6F676C652E6D6170732E4F7665726C61795669657720696E746572666163652E20576520757365';
wwv_flow_api.g_varchar2_table(259) := '207468650A20202F2F20657874656E642066756E6374696F6E20746F20657874656E64204D61726B6572436C75737465726572207769746820676F6F676C652E6D6170732E4F7665726C6179566965770A20202F2F2062656361757365206974206D6967';
wwv_flow_api.g_varchar2_table(260) := '6874206E6F7420616C7761797320626520617661696C61626C65207768656E2074686520636F646520697320646566696E656420736F2077650A20202F2F206C6F6F6B20666F7220697420617420746865206C61737420706F737369626C65206D6F6D65';
wwv_flow_api.g_varchar2_table(261) := '6E742E20496620697420646F65736E2774206578697374206E6F77207468656E0A20202F2F207468657265206973206E6F20706F696E7420676F696E67206168656164203A290A2020746869732E657874656E64284D61726B6572436C75737465726572';
wwv_flow_api.g_varchar2_table(262) := '2C20676F6F676C652E6D6170732E4F7665726C617956696577293B0A0A20206F70745F6D61726B657273203D206F70745F6D61726B657273207C7C205B5D3B0A20206F70745F6F7074696F6E73203D206F70745F6F7074696F6E73207C7C207B7D3B0A0A';
wwv_flow_api.g_varchar2_table(263) := '2020746869732E6D61726B6572735F203D205B5D3B0A2020746869732E636C7573746572735F203D205B5D3B0A2020746869732E6C697374656E6572735F203D205B5D3B0A2020746869732E6163746976654D61705F203D206E756C6C3B0A2020746869';
wwv_flow_api.g_varchar2_table(264) := '732E72656164795F203D2066616C73653B0A0A2020746869732E6772696453697A655F203D206F70745F6F7074696F6E732E6772696453697A65207C7C2036303B0A2020746869732E6D696E436C757374657253697A655F203D206F70745F6F7074696F';
wwv_flow_api.g_varchar2_table(265) := '6E732E6D696E696D756D436C757374657253697A65207C7C20323B0A2020746869732E6D61785A6F6F6D5F203D206F70745F6F7074696F6E732E6D61785A6F6F6D207C7C206E756C6C3B0A2020746869732E7374796C65735F203D206F70745F6F707469';
wwv_flow_api.g_varchar2_table(266) := '6F6E732E7374796C6573207C7C205B5D3B0A2020746869732E7469746C655F203D206F70745F6F7074696F6E732E7469746C65207C7C2022223B0A2020746869732E7A6F6F6D4F6E436C69636B5F203D20747275653B0A2020696620286F70745F6F7074';
wwv_flow_api.g_varchar2_table(267) := '696F6E732E7A6F6F6D4F6E436C69636B20213D3D20756E646566696E656429207B0A20202020746869732E7A6F6F6D4F6E436C69636B5F203D206F70745F6F7074696F6E732E7A6F6F6D4F6E436C69636B3B0A20207D0A2020746869732E617665726167';
wwv_flow_api.g_varchar2_table(268) := '6543656E7465725F203D2066616C73653B0A2020696620286F70745F6F7074696F6E732E6176657261676543656E74657220213D3D20756E646566696E656429207B0A20202020746869732E6176657261676543656E7465725F203D206F70745F6F7074';
wwv_flow_api.g_varchar2_table(269) := '696F6E732E6176657261676543656E7465723B0A20207D0A2020746869732E69676E6F726548696464656E5F203D2066616C73653B0A2020696620286F70745F6F7074696F6E732E69676E6F726548696464656E20213D3D20756E646566696E65642920';
wwv_flow_api.g_varchar2_table(270) := '7B0A20202020746869732E69676E6F726548696464656E5F203D206F70745F6F7074696F6E732E69676E6F726548696464656E3B0A20207D0A2020746869732E656E61626C65526574696E6149636F6E735F203D2066616C73653B0A2020696620286F70';
wwv_flow_api.g_varchar2_table(271) := '745F6F7074696F6E732E656E61626C65526574696E6149636F6E7320213D3D20756E646566696E656429207B0A20202020746869732E656E61626C65526574696E6149636F6E735F203D206F70745F6F7074696F6E732E656E61626C65526574696E6149';
wwv_flow_api.g_varchar2_table(272) := '636F6E733B0A20207D0A2020746869732E696D616765506174685F203D206F70745F6F7074696F6E732E696D61676550617468207C7C204D61726B6572436C757374657265722E494D4147455F504154483B0A2020746869732E696D616765457874656E';
wwv_flow_api.g_varchar2_table(273) := '73696F6E5F203D206F70745F6F7074696F6E732E696D616765457874656E73696F6E207C7C204D61726B6572436C757374657265722E494D4147455F455854454E53494F4E3B0A2020746869732E696D61676553697A65735F203D206F70745F6F707469';
wwv_flow_api.g_varchar2_table(274) := '6F6E732E696D61676553697A6573207C7C204D61726B6572436C757374657265722E494D4147455F53495A45533B0A2020746869732E63616C63756C61746F725F203D206F70745F6F7074696F6E732E63616C63756C61746F72207C7C204D61726B6572';
wwv_flow_api.g_varchar2_table(275) := '436C757374657265722E43414C43554C41544F523B0A2020746869732E626174636853697A655F203D206F70745F6F7074696F6E732E626174636853697A65207C7C204D61726B6572436C757374657265722E42415443485F53495A453B0A2020746869';
wwv_flow_api.g_varchar2_table(276) := '732E626174636853697A6549455F203D206F70745F6F7074696F6E732E626174636853697A654945207C7C204D61726B6572436C757374657265722E42415443485F53495A455F49453B0A2020746869732E636C7573746572436C6173735F203D206F70';
wwv_flow_api.g_varchar2_table(277) := '745F6F7074696F6E732E636C7573746572436C617373207C7C2022636C7573746572223B0A0A2020696620286E6176696761746F722E757365724167656E742E746F4C6F7765724361736528292E696E6465784F6628226D736965222920213D3D202D31';
wwv_flow_api.g_varchar2_table(278) := '29207B0A202020202F2F2054727920746F2061766F69642049452074696D656F7574207768656E2070726F63657373696E6720612068756765206E756D626572206F66206D61726B6572733A0A20202020746869732E626174636853697A655F203D2074';
wwv_flow_api.g_varchar2_table(279) := '6869732E626174636853697A6549455F3B0A20207D0A0A2020746869732E73657475705374796C65735F28293B0A0A2020746869732E6164644D61726B657273286F70745F6D61726B6572732C2074727565293B0A2020746869732E7365744D6170286D';
wwv_flow_api.g_varchar2_table(280) := '6170293B202F2F204E6F74653A207468697320636175736573206F6E41646420746F2062652063616C6C65640A7D0A0A0A2F2A2A0A202A20496D706C656D656E746174696F6E206F6620746865206F6E41646420696E74657266616365206D6574686F64';
wwv_flow_api.g_varchar2_table(281) := '2E0A202A204069676E6F72650A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6F6E416464203D2066756E6374696F6E202829207B0A202076617220634D61726B6572436C75737465726572203D20746869733B0A0A202074';
wwv_flow_api.g_varchar2_table(282) := '6869732E6163746976654D61705F203D20746869732E6765744D617028293B0A2020746869732E72656164795F203D20747275653B0A0A2020746869732E72657061696E7428293B0A0A20202F2F2041646420746865206D6170206576656E74206C6973';
wwv_flow_api.g_varchar2_table(283) := '74656E6572730A2020746869732E6C697374656E6572735F203D205B0A20202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6765744D617028292C20227A6F6F6D5F6368616E676564222C2066756E637469';
wwv_flow_api.g_varchar2_table(284) := '6F6E202829207B0A202020202020634D61726B6572436C757374657265722E726573657456696577706F72745F2866616C7365293B0A2020202020202F2F20576F726B61726F756E6420666F72207468697320476F6F676C65206275673A207768656E20';
wwv_flow_api.g_varchar2_table(285) := '6D6170206973206174206C6576656C203020616E6420222D22206F660A2020202020202F2F207A6F6F6D20736C6964657220697320636C69636B65642C206120227A6F6F6D5F6368616E67656422206576656E74206973206669726564206576656E2074';
wwv_flow_api.g_varchar2_table(286) := '686F7567680A2020202020202F2F20746865206D617020646F65736E2774207A6F6F6D206F757420616E7920667572746865722E20496E207468697320736974756174696F6E2C206E6F202269646C65220A2020202020202F2F206576656E7420697320';
wwv_flow_api.g_varchar2_table(287) := '74726967676572656420736F2074686520636C7573746572206D61726B65727320746861742068617665206265656E2072656D6F7665640A2020202020202F2F20646F206E6F7420676574207265647261776E2E2053616D6520676F657320666F722061';
wwv_flow_api.g_varchar2_table(288) := '207A6F6F6D20696E206174206D61785A6F6F6D2E0A20202020202069662028746869732E6765745A6F6F6D2829203D3D3D2028746869732E67657428226D696E5A6F6F6D2229207C7C203029207C7C20746869732E6765745A6F6F6D2829203D3D3D2074';
wwv_flow_api.g_varchar2_table(289) := '6869732E67657428226D61785A6F6F6D222929207B0A2020202020202020676F6F676C652E6D6170732E6576656E742E7472696767657228746869732C202269646C6522293B0A2020202020207D0A202020207D292C0A20202020676F6F676C652E6D61';
wwv_flow_api.g_varchar2_table(290) := '70732E6576656E742E6164644C697374656E657228746869732E6765744D617028292C202269646C65222C2066756E6374696F6E202829207B0A202020202020634D61726B6572436C757374657265722E7265647261775F28293B0A202020207D290A20';
wwv_flow_api.g_varchar2_table(291) := '205D3B0A7D3B0A0A0A2F2A2A0A202A20496D706C656D656E746174696F6E206F6620746865206F6E52656D6F766520696E74657266616365206D6574686F642E0A202A2052656D6F766573206D6170206576656E74206C697374656E65727320616E6420';
wwv_flow_api.g_varchar2_table(292) := '616C6C20636C75737465722069636F6E732066726F6D2074686520444F4D2E0A202A20416C6C206D616E61676564206D61726B6572732061726520616C736F20707574206261636B206F6E20746865206D61702E0A202A204069676E6F72650A202A2F0A';
wwv_flow_api.g_varchar2_table(293) := '4D61726B6572436C757374657265722E70726F746F747970652E6F6E52656D6F7665203D2066756E6374696F6E202829207B0A202076617220693B0A0A20202F2F2050757420616C6C20746865206D616E61676564206D61726B657273206261636B206F';
wwv_flow_api.g_varchar2_table(294) := '6E20746865206D61703A0A2020666F72202869203D20303B2069203C20746869732E6D61726B6572735F2E6C656E6774683B20692B2B29207B0A2020202069662028746869732E6D61726B6572735F5B695D2E6765744D6170282920213D3D2074686973';
wwv_flow_api.g_varchar2_table(295) := '2E6163746976654D61705F29207B0A202020202020746869732E6D61726B6572735F5B695D2E7365744D617028746869732E6163746976654D61705F293B0A202020207D0A20207D0A0A20202F2F2052656D6F766520616C6C20636C7573746572733A0A';
wwv_flow_api.g_varchar2_table(296) := '2020666F72202869203D20303B2069203C20746869732E636C7573746572735F2E6C656E6774683B20692B2B29207B0A20202020746869732E636C7573746572735F5B695D2E72656D6F766528293B0A20207D0A2020746869732E636C7573746572735F';
wwv_flow_api.g_varchar2_table(297) := '203D205B5D3B0A0A20202F2F2052656D6F7665206D6170206576656E74206C697374656E6572733A0A2020666F72202869203D20303B2069203C20746869732E6C697374656E6572735F2E6C656E6774683B20692B2B29207B0A20202020676F6F676C65';
wwv_flow_api.g_varchar2_table(298) := '2E6D6170732E6576656E742E72656D6F76654C697374656E657228746869732E6C697374656E6572735F5B695D293B0A20207D0A2020746869732E6C697374656E6572735F203D205B5D3B0A0A2020746869732E6163746976654D61705F203D206E756C';
wwv_flow_api.g_varchar2_table(299) := '6C3B0A2020746869732E72656164795F203D2066616C73653B0A7D3B0A0A0A2F2A2A0A202A20496D706C656D656E746174696F6E206F6620746865206472617720696E74657266616365206D6574686F642E0A202A204069676E6F72650A202A2F0A4D61';
wwv_flow_api.g_varchar2_table(300) := '726B6572436C757374657265722E70726F746F747970652E64726177203D2066756E6374696F6E202829207B7D3B0A0A0A2F2A2A0A202A205365747320757020746865207374796C6573206F626A6563742E0A202A2F0A4D61726B6572436C7573746572';
wwv_flow_api.g_varchar2_table(301) := '65722E70726F746F747970652E73657475705374796C65735F203D2066756E6374696F6E202829207B0A202076617220692C2073697A653B0A202069662028746869732E7374796C65735F2E6C656E677468203E203029207B0A2020202072657475726E';
wwv_flow_api.g_varchar2_table(302) := '3B0A20207D0A0A2020666F72202869203D20303B2069203C20746869732E696D61676553697A65735F2E6C656E6774683B20692B2B29207B0A2020202073697A65203D20746869732E696D61676553697A65735F5B695D3B0A20202020746869732E7374';
wwv_flow_api.g_varchar2_table(303) := '796C65735F2E70757368287B0A20202020202075726C3A20746869732E696D616765506174685F202B202869202B203129202B20222E22202B20746869732E696D616765457874656E73696F6E5F2C0A2020202020206865696768743A2073697A652C0A';
wwv_flow_api.g_varchar2_table(304) := '20202020202077696474683A2073697A650A202020207D293B0A20207D0A7D3B0A0A0A2F2A2A0A202A20204669747320746865206D617020746F2074686520626F756E6473206F6620746865206D61726B657273206D616E616765642062792074686520';
wwv_flow_api.g_varchar2_table(305) := '636C757374657265722E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6669744D6170546F4D61726B657273203D2066756E6374696F6E202829207B0A202076617220693B0A2020766172206D61726B657273203D207468';
wwv_flow_api.g_varchar2_table(306) := '69732E6765744D61726B65727328293B0A202076617220626F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E647328293B0A2020666F72202869203D20303B2069203C206D61726B6572732E6C656E6774683B20692B';
wwv_flow_api.g_varchar2_table(307) := '2B29207B0A20202020626F756E64732E657874656E64286D61726B6572735B695D2E676574506F736974696F6E2829293B0A20207D0A0A2020746869732E6765744D617028292E666974426F756E647328626F756E6473293B0A7D3B0A0A0A2F2A2A0A20';
wwv_flow_api.g_varchar2_table(308) := '2A2052657475726E73207468652076616C7565206F6620746865203C636F64653E6772696453697A653C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B6E756D6265727D2054686520677269642073697A652E0A202A2F';
wwv_flow_api.g_varchar2_table(309) := '0A4D61726B6572436C757374657265722E70726F746F747970652E6765744772696453697A65203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6772696453697A655F3B0A7D3B0A0A0A2F2A2A0A202A205365747320746865';
wwv_flow_api.g_varchar2_table(310) := '2076616C7565206F6620746865203C636F64653E6772696453697A653C2F636F64653E2070726F70657274792E0A202A0A202A2040706172616D207B6E756D6265727D206772696453697A652054686520677269642073697A652E0A202A2F0A4D61726B';
wwv_flow_api.g_varchar2_table(311) := '6572436C757374657265722E70726F746F747970652E7365744772696453697A65203D2066756E6374696F6E20286772696453697A6529207B0A2020746869732E6772696453697A655F203D206772696453697A653B0A7D3B0A0A0A2F2A2A0A202A2052';
wwv_flow_api.g_varchar2_table(312) := '657475726E73207468652076616C7565206F6620746865203C636F64653E6D696E696D756D436C757374657253697A653C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B6E756D6265727D20546865206D696E696D756D';
wwv_flow_api.g_varchar2_table(313) := '20636C75737465722073697A652E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6765744D696E696D756D436C757374657253697A65203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D696E';
wwv_flow_api.g_varchar2_table(314) := '436C757374657253697A655F3B0A7D3B0A0A2F2A2A0A202A2053657473207468652076616C7565206F6620746865203C636F64653E6D696E696D756D436C757374657253697A653C2F636F64653E2070726F70657274792E0A202A0A202A204070617261';
wwv_flow_api.g_varchar2_table(315) := '6D207B6E756D6265727D206D696E696D756D436C757374657253697A6520546865206D696E696D756D20636C75737465722073697A652E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E7365744D696E696D756D436C7573';
wwv_flow_api.g_varchar2_table(316) := '74657253697A65203D2066756E6374696F6E20286D696E696D756D436C757374657253697A6529207B0A2020746869732E6D696E436C757374657253697A655F203D206D696E696D756D436C757374657253697A653B0A7D3B0A0A0A2F2A2A0A202A2020';
wwv_flow_api.g_varchar2_table(317) := '52657475726E73207468652076616C7565206F6620746865203C636F64653E6D61785A6F6F6D3C2F636F64653E2070726F70657274792E0A202A0A202A20204072657475726E207B6E756D6265727D20546865206D6178696D756D207A6F6F6D206C6576';
wwv_flow_api.g_varchar2_table(318) := '656C2E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6765744D61785A6F6F6D203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D61785A6F6F6D5F3B0A7D3B0A0A0A2F2A2A0A202A20205365';
wwv_flow_api.g_varchar2_table(319) := '7473207468652076616C7565206F6620746865203C636F64653E6D61785A6F6F6D3C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B6E756D6265727D206D61785A6F6F6D20546865206D6178696D756D207A6F6F6D206C';
wwv_flow_api.g_varchar2_table(320) := '6576656C2E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E7365744D61785A6F6F6D203D2066756E6374696F6E20286D61785A6F6F6D29207B0A2020746869732E6D61785A6F6F6D5F203D206D61785A6F6F6D3B0A7D3B0A';
wwv_flow_api.g_varchar2_table(321) := '0A0A2F2A2A0A202A202052657475726E73207468652076616C7565206F6620746865203C636F64653E7374796C65733C2F636F64653E2070726F70657274792E0A202A0A202A20204072657475726E207B41727261797D20546865206172726179206F66';
wwv_flow_api.g_varchar2_table(322) := '207374796C657320646566696E696E672074686520636C7573746572206D61726B65727320746F20626520757365642E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6765745374796C6573203D2066756E6374696F6E20';
wwv_flow_api.g_varchar2_table(323) := '2829207B0A202072657475726E20746869732E7374796C65735F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865203C636F64653E7374796C65733C2F636F64653E2070726F70657274792E0A202A0A202A2020';
wwv_flow_api.g_varchar2_table(324) := '40706172616D207B41727261792E3C436C757374657249636F6E5374796C653E7D207374796C657320546865206172726179206F66207374796C657320746F207573652E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E73';
wwv_flow_api.g_varchar2_table(325) := '65745374796C6573203D2066756E6374696F6E20287374796C657329207B0A2020746869732E7374796C65735F203D207374796C65733B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E74';
wwv_flow_api.g_varchar2_table(326) := '69746C653C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B737472696E677D2054686520636F6E74656E74206F6620746865207469746C6520746578742E0A202A2F0A4D61726B6572436C757374657265722E70726F74';
wwv_flow_api.g_varchar2_table(327) := '6F747970652E6765745469746C65203D2066756E6374696F6E202829207B0A202072657475726E20746869732E7469746C655F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865203C636F64653E7469746C653C';
wwv_flow_api.g_varchar2_table(328) := '2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B737472696E677D207469746C65205468652076616C7565206F6620746865207469746C652070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70';
wwv_flow_api.g_varchar2_table(329) := '726F746F747970652E7365745469746C65203D2066756E6374696F6E20287469746C6529207B0A2020746869732E7469746C655F203D207469746C653B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C';
wwv_flow_api.g_varchar2_table(330) := '636F64653E7A6F6F6D4F6E436C69636B3C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B626F6F6C65616E7D2054727565206966207A6F6F6D4F6E436C69636B2070726F7065727479206973207365742E0A202A2F0A4D';
wwv_flow_api.g_varchar2_table(331) := '61726B6572436C757374657265722E70726F746F747970652E6765745A6F6F6D4F6E436C69636B203D2066756E6374696F6E202829207B0A202072657475726E20746869732E7A6F6F6D4F6E436C69636B5F3B0A7D3B0A0A0A2F2A2A0A202A2020536574';
wwv_flow_api.g_varchar2_table(332) := '73207468652076616C7565206F6620746865203C636F64653E7A6F6F6D4F6E436C69636B3C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B626F6F6C65616E7D207A6F6F6D4F6E436C69636B205468652076616C756520';
wwv_flow_api.g_varchar2_table(333) := '6F6620746865207A6F6F6D4F6E436C69636B2070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E7365745A6F6F6D4F6E436C69636B203D2066756E6374696F6E20287A6F6F6D4F6E436C69636B29207B';
wwv_flow_api.g_varchar2_table(334) := '0A2020746869732E7A6F6F6D4F6E436C69636B5F203D207A6F6F6D4F6E436C69636B3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E6176657261676543656E7465723C2F636F64653E20';
wwv_flow_api.g_varchar2_table(335) := '70726F70657274792E0A202A0A202A204072657475726E207B626F6F6C65616E7D2054727565206966206176657261676543656E7465722070726F7065727479206973207365742E0A202A2F0A4D61726B6572436C757374657265722E70726F746F7479';
wwv_flow_api.g_varchar2_table(336) := '70652E6765744176657261676543656E746572203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6176657261676543656E7465725F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865';
wwv_flow_api.g_varchar2_table(337) := '203C636F64653E6176657261676543656E7465723C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B626F6F6C65616E7D206176657261676543656E746572205468652076616C7565206F66207468652061766572616765';
wwv_flow_api.g_varchar2_table(338) := '43656E7465722070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E7365744176657261676543656E746572203D2066756E6374696F6E20286176657261676543656E74657229207B0A2020746869732E';
wwv_flow_api.g_varchar2_table(339) := '6176657261676543656E7465725F203D206176657261676543656E7465723B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E69676E6F726548696464656E3C2F636F64653E2070726F7065';
wwv_flow_api.g_varchar2_table(340) := '7274792E0A202A0A202A204072657475726E207B626F6F6C65616E7D20547275652069662069676E6F726548696464656E2070726F7065727479206973207365742E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574';
wwv_flow_api.g_varchar2_table(341) := '49676E6F726548696464656E203D2066756E6374696F6E202829207B0A202072657475726E20746869732E69676E6F726548696464656E5F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865203C636F64653E69';
wwv_flow_api.g_varchar2_table(342) := '676E6F726548696464656E3C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B626F6F6C65616E7D2069676E6F726548696464656E205468652076616C7565206F66207468652069676E6F726548696464656E2070726F70';
wwv_flow_api.g_varchar2_table(343) := '657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E73657449676E6F726548696464656E203D2066756E6374696F6E202869676E6F726548696464656E29207B0A2020746869732E69676E6F726548696464656E5F';
wwv_flow_api.g_varchar2_table(344) := '203D2069676E6F726548696464656E3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E656E61626C65526574696E6149636F6E733C2F636F64653E2070726F70657274792E0A202A0A202A';
wwv_flow_api.g_varchar2_table(345) := '204072657475726E207B626F6F6C65616E7D205472756520696620656E61626C65526574696E6149636F6E732070726F7065727479206973207365742E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574456E61626C';
wwv_flow_api.g_varchar2_table(346) := '65526574696E6149636F6E73203D2066756E6374696F6E202829207B0A202072657475726E20746869732E656E61626C65526574696E6149636F6E735F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865203C63';
wwv_flow_api.g_varchar2_table(347) := '6F64653E656E61626C65526574696E6149636F6E733C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B626F6F6C65616E7D20656E61626C65526574696E6149636F6E73205468652076616C7565206F662074686520656E';
wwv_flow_api.g_varchar2_table(348) := '61626C65526574696E6149636F6E732070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E736574456E61626C65526574696E6149636F6E73203D2066756E6374696F6E2028656E61626C65526574696E';
wwv_flow_api.g_varchar2_table(349) := '6149636F6E7329207B0A2020746869732E656E61626C65526574696E6149636F6E735F203D20656E61626C65526574696E6149636F6E733B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E';
wwv_flow_api.g_varchar2_table(350) := '696D616765457874656E73696F6E3C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B737472696E677D205468652076616C7565206F662074686520696D616765457874656E73696F6E2070726F70657274792E0A202A2F';
wwv_flow_api.g_varchar2_table(351) := '0A4D61726B6572436C757374657265722E70726F746F747970652E676574496D616765457874656E73696F6E203D2066756E6374696F6E202829207B0A202072657475726E20746869732E696D616765457874656E73696F6E5F3B0A7D3B0A0A0A2F2A2A';
wwv_flow_api.g_varchar2_table(352) := '0A202A202053657473207468652076616C7565206F6620746865203C636F64653E696D616765457874656E73696F6E3C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B737472696E677D20696D616765457874656E7369';
wwv_flow_api.g_varchar2_table(353) := '6F6E205468652076616C7565206F662074686520696D616765457874656E73696F6E2070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E736574496D616765457874656E73696F6E203D2066756E6374';
wwv_flow_api.g_varchar2_table(354) := '696F6E2028696D616765457874656E73696F6E29207B0A2020746869732E696D616765457874656E73696F6E5F203D20696D616765457874656E73696F6E3B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865';
wwv_flow_api.g_varchar2_table(355) := '203C636F64653E696D616765506174683C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B737472696E677D205468652076616C7565206F662074686520696D616765506174682070726F70657274792E0A202A2F0A4D61';
wwv_flow_api.g_varchar2_table(356) := '726B6572436C757374657265722E70726F746F747970652E676574496D61676550617468203D2066756E6374696F6E202829207B0A202072657475726E20746869732E696D616765506174685F3B0A7D3B0A0A0A2F2A2A0A202A20205365747320746865';
wwv_flow_api.g_varchar2_table(357) := '2076616C7565206F6620746865203C636F64653E696D616765506174683C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B737472696E677D20696D61676550617468205468652076616C7565206F662074686520696D61';
wwv_flow_api.g_varchar2_table(358) := '6765506174682070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E736574496D61676550617468203D2066756E6374696F6E2028696D6167655061746829207B0A2020746869732E696D616765506174';
wwv_flow_api.g_varchar2_table(359) := '685F203D20696D616765506174683B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E696D61676553697A65733C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E';
wwv_flow_api.g_varchar2_table(360) := '207B41727261797D205468652076616C7565206F662074686520696D61676553697A65732070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574496D61676553697A6573203D2066756E6374696F';
wwv_flow_api.g_varchar2_table(361) := '6E202829207B0A202072657475726E20746869732E696D61676553697A65735F3B0A7D3B0A0A0A2F2A2A0A202A202053657473207468652076616C7565206F6620746865203C636F64653E696D61676553697A65733C2F636F64653E2070726F70657274';
wwv_flow_api.g_varchar2_table(362) := '792E0A202A0A202A202040706172616D207B41727261797D20696D61676553697A6573205468652076616C7565206F662074686520696D61676553697A65732070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F74';
wwv_flow_api.g_varchar2_table(363) := '7970652E736574496D61676553697A6573203D2066756E6374696F6E2028696D61676553697A657329207B0A2020746869732E696D61676553697A65735F203D20696D61676553697A65733B0A7D3B0A0A0A2F2A2A0A202A2052657475726E7320746865';
wwv_flow_api.g_varchar2_table(364) := '2076616C7565206F6620746865203C636F64653E63616C63756C61746F723C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B66756E6374696F6E7D207468652076616C7565206F66207468652063616C63756C61746F72';
wwv_flow_api.g_varchar2_table(365) := '2070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E67657443616C63756C61746F72203D2066756E6374696F6E202829207B0A202072657475726E20746869732E63616C63756C61746F725F3B0A7D3B';
wwv_flow_api.g_varchar2_table(366) := '0A0A0A2F2A2A0A202A2053657473207468652076616C7565206F6620746865203C636F64653E63616C63756C61746F723C2F636F64653E2070726F70657274792E0A202A0A202A2040706172616D207B66756E6374696F6E2841727261792E3C676F6F67';
wwv_flow_api.g_varchar2_table(367) := '6C652E6D6170732E4D61726B65723E2C206E756D626572297D2063616C63756C61746F72205468652076616C75650A202A20206F66207468652063616C63756C61746F722070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70';
wwv_flow_api.g_varchar2_table(368) := '726F746F747970652E73657443616C63756C61746F72203D2066756E6374696F6E202863616C63756C61746F7229207B0A2020746869732E63616C63756C61746F725F203D2063616C63756C61746F723B0A7D3B0A0A0A2F2A2A0A202A2052657475726E';
wwv_flow_api.g_varchar2_table(369) := '73207468652076616C7565206F6620746865203C636F64653E626174636853697A6549453C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B6E756D6265727D207468652076616C7565206F662074686520626174636853';
wwv_flow_api.g_varchar2_table(370) := '697A6549452070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574426174636853697A654945203D2066756E6374696F6E202829207B0A202072657475726E20746869732E626174636853697A65';
wwv_flow_api.g_varchar2_table(371) := '49455F3B0A7D3B0A0A0A2F2A2A0A202A2053657473207468652076616C7565206F6620746865203C636F64653E626174636853697A6549453C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B6E756D6265727D20626174';
wwv_flow_api.g_varchar2_table(372) := '636853697A654945205468652076616C7565206F662074686520626174636853697A6549452070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E736574426174636853697A654945203D2066756E6374';
wwv_flow_api.g_varchar2_table(373) := '696F6E2028626174636853697A65494529207B0A2020746869732E626174636853697A6549455F203D20626174636853697A6549453B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652076616C7565206F6620746865203C636F64653E636C';
wwv_flow_api.g_varchar2_table(374) := '7573746572436C6173733C2F636F64653E2070726F70657274792E0A202A0A202A204072657475726E207B737472696E677D207468652076616C7565206F662074686520636C7573746572436C6173732070726F70657274792E0A202A2F0A4D61726B65';
wwv_flow_api.g_varchar2_table(375) := '72436C757374657265722E70726F746F747970652E676574436C7573746572436C617373203D2066756E6374696F6E202829207B0A202072657475726E20746869732E636C7573746572436C6173735F3B0A7D3B0A0A0A2F2A2A0A202A20536574732074';
wwv_flow_api.g_varchar2_table(376) := '68652076616C7565206F6620746865203C636F64653E636C7573746572436C6173733C2F636F64653E2070726F70657274792E0A202A0A202A202040706172616D207B737472696E677D20636C7573746572436C617373205468652076616C7565206F66';
wwv_flow_api.g_varchar2_table(377) := '2074686520636C7573746572436C6173732070726F70657274792E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E736574436C7573746572436C617373203D2066756E6374696F6E2028636C7573746572436C6173732920';
wwv_flow_api.g_varchar2_table(378) := '7B0A2020746869732E636C7573746572436C6173735F203D20636C7573746572436C6173733B0A7D3B0A0A0A2F2A2A0A202A202052657475726E7320746865206172726179206F66206D61726B657273206D616E616765642062792074686520636C7573';
wwv_flow_api.g_varchar2_table(379) := '74657265722E0A202A0A202A20204072657475726E207B41727261797D20546865206172726179206F66206D61726B657273206D616E616765642062792074686520636C757374657265722E0A202A2F0A4D61726B6572436C757374657265722E70726F';
wwv_flow_api.g_varchar2_table(380) := '746F747970652E6765744D61726B657273203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D61726B6572735F3B0A7D3B0A0A0A2F2A2A0A202A202052657475726E7320746865206E756D626572206F66206D61726B657273';
wwv_flow_api.g_varchar2_table(381) := '206D616E616765642062792074686520636C757374657265722E0A202A0A202A20204072657475726E207B6E756D6265727D20546865206E756D626572206F66206D61726B6572732E0A202A2F0A4D61726B6572436C757374657265722E70726F746F74';
wwv_flow_api.g_varchar2_table(382) := '7970652E676574546F74616C4D61726B657273203D2066756E6374696F6E202829207B0A202072657475726E20746869732E6D61726B6572735F2E6C656E6774683B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652063757272656E742061';
wwv_flow_api.g_varchar2_table(383) := '72726179206F6620636C75737465727320666F726D65642062792074686520636C757374657265722E0A202A0A202A204072657475726E207B41727261797D20546865206172726179206F6620636C75737465727320666F726D65642062792074686520';
wwv_flow_api.g_varchar2_table(384) := '636C757374657265722E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574436C757374657273203D2066756E6374696F6E202829207B0A202072657475726E20746869732E636C7573746572735F3B0A7D3B0A0A0A2F';
wwv_flow_api.g_varchar2_table(385) := '2A2A0A202A2052657475726E7320746865206E756D626572206F6620636C75737465727320666F726D65642062792074686520636C757374657265722E0A202A0A202A204072657475726E207B6E756D6265727D20546865206E756D626572206F662063';
wwv_flow_api.g_varchar2_table(386) := '6C75737465727320666F726D65642062792074686520636C757374657265722E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574546F74616C436C757374657273203D2066756E6374696F6E202829207B0A20207265';
wwv_flow_api.g_varchar2_table(387) := '7475726E20746869732E636C7573746572735F2E6C656E6774683B0A7D3B0A0A0A2F2A2A0A202A20416464732061206D61726B657220746F2074686520636C757374657265722E2054686520636C75737465727320617265207265647261776E20756E6C';
wwv_flow_api.g_varchar2_table(388) := '6573730A202A20203C636F64653E6F70745F6E6F647261773C2F636F64653E2069732073657420746F203C636F64653E747275653C2F636F64653E2E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B65';
wwv_flow_api.g_varchar2_table(389) := '7220546865206D61726B657220746F206164642E0A202A2040706172616D207B626F6F6C65616E7D205B6F70745F6E6F647261775D2053657420746F203C636F64653E747275653C2F636F64653E20746F2070726576656E7420726564726177696E672E';
wwv_flow_api.g_varchar2_table(390) := '0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6164644D61726B6572203D2066756E6374696F6E20286D61726B65722C206F70745F6E6F6472617729207B0A2020746869732E707573684D61726B6572546F5F286D61726B';
wwv_flow_api.g_varchar2_table(391) := '6572293B0A202069662028216F70745F6E6F6472617729207B0A20202020746869732E7265647261775F28293B0A20207D0A7D3B0A0A0A2F2A2A0A202A204164647320616E206172726179206F66206D61726B65727320746F2074686520636C75737465';
wwv_flow_api.g_varchar2_table(392) := '7265722E2054686520636C75737465727320617265207265647261776E20756E6C6573730A202A20203C636F64653E6F70745F6E6F647261773C2F636F64653E2069732073657420746F203C636F64653E747275653C2F636F64653E2E0A202A0A202A20';
wwv_flow_api.g_varchar2_table(393) := '40706172616D207B41727261792E3C676F6F676C652E6D6170732E4D61726B65723E7D206D61726B65727320546865206D61726B65727320746F206164642E0A202A2040706172616D207B626F6F6C65616E7D205B6F70745F6E6F647261775D20536574';
wwv_flow_api.g_varchar2_table(394) := '20746F203C636F64653E747275653C2F636F64653E20746F2070726576656E7420726564726177696E672E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E6164644D61726B657273203D2066756E6374696F6E20286D6172';
wwv_flow_api.g_varchar2_table(395) := '6B6572732C206F70745F6E6F6472617729207B0A2020766172206B65793B0A2020666F7220286B657920696E206D61726B65727329207B0A20202020696620286D61726B6572732E6861734F776E50726F7065727479286B65792929207B0A2020202020';
wwv_flow_api.g_varchar2_table(396) := '20746869732E707573684D61726B6572546F5F286D61726B6572735B6B65795D293B0A202020207D0A20207D20200A202069662028216F70745F6E6F6472617729207B0A20202020746869732E7265647261775F28293B0A20207D0A7D3B0A0A0A2F2A2A';
wwv_flow_api.g_varchar2_table(397) := '0A202A205075736865732061206D61726B657220746F2074686520636C757374657265722E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F206164642E0A202A';
wwv_flow_api.g_varchar2_table(398) := '2F0A4D61726B6572436C757374657265722E70726F746F747970652E707573684D61726B6572546F5F203D2066756E6374696F6E20286D61726B657229207B0A20202F2F20496620746865206D61726B657220697320647261676761626C652061646420';
wwv_flow_api.g_varchar2_table(399) := '61206C697374656E657220736F2077652063616E207570646174652074686520636C757374657273206F6E207468652064726167656E643A0A2020696620286D61726B65722E676574447261676761626C65282929207B0A2020202076617220634D6172';
wwv_flow_api.g_varchar2_table(400) := '6B6572436C75737465726572203D20746869733B0A20202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286D61726B65722C202264726167656E64222C2066756E6374696F6E202829207B0A20202020202069662028634D';
wwv_flow_api.g_varchar2_table(401) := '61726B6572436C757374657265722E72656164795F29207B0A2020202020202020746869732E69734164646564203D2066616C73653B0A2020202020202020634D61726B6572436C757374657265722E72657061696E7428293B0A2020202020207D0A20';
wwv_flow_api.g_varchar2_table(402) := '2020207D293B0A20207D0A20206D61726B65722E69734164646564203D2066616C73653B0A2020746869732E6D61726B6572735F2E70757368286D61726B6572293B0A7D3B0A0A0A2F2A2A0A202A2052656D6F7665732061206D61726B65722066726F6D';
wwv_flow_api.g_varchar2_table(403) := '2074686520636C75737465722E202054686520636C75737465727320617265207265647261776E20756E6C6573730A202A20203C636F64653E6F70745F6E6F647261773C2F636F64653E2069732073657420746F203C636F64653E747275653C2F636F64';
wwv_flow_api.g_varchar2_table(404) := '653E2E2052657475726E73203C636F64653E747275653C2F636F64653E206966207468650A202A20206D61726B6572207761732072656D6F7665642066726F6D2074686520636C757374657265722E0A202A0A202A2040706172616D207B676F6F676C65';
wwv_flow_api.g_varchar2_table(405) := '2E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F2072656D6F76652E0A202A2040706172616D207B626F6F6C65616E7D205B6F70745F6E6F647261775D2053657420746F203C636F64653E747275653C2F636F64653E';
wwv_flow_api.g_varchar2_table(406) := '20746F2070726576656E7420726564726177696E672E0A202A204072657475726E207B626F6F6C65616E7D205472756520696620746865206D61726B6572207761732072656D6F7665642066726F6D2074686520636C757374657265722E0A202A2F0A4D';
wwv_flow_api.g_varchar2_table(407) := '61726B6572436C757374657265722E70726F746F747970652E72656D6F76654D61726B6572203D2066756E6374696F6E20286D61726B65722C206F70745F6E6F6472617729207B0A20207661722072656D6F766564203D20746869732E72656D6F76654D';
wwv_flow_api.g_varchar2_table(408) := '61726B65725F286D61726B6572293B0A0A202069662028216F70745F6E6F647261772026262072656D6F76656429207B0A20202020746869732E72657061696E7428293B0A20207D0A0A202072657475726E2072656D6F7665643B0A7D3B0A0A0A2F2A2A';
wwv_flow_api.g_varchar2_table(409) := '0A202A2052656D6F76657320616E206172726179206F66206D61726B6572732066726F6D2074686520636C75737465722E2054686520636C75737465727320617265207265647261776E20756E6C6573730A202A20203C636F64653E6F70745F6E6F6472';
wwv_flow_api.g_varchar2_table(410) := '61773C2F636F64653E2069732073657420746F203C636F64653E747275653C2F636F64653E2E2052657475726E73203C636F64653E747275653C2F636F64653E206966206D61726B6572730A202A2020776572652072656D6F7665642066726F6D207468';
wwv_flow_api.g_varchar2_table(411) := '6520636C757374657265722E0A202A0A202A2040706172616D207B41727261792E3C676F6F676C652E6D6170732E4D61726B65723E7D206D61726B65727320546865206D61726B65727320746F2072656D6F76652E0A202A2040706172616D207B626F6F';
wwv_flow_api.g_varchar2_table(412) := '6C65616E7D205B6F70745F6E6F647261775D2053657420746F203C636F64653E747275653C2F636F64653E20746F2070726576656E7420726564726177696E672E0A202A204072657475726E207B626F6F6C65616E7D2054727565206966206D61726B65';
wwv_flow_api.g_varchar2_table(413) := '727320776572652072656D6F7665642066726F6D2074686520636C757374657265722E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E72656D6F76654D61726B657273203D2066756E6374696F6E20286D61726B6572732C';
wwv_flow_api.g_varchar2_table(414) := '206F70745F6E6F6472617729207B0A202076617220692C20723B0A20207661722072656D6F766564203D2066616C73653B0A0A2020666F72202869203D20303B2069203C206D61726B6572732E6C656E6774683B20692B2B29207B0A2020202072203D20';
wwv_flow_api.g_varchar2_table(415) := '746869732E72656D6F76654D61726B65725F286D61726B6572735B695D293B0A2020202072656D6F766564203D2072656D6F766564207C7C20723B0A20207D0A0A202069662028216F70745F6E6F647261772026262072656D6F76656429207B0A202020';
wwv_flow_api.g_varchar2_table(416) := '20746869732E72657061696E7428293B0A20207D0A0A202072657475726E2072656D6F7665643B0A7D3B0A0A0A2F2A2A0A202A2052656D6F7665732061206D61726B657220616E642072657475726E7320747275652069662072656D6F7665642C206661';
wwv_flow_api.g_varchar2_table(417) := '6C7365206966206E6F742E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F2072656D6F76650A202A204072657475726E207B626F6F6C65616E7D205768657468';
wwv_flow_api.g_varchar2_table(418) := '657220746865206D61726B6572207761732072656D6F766564206F72206E6F740A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E72656D6F76654D61726B65725F203D2066756E6374696F6E20286D61726B657229207B0A20';
wwv_flow_api.g_varchar2_table(419) := '2076617220693B0A202076617220696E646578203D202D313B0A202069662028746869732E6D61726B6572735F2E696E6465784F6629207B0A20202020696E646578203D20746869732E6D61726B6572735F2E696E6465784F66286D61726B6572293B0A';
wwv_flow_api.g_varchar2_table(420) := '20207D20656C7365207B0A20202020666F72202869203D20303B2069203C20746869732E6D61726B6572735F2E6C656E6774683B20692B2B29207B0A202020202020696620286D61726B6572203D3D3D20746869732E6D61726B6572735F5B695D29207B';
wwv_flow_api.g_varchar2_table(421) := '0A2020202020202020696E646578203D20693B0A2020202020202020627265616B3B0A2020202020207D0A202020207D0A20207D0A0A202069662028696E646578203D3D3D202D3129207B0A202020202F2F204D61726B6572206973206E6F7420696E20';
wwv_flow_api.g_varchar2_table(422) := '6F7572206C697374206F66206D61726B6572732C20736F20646F206E6F7468696E673A0A2020202072657475726E2066616C73653B0A20207D0A0A20206D61726B65722E7365744D6170286E756C6C293B0A2020746869732E6D61726B6572735F2E7370';
wwv_flow_api.g_varchar2_table(423) := '6C69636528696E6465782C2031293B202F2F2052656D6F766520746865206D61726B65722066726F6D20746865206C697374206F66206D616E61676564206D61726B6572730A202072657475726E20747275653B0A7D3B0A0A0A2F2A2A0A202A2052656D';
wwv_flow_api.g_varchar2_table(424) := '6F76657320616C6C20636C75737465727320616E64206D61726B6572732066726F6D20746865206D617020616E6420616C736F2072656D6F76657320616C6C206D61726B6572730A202A20206D616E616765642062792074686520636C75737465726572';
wwv_flow_api.g_varchar2_table(425) := '2E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E636C6561724D61726B657273203D2066756E6374696F6E202829207B0A2020746869732E726573657456696577706F72745F2874727565293B0A2020746869732E6D6172';
wwv_flow_api.g_varchar2_table(426) := '6B6572735F203D205B5D3B0A7D3B0A0A0A2F2A2A0A202A20526563616C63756C6174657320616E64207265647261777320616C6C20746865206D61726B657220636C7573746572732066726F6D20736372617463682E0A202A202043616C6C2074686973';
wwv_flow_api.g_varchar2_table(427) := '206166746572206368616E67696E6720616E792070726F706572746965732E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E72657061696E74203D2066756E6374696F6E202829207B0A2020766172206F6C64436C757374';
wwv_flow_api.g_varchar2_table(428) := '657273203D20746869732E636C7573746572735F2E736C69636528293B0A2020746869732E636C7573746572735F203D205B5D3B0A2020746869732E726573657456696577706F72745F2866616C7365293B0A2020746869732E7265647261775F28293B';
wwv_flow_api.g_varchar2_table(429) := '0A0A20202F2F2052656D6F766520746865206F6C6420636C7573746572732E0A20202F2F20446F20697420696E20612074696D656F757420746F2070726576656E7420626C696E6B696E67206566666563742E0A202073657454696D656F75742866756E';
wwv_flow_api.g_varchar2_table(430) := '6374696F6E202829207B0A2020202076617220693B0A20202020666F72202869203D20303B2069203C206F6C64436C7573746572732E6C656E6774683B20692B2B29207B0A2020202020206F6C64436C7573746572735B695D2E72656D6F766528293B0A';
wwv_flow_api.g_varchar2_table(431) := '202020207D0A20207D2C2030293B0A7D3B0A0A0A2F2A2A0A202A2052657475726E73207468652063757272656E7420626F756E647320657874656E6465642062792074686520677269642073697A652E0A202A0A202A2040706172616D207B676F6F676C';
wwv_flow_api.g_varchar2_table(432) := '652E6D6170732E4C61744C6E67426F756E64737D20626F756E64732054686520626F756E647320746F20657874656E642E0A202A204072657475726E207B676F6F676C652E6D6170732E4C61744C6E67426F756E64737D2054686520657874656E646564';
wwv_flow_api.g_varchar2_table(433) := '20626F756E64732E0A202A204069676E6F72650A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E676574457874656E646564426F756E6473203D2066756E6374696F6E2028626F756E647329207B0A20207661722070726F6A';
wwv_flow_api.g_varchar2_table(434) := '656374696F6E203D20746869732E67657450726F6A656374696F6E28293B0A0A20202F2F205475726E2074686520626F756E647320696E746F206C61746C6E672E0A2020766172207472203D206E657720676F6F676C652E6D6170732E4C61744C6E6728';
wwv_flow_api.g_varchar2_table(435) := '626F756E64732E6765744E6F7274684561737428292E6C617428292C0A202020202020626F756E64732E6765744E6F7274684561737428292E6C6E672829293B0A202076617220626C203D206E657720676F6F676C652E6D6170732E4C61744C6E672862';
wwv_flow_api.g_varchar2_table(436) := '6F756E64732E676574536F7574685765737428292E6C617428292C0A202020202020626F756E64732E676574536F7574685765737428292E6C6E672829293B0A0A20202F2F20436F6E766572742074686520706F696E747320746F20706978656C732061';
wwv_flow_api.g_varchar2_table(437) := '6E642074686520657874656E64206F75742062792074686520677269642073697A652E0A2020766172207472506978203D2070726F6A656374696F6E2E66726F6D4C61744C6E67546F446976506978656C287472293B0A202074725069782E78202B3D20';
wwv_flow_api.g_varchar2_table(438) := '746869732E6772696453697A655F3B0A202074725069782E79202D3D20746869732E6772696453697A655F3B0A0A202076617220626C506978203D2070726F6A656374696F6E2E66726F6D4C61744C6E67546F446976506978656C28626C293B0A202062';
wwv_flow_api.g_varchar2_table(439) := '6C5069782E78202D3D20746869732E6772696453697A655F3B0A2020626C5069782E79202B3D20746869732E6772696453697A655F3B0A0A20202F2F20436F6E766572742074686520706978656C20706F696E7473206261636B20746F204C61744C6E67';
wwv_flow_api.g_varchar2_table(440) := '0A2020766172206E65203D2070726F6A656374696F6E2E66726F6D446976506978656C546F4C61744C6E67287472506978293B0A2020766172207377203D2070726F6A656374696F6E2E66726F6D446976506978656C546F4C61744C6E6728626C506978';
wwv_flow_api.g_varchar2_table(441) := '293B0A0A20202F2F20457874656E642074686520626F756E647320746F20636F6E7461696E20746865206E657720626F756E64732E0A2020626F756E64732E657874656E64286E65293B0A2020626F756E64732E657874656E64287377293B0A0A202072';
wwv_flow_api.g_varchar2_table(442) := '657475726E20626F756E64733B0A7D3B0A0A0A2F2A2A0A202A205265647261777320616C6C2074686520636C7573746572732E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E7265647261775F203D2066756E6374696F6E';
wwv_flow_api.g_varchar2_table(443) := '202829207B0A2020746869732E637265617465436C7573746572735F2830293B0A7D3B0A0A0A2F2A2A0A202A2052656D6F76657320616C6C20636C7573746572732066726F6D20746865206D61702E20546865206D61726B6572732061726520616C736F';
wwv_flow_api.g_varchar2_table(444) := '2072656D6F7665642066726F6D20746865206D61700A202A20206966203C636F64653E6F70745F686964653C2F636F64653E2069732073657420746F203C636F64653E747275653C2F636F64653E2E0A202A0A202A2040706172616D207B626F6F6C6561';
wwv_flow_api.g_varchar2_table(445) := '6E7D205B6F70745F686964655D2053657420746F203C636F64653E747275653C2F636F64653E20746F20616C736F2072656D6F766520746865206D61726B6572730A202A202066726F6D20746865206D61702E0A202A2F0A4D61726B6572436C75737465';
wwv_flow_api.g_varchar2_table(446) := '7265722E70726F746F747970652E726573657456696577706F72745F203D2066756E6374696F6E20286F70745F6869646529207B0A202076617220692C206D61726B65723B0A20202F2F2052656D6F766520616C6C2074686520636C7573746572730A20';
wwv_flow_api.g_varchar2_table(447) := '20666F72202869203D20303B2069203C20746869732E636C7573746572735F2E6C656E6774683B20692B2B29207B0A20202020746869732E636C7573746572735F5B695D2E72656D6F766528293B0A20207D0A2020746869732E636C7573746572735F20';
wwv_flow_api.g_varchar2_table(448) := '3D205B5D3B0A0A20202F2F20526573657420746865206D61726B65727320746F206E6F7420626520616464656420616E6420746F2062652072656D6F7665642066726F6D20746865206D61702E0A2020666F72202869203D20303B2069203C2074686973';
wwv_flow_api.g_varchar2_table(449) := '2E6D61726B6572735F2E6C656E6774683B20692B2B29207B0A202020206D61726B6572203D20746869732E6D61726B6572735F5B695D3B0A202020206D61726B65722E69734164646564203D2066616C73653B0A20202020696620286F70745F68696465';
wwv_flow_api.g_varchar2_table(450) := '29207B0A2020202020206D61726B65722E7365744D6170286E756C6C293B0A202020207D0A20207D0A7D3B0A0A0A2F2A2A0A202A2043616C63756C61746573207468652064697374616E6365206265747765656E2074776F206C61746C6E67206C6F6361';
wwv_flow_api.g_varchar2_table(451) := '74696F6E7320696E206B6D2E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4C61744C6E677D20703120546865206669727374206C6174206C6E6720706F696E742E0A202A2040706172616D207B676F6F676C652E6D6170732E4C61';
wwv_flow_api.g_varchar2_table(452) := '744C6E677D20703220546865207365636F6E64206C6174206C6E6720706F696E742E0A202A204072657475726E207B6E756D6265727D205468652064697374616E6365206265747765656E207468652074776F20706F696E747320696E206B6D2E0A202A';
wwv_flow_api.g_varchar2_table(453) := '204073656520687474703A2F2F7777772E6D6F7661626C652D747970652E636F2E756B2F736372697074732F6C61746C6F6E672E68746D6C0A2A2F0A4D61726B6572436C757374657265722E70726F746F747970652E64697374616E6365426574776565';
wwv_flow_api.g_varchar2_table(454) := '6E506F696E74735F203D2066756E6374696F6E202870312C20703229207B0A20207661722052203D20363337313B202F2F20526164697573206F662074686520456172746820696E206B6D0A202076617220644C6174203D202870322E6C61742829202D';
wwv_flow_api.g_varchar2_table(455) := '2070312E6C6174282929202A204D6174682E5049202F203138303B0A202076617220644C6F6E203D202870322E6C6E672829202D2070312E6C6E67282929202A204D6174682E5049202F203138303B0A20207661722061203D204D6174682E73696E2864';
wwv_flow_api.g_varchar2_table(456) := '4C6174202F203229202A204D6174682E73696E28644C6174202F203229202B0A202020204D6174682E636F732870312E6C61742829202A204D6174682E5049202F2031383029202A204D6174682E636F732870322E6C61742829202A204D6174682E5049';
wwv_flow_api.g_varchar2_table(457) := '202F2031383029202A0A202020204D6174682E73696E28644C6F6E202F203229202A204D6174682E73696E28644C6F6E202F2032293B0A20207661722063203D2032202A204D6174682E6174616E32284D6174682E737172742861292C204D6174682E73';
wwv_flow_api.g_varchar2_table(458) := '7172742831202D206129293B0A20207661722064203D2052202A20633B0A202072657475726E20643B0A7D3B0A0A0A2F2A2A0A202A2044657465726D696E65732069662061206D61726B657220697320636F6E7461696E656420696E206120626F756E64';
wwv_flow_api.g_varchar2_table(459) := '732E0A202A0A202A2040706172616D207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F20636865636B2E0A202A2040706172616D207B676F6F676C652E6D6170732E4C61744C6E67426F756E6473';
wwv_flow_api.g_varchar2_table(460) := '7D20626F756E64732054686520626F756E647320746F20636865636B20616761696E73742E0A202A204072657475726E207B626F6F6C65616E7D205472756520696620746865206D61726B657220697320696E2074686520626F756E64732E0A202A2F0A';
wwv_flow_api.g_varchar2_table(461) := '4D61726B6572436C757374657265722E70726F746F747970652E69734D61726B6572496E426F756E64735F203D2066756E6374696F6E20286D61726B65722C20626F756E647329207B0A202072657475726E20626F756E64732E636F6E7461696E73286D';
wwv_flow_api.g_varchar2_table(462) := '61726B65722E676574506F736974696F6E2829293B0A7D3B0A0A0A2F2A2A0A202A20416464732061206D61726B657220746F206120636C75737465722C206F7220637265617465732061206E657720636C75737465722E0A202A0A202A2040706172616D';
wwv_flow_api.g_varchar2_table(463) := '207B676F6F676C652E6D6170732E4D61726B65727D206D61726B657220546865206D61726B657220746F206164642E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E616464546F436C6F73657374436C75737465725F203D';
wwv_flow_api.g_varchar2_table(464) := '2066756E6374696F6E20286D61726B657229207B0A202076617220692C20642C20636C75737465722C2063656E7465723B0A20207661722064697374616E6365203D2034303030303B202F2F20536F6D65206C61726765206E756D6265720A2020766172';
wwv_flow_api.g_varchar2_table(465) := '20636C7573746572546F416464546F203D206E756C6C3B0A2020666F72202869203D20303B2069203C20746869732E636C7573746572735F2E6C656E6774683B20692B2B29207B0A20202020636C7573746572203D20746869732E636C7573746572735F';
wwv_flow_api.g_varchar2_table(466) := '5B695D3B0A2020202063656E746572203D20636C75737465722E67657443656E74657228293B0A202020206966202863656E74657229207B0A20202020202064203D20746869732E64697374616E63654265747765656E506F696E74735F2863656E7465';
wwv_flow_api.g_varchar2_table(467) := '722C206D61726B65722E676574506F736974696F6E2829293B0A2020202020206966202864203C2064697374616E636529207B0A202020202020202064697374616E6365203D20643B0A2020202020202020636C7573746572546F416464546F203D2063';
wwv_flow_api.g_varchar2_table(468) := '6C75737465723B0A2020202020207D0A202020207D0A20207D0A0A202069662028636C7573746572546F416464546F20262620636C7573746572546F416464546F2E69734D61726B6572496E436C7573746572426F756E6473286D61726B65722929207B';
wwv_flow_api.g_varchar2_table(469) := '0A20202020636C7573746572546F416464546F2E6164644D61726B6572286D61726B6572293B0A20207D20656C7365207B0A20202020636C7573746572203D206E657720436C75737465722874686973293B0A20202020636C75737465722E6164644D61';
wwv_flow_api.g_varchar2_table(470) := '726B6572286D61726B6572293B0A20202020746869732E636C7573746572735F2E7075736828636C7573746572293B0A20207D0A7D3B0A0A0A2F2A2A0A202A20437265617465732074686520636C7573746572732E205468697320697320646F6E652069';
wwv_flow_api.g_varchar2_table(471) := '6E206261746368657320746F2061766F69642074696D656F7574206572726F72730A202A2020696E20736F6D652062726F7773657273207768656E20746865726520697320612068756765206E756D626572206F66206D61726B6572732E0A202A0A202A';
wwv_flow_api.g_varchar2_table(472) := '2040706172616D207B6E756D6265727D206946697273742054686520696E646578206F6620746865206669727374206D61726B657220696E20746865206261746368206F660A202A20206D61726B65727320746F20626520616464656420746F20636C75';
wwv_flow_api.g_varchar2_table(473) := '73746572732E0A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E637265617465436C7573746572735F203D2066756E6374696F6E202869466972737429207B0A202076617220692C206D61726B65723B0A2020766172206D61';
wwv_flow_api.g_varchar2_table(474) := '70426F756E64733B0A202076617220634D61726B6572436C75737465726572203D20746869733B0A20206966202821746869732E72656164795F29207B0A2020202072657475726E3B0A20207D0A0A20202F2F2043616E63656C2070726576696F757320';
wwv_flow_api.g_varchar2_table(475) := '62617463682070726F63657373696E6720696620776527726520776F726B696E67206F6E207468652066697273742062617463683A0A202069662028694669727374203D3D3D203029207B0A202020202F2A2A0A20202020202A2054686973206576656E';
wwv_flow_api.g_varchar2_table(476) := '74206973206669726564207768656E20746865203C636F64653E4D61726B6572436C757374657265723C2F636F64653E20626567696E730A20202020202A2020636C7573746572696E67206D61726B6572732E0A20202020202A20406E616D65204D6172';
wwv_flow_api.g_varchar2_table(477) := '6B6572436C7573746572657223636C7573746572696E67626567696E0A20202020202A2040706172616D207B4D61726B6572436C757374657265727D206D6320546865204D61726B6572436C757374657265722077686F7365206D61726B657273206172';
wwv_flow_api.g_varchar2_table(478) := '65206265696E6720636C757374657265642E0A20202020202A20406576656E740A20202020202A2F0A20202020676F6F676C652E6D6170732E6576656E742E7472696767657228746869732C2022636C7573746572696E67626567696E222C2074686973';
wwv_flow_api.g_varchar2_table(479) := '293B0A0A2020202069662028747970656F6620746869732E74696D657252656653746174696320213D3D2022756E646566696E65642229207B0A202020202020636C65617254696D656F757428746869732E74696D6572526566537461746963293B0A20';
wwv_flow_api.g_varchar2_table(480) := '202020202064656C65746520746869732E74696D65725265665374617469633B0A202020207D0A20207D0A0A20202F2F20476574206F75722063757272656E74206D6170207669657720626F756E64732E0A20202F2F204372656174652061206E657720';
wwv_flow_api.g_varchar2_table(481) := '626F756E6473206F626A65637420736F20776520646F6E27742061666665637420746865206D61702E0A20202F2F0A20202F2F2053656520436F6D6D656E747320392026203131206F6E20497373756520333635312072656C6174696E6720746F207468';
wwv_flow_api.g_varchar2_table(482) := '697320776F726B61726F756E6420666F72206120476F6F676C65204D617073206275673A0A202069662028746869732E6765744D617028292E6765745A6F6F6D2829203E203329207B0A202020206D6170426F756E6473203D206E657720676F6F676C65';
wwv_flow_api.g_varchar2_table(483) := '2E6D6170732E4C61744C6E67426F756E647328746869732E6765744D617028292E676574426F756E647328292E676574536F7574685765737428292C0A202020202020746869732E6765744D617028292E676574426F756E647328292E6765744E6F7274';
wwv_flow_api.g_varchar2_table(484) := '68456173742829293B0A20207D20656C7365207B0A202020206D6170426F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E672838352E3032303730373731';
wwv_flow_api.g_varchar2_table(485) := '3734333437322C202D3137382E3438333838343334333735292C206E657720676F6F676C652E6D6170732E4C61744C6E67282D38352E30383133363434343338343534342C203137382E303030343838363536323529293B0A20207D0A20207661722062';
wwv_flow_api.g_varchar2_table(486) := '6F756E6473203D20746869732E676574457874656E646564426F756E6473286D6170426F756E6473293B0A0A202076617220694C617374203D204D6174682E6D696E28694669727374202B20746869732E626174636853697A655F2C20746869732E6D61';
wwv_flow_api.g_varchar2_table(487) := '726B6572735F2E6C656E677468293B0A0A2020666F72202869203D206946697273743B2069203C20694C6173743B20692B2B29207B0A202020206D61726B6572203D20746869732E6D61726B6572735F5B695D3B0A2020202069662028216D61726B6572';
wwv_flow_api.g_varchar2_table(488) := '2E6973416464656420262620746869732E69734D61726B6572496E426F756E64735F286D61726B65722C20626F756E64732929207B0A2020202020206966202821746869732E69676E6F726548696464656E5F207C7C2028746869732E69676E6F726548';
wwv_flow_api.g_varchar2_table(489) := '696464656E5F202626206D61726B65722E67657456697369626C6528292929207B0A2020202020202020746869732E616464546F436C6F73657374436C75737465725F286D61726B6572293B0A2020202020207D0A202020207D0A20207D0A0A20206966';
wwv_flow_api.g_varchar2_table(490) := '2028694C617374203C20746869732E6D61726B6572735F2E6C656E67746829207B0A20202020746869732E74696D6572526566537461746963203D2073657454696D656F75742866756E6374696F6E202829207B0A202020202020634D61726B6572436C';
wwv_flow_api.g_varchar2_table(491) := '757374657265722E637265617465436C7573746572735F28694C617374293B0A202020207D2C2030293B0A20207D20656C7365207B0A2020202064656C65746520746869732E74696D65725265665374617469633B0A0A202020202F2A2A0A2020202020';
wwv_flow_api.g_varchar2_table(492) := '2A2054686973206576656E74206973206669726564207768656E20746865203C636F64653E4D61726B6572436C757374657265723C2F636F64653E2073746F70730A20202020202A2020636C7573746572696E67206D61726B6572732E0A20202020202A';
wwv_flow_api.g_varchar2_table(493) := '20406E616D65204D61726B6572436C7573746572657223636C7573746572696E67656E640A20202020202A2040706172616D207B4D61726B6572436C757374657265727D206D6320546865204D61726B6572436C757374657265722077686F7365206D61';
wwv_flow_api.g_varchar2_table(494) := '726B65727320617265206265696E6720636C757374657265642E0A20202020202A20406576656E740A20202020202A2F0A20202020676F6F676C652E6D6170732E6576656E742E7472696767657228746869732C2022636C7573746572696E67656E6422';
wwv_flow_api.g_varchar2_table(495) := '2C2074686973293B0A20207D0A7D3B0A0A0A2F2A2A0A202A20457874656E647320616E206F626A65637427732070726F746F7479706520627920616E6F7468657227732E0A202A0A202A2040706172616D207B4F626A6563747D206F626A312054686520';
wwv_flow_api.g_varchar2_table(496) := '6F626A65637420746F20626520657874656E6465642E0A202A2040706172616D207B4F626A6563747D206F626A3220546865206F626A65637420746F20657874656E6420776974682E0A202A204072657475726E207B4F626A6563747D20546865206E65';
wwv_flow_api.g_varchar2_table(497) := '7720657874656E646564206F626A6563742E0A202A204069676E6F72650A202A2F0A4D61726B6572436C757374657265722E70726F746F747970652E657874656E64203D2066756E6374696F6E20286F626A312C206F626A3229207B0A20207265747572';
wwv_flow_api.g_varchar2_table(498) := '6E202866756E6374696F6E20286F626A65637429207B0A202020207661722070726F70657274793B0A20202020666F72202870726F706572747920696E206F626A6563742E70726F746F7479706529207B0A202020202020746869732E70726F746F7479';
wwv_flow_api.g_varchar2_table(499) := '70655B70726F70657274795D203D206F626A6563742E70726F746F747970655B70726F70657274795D3B0A202020207D0A2020202072657475726E20746869733B0A20207D292E6170706C79286F626A312C205B6F626A325D293B0A7D3B0A0A0A2F2A2A';
wwv_flow_api.g_varchar2_table(500) := '0A202A205468652064656661756C742066756E6374696F6E20666F722064657465726D696E696E6720746865206C6162656C207465787420616E64207374796C650A202A20666F72206120636C75737465722069636F6E2E0A202A0A202A204070617261';
wwv_flow_api.g_varchar2_table(501) := '6D207B41727261792E3C676F6F676C652E6D6170732E4D61726B65723E7D206D61726B65727320546865206172726179206F66206D61726B65727320726570726573656E7465642062792074686520636C75737465722E0A202A2040706172616D207B6E';
wwv_flow_api.g_varchar2_table(502) := '756D6265727D206E756D5374796C657320546865206E756D626572206F66206D61726B6572207374796C657320617661696C61626C652E0A202A204072657475726E207B436C757374657249636F6E496E666F7D2054686520696E666F726D6174696F6E';
wwv_flow_api.g_varchar2_table(503) := '207265736F7572636520666F722074686520636C75737465722E0A202A2040636F6E7374616E740A202A204069676E6F72650A202A2F0A4D61726B6572436C757374657265722E43414C43554C41544F52203D2066756E6374696F6E20286D61726B6572';
wwv_flow_api.g_varchar2_table(504) := '732C206E756D5374796C657329207B0A202076617220696E646578203D20303B0A2020766172207469746C65203D2022223B0A202076617220636F756E74203D206D61726B6572732E6C656E6774682E746F537472696E6728293B0A0A20207661722064';
wwv_flow_api.g_varchar2_table(505) := '76203D20636F756E743B0A20207768696C652028647620213D3D203029207B0A202020206476203D207061727365496E74286476202F2031302C203130293B0A20202020696E6465782B2B3B0A20207D0A0A2020696E646578203D204D6174682E6D696E';
wwv_flow_api.g_varchar2_table(506) := '28696E6465782C206E756D5374796C6573293B0A202072657475726E207B0A20202020746578743A20636F756E742C0A20202020696E6465783A20696E6465782C0A202020207469746C653A207469746C650A20207D3B0A7D3B0A0A0A2F2A2A0A202A20';
wwv_flow_api.g_varchar2_table(507) := '546865206E756D626572206F66206D61726B65727320746F2070726F6365737320696E206F6E652062617463682E0A202A0A202A204074797065207B6E756D6265727D0A202A2040636F6E7374616E740A202A2F0A4D61726B6572436C75737465726572';
wwv_flow_api.g_varchar2_table(508) := '2E42415443485F53495A45203D20323030303B0A0A0A2F2A2A0A202A20546865206E756D626572206F66206D61726B65727320746F2070726F6365737320696E206F6E6520626174636820284945206F6E6C79292E0A202A0A202A204074797065207B6E';
wwv_flow_api.g_varchar2_table(509) := '756D6265727D0A202A2040636F6E7374616E740A202A2F0A4D61726B6572436C757374657265722E42415443485F53495A455F4945203D203530303B0A0A0A2F2A2A0A202A205468652064656661756C7420726F6F74206E616D6520666F722074686520';
wwv_flow_api.g_varchar2_table(510) := '6D61726B657220636C757374657220696D616765732E0A202A0A202A204074797065207B737472696E677D0A202A2040636F6E7374616E740A202A2F0A4D61726B6572436C757374657265722E494D4147455F50415448203D2022687474703A2F2F676F';
wwv_flow_api.g_varchar2_table(511) := '6F676C652D6D6170732D7574696C6974792D6C6962726172792D76332E676F6F676C65636F64652E636F6D2F73766E2F7472756E6B2F6D61726B6572636C75737465726572706C75732F696D616765732F6D223B0A0A0A2F2A2A0A202A20546865206465';
wwv_flow_api.g_varchar2_table(512) := '6661756C7420657874656E73696F6E206E616D6520666F7220746865206D61726B657220636C757374657220696D616765732E0A202A0A202A204074797065207B737472696E677D0A202A2040636F6E7374616E740A202A2F0A4D61726B6572436C7573';
wwv_flow_api.g_varchar2_table(513) := '74657265722E494D4147455F455854454E53494F4E203D2022706E67223B0A0A0A2F2A2A0A202A205468652064656661756C74206172726179206F662073697A657320666F7220746865206D61726B657220636C757374657220696D616765732E0A202A';
wwv_flow_api.g_varchar2_table(514) := '0A202A204074797065207B41727261792E3C6E756D6265723E7D0A202A2040636F6E7374616E740A202A2F0A4D61726B6572436C757374657265722E494D4147455F53495A4553203D205B35332C2035362C2036362C2037382C2039305D3B0A0A696620';
wwv_flow_api.g_varchar2_table(515) := '28747970656F6620537472696E672E70726F746F747970652E7472696D20213D3D202766756E6374696F6E2729207B0A20202F2A2A0A2020202A204945206861636B2073696E6365207472696D282920646F65736E277420657869737420696E20616C6C';
wwv_flow_api.g_varchar2_table(516) := '2062726F77736572730A2020202A204072657475726E207B737472696E677D2054686520737472696E6720776974682072656D6F76656420776869746573706163650A2020202A2F0A2020537472696E672E70726F746F747970652E7472696D203D2066';
wwv_flow_api.g_varchar2_table(517) := '756E6374696F6E2829207B0A2020202072657475726E20746869732E7265706C616365282F5E5C732B7C5C732B242F672C202727293B200A20207D0A7D0A0A';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33057958710766769)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'markerclusterer.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '6576616C2866756E6374696F6E28702C612C632C6B2C652C72297B653D66756E6374696F6E2863297B72657475726E28633C613F27273A65287061727365496E7428632F612929292B2828633D632561293E33353F537472696E672E66726F6D43686172';
wwv_flow_api.g_varchar2_table(2) := '436F646528632B3239293A632E746F537472696E6728333629297D3B6966282127272E7265706C616365282F5E2F2C537472696E6729297B7768696C6528632D2D29725B652863295D3D6B5B635D7C7C652863293B6B3D5B66756E6374696F6E2865297B';
wwv_flow_api.g_varchar2_table(3) := '72657475726E20725B655D7D5D3B653D66756E6374696F6E28297B72657475726E275C5C772B277D3B633D317D3B7768696C6528632D2D296966286B5B635D29703D702E7265706C616365286E65772052656745787028275C5C62272B652863292B275C';
wwv_flow_api.g_varchar2_table(4) := '5C62272C276727292C6B5B635D293B72657475726E20707D282735204728622C61297B622E4E28292E5628472C6E2E6F2E325A293B342E493D623B342E32453D622E4E28292E327928293B342E4D3D613B342E433D743B342E713D743B342E31363D743B';
wwv_flow_api.g_varchar2_table(5) := '342E316F3D773B342E4B28622E762829297D472E362E32463D3528297B3720643D343B3720673B3720663B342E713D33412E33752822315922293B342E712E35703D342E32453B3928342E316F297B342E326128297D342E344F28292E34482E34422834';
wwv_flow_api.g_varchar2_table(6) := '2E71293B342E32583D6E2E6F2E752E314728342E7628292C223462222C3528297B663D677D293B6E2E6F2E752E314528342E712C223432222C3528297B673D483B663D777D293B6E2E6F2E752E314528342E712C22324D222C352865297B673D773B3928';
wwv_flow_api.g_varchar2_table(7) := '2166297B3720633B3720623B3720613D642E492E4E28293B6E2E6F2E752E5828612C22324D222C642E49293B6E2E6F2E752E5828612C223356222C642E49293B3928612E32422829297B623D612E317928293B633D642E492E317328293B612E7628292E';
wwv_flow_api.g_varchar2_table(8) := '31562863293B3155283528297B612E7628292E31562863293B392862213D3D74262628612E7628292E313728293E6229297B612E7628292E334628622B31297D7D2C337A297D652E33773D483B3928652E326A297B652E326A28297D7D7D293B6E2E6F2E';
wwv_flow_api.g_varchar2_table(9) := '752E314528342E712C223255222C3528297B3720613D642E492E4E28293B6E2E6F2E752E5828612C223255222C642E49297D293B6E2E6F2E752E314528342E712C22324C222C3528297B3720613D642E492E4E28293B6E2E6F2E752E5828612C22324C22';
wwv_flow_api.g_varchar2_table(10) := '2C642E49297D297D3B472E362E32513D3528297B3928342E712626342E712E3365297B342E314628293B6E2E6F2E752E336228342E3258293B6E2E6F2E752E353728342E71293B342E712E33652E345A28342E71293B342E713D747D7D3B472E362E3338';
wwv_flow_api.g_varchar2_table(11) := '3D3528297B3928342E316F297B3720613D342E323828342E43293B342E712E552E314A3D612E792B227A223B342E712E552E31483D612E782B227A227D7D3B472E362E31463D3528297B3928342E71297B342E712E552E33363D223256227D342E316F3D';
wwv_flow_api.g_varchar2_table(12) := '777D3B472E362E32613D3528297B3928342E71297B3720653D22223B3720633D342E33672E346A28222022293B3720623D313228635B305D2E314E28292C3130293B3720643D313228635B315D2E314E28292C3130293B3720613D342E323828342E4329';
wwv_flow_api.g_varchar2_table(13) := '3B342E712E552E34333D342E32502861293B653D223C343120335A3D5C27222B342E324F2B225C2720553D5C2732303A20315A3B20314A3A20222B642B227A3B2031483A20222B622B227A3B20223B392821342E492E4E28292E316C297B652B3D223359';
wwv_flow_api.g_varchar2_table(14) := '3A20335828222B282D312A64292B227A2C20222B28282D312A62292B342E3172292B227A2C20222B28282D312A64292B342E316B292B227A2C20222B282D312A62292B227A293B227D652B3D225C273E223B342E712E33573D652B223C315920553D5C27';
wwv_flow_api.g_varchar2_table(15) := '222B2232303A20315A3B222B22314A3A20222B342E31585B305D2B227A3B222B2231483A20222B342E31585B315D2B227A3B222B2233543A20222B342E32442B223B222B22314F2D31663A20222B342E327A2B227A3B222B22314F2D33503A20222B342E';
wwv_flow_api.g_varchar2_table(16) := '32762B223B222B22314F2D334E3A20222B342E32742B223B222B22314F2D553A20222B342E32732B223B222B2231772D33493A20222B342E326F2B223B222B2231772D33453A2031683B222B2231783A20222B342E31722B227A3B222B2233422D31753A';
wwv_flow_api.g_varchar2_table(17) := '222B342E316B2B227A3B222B225C273E222B342E31362E31772B223C2F31593E223B3928315120342E31362E31343D3D3D223135227C7C342E31362E31343D3D3D2222297B342E712E31343D342E492E4E28292E324728297D4C7B342E712E31343D342E';
wwv_flow_api.g_varchar2_table(18) := '31362E31347D342E712E552E33363D22227D342E316F3D487D3B472E362E33693D352861297B342E31363D613B3720623D412E337028302C612E32542D31293B623D412E323228342E4D2E702D312C62293B3720633D342E4D5B625D3B342E324F3D632E';
wwv_flow_api.g_varchar2_table(19) := '33663B342E316B3D632E31753B342E31723D632E31783B342E31583D632E356D7C7C5B302C305D3B342E32633D632E35677C7C5B313228342E316B2F322C3130292C313228342E31722F322C3130295D3B342E32443D632E35627C7C223535223B342E32';
wwv_flow_api.g_varchar2_table(20) := '7A3D632E35317C7C31313B342E326F3D632E34567C7C223256223B342E32743D632E34547C7C223452223B342E32733D632E344E7C7C22344B223B342E32763D632E344A7C7C2234492C34472D3446223B342E33673D632E34447C7C22302030227D3B47';
wwv_flow_api.g_varchar2_table(21) := '2E362E33683D352861297B342E433D617D3B472E362E32503D352862297B3720613D5B5D3B612E59282234413A2034793B22293B612E59282232303A20315A3B20314A3A20222B622E792B227A3B2031483A20222B622E782B227A3B22293B612E592822';
wwv_flow_api.g_varchar2_table(22) := '31783A20222B342E31722B227A3B2031753A20222B342E316B2B227A3B22293B6A20612E3476282222297D3B472E362E32383D352862297B3720613D342E333728292E31502862293B612E782D3D342E32635B315D3B612E792D3D342E32635B305D3B61';
wwv_flow_api.g_varchar2_table(23) := '2E783D313228612E782C3130293B612E793D313228612E792C3130293B6A20617D3B3520442861297B342E573D613B342E513D612E7628293B342E543D612E336328293B342E31333D612E325328293B342E31383D612E336128293B342E6B3D5B5D3B34';
wwv_flow_api.g_varchar2_table(24) := '2E433D743B342E32653D743B342E5A3D46204728342C612E32332829297D442E362E34353D3528297B6A20342E6B2E707D3B442E362E31443D3528297B6A20342E6B7D3B442E362E32523D3528297B6A20342E437D3B442E362E763D3528297B6A20342E';
wwv_flow_api.g_varchar2_table(25) := '517D3B442E362E4E3D3528297B6A20342E577D3B442E362E31733D3528297B3720693B3720623D46206E2E6F2E316D28342E432C342E43293B3720613D342E314428293B4228693D303B693C612E703B692B2B297B622E5628615B695D2E532829297D6A';
wwv_flow_api.g_varchar2_table(26) := '20627D3B442E362E31433D3528297B342E5A2E4B2874293B342E6B3D5B5D3B323120342E6B7D3B442E362E31423D352865297B3720693B3720633B3720623B3928342E324E286529297B6A20777D392821342E43297B342E433D652E5328293B342E3235';
wwv_flow_api.g_varchar2_table(27) := '28297D4C7B3928342E3138297B37206C3D342E6B2E702B313B3720613D28342E432E4F28292A286C2D31292B652E5328292E4F2829292F6C3B3720643D28342E432E313928292A286C2D31292B652E5328292E31392829292F6C3B342E433D46206E2E6F';
wwv_flow_api.g_varchar2_table(28) := '2E317128612C64293B342E323528297D7D652E31703D483B342E6B2E592865293B633D342E6B2E703B623D342E572E317928293B392862213D3D742626342E512E313728293E62297B3928652E762829213D3D342E51297B652E4B28342E51297D7D4C20';
wwv_flow_api.g_varchar2_table(29) := '3928633C342E3133297B3928652E762829213D3D342E51297B652E4B28342E51297D7D4C203928633D3D3D342E3133297B4228693D303B693C633B692B2B297B342E6B5B695D2E4B2874297D7D4C7B652E4B2874297D342E324B28293B6A20487D3B442E';
wwv_flow_api.g_varchar2_table(30) := '362E324A3D352861297B6A20342E32652E324928612E532829297D3B442E362E32353D3528297B3720613D46206E2E6F2E316D28342E432C342E43293B342E32653D342E572E32662861297D3B442E362E324B3D3528297B3720633D342E6B2E703B3720';
wwv_flow_api.g_varchar2_table(31) := '613D342E572E317928293B392861213D3D742626342E512E313728293E61297B342E5A2E314628293B6A7D3928633C342E3133297B342E5A2E314628293B6A7D3720623D342E572E323328292E703B3720643D342E572E3248282928342E6B2C62293B34';
wwv_flow_api.g_varchar2_table(32) := '2E5A2E336828342E43293B342E5A2E33692864293B342E5A2E326128297D3B442E362E324E3D352861297B3720693B3928342E6B2E3164297B6A20342E6B2E3164286129213D3D2D317D4C7B4228693D303B693C342E6B2E703B692B2B297B3928613D3D';
wwv_flow_api.g_varchar2_table(33) := '3D342E6B5B695D297B6A20487D7D7D6A20777D3B35203828612C632C62297B342E5628382C6E2E6F2E325A293B633D637C7C5B5D3B623D627C7C7B7D3B342E6B3D5B5D3B342E453D5B5D3B342E316A3D5B5D3B342E31653D743B342E31693D773B342E54';
wwv_flow_api.g_varchar2_table(34) := '3D622E33557C7C33533B342E31333D622E33527C7C323B342E31573D622E32437C7C743B342E4D3D622E33517C7C5B5D3B342E32643D622E31347C7C22223B342E317A3D483B3928622E3241213D3D3135297B342E317A3D622E32417D342E31383D773B';
wwv_flow_api.g_varchar2_table(35) := '3928622E326B213D3D3135297B342E31383D622E326B7D342E31613D773B3928622E3278213D3D3135297B342E31613D622E32787D342E316C3D773B3928622E3277213D3D3135297B342E316C3D622E32777D342E31493D622E334F7C7C382E32753B34';
wwv_flow_api.g_varchar2_table(36) := '2E31743D622E334C7C7C382E32673B342E31633D622E334A7C7C382E32723B342E31543D622E33487C7C382E32703B342E31523D622E33477C7C382E326E3B342E31763D622E33447C7C382E326D3B342E31533D622E33437C7C2250223B3928334B2E33';
wwv_flow_api.g_varchar2_table(37) := '792E334D28292E3164282233782229213D3D2D31297B342E31523D342E31767D342E327128293B342E326C28632C48293B342E4B2861297D382E362E32463D3528297B3720613D343B342E31653D342E7628293B342E31693D483B342E316228293B342E';
wwv_flow_api.g_varchar2_table(38) := '316A3D5B6E2E6F2E752E314728342E7628292C223376222C3528297B612E31412877293B3928342E313728293D3D3D28342E32692822337422297C7C30297C7C342E313728293D3D3D342E3269282232432229297B6E2E6F2E752E5828342C2232682229';
wwv_flow_api.g_varchar2_table(39) := '7D7D292C6E2E6F2E752E314728342E7628292C223268222C3528297B612E316E28297D295D7D3B382E362E32513D3528297B3720693B4228693D303B693C342E6B2E703B692B2B297B3928342E6B5B695D2E762829213D3D342E3165297B342E6B5B695D';
wwv_flow_api.g_varchar2_table(40) := '2E4B28342E3165297D7D4228693D303B693C342E452E703B692B2B297B342E455B695D2E314328297D342E453D5B5D3B4228693D303B693C342E316A2E703B692B2B297B6E2E6F2E752E336228342E316A5B695D297D342E316A3D5B5D3B342E31653D74';
wwv_flow_api.g_varchar2_table(41) := '3B342E31693D777D3B382E362E33383D3528297B7D3B382E362E32713D3528297B3720692C31663B3928342E4D2E703E30297B6A7D4228693D303B693C342E31632E703B692B2B297B31663D342E31635B695D3B342E4D2E59287B33663A342E31492B28';
wwv_flow_api.g_varchar2_table(42) := '692B31292B222E222B342E31742C31753A31662C31783A31667D297D7D3B382E362E33733D3528297B3720693B3720613D342E314428293B3720623D46206E2E6F2E316D28293B4228693D303B693C612E703B692B2B297B622E5628615B695D2E532829';
wwv_flow_api.g_varchar2_table(43) := '297D342E7628292E31562862297D3B382E362E33633D3528297B6A20342E547D3B382E362E33723D352861297B342E543D617D3B382E362E32533D3528297B6A20342E31337D3B382E362E33713D352861297B342E31333D617D3B382E362E31793D3528';
wwv_flow_api.g_varchar2_table(44) := '297B6A20342E31577D3B382E362E34303D352861297B342E31573D617D3B382E362E32333D3528297B6A20342E4D7D3B382E362E336F3D352861297B342E4D3D617D3B382E362E32473D3528297B6A20342E32647D3B382E362E336E3D352861297B342E';
wwv_flow_api.g_varchar2_table(45) := '32643D617D3B382E362E32423D3528297B6A20342E317A7D3B382E362E336D3D352861297B342E317A3D617D3B382E362E33613D3528297B6A20342E31387D3B382E362E34343D352861297B342E31383D617D3B382E362E336C3D3528297B6A20342E31';
wwv_flow_api.g_varchar2_table(46) := '617D3B382E362E336B3D352861297B342E31613D617D3B382E362E336A3D3528297B6A20342E316C7D3B382E362E34383D352861297B342E316C3D617D3B382E362E356F3D3528297B6A20342E31747D3B382E362E356E3D352861297B342E31743D617D';
wwv_flow_api.g_varchar2_table(47) := '3B382E362E356C3D3528297B6A20342E31497D3B382E362E356B3D352861297B342E31493D617D3B382E362E35693D3528297B6A20342E31637D3B382E362E35683D352861297B342E31633D617D3B382E362E32483D3528297B6A20342E31547D3B382E';
wwv_flow_api.g_varchar2_table(48) := '362E35663D352861297B342E31543D617D3B382E362E35653D3528297B6A20342E31767D3B382E362E35643D352861297B342E31763D617D3B382E362E32793D3528297B6A20342E31537D3B382E362E35633D352861297B342E31533D617D3B382E362E';
wwv_flow_api.g_varchar2_table(49) := '31443D3528297B6A20342E6B7D3B382E362E35613D3528297B6A20342E6B2E707D3B382E362E35393D3528297B6A20342E457D3B382E362E35343D3528297B6A20342E452E707D3B382E362E31423D3528622C61297B342E32622862293B39282161297B';
wwv_flow_api.g_varchar2_table(50) := '342E316E28297D7D3B382E362E326C3D3528622C61297B3720633B4228632033392062297B3928622E3530286329297B342E326228625B635D297D7D39282161297B342E316E28297D7D3B382E362E32623D352862297B3928622E34582829297B372061';
wwv_flow_api.g_varchar2_table(51) := '3D343B6E2E6F2E752E314728622C223457222C3528297B3928612E3169297B342E31703D773B612E316228297D7D297D622E31703D773B342E6B2E592862297D3B382E362E34553D3528632C61297B3720623D342E32392863293B39282161262662297B';
wwv_flow_api.g_varchar2_table(52) := '342E316228297D6A20627D3B382E362E34533D3528612C63297B3720692C723B3720623D773B4228693D303B693C612E703B692B2B297B723D342E323928615B695D293B623D627C7C727D39282163262662297B342E316228297D6A20627D3B382E362E';
wwv_flow_api.g_varchar2_table(53) := '32393D352862297B3720693B3720613D2D313B3928342E6B2E3164297B613D342E6B2E31642862297D4C7B4228693D303B693C342E6B2E703B692B2B297B3928623D3D3D342E6B5B695D297B613D693B34517D7D7D3928613D3D3D2D31297B6A20777D62';
wwv_flow_api.g_varchar2_table(54) := '2E4B2874293B342E6B2E345028612C31293B6A20487D3B382E362E344D3D3528297B342E31412848293B342E6B3D5B5D7D3B382E362E31623D3528297B3720613D342E452E344C28293B342E453D5B5D3B342E31412877293B342E316E28293B31552835';
wwv_flow_api.g_varchar2_table(55) := '28297B3720693B4228693D303B693C612E703B692B2B297B615B695D2E314328297D7D2C30297D3B382E362E32663D352864297B3720663D342E333728293B3720633D46206E2E6F2E317128642E323728292E4F28292C642E323728292E31392829293B';
wwv_flow_api.g_varchar2_table(56) := '3720613D46206E2E6F2E317128642E323428292E4F28292C642E323428292E31392829293B3720653D662E31502863293B652E782B3D342E543B652E792D3D342E543B3720673D662E31502861293B672E782D3D342E543B672E792B3D342E543B372062';
wwv_flow_api.g_varchar2_table(57) := '3D662E33322865293B3720683D662E33322867293B642E562862293B642E562868293B6A20647D3B382E362E316E3D3528297B342E32362830297D3B382E362E31413D352861297B3720692C4A3B4228693D303B693C342E452E703B692B2B297B342E45';
wwv_flow_api.g_varchar2_table(58) := '5B695D2E314328297D342E453D5B5D3B4228693D303B693C342E6B2E703B692B2B297B4A3D342E6B5B695D3B4A2E31703D773B392861297B4A2E4B2874297D7D7D3B382E362E33303D3528622C65297B3720523D34453B3720673D28652E4F28292D622E';
wwv_flow_api.g_varchar2_table(59) := '4F2829292A412E314B2F314D3B3720663D28652E313928292D622E31392829292A412E314B2F314D3B3720613D412E314C28672F32292A412E314C28672F32292B412E333128622E4F28292A412E314B2F314D292A412E333128652E4F28292A412E314B';
wwv_flow_api.g_varchar2_table(60) := '2F314D292A412E314C28662F32292A412E314C28662F32293B3720633D322A412E344328412E32592861292C412E325928312D6129293B3720643D522A633B6A20647D3B382E362E33353D3528622C61297B6A20612E324928622E532829297D3B382E36';
wwv_flow_api.g_varchar2_table(61) := '2E33333D352863297B3720692C642C502C31683B3720613D347A3B3720623D743B4228693D303B693C342E452E703B692B2B297B503D342E455B695D3B31683D502E325228293B39283168297B643D342E33302831682C632E532829293B3928643C6129';
wwv_flow_api.g_varchar2_table(62) := '7B613D643B623D507D7D7D3928622626622E324A286329297B622E31422863297D4C7B503D4620442834293B502E31422863293B342E452E592850297D7D3B382E362E32363D352865297B3720692C4A3B3720643B3720633D343B392821342E3169297B';
wwv_flow_api.g_varchar2_table(63) := '6A7D3928653D3D3D30297B6E2E6F2E752E5828342C223478222C34293B3928315120342E3167213D3D22313522297B347728342E3167293B323120342E31677D7D3928342E7628292E313728293E33297B643D46206E2E6F2E316D28342E7628292E3173';
wwv_flow_api.g_varchar2_table(64) := '28292E323428292C342E7628292E317328292E32372829297D4C7B643D46206E2E6F2E316D2846206E2E6F2E31712833342E34752C2D32572E3474292C46206E2E6F2E3171282D33342E34732C32572E347229297D3720613D342E32662864293B372062';
wwv_flow_api.g_varchar2_table(65) := '3D412E323228652B342E31522C342E6B2E70293B4228693D653B693C623B692B2B297B4A3D342E6B5B695D3B3928214A2E31702626342E3335284A2C6129297B392821342E31617C7C28342E316126264A2E3471282929297B342E3333284A297D7D7D39';
wwv_flow_api.g_varchar2_table(66) := '28623C342E6B2E70297B342E31673D3155283528297B632E32362862297D2C30297D4C7B323120342E31673B6E2E6F2E752E5828342C223459222C34297D7D3B382E362E563D3528642C63297B6A28352862297B3720613B42286120333920622E36297B';
wwv_flow_api.g_varchar2_table(67) := '342E365B615D3D622E365B615D7D6A20347D292E347028642C5B635D297D3B382E32703D3528612C63297B3720663D303B3720623D22223B3720643D612E702E346F28293B3720653D643B346E2865213D3D30297B653D313228652F31302C3130293B66';
wwv_flow_api.g_varchar2_table(68) := '2B2B7D663D412E323228662C63293B6A7B31773A642C32543A662C31343A627D7D3B382E326E3D35323B382E326D3D346D3B382E32753D22346C3A2F2F6E2D6F2D346B2D35382D34692E34682E34672F34662F34652F34642F34632F6D223B382E32673D';
wwv_flow_api.g_varchar2_table(69) := '223461223B382E32723D5B35332C35362C356A2C34392C34375D3B392831512033642E362E314E213D3D5C27355C27297B33642E362E314E3D3528297B6A20342E3436282F5E5C5C732B7C5C5C732B242F672C5C275C27297D7D272C36322C3333362C27';
wwv_flow_api.g_varchar2_table(70) := '7C7C7C7C746869737C66756E6374696F6E7C70726F746F747970657C7661727C4D61726B6572436C757374657265727C69667C7C7C7C7C7C7C7C7C7C72657475726E7C6D61726B6572735F7C7C7C676F6F676C657C6D6170737C6C656E6774687C646976';
wwv_flow_api.g_varchar2_table(71) := '5F7C7C7C6E756C6C7C6576656E747C6765744D61707C66616C73657C7C7C70787C4D6174687C666F727C63656E7465725F7C436C75737465727C636C7573746572735F7C6E65777C436C757374657249636F6E7C747275657C636C75737465725F7C6D61';
wwv_flow_api.g_varchar2_table(72) := '726B65727C7365744D61707C656C73657C7374796C65735F7C6765744D61726B6572436C757374657265727C6C61747C636C75737465727C6D61705F7C7C676574506F736974696F6E7C6772696453697A655F7C7374796C657C657874656E647C6D6172';
wwv_flow_api.g_varchar2_table(73) := '6B6572436C757374657265725F7C747269676765727C707573687C636C757374657249636F6E5F7C7C7C7061727365496E747C6D696E436C757374657253697A655F7C7469746C657C756E646566696E65647C73756D735F7C6765745A6F6F6D7C617665';
wwv_flow_api.g_varchar2_table(74) := '7261676543656E7465725F7C6C6E677C69676E6F726548696464656E5F7C72657061696E747C696D61676553697A65735F7C696E6465784F667C6163746976654D61705F7C73697A657C74696D65725265665374617469637C63656E7465727C72656164';
wwv_flow_api.g_varchar2_table(75) := '795F7C6C697374656E6572735F7C6865696768745F7C656E61626C65526574696E6149636F6E735F7C4C61744C6E67426F756E64737C7265647261775F7C76697369626C655F7C697341646465647C4C61744C6E677C77696474685F7C676574426F756E';
wwv_flow_api.g_varchar2_table(76) := '64737C696D616765457874656E73696F6E5F7C6865696768747C626174636853697A6549455F7C746578747C77696474687C6765744D61785A6F6F6D7C7A6F6F6D4F6E436C69636B5F7C726573657456696577706F72745F7C6164644D61726B65727C72';
wwv_flow_api.g_varchar2_table(77) := '656D6F76657C6765744D61726B6572737C616464446F6D4C697374656E65727C686964657C6164644C697374656E65727C6C6566747C696D616765506174685F7C746F707C50497C73696E7C3138307C7472696D7C666F6E747C66726F6D4C61744C6E67';
wwv_flow_api.g_varchar2_table(78) := '546F446976506978656C7C747970656F667C626174636853697A655F7C636C7573746572436C6173735F7C63616C63756C61746F725F7C73657454696D656F75747C666974426F756E64737C6D61785A6F6F6D5F7C616E63686F72546578745F7C646976';
wwv_flow_api.g_varchar2_table(79) := '7C6162736F6C7574657C706F736974696F6E7C64656C6574657C6D696E7C6765745374796C65737C676574536F757468576573747C63616C63756C617465426F756E64735F7C637265617465436C7573746572735F7C6765744E6F727468456173747C67';
wwv_flow_api.g_varchar2_table(80) := '6574506F7346726F6D4C61744C6E675F7C72656D6F76654D61726B65725F7C73686F777C707573684D61726B6572546F5F7C616E63686F7249636F6E5F7C7469746C655F7C626F756E64735F7C676574457874656E646564426F756E64737C494D414745';
wwv_flow_api.g_varchar2_table(81) := '5F455854454E53494F4E7C69646C657C6765747C73746F7050726F7061676174696F6E7C6176657261676543656E7465727C6164644D61726B6572737C42415443485F53495A455F49457C42415443485F53495A457C746578744465636F726174696F6E';
wwv_flow_api.g_varchar2_table(82) := '5F7C43414C43554C41544F527C73657475705374796C65735F7C494D4147455F53495A45537C666F6E745374796C655F7C666F6E745765696768745F7C494D4147455F504154487C666F6E7446616D696C795F7C656E61626C65526574696E6149636F6E';
wwv_flow_api.g_varchar2_table(83) := '737C69676E6F726548696464656E7C676574436C7573746572436C6173737C7465787453697A655F7C7A6F6F6D4F6E436C69636B7C6765745A6F6F6D4F6E436C69636B7C6D61785A6F6F6D7C74657874436F6C6F725F7C636C6173734E616D655F7C6F6E';
wwv_flow_api.g_varchar2_table(84) := '4164647C6765745469746C657C67657443616C63756C61746F727C636F6E7461696E737C69734D61726B6572496E436C7573746572426F756E64737C75706461746549636F6E5F7C6D6F7573656F75747C636C69636B7C69734D61726B6572416C726561';
wwv_flow_api.g_varchar2_table(85) := '647941646465645F7C75726C5F7C6372656174654373737C6F6E52656D6F76657C67657443656E7465727C6765744D696E696D756D436C757374657253697A657C696E6465787C6D6F7573656F7665727C6E6F6E657C3137387C626F756E64734368616E';
wwv_flow_api.g_varchar2_table(86) := '6765644C697374656E65725F7C737172747C4F7665726C6179566965777C64697374616E63654265747765656E506F696E74735F7C636F737C66726F6D446976506978656C546F4C61744C6E677C616464546F436C6F73657374436C75737465725F7C38';
wwv_flow_api.g_varchar2_table(87) := '357C69734D61726B6572496E426F756E64735F7C646973706C61797C67657450726F6A656374696F6E7C647261777C696E7C6765744176657261676543656E7465727C72656D6F76654C697374656E65727C6765744772696453697A657C537472696E67';
wwv_flow_api.g_varchar2_table(88) := '7C706172656E744E6F64657C75726C7C6261636B67726F756E64506F736974696F6E5F7C73657443656E7465727C7573655374796C657C676574456E61626C65526574696E6149636F6E737C73657449676E6F726548696464656E7C67657449676E6F72';
wwv_flow_api.g_varchar2_table(89) := '6548696464656E7C7365745A6F6F6D4F6E436C69636B7C7365745469746C657C7365745374796C65737C6D61787C7365744D696E696D756D436C757374657253697A657C7365744772696453697A657C6669744D6170546F4D61726B6572737C6D696E5A';
wwv_flow_api.g_varchar2_table(90) := '6F6F6D7C637265617465456C656D656E747C7A6F6F6D5F6368616E6765647C63616E63656C427562626C657C6D7369657C757365724167656E747C3130307C646F63756D656E747C6C696E657C636C7573746572436C6173737C626174636853697A6549';
wwv_flow_api.g_varchar2_table(91) := '457C616C69676E7C7365745A6F6F6D7C626174636853697A657C63616C63756C61746F727C6465636F726174696F6E7C696D61676553697A65737C6E6176696761746F727C696D616765457874656E73696F6E7C746F4C6F776572436173657C77656967';
wwv_flow_api.g_varchar2_table(92) := '68747C696D616765506174687C66616D696C797C7374796C65737C6D696E696D756D436C757374657253697A657C36307C636F6C6F727C6772696453697A657C636C7573746572636C69636B7C696E6E657248544D4C7C726563747C636C69707C737263';
wwv_flow_api.g_varchar2_table(93) := '7C7365744D61785A6F6F6D7C696D677C6D6F757365646F776E7C637373546578747C7365744176657261676543656E7465727C67657453697A657C7265706C6163657C39307C736574456E61626C65526574696E6149636F6E737C37387C706E677C626F';
wwv_flow_api.g_varchar2_table(94) := '756E64735F6368616E6765647C696D616765737C6D61726B6572636C75737465726572706C75737C7472756E6B7C73766E7C636F6D7C676F6F676C65636F64657C76337C73706C69747C7574696C6974797C687474707C3530307C7768696C657C746F53';
wwv_flow_api.g_varchar2_table(95) := '7472696E677C6170706C797C67657456697369626C657C30303034383836353632357C30383133363434343338343534347C34383338383433343337357C30323037303737313734333437327C6A6F696E7C636C65617254696D656F75747C636C757374';
wwv_flow_api.g_varchar2_table(96) := '6572696E67626567696E7C706F696E7465727C34303030307C637572736F727C617070656E644368696C647C6174616E327C6261636B67726F756E64506F736974696F6E7C363337317C73657269667C73616E737C6F7665726C61794D6F757365546172';
wwv_flow_api.g_varchar2_table(97) := '6765747C417269616C7C666F6E7446616D696C797C6E6F726D616C7C736C6963657C636C6561724D61726B6572737C666F6E745374796C657C67657450616E65737C73706C6963657C627265616B7C626F6C647C72656D6F76654D61726B6572737C666F';
wwv_flow_api.g_varchar2_table(98) := '6E745765696768747C72656D6F76654D61726B65727C746578744465636F726174696F6E7C64726167656E647C676574447261676761626C657C636C7573746572696E67656E647C72656D6F76654368696C647C6861734F776E50726F70657274797C74';
wwv_flow_api.g_varchar2_table(99) := '65787453697A657C323030307C7C676574546F74616C436C7573746572737C626C61636B7C7C636C656172496E7374616E63654C697374656E6572737C6C6962726172797C676574436C7573746572737C676574546F74616C4D61726B6572737C746578';
wwv_flow_api.g_varchar2_table(100) := '74436F6C6F727C736574436C7573746572436C6173737C736574426174636853697A6549457C676574426174636853697A6549457C73657443616C63756C61746F727C616E63686F7249636F6E7C736574496D61676553697A65737C676574496D616765';
wwv_flow_api.g_varchar2_table(101) := '53697A65737C36367C736574496D616765506174687C676574496D616765506174687C616E63686F72546578747C736574496D616765457874656E73696F6E7C676574496D616765457874656E73696F6E7C636C6173734E616D65272E73706C69742827';
wwv_flow_api.g_varchar2_table(102) := '7C27292C302C7B7D2929';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33058399364766772)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'markerclusterer.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D49484452000000350000003408060000002ABA70D5000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082A11';
wwv_flow_api.g_varchar2_table(2) := '9200839500000B3B4944415468DEBD9A5B8C5D6775C77FFF7D66C6638FC7F6C471629C40139AA4A913053058DCA14A0BA9DA7011E181B6525111F040E005CE163C70111709C139028907505504A87988902A352A8990824AA526A14004283121C56E48D2';
wwv_flow_api.g_varchar2_table(3) := '38C4E3D8E3198FE77ECEFEF3B0D7DEE79BE3DB991B5B1A9D3997FDED6F7D6B7DFFF55FFFF589CDBEDA06C800010DA0810DD2087681D4018C5DBE967F0579D6BBBFA90D4D61FD77B70AEA8994EF478151A4A1302443CAC280789A0803C1165281DD45EA62';
wwv_flow_api.g_varchar2_table(4) := 'AF202DD0D4CA46D755EBF24453A55120A43160671801B691CA716DD7CF888F6A03E1C2BF8315E02CB0542F5AFF026EAA513D8332A49DD83BC21B9531E998D5843B6154119FA90ECDD240275E74F2FD32D21C4DCDAF352CB5E6706B15DB91760359845215';
wwv_flow_api.g_varchar2_table(5) := '5E95478C3D07CC23752E3A91B6C1DE86B4037B7B6F468971E55805D2699AEA0C6A98D6E41DD8036C078AFAFED23B1DEC05A479EC21A41DC06EEC09A49DC0484C9408B905ECB3C0196016691E10F64E605B004DB540D562CD60CF916797F59A0634681869';
wwv_flow_api.g_varchar2_table(6) := '2226ECFADE7215A7696A91B60F00D70363D8233131AF0288D5FF5793ED602F214D631F25CF66697B1CD8152093EECB25EC29F2CC1BF354AB1806F6F581808145601AB80AB82D8CE9D6007021C4AB21C2AC1AAF37F1216012783CBCBE1769B80F4C9681D3';
wwv_flow_api.g_varchar2_table(7) := '97326CE8B2FB48DA960041E91D3889B40BFBF5617001746AA8B61B113A33C01CD26CED357B18691C7B2CBCD1058A307A05FB4AA4B7623F8FF464A0EA15C9020D233580CEFA8C92A0A97309DA75C9B349DABE1EFBD6F855374251E1A559E029ECE30988EC';
wwv_flow_api.g_varchar2_table(8) := '077647481E8D9C64EC21E0E5C00D013C8A9013F052ECAB8047C27BFBE2795334D5D968F8119B7307F622702B705D1F581461C431601CFB16A45B819701FBEBB02CAF46E4A2E3C0B348478027B187819B90AE8EB19D24E8234827B121CF162F97B7B44638';
wwv_flow_api.g_varchar2_table(9) := 'BF0EE995B5EBED0C3887F410F63EA47F0AAF8C24FBA79764D33D95C2B7B488FD38D23D1192AF0DE31D51B0023C4C9E9D1B04D6B58EC4FBE7112E203D0D1CC3BE03E91DB199530F6611722BD8CBF1BCED492E2A12841C06CE62DF83F4247018988850FD25';
wwv_flow_api.g_varchar2_table(10) := '4D9DD81A46D10BC59BB1678105E06EA4EB2257556032823403FC1C780CFB45603E567F0CB81638041C0E033B754E9232ECFF21CFBE43AB38089C20CFA6D64295D6CEFD526601AD586127407106F837E017D83723DD8E7D6320DA09A4A78087B0FF1B7811';
wwv_flow_api.g_varchar2_table(11) := '7837F0C6E090156D1A029EA7A9CFFDF1587A158A6DDF09BC33F6C802D2BDC073C0DDD8770137AD42D2D5390AA48781EFC422DC81FDF63A074ADFA2A9FF5D2B99DD58E9D1F3DC5DC09B903E07BC01FBDF91B625F4E6FC7B7ADCAE028DE7915E8FBD1FE983';
wwv_flow_api.g_varchar2_table(12) := 'D86DF2ECD87A0CDAB8513DF09840BA1BF8621242838E5D21DC39A4F761FF883C5BDE48B19845A55AD547EBBD3E80FDC5241769CD0B5B12DFFB915EB5394562C9EF8CD4A5299FE7894B87DFBB80FB56157DEBBD4AF4EC60DF449E3DB3A668594593CABA66';
wwv_flow_api.g_varchar2_table(13) := '77A0589756B114546784A6162F5ABE97031E00FE65D3F667B928C3489F07DE3FD0A2BA8EB491E0A92BA2ED2C7855237E34170FF80B602ED0EC77A125B8F664B9189F406A6FBA7853F1C59267AE36AC12764A627B2D4D3D45DBFB826681B428DA6E44F9A0';
wwv_flow_api.g_varchar2_table(14) := '487E2F06E5794D30F221A4FB81F744E1F734F024D271EC27900E6EB2415518DF4B537F1F5E1803FE3418FF4C943ABBA2BE7B200ACB1D91268A4ACACA924DBE8C7455F2FE2C4DAD60DF06BC06E9BD487F89BD1B38B8E95EEAD5627F17067D01F82AD24781';
wwv_flow_api.g_varchar2_table(15) := 'BFC65E8AF2BF8BB4827D1576A7961620CB80E1A400EB86AB4792C754E1784D02BF4F037FCB565D55FE6A15B72035A27E2A906E413A57F3CBD290B160FD751AC912C98AA4901B0B342B9942DB63D80DEC8A0E9D45FA3324B6D4B072AF4F4535A078FE7812';
wwv_flow_api.g_varchar2_table(16) := '450EADD1E95CB28B0CE8C4D82EB01FA988585F024E614FF42D085B148A937DC83A7441F44BE6925D1685CA81CF25030F03E35147B1C59783D5BB0FF62FE6D9306AB572AA0B1471DBC8B3C9245433605B283B5B6C920BE01AA0A8EBAFA64EAF527DABFDB7';
wwv_flow_api.g_varchar2_table(17) := 'CA53E58DAB3D57C2A6C2533BE2BB3331888183D8F7C682784B3C544EF208D2B6F04E86344DDBA3C9E22BC49D067D467491149315AD62089849DC391EAF47631023DD081C8B22515BE02121FD3654AAD158E806F058CCA75AFC0CE9546C890A48C8C2B59D';
wwv_flow_api.g_varchar2_table(18) := '989C23919D4924E5115AC504F6D15A0A861B817DD8DFDE42E4FB08F6A1C8490E95F767C0DE2497197B1669B8D6F1A5E52CE0B09B0CB91D7B3EC44AC57737004FD49F9512F3FB81EF024BB5A4BC799E3A42533F46FA9BA4AA3E419E3D075C9D183E459E15';
wwv_flow_api.g_varchar2_table(19) := 'E1A9EADEE58CA68CDDAD2D2F63B88382CC967BEE00D2E98072A29F7403308DFD40A2DA6EC65EEA223569156F03AE8C7133E047B48A5DC0DE24D11EA7550CD739B43474B182F4A5042E8DBD0D7BB286F43244AF05EE431A4D90E61F80BB809F6C786FF558';
wwv_flow_api.g_varchar2_table(20) := 'CDD7B17F83745768EC20CD613F9AC8738AD749A4F1883605D3E85446CD27C0606007702C949DCA832F23CF1EC3FE75A2C95D177AC45FC5E7E904D78674E53EF932D2A7800FD77D2ABB01FC2C26BD07BB8839CD00F3C99E23F4C1A2AC7CCB3A6931C95143';
wwv_flow_api.g_varchar2_table(21) := '756C43230CDE49ABB815F867A4D9BA8523BD1AF847E076ECFF48988007F04EDA0EFA2CF035EC8FD53CB3E47DBFA3A97BB16FABD38FD4C07E0A18AFD94F39D622794696D42AD34902167005F00CD2D9785F20BD3C14D4EF2774651938141AC5FBB0EF0C20';
wwv_flow_api.g_varchar2_table(22) := 'D1459373AF5705F02BE000F677913E19CCBFEAFBCE00DFA4551C44DA55C3384C926727A257E63A25E5D95C8F41B46BFE34110A6AB5394F47ADF58A244C8CFD20F056E0BD492AC80240EE41FA05F6BB810F21EDC7DEB3AAAF0527B18F856E7804FB0EE03D';
wwv_flow_api.g_varchar2_table(23) := '484B09302C607F2B9A72AF4D14DE0ED283D83B6BADB05CA3B3952CADBEF27C047B6FF2F0AA6D7308FB9ABAC35186EA7F221DC6FE501853A9B3024E01CF02FF1A4973CF2A51C69E42BA05781D707D30EF22599C59ECAFC6FBC3B5D7CBD7C7914E007B9348';
wwv_flow_api.g_varchar2_table(24) := '5889E216F22C31AA27505E813D5A330C58A4A929DABEBD8F5C36B0FF2B7A4D1F8F560FC97D0BC09768EAD405C49AD108B5037D0A94B19F05BE11E17F285845B5182F90678FD2F64BFAF8E919F26CF17C96DEAC89ED541CE0A868C7286DEFC27E28126DB5';
wwv_flow_api.g_varchar2_table(25) := '570AE0CDD8DB913E8D7D1F700E188D8D7B328E0E9C7FE5D922F6EF1382BC1DFB24F6F780AF0037221D8AC4EF78E62479F628ADE2CA045C84BD941A747EE9512946F699BECDBC3338D88F91166A83CB50B919FB4DC0C34879C8C873C0FFD3D4F225A8D06F';
wwv_flow_api.g_varchar2_table(26) := 'C3DB2F002DF2EC3321F2DC89746D5FF7641AE9E7B4BD2F4ECE1061DE05A6FA754B5D42CF1B43DA13CDEA8A64CE44E3ED30D2D5D14CAB1EDC08C6712C3A7FA3FD2BD837FE7854ADA7A26B783DD244D2F6ACC8F3B334758456B1374A9EB4803D459EADF42B';
wwv_flow_api.g_varchar2_table(27) := '4E97EBCE8F63EF4A0E76187B29CA903F015E594B6795765E1D0469EA81015A426FC11E8BA33FA4E24918F44834CBF7D57DE45EB3EF1479B674213D32BB8CF2391BFB244DA6A348FB80E7B01F449A0A6F2A49BCD3AB52C5F97B8ABA464BCF5894CFE900CF';
wwv_flow_api.g_varchar2_table(28) := '91673F8830DE9F34C6ABFD5C1AD4230EEB381C5282C11554A7BECA507420DC4C68702F8DE6DB28F64FC9B3E3038C3D01DC1E7B6309380ABC1039694FBD7F7A0D3947237BE9521D916C202A93670BD8A78277A50BB103FB40FCFF044DDD0F3C8274FCA25E';
wwv_flow_api.g_varchar2_table(29) := '4A43D09EC6FE3FEC9FD0D40F8167229D5C1D325D7ADEA924B097316870FDBBD7B26900BB90B6AF3A2CD583D825600E7B71E0BE52AB688464305AD745FD87B7CA56EC39F2CC83E8EB833DB93A0A9767DDD80753C10555F32EC7012A181958652ABDB9137B';
wwv_flow_api.g_varchar2_table(30) := '1C7B385928D55D797B126976508336D6F32D273516A472B88EF9BEEC3E8061D5E1ACF414DA12D27CDD7559634771EDBDC7B2895D79702EF6DA8BD1FEE9240C7BD06B393CB41CDAC8C90083F210C83A5AA47F00FF136947614E93120000000049454E44AE';
wwv_flow_api.g_varchar2_table(31) := '426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33059109797766773)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'images/m1.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000003800000037080600000059D089CB000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082935';
wwv_flow_api.g_varchar2_table(2) := '852E348700000C3B4944415468DEC59A5B6CA56775869FF7F7F6611C7B0E9E49C2E41C8610483230A401955605F68F202861B8E024B800120909B50855AAE0A612EA454F522BA4F682AA055A21AE68AB5E1444C221DA3B4224402003219310C221936486';
wwv_flow_api.g_varchar2_table(3) := 'C499B13D3E8FB7F7FEDF5E787D7B3EEFD81E7BEC497FC9DAD63EFCFFB7BEF5AE77ADF5AE4F5C82AB6A80846C14AF3540127D40CD6659A2B2A9243A3696B08D8B72E51E6E82EADB5F8BB6F3E3DE45B8493F301846F4037D127DF6F9AF481086AFBCB1F259';
wwv_flow_api.g_varchar2_table(4) := '47A20D2C03CB36ADA2A4BD139BADED7829DBED619BCB805ABA6F18928C5AF73936A4EF86D1066CB30CCC1625ADED7854DBF09E8021600F50AC654CB6F8E443AF588FE233F518E858537A15D0B299065A45B9754375317074935DC065368369C7B3852BFE';
wwv_flow_api.g_varchar2_table(5) := '6F014B01BBB64D959C0F14E1AD1AD06733203100F4A7CDC8BC990C5DB4992D4A96DD5CD99084A06D1BD863DC98CD5016538A4549A203CCDA2C1425540DFA81FDC05E8991148BE1B10A989598B4992A4AAAAA81244663F394DD9F0C01F345C9CC8E793019';
wwv_flow_api.g_varchar2_table(6) := '5735A849EC8F1DEF7A2C1EDAB69909B218B1B956E24A6034BEEB4430397C9377029A5336A724C681057B0525595C3B5BF3A2C4B4EA541782AC364324558341605F40CBB1B80268494CD9141237D8BC0AD81BF7ADB4097C24EF67C6B66D2681DF4B9C0CD8';
wwv_flow_api.g_varchar2_table(7) := 'EE8DE7395B735B6242753A39E16DD983E1B92B33AF394865A628997593EB6D6E8994A01EB2E92E28C566F7C119F964E4B2DA76B328F15360DA66BFD48DF9F4DDCA66BC28F1457930B9DF4D76032319494C0654DF2071D0A6139ECD21B768B32031613323';
wwv_flow_api.g_varchar2_table(8) := '712620970CEB84B7F7488C01BB805D91FC73CFF649FC1A780A180646527C02678B92C58D60BA9518DC2D310C9CB1392071D866382A124B1461F4EF257E034C01076D0E495C673328B1373C83C4B4CD69E045E0D7C09CC4E5C06BC3F04E0F7C27258EC566';
wwv_flow_api.g_varchar2_table(9) := 'EEB3395B949CDB560CF61A1AD7419B3B12B4125948CC01C75467DA4DFEC4E6BDC0EE0CB679F2EF85A880DFD97CB32879D24DAEB1391C0493183A114D0358484475A154A1AD562E55835B240E6595C7B2CD33C033127F68F34189DD402BE0AC0C9645C688';
wwv_flow_api.g_varchar2_table(10) := 'DDA2203EEB03FA8113C07F4AFCC6E636E09A8CAC3AC0E3AAF3FC6613FE962A99AAD1FDF77512AF05CE013F005E65F37189AB028229252858B02651441A6847AC5D198CD906DA59CE2B806589A76DBE0A0C4BBC390A864755677C23D6DC76A99679F2F512';
wwv_flow_api.g_varchar2_table(11) := 'BF058ED8DC9B41304FD00BC0F781478B92E7A2CB48E9A1267173C0FD2D40ADB77EB59902FE213C3752949C7A456AD164A49B5C0FFC6556471661E093120FD89C02EE08E8FE01B01BB819F889C402F088CD0F259E026E07FED8E686F0B2A3239901FEA228';
wwv_flow_api.g_varchar2_table(12) := 'F1C514DCDB29B653B23F6A7334D8741EF832F012F07989BB6D5E9DC5DAAA3C18EF2D49FC0AF80AF06FC03B800FA4CF802F1525C75FF16EA207AE1F0E4FFDBDCD1B25EE07863222DA70AF32223A01BC0D18033E05FC7B51F2E8FF5BC3DB63E498C43D365F';
wwv_flow_api.g_varchar2_table(13) := '482960A33E70AD922DE26E02F898C483AAB3B8154259EB2A3266BCB81D52F7F5A3365FC8DED716EF93C869BFC47DC0E11DEBE8AB46B78836ACDEB1CD60DF4DEA368D756ACA8B0AF158CBA1A2E4C4C54A28008AE6711F3024D18AC09E03068B92A50BDDA0';
wwv_flow_api.g_varchar2_table(14) := '6A70204AB33D3B295C05217D03F890446BBD4DEE857020B2167FED5AD07A2DF03F081445C95CD5E0AD55830EF092C429D599CB9ADEDCD0CF02BBB71A739B84EDDD36B7A9CEB1F50C8BF8AF05319D01C642E82A80C56458DFAAD26B456F198B326C9FCD55';
wwv_flow_api.g_varchar2_table(15) := '5583E3126FB779C466DC4DDAD1C2DC9DAB643BE9C428DF3E03DC9BA5A61AD0A73A4B55839B81AB254623DD7CCFA62F7E0730504B2D49F456925806AE486D4BC4D50470ADCDBB81A3D1E47E5D6209B8ED1218970B52F700F7560D0ED91C91B8D666C44DFE';
wwv_flow_api.g_varchar2_table(16) := '29CABDD14CEF198CF5A622BE560B517695FC106A595722880EFB884415F5E758B4436FED51C376DA48074FDC6A7308B82B64917EE0B2D073F6455A2A422B6A45FDBA92267AE3C6A613FD9E53272E311B5A8B6C1C12C5D3C0BB772A9F5E204FBF1738191B';
wwv_flow_api.g_varchar2_table(17) := 'EC88AFFEA8559569B1C39963BAA5D6CBF25A32AE47BE1B8DCF243163770BE657E2EA0073F68A081C65E18DD175AC5A67EF7A8ACDD075DAB18CBEA7E36683F6A5B72EC2A01DFD259974D2FBBD97895DC53A06D1B3F076E4C69484AF8BDFCEF00A5D218FF4';
wwv_flow_api.g_varchar2_table(18) := '676F2DAF151AE18CEE55CBCBAD8C6C167AE87A97CD7C826840E600F0FCA586686CF4B3A1C9D662B3FB8067437725AB7D97D78AC1F6AACA6685559732099E50A6CF6474DCB17903F04078FB520135D1FDFDC00D59E73119296A4FE28B283597ECD5615304';
wwv_flow_api.g_varchar2_table(19) := '969D61BD1F180F952CC90F63A1BB24A5AB1D5DF8D3129397824583AD25F1A4EACC01372545CE66C26631D25562D60A98EF9D6C1571A37676E39AEA2CC45427699C23C078E49804D19BC2E0072F497E5077A17F5D35B809B826F3E80B12B5986124D5AD15';
wwv_flow_api.g_varchar2_table(20) := '445464AA5DAB90707C9052C440183A1EF1966AD4C15099FBB2B1D69DC0BFC66CE252C0F469E07EE05E9B56128C6D9EB0B92A1853919F5F4A93E4ECF7AD4275B0594EB164D3E72603122F24468ADDBADAE63BF92C4FE208F088C437B3B9DE4EC1139B7F94';
wwv_flow_api.g_varchar2_table(21) := '38045C918C913807FC4CE2BA282F53A83D2BB12B1F15489C4B062C27252B20396AF3524C795202BDA12899001E90E88FF787A38B7F3FF050AA7476805814C8F82FE02312ED20BB41E0BBC1EA435915365394CC45899920DE063A45587B2E49F0A9688DE0';
wwv_flow_api.g_varchar2_table(22) := '1D4F1EB319A81A1C06BE132C963C7618B847E23D123FDF26E12462F967E0CF243E09ECCDBC745275BE1D9A6C9109C68FC7F9803C4F2ED9544557025C69379405F288C4898086A3C87D4D7CFEDD0C4AED108A8E0277493C9C687A93558EB302A302BE188A';
wwv_flow_api.g_varchar2_table(23) := 'DC4781374657A34801FFE226076DAE8E1091C47474377B393FDF37B054942BCD6D72E94C960B6DB3CB66C6E6C5C44C61CC11A069F30B89C1804E2BE4BEF7D9BC0BF884CD64260D7AA3541031FD338952E2AF804FDBBC33C66744717F7F54536F8A3E356D';
wwv_flow_api.g_varchar2_table(24) := 'CE099B3E8981D474675DCFF9B246F5155D3355069107478163D994C721DEDE56947CD1E6F1D45CC6036F97F83BE03870C0E6E331C8D40642D33189B7A9CEEDC1907F0BE70BE928E87FA83AF78584DF97B5670BAAF38CC49E342E08242CA81E48ECD1328A';
wwv_flow_api.g_varchar2_table(25) := '183DE742EDE948F46F4E10B619001E937816F8D380522793DCFB259E0C283F15315DE693A5186AFE28D2D2AD364781AB80A56CD608D004BE2E7187CDC1EC1915D08899C7EEAC49EE14E5F9F945ADA72DAA80799B91EC46FB43973961736378B76573ABCD';
wwv_flow_api.g_varchar2_table(26) := 'A8C4576C4A890F453B53492CDBDC2C710BF02DD5F91FE07FD750C16E04FE3C9ED7855540AE63F33589476DFE28F5A809D2C0B1088D2BF2830A1267D76C9754EF0A49B3590275ECD098EA1C074EA7F9834415F2C1EDC07D01ADA9CCF3954DDBE6890DF2DD';
wwv_flow_api.g_varchar2_table(27) := '7336C35119A58A44C0499BCF493C06BC3D0AED2A8BBBDF4ABC10D24AD2538961CF929BE795B6620D59D0210574094762A06AB0BB28F951285709DE963800DC293127F179E0BF635658C5DFAFD6D3308B924E24E8A13839F194CD7F48FC4DC4F03B02DEC9';
wwv_flow_api.g_varchar2_table(28) := 'F8023809FC12B83C0B19C5E4773673D4DA524336391A8E9315CE14B705E0ACCD9B80EBE25C4C7EC0E06CB450A76281D716258F6C241E570DDE22B1CBE60989D9A898AE0F32ABB25011F073E079607FC46E1EAB678A9256AF4EAA0B0C3AF784B8938C1470';
wwv_flow_api.g_varchar2_table(29) := '4E7526DDE4269BD7AD354489EF3F27F184EA2B9B7081F9FF5EE0FA388AD27B08211D19790C78C1E672895A566413F3FA853595ED0B0C5624B12F4E4054D9ACBD15796E8FCDEBE3F040D53329AA497C632303B3CDBC2BDAB44E827ED4C1551C52381E461E';
wwv_flow_api.g_varchar2_table(30) := 'C82A98B49619D5995B6F48536CB4BB458943329CCF15B8385B764524FE1F030F4712EECF5879DC5E39A4B389E1CD8B3D9B33009C917828F2E4506C62911D5CE803A6A3575C7702B5AE81C9D512A8CED9605727D52D987454E280CD94EA346D1EB2391B39';
wwv_flow_api.g_varchar2_table(31) := 'EAB474E1D157407F222BFB2624BE57943C0C2C025706D3929FB8B099284AE6B3D31F3B72086138E4C324F5E7877F9680F998E90D019DA2647993F7DD15709F9658B4B94C623890E26C76989E33A3FACB09E5A20DEC39FCDA67B327A89DAC444A3BDB8944';
wwv_flow_api.g_varchar2_table(32) := '3FB5D111AB35E270248C2A221CE8893542C59B4F65D8A606A09BFA52B90ABA9DA26432A0D8C98E8B74072636DAAC71591C0E459D5964C27362E5659BD3AA33B7D57EB3E022AEF0E8421C7D9C8E122B49FAA9BBA06A6E6968B91C8545D2361D2731A654E7';
wwv_flow_api.g_varchar2_table(33) := '743A08BBD571F64E9DD926BA8A74A0EEEC66E32F337430EADE561C0B5BA96BEB9B9F34AF75FD1F0AC219E5F22D72070000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33059513691766773)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'images/m2.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000004200000041080600000065C07246000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082A2C';
wwv_flow_api.g_varchar2_table(2) := 'CA68CF8400000EF44944415478DAC59CDD8F9CF755C73FE799D937DBBBB6E3B7244E53DB4993344E4A04729B3608FA1A540A52ABB6820615F5861BDA72C32552051217FC05880B0A2D15A5481429424254A4081252A212540A4EE2247662BB49ECC4217E';
wwv_flow_api.g_varchar2_table(3) := 'DBD7999DE77071BEBF7DCE3C1EC7BBEB5D7B246B7667679EE7F73BBF73BEE77BBEE78C8D4D78D440D5FA3D3F0CBA7A8B011D8FDF970D96F59681C3C000D70BF97AAE0F6EE4C33671F366600E95C1B8C3043066309637547EB42BD7E240DFA10F2C59FC5C';
wwv_flow_api.g_varchar2_table(4) := '5BFCDB70A3D8461BC0A172E81A4C3A4C188CE77DAF72E14E1831AFD30D7A0E4BC02230A892B3B5D771D33CC2A1034C12273F214F706DFC8AFD9717BCB59851EFF7E4311E9E3670E8591864D16490EBF10EBB5E4FA8E3225B812DC8ED7DD8DD5D8BC7753F';
wwv_flow_api.g_varchar2_table(5) := 'DDB49F363D9021CBDFC7B579F4F995EB79CB600A9DF90AE6AFC718B68E93C71B238C1B6C27C0CEDAA7A91FCABA8B4B2F39D4D595189A71A312884E10E135A1EBBB35619371A506961D2E54F1BCB2C64D31448EC31AB61B6C29A79DBD3D9DFCA2C3AC851B';
wwv_flow_api.g_varchar2_table(6) := '97F0D9EEB083F0A2C9143EE5020BC09CC305834B06B58C33096CF578F6EC71691FB5C35C0597D78A1BB65A2FB06130BC8500C1E2BED60A8779E092507E9BC37E83BD1EC6AB92BB6357C78D82051780378033F2A80E3063309541D5860F62D1C290BE5A83';
wwv_flow_api.g_varchar2_table(7) := 'D81ABD60DCE234BB05C4F269140FD02676017713CF7893F6561BC665936661FCDAE02DE084C379197C5A99C9DA3802F450A8ACC618B6DA90A06584D6692C217774B815B8CB608748917BB3C06C04B356E2F01654643CA0E1251DE06DE015833745C6A60B';
wwv_flow_api.g_varchar2_table(8) := '505B139AA6755D1059DB98D000B60133DEF2620B032C38EC060E19EC957BD69640CDE3402A2D6ED1E3C416ACD9BF035D61C038CD732D9CC8E0583CE42CF08AF064ABC71AB33100DEB10895EB3344D9B198E2B4C3565B7989F31ED6BE17B8D3C36BBC95F7';
wwv_flow_api.g_varchar2_table(9) := 'BB0458BE4D9CE0450BC32D2AF3ECD1662B8373757C6E92C0809DC296DD40479891E1A5121E9D3478599FD991B2CA6587D96AA34223839847BA9C927B8E197CC06333852B1437AE082678C2E0B4C1620DB703F718BCC7E176196B3285CC820CF9B20C77CC';
wwv_flow_api.g_varchar2_table(10) := 'E09C47763A208FEB685F859F9878C859E07FF4FB2DCA56B3B64A50B27512A84AA7F68872BD25172FA7711C7849EEFE61835F0276897E7784FEB430A2187399C0971A78DDE1DF801FAB58BBCFE160F2BC7CCF39871F898A7BB58614BA6642950C72BF4556';
wwv_flow_api.g_varchar2_table(11) := 'F0C41D4CE0F4ACE8EFA30E9F9607798B6C79F2A29C9E3316E453BF0C3C6EF0A40710FF3CB0AD182461D63183E3F56612AA11A1F220E1B265D12780970C0E393C6670403581B74E3C33CE41CA40DD16AD26112EF308C5171DBE6B70D6E1307047BAD67183';
wwv_flow_api.g_varchar2_table(12) := '63EB29C0D65D6B24107D8088F7173CF2FC27812F28650D686A8C4AAB9D15885D06E688D8EE5984DA6D0E5302E51965823A9D3A16A1B66CF03D87A765EC43C0AB15BCB4DE2A7423CAF08A00D009835F073EE802331A03546287CF014745886A6D7A4660FB';
wwv_flow_api.g_varchar2_table(13) := '86E8F5BC0727D86D61E4C30E7B64D4629012FE4F02FF0474AAC838EB2EC5AFCB10ADD8FE65E031B97F2D2FE81239FE09871F1314FB51870F0177101BDCA68DBEA1C2ECAC479679DAE10981E6871D3E21AF59F646E55A04FECCE0E84D1766125E8C3B7CD6';
wwv_flow_api.g_varchar2_table(14) := 'E0E33246D7E1A7443CCF005F7778D4E0A007780E554C23F489590BCC791CF85319F5CB0467E9A9FCFE07831F5A639C9BFBF0E19F7FB386BFACE1F37518E3B71C4ED7B158AFC53A5D6E7EAD7F75E816271C3EA5EBFD760DDF74F8D551F7BFE98F7AD818F7';
wwv_flow_api.g_varchar2_table(15) := '3A580D7FA00DD575B3B1D51AA11EF1F3EFE85E775F4D18DE90D3AC37F65AFFB8C68D5FCB33CA75BE73433DC1AFCF08DFD848238CF08CAF6EB831543F54356CAD61CC1BEABB2E4F71F8CA5A71608D9EE11E45DBAF6DE8017B6C74CAE18E1AF679D403DBF4';
wwv_flow_api.g_varchar2_table(16) := 'FA967A446AAEAF7271874335BC526F82015A8670877F97F671CD83AA47EFBBF250DBB7D630566913137A7F87A61F8105857ED8E17E877DB57A1455CB00894B7C0DB873B3A356F73DE2F045AE42A2F2E6C5BEBA75A3964DAB00DC2132B8A570FB2EC379BC';
wwv_flow_api.g_varchar2_table(17) := 'A70FECD5F34EA2E27BAE0E29EE5EE0398B02AB18E17D0E1FB7509F37ED91A4B871834F3BFC9DC19936ABD4E6670C6EF560A953F2A47F2DDDB754C78C75C500278A102B632C7990209222E40E730677015F7478AC0E91E53F3C98E347817B36B13D398AC7';
wwv_flow_api.g_varchar2_table(18) := 'FDA20ABF335523133EE070A7C1531EC4EBEE54F2F7A59CF75B171BEBDA7047A9D4D2CB2E374AAC6FD1A30ED8AF365EC742397AC4E03F1DEE4356B74D267949FF9C060ED421D1FD8937CAF622C14A8FAAF8EBD0E8283B09B12787B555A4A6AC1ECBDA4CC7';
wwv_flow_api.g_varchar2_table(19) := '866FBC64A120DD562CACC5CCEAFD07AD29AF37FD614DEFE4B06A90BEC5BF6542D1BADDC28307AD501D27DE3324E85649032CA7EF5584C1CE96A7F4D54099CC8EE271F3310FCDF266D0FBFB24F12D26F5DAB5A6DA87376C6A125DD177ADAE9663EDCAACB3';
wwv_flow_api.g_varchar2_table(20) := '2CB49D2827A216FD3BF2AAEA26D8019D78479A25C953A709A1B96ED5423ECA65D7B278B748AB9DC41B6AC5DBF88810BB91C64022CFA836EDA8C10B6FA3F95A65BD39854279A1237579410075B3AA5F37D8612D00CCCDE851F8F2AE1E91C891B5B0634C0A';
wwv_flow_api.g_varchar2_table(21) := '52CF87BB51A50973C3F5006B74D0DA615F56C33D42F6624A9D2B3DD551D7AAACC510453D4D7D857CD371356BE61956A3B70A345FF4263E6F8817E846FFA5A653B74560066A14775BE17D39ABE7D923FAA931E334835E2D8981096218E4B48849B9E914A1';
wwv_flow_api.g_varchar2_table(22) := '3E9FE406A6CFB2198317D4D0C9C5E265839F69BD9DD68296D46BE95AD38A5869D1D729A69C483DE77C38CB4CCAF2AFA6E937F4DA218F06CC3B7E03A48284FCAF7918E2FD96CA04F562DFF41086C792A7963665373586CC6270A5A92D32E9A82237F7BC61';
wwv_flow_api.g_varchar2_table(23) := '71952C7FDA1B602C9E7298A0DA476D83B4D0D5902987270C5ED5FD3B89DBCC5ACC536C974714B6BB2C8F18F3E18CD2AB1207B7D6E600CE59D369AA094A3D071C4F54BA060E48A0FD7B0F627323AACF0B068F7BF452F77A03F0038353F2F299D660DA3BD6';
wwv_flow_api.g_varchar2_table(24) := '007CF6B07E25ABF46CD8A5C7D4C63FA7E732AAB303B8C5E029D2EB2AD03E61F04D83176C13432365B37F71F881C1C36A2996BF2F024F19ECD5E17802D63302FCB1DC5204964AD628F4D9D270C614F01A4D8FA2B8D24183172DBCA292DB0D805F203A4E5F';
wwv_flow_api.g_varchar2_table(25) := 'DA4C49515678D3E1AB16F7BCBF74C374CFB70C4EA96B96874C065518622A570E161ED44F53412CA5D6BF132A55AD967E5598A4C37E0F34FEBE0855F958E56184D755A6DB461A249DEA82C19754517ED68707D8DCE06FEB98F1BA2D4DE99A3A6D289378A2';
wwv_flow_api.g_varchar2_table(26) := '9E2B9DF3D2685DF4E1719E2E21659D482E59BCE5418B5EC33342EB129BFB1CBEAEC6CBE7054E763DFC22819A5988429F019E01BEE23148525BD35A7CD662A4E89E96EB1BF07C1DD8D72DF85606DF8C106D5706404B3BAD184745CB9C0777E824A2B25FBA';
wwv_flow_api.g_varchar2_table(27) := 'C4F7E4A6A52CEF499CF97DE09F812F38BCDE9EBC5BAB01F48113C0673C08D49705927DFDAD63F086C3B7EB6825EE47E5B73CE735AD6DBA855FCB051FABAAD9F8B2661A72CB7E52D4FAA4526C61647D8707B5D8EF286F1706B7E470B7C3D7D4F2FB14F037';
wwv_flow_api.g_varchar2_table(28) := '3493B1B64A63AC203DF0E7C450CAEBC0EF490C5AA0E981CE397CDBA2A9FC402903B48F9EC1319AC1D5CC8AE7955D564E1203FE30363AE10D6B43D3F4E70983EC4E75458728749E17937B9F744497BBEE32F880C19B32D6534A790745C246EA79C942A765';
wwv_flow_api.g_varchar2_table(29) := '803F36F81670C4E0370839AE64B9AE0766FC35319DF3417971F1A63111AE7316B851A519CE1AB85CA94CB7562317C5DD547ADD1D2E697147949BCB10B85920F1B3C0270D3EA7D45BE2D6248C9C72785AD2D91E0BA1F72183875C33147A7414FF3F2562FD';
wwv_flow_api.g_varchar2_table(30) := '82DEF7B0D4F10ECDC23B04AE7DDF623CE088C3BEB4B6AE0EE159A5D76D0C4FDBCD0297D238549336F4E2A4F842950CB42CFABC97104BC75BF63B59C1D11A3E6621B177FCCA21F29E98EAF3553471C7BC71D5CC18171D0E021F15759FD6C9E698AA3499F7';
wwv_flow_api.g_varchar2_table(31) := '5D0BC31D21AACF3CA3BDE4F01379E1AE34166D3473DBBDB2EFEE88BA7C512AF6648AD52E30530520ED02DE9B66B00DB8AB8EF73F49E0C9EF223293AE516627F7D1487FFDAB00E57B808F4827B5E499E5E4CE007F61C1733EE4419E48C6AF09EA7D4EE15C';
wwv_flow_api.g_varchar2_table(32) := '25D0718D36F646EA11AD2F9F5C4C6929175DD306FF4B6402F726BF0F08B4FE0831E8F10D83673C55A9C55DE5AAD7CA18C744D6CC8775D325E2BA7FE4F0B6C323C0AD9686D4658C37AA98BBDC21F58C942DFA366268BD3BAA4354451BFFA2C1CE1661D9A6';
wwv_flow_api.g_varchar2_table(33) := '30F98972F2EE64AC6502903EA609966F19FCD0E157E4E23BE4D22F5CAB3D67F07F9AC7DA2D0275419EF603E1CD7BC528C76930A684F91987FF96C43FD5E2130520AF90EAECDDBA2775B87719E15B79BF406CDEE07EA2E153DC314FBF9D11193B2F807CC8';
wwv_flow_api.g_varchar2_table(34) := 'E3F4FE8A6BCC466B86EA7344EBE04581E75BC2A8031683ABBD54805512714F11735A5B54791631A6A4ED4B55B41FAED8B8ADA253BE5DC6A887852C2E297F1F22BA495BCA0675A3D22A384FA0F759B9E535E7A235EE3C237DD4D4A3D843E05355324D6A57';
wwv_flow_api.g_varchar2_table(35) := 'CE39BC5CC1498F89BC698671A552FFE5E2D58650ED5A3D352D6AA726E0EA94875D39FCA2748AC30A8D810D7F79A5143E038BA9D80BAB6496931E45D514716F4B2A5A594357C079CC631D3BCBB77D523D51118D9E8B362224B81A46B42DA478BAA8DFA748';
wwv_flow_api.g_varchar2_table(36) := '73D0FA7D8CF8FB8FA468DF57327141F024A40CD6506354D20DB690A6FD6986D1FBE225A72415EE49EC367BC21CF14D20AFDFE5E4BBABE9B41A0C049E268BE7543566E111732ACD4F03EF2706416B9AEF7EBE25D45FEDA3A779CC99CC79B4A657C5249794';
wwv_flow_api.g_varchar2_table(37) := 'C9B62421DA93C1E6850BF5B57A176B9ACED76A768A0F58EB2B03A5EB74BE8A4D4C7800DB1D2ADB5FB298BA5FF5004E1D1EF6732AAEFA063F73385EC1B278CB4C52AFF357235CD9E65DC361CD8668F7F9954DA64A45EA099953C3781601631D75C782C1FC';
wwv_flow_api.g_varchar2_table(38) := '6AA663EBE1F986DB24B19D13404CAA9D37DEEA6695E50DF405B759D8A4E9FC9631262D72F578AB2E59E93249ED5ED0E9F4D7732FED7442730D93454F60D8F805177A1605606FAD431AEB529BD38955C0160D8F77D314BE33CCED178878F7B51AA3A4EFC4';
wwv_flow_api.g_varchar2_table(39) := '098626FD53477E4E228BD7EBE86776D76388948B6BE5E7256BBE97D9498B2E94B7B71E415761E5AD382FB4DBF4059759C98CCB6B09850D3144CB1818F46B7D3559AD806D4AAB45D8EDAFD55553C62AFF4B4095C2AE5F3088F4BF075CCFBCD2BA0D41D6F3';
wwv_flow_api.g_varchar2_table(40) := '9B5318D4618C791962ABFEB4BCD6384C9BEB2BD3B88641E6CA107AD5EAFF5F4F57E9FF011B99B0508E2564630000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33059983340766773)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'images/m3.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000004E0000004D0806000000083E52B3000000097048597300000B1300000B1301009A9C18000001396943435050686F746F73686F70204943432070726F66696C65000078DAAD91B14AC3501486BF1B45C5A1';
wwv_flow_api.g_varchar2_table(2) := '5608E2E0702751506CD5C18C495B8A2058AB4392AD494395D224DCDCAA7D0847B70E2EEE3E8193A3E0A0F804BE81E2D4C121487012C16FFACECFE170E007A362D79D86518641AC55BBE948D7F3E5EC13334C014027CC52BBD53A00889338E227023E5F11';
wwv_flow_api.g_varchar2_table(3) := '00CF9B76DD69F037E6C3546960026C77A32C045101FA173AD520C68019F4530DE20E30D549BB06E20128F5727F014A41EE6F4049B99E0FE203307BAEE78331079841EE2B80A9A34B0D504BD2913AEB9D6A59B52C4BDADD2488E4F128D3D12093FB7198A8';
wwv_flow_api.g_varchar2_table(4) := '34511D1D7581FC3F0016F3C576D3916B55CBDA5BE79F713D5FE6F67E8400C4D2639115844375FEDD85B1F3FB5CDC182FC3E12D4C4F8A6CF70A6E3660E1BAC856AB50DE82FBF117C2B34FFE1C09B327000000206348524D00007A25000080830000F9FF00';
wwv_flow_api.g_varchar2_table(5) := '0080E8000052080001155800003A970000176FD75A1F900000148A4944415478DAD49C596C5CE775C77FE7CE0C878B286ADF65CB966DC5CD66174DDA38B0EB382D9A3A05D2026E80224F7D2D50A02D52146881E6A54F7DEB73D087BC1445DBD4DDEC2E40';
wwv_flow_api.g_varchar2_table(6) := '5C277613C349E3C6756CC79257598B29D1A21672389C997BFA30FF431E5E8D280E458AE90508519C3BF77EDFFF3BEBFF9CEFB3928BACE7320CC7AFFBDBA02BEECBDFA9FE0ED4800230FD5B385E077A867501D74F0F28F3736F349E3C26C76F38E6F86C98';
wwv_flow_api.g_varchar2_table(7) := 'ABCED65C053002343486BA00B30488A589FB8A75E8FF74F5D3D14FEF764EE076015718D670BC615823A4CBB090AC22AF78FADD97FEB4123873BC21C92B81D2F19E611DC703C8F2FF2B7085006A1816D2554BD2E5E9A7ACAA7402CC07485CDC50ABCCA12B';
wwv_flow_api.g_varchar2_table(8) := 'C9EBA49FEE668058DF44C046933AD61C37C3DCF112700B4D044BBF2F8124104B01192A6CF17BA8B09E17F7D480BA61238E07806DFDF43612C08D042E6CD4B8406BEAFFA5E32155019EC920BB3E73C34C4EA0179FE9BBE6789116A5E1B80780F15EC7CB8A';
wwv_flow_api.g_varchar2_table(9) := '3D2C621C8E2F020BFAE95524784B8133013519AA98008949065861CF7A40DBB045605112B2422DAB9E50DF2B0CAB393E028CC80CD4652B5D8067E9B574CF38701568FD34005703260D1B4D463E4B048E874A761D9F07E6816EB265A3C01430A1DF1B15B5';
wwv_flow_api.g_varchar2_table(10) := '32D9AA1630EFF835C3E61C9F13A875C3C60D1B13A05EF1B21E218E61538E378139A9F2960037AAC98E840D936459F2A66ED88206DA967A8E030781ED8E8F1B3622AF5B4FF19C57622B971A4718B2A867CE02171DBF62D81549FE846163152F1CEA5FD367';
wwv_flow_api.g_varchar2_table(11) := '851671E1760267C0A861DBE40008239D62B052D2D1923A16C05E60A7613B816D8E8F498D004A4DCC6F14C44A6A2D05C98B86CD03571CBF0CCC1A76C9F15949E7986C5CCDB0321C8E9E11E099C0F3CD06AED04BB7E9FB4BB19606514AB216808EE375C7F7';
wwv_flow_api.g_varchar2_table(12) := '1BB60BD80FEC90542DC6BDE9B9D9C90C9A4859F9B726BBBA4BAA7919B8005C94245ED3F3C7A4FE85BEEBC92ED7F5F7D6305ED7864CB942D2A63468AF00570AB096FEBED3F123C041D99FAE3C6729D52E3CFB02425C57489E6B418A14BF594AA50288701A';
wwv_flow_api.g_varchar2_table(13) := '4DD9D073869D062EC92B87A7AFA550A608DB0B5CD1F7D606843333ACB44D48CD8AB44226633F072C38BE0D380A1C366C02E80AD4F0B608B488C91681760A1B3A52A79C398CC8F03704C04884375A0892432A34BE79C3CE00EFCBA18C686C8DF0F8E1B804';
wwv_flow_api.g_varchar2_table(14) := 'DCDC5AA5CED691E4D70C0BFB54D34BDBC0ACE31DC38E02773A3E15AB1BA049424235160CBB08CC387ED9B079196BD7777629C1AF397E450EC192E79D326C37B0C7F131D9AE6E2C4CB2835DA9ED19E05D8D79879E512A849977FCDA30F9EE7A804393D926';
wwv_flow_api.g_varchar2_table(15) := '3BB7005C1248C71D3F086C531E1A91BD458EEAF80CF08E6167259D93C07EC3F639BE071817C8E302A106CC19D603E61C3F27C93E2B296902871DBF03D8ABFB22902E34AE9E1CD579E094616D6037302A49BCA63892A155D587702A9288BAC0E868F54E68';
wwv_flow_api.g_varchar2_table(16) := 'E2A3A13EE18014DFCD00EF02E704C85D861D07F63ABE5B76732ABC744EEC937AB7057CCBB04BC0078E9F02DE91A41E04EE707CAFECD86204DDB2C18B864D3BFE2670D5B0A6E36DC37A3E6432712B715CC4534DE06EE0B854368C75A8F17CA88954E11EE0';
wwv_flow_api.g_varchar2_table(17) := '23C0FDC09DB237A4EF79D5AB26DBD814B84BE108F01EF063E024F0B63CEA51E00EA975E4A8A645B95BCF7E751867B0199943C449AD64C76A1AEC65017606D803FC82E38F0287A4A66DC3DAE97B395ECB04A34BED57504E52C57B0DFB28300D3C07BC60D8';
wwv_flow_api.g_varchar2_table(18) := '9BB259C781ED32113DBD6341EF6B0E13FCE660DCF1C1AA7A2336F546ACA9E34DC34E004722B673FC0349C182610F3AFEB861772AF26F07239258931C8A8434075332225B6595142E7FAFE1F88861671D7FDAB017B5A8F7C9F6157ADE19E00D79D01B32C3';
wwv_flow_api.g_varchar2_table(19) := 'AB31DBAB02B79ADD1B001CB2172714829C017EE2F876E071E0730A31CA0446E48E26299893F19F97D1BFA8EF3480DD8EEF90FD9C707C4271A1CBF0673B5893FD7D0E78CAF14B86DDEFF821C5762703B4B5003788525F3770AB5C6372F52D8525BF087C5C';
wwv_flow_api.g_varchar2_table(20) := '6C6D27D9AF5149CF34F026F0AAE367059E8B296E2AA4B92C2FD8D567DB8003867D440E69AFA4AF9582E578DF2BC077642EA6800B4AD1580B70ABD5508602EE66229DECD351E0D7814F295B68EB7BA3405312F95DC75F92541D72FC2EE080D2A71D866D77';
wwv_flow_api.g_varchar2_table(21) := '7C9F61D3B2955794CC5F30EC1DC7DF13ADF400F090E347054A5B608CC981BC04FCB5E3172A8CCC2D01B7190CB0CB5B5DD4BF4D0D62DCF136F03DE079017102F838F069E06744026C537CD548CF0CCE2E54F80DE04581F203E07549F7838A03C3E8CF2977';
wwv_flow_api.g_varchar2_table(22) := '6D4962378EB51D56E26EA6C2E99EBDC063863D2AEAE892E3CFCBF3ED30EC09E009C74FC85E0DB4A1555B9AEEE94A15FF1EF83B01F430F01070405EF5DBC03392DA35ACB86F9EAA0E011C4A8BBEE4F827807F03BE63D867813F013E5F016750456B4D1395';
wwv_flow_api.g_varchar2_table(23) := '23F89AE3CF19F690E3BF2A27F08F8ECFDCAC66BA5ACD75AB80C3B0A6C294B71CFFB2617FA620D8158A50A921ACD51C58E5F773C01F027FABCCE1AA78BAD501A848F796035779510DF873C3BEACB0A018B672BE06E973A9E493C09F4A75D72C69C302576C';
wwv_flow_api.g_varchar2_table(24) := 'A8C11CFCA21AF05B867DC5F123A958C306BFDB44947E05F84D79F04D2D1AE709D636F8F923C01765D3F6731B2EB12DBFA770A8BED9C00541992B4D1BF1D24F005F5552CF6648DA0DAE7B81DF017E6E13F0AA0156975E370C1B17CBDA8C9AA762AD49494E';
wwv_flow_api.g_varchar2_table(25) := '2BE590E51A8A1B93C06F38FE305B737D06784221CBB575963D7B09AC5AA2BC16EB49A53CDD686A627191848705DC25B1A9B3621642847A55830B3CECF8E35B005878EB3AF088E39F35ECDF2B631B544B596A2F8BEA9852C231604C0EAE264C8A7AF0FFA1';
wwv_flow_api.g_varchar2_table(26) := 'B6111E44B15636634A4CC394D2965322148FE8BE9315091C71FC41E0F81AD3B40D7512E97D7718F669E0D9544D1B748D033BC50A4771FDAA523C0CAB8B720F6AAB1EED0A23A9081C74CD22FD0A793DEBB7E38847DB2175B84775CC0B22147FE8F8BDB22F';
wwv_flow_api.g_varchar2_table(27) := 'DB06C45DB7C747F4DFB707F88CE3478153E9F3C3B283358DB9E6F89DCA688A44923612A313E46AE178BD9EBB861C5F220BD56BB643897499CA7F8B6A3DB8DBB043625B0F1A760CD867D8DB8E1F17BB6BEB086E374AEA82853E2AE2F434F045999D4949D8';
wwv_flow_api.g_varchar2_table(28) := '8C72DF69A961239528EB2241AF44B13D39B8A27E03EF1974F3680A514C7F5F50DFC66E79E068A18AEA514380EE5C2735B5D1D736C38E39FE8AF2D8BB92DAD6C5C0BC2D9B5D263B58930ACFCA218E54DD6BC1F51D8FD16A359298D3B07F8BA282266538C3';
wwv_flow_api.g_varchar2_table(29) := '207781CBEA883C20BBC8ED96B64A401CDEFD84C0F8D0B019C3AE88E31B91542DD2EF3AF08AC3C84E73452F4B916F968A86940469584FACADAB7619ADA4355656DC3B2A34EF767C7CABA54D131D73FC80E8FA6B3247E1084BEB87646186AA7D77A3B99931';
wwv_flow_api.g_varchar2_table(30) := 'CFA758857140B474B58DB494A48DB2DCE06C86750D9B1D20C15B76692ED11B5C73FC430158482D0B39B089289C677052B3E22D57B9A259B029FB6049853B865DD0609A831665ABA54FF58CEE00D3E4AB10144B1DA359888AA1DFDFBFDAA2C497F45E55A6';
wwv_flow_api.g_varchar2_table(31) := 'BD2C7720F57E9A8093CD1E95B465558E7E3C146A0DB29556B17F2B81AB767D47374F65D56AF240517C8E55AB2BB62B653BCCB65863656E0A157F7A8A0446356E936A5E13C5BFA2102E2C8AB5B02383AE6836B6747F5D2F5EACDA04967BD0AEB2CE4EC74D';
wwv_flow_api.g_varchar2_table(32) := 'B81615AB452F5D8C3FE634AF7B6A153C227B1AE8E10A650979854C52656A0DEDA495B0B46761AE92AF9A5A541B8E9F767C46A2EF5BA49AAEF7CF023F562DB69654D20DEBD0EFEA1C57E89155A454B93252D2EBBC6A37C04B935CEAC3ADAC0032FC134AB1';
wwv_flow_api.g_varchar2_table(33) := '66B35ACB698C8989BDB495715CF2F8570D7B1FD8A5D432E65D02970C3B27D01A118E254159543A560F218B7C35B762556398BAE3B30A6803C442C9FEB861D3924892C48D1976875AB1DECE31E1ED96B604C27B8E9F038EA9D6EA29D49AD31CC71C1F71BC';
wwv_flow_api.g_varchar2_table(34) := '90A446D07B253A4753CB068695D14ADAAD24E24BD570754B9224B20E4C397E510DCBB968D2A4DF85F49EE33F50E334B73BAE4B01EB8CE32F18761EB84FF1E7927D73FCAAB46342397980BA945EB2DC601DA6CA816E18C36EC560A2071186DEB05AF292BB';
wwv_flow_api.g_varchar2_table(35) := 'F4D0F38E5FAB6C623B26957D897E6BC3EDCE57B3CD7EDDB0EF2B1F3DAC46EE58C805C32E3ABEA07CB69E84A62B1BEE4AFC7338E28E778A6042B8BEA33BECC1ACE3AD947AB912F809FA7D1FA7E5E2A3177707F029FAD5F627B7285B404EED5BC0FFD2EF14';
wwv_flow_api.g_varchar2_table(36) := 'D89608CB1A705E639C346C7BD83DA96B5BCC49E4AB45254CE984C4452751953A1E113B30274F1B117613386AD819C37EC2F575CE87B4D3E549C3BE6BB75B53FBD7B7E917A4A3BFA4965329F59E9C14933391A4AA90365D64793F6D8E494B60B1902A952C';
wwv_flow_api.g_varchar2_table(37) := '7703851EA3F0A2A51C34723B57FE7758BFBF66D8BB1AA08B75D8073C269EEB8FC3C3DEC6C4FEB2E37FE1F849C3BE00EC53DE590AC00F8177C5E8EC4B1898E6102D67C1FE9429BDEC1AD6CB015F47A189254730A62F5C32ECC3B0038EF7D4157E10780BF8';
wwv_flow_api.g_varchar2_table(38) := '9EFA3F6259E61C7F40859A17813F922D59911B6E46DCA6C97DCDB0E7D56EF129BD3B5AC0460D7BC9B0FF11C1B95B60B9428F39014B22323CCDBB03CBDB19717C511F1429A1AD895AF9D0F16905B7247B764C0FFF91E36FCA901652FD86618F38FE08F00D';
wwv_flow_api.g_varchar2_table(39) := 'C37E5792B7B493F05683E3143A90B66DFE01F075E0238E3F16E956B4AF1A76CEF197E5F18FB1DC26EBFA7C867ED7661019514EA84962DBD54A7E6C8CF54ACE3AAE174F2B0A0FBA7DD1B0BD6254A70DFB67A561D134BDE0F84EE097804780BF02BEEAF8C9';
wwv_flow_api.g_varchar2_table(40) := 'C4B2DA7AE2BC0C567AC6FBC0EF3BFE75C78F38FECB861D326C419FD714E83F0DBC266AFF00FDCD2B68D15B0AB3BA413555AEAE611DC3964008A3D711131A7F2F15F08ED26FEE3BAB2207DA54E6E2F4670DFB21700C7854F72F28F2DEE7F8AFE959FF2235';
wwv_flow_api.g_varchar2_table(41) := 'F86DE0F332CAB1F37998A24EBEA7053C03FCA5E3CF011FD3621DD7FB4BA58905F09C612FC8C3DE93174199C35BA159868DA610CDA4A2EDB0FF553E2EF6B1D7933D0AEEFD8A1A93F76BC2411F8DAAD2D552FD7227F000CB5DDD0BA2D19FD067FF65D83BAA';
wwv_flow_api.g_varchar2_table(42) := '2E7D4E25C6230300B9D9759E7E7BFEB3C0DF28347A58A0ED5773E1A2C6D1035E77FC29D9E98F2AE16FC921D415AF9ED6DF7609E85E1AD7622E3156F772C5D6F0EDD9BBEAEF57A5DF7719766FCAF7220AFFD0B01F39BEC7B02F3AFE49A9F5628A0B0BE065';
wwv_flow_api.g_varchar2_table(43) := 'C5571FA823FC670DFB82E3F728D91E93872E2B2C4E4744E41CFD9EDE6F69115ED1441FA7DF6F5C931971BDB374FC9461DF74FC7D49E491A0BF64D36B8EBF264757D7B6D0B07BA10D5744410D042E2A3F3B621F69DA5CD6D6171BF4DB4F77EBEF652A034E';
wwv_flow_api.g_varchar2_table(44) := '3BFE7DFABB66BE44BF77A493F672C5FEFA6B86BDAE7BDF943D3924203F69D85105A124EF7616F8BEEAA31F187659B5D09F37EC7E49752F55AAA26DE194E3FF64D8AB02F688C0E9453AA53D652F4BA2A612E011302FD06F0759DA513D682F9769229329A9';
wwv_flow_api.g_varchar2_table(45) := '8D54A3A582C77EFAFDBB93ACDCFFD993B8FF98FECE96270C7B10B816DE29EF18D43EAA964881A714AD4FCA46F6526C56136FD65371F9634AA176699CCD743842388231E015C7BF69D82949DA41DD1B315B08C46BF45BF9C78089E41C4DF3BE1A29D86A35';
wwv_flow_api.g_varchar2_table(46) := '0717C2B98139FA2A9AF22CE7B432B107BE2370EBF4770E16928C6F48527E25D134A1DE4D967BD8261DFF0FD9A5D508D009C3EEA6DF65DE485B375D6A67E94098FF049E567871BFE38745EF07DD5F53A9F32C70561A3616417EA2CBE2080E5F4BB1A62B69';
wwv_flow_api.g_varchar2_table(47) := '984AA94A3023E37AD03B12F93B754FA995AC2B44A9033F01FEC1F10FD49B7B97EEEDA4ADE835FA6DA8ED3584215DA9F91EB5E6775399B321BB36EDF8B3C00BF28227443C2040C2E19569435CA179D5D32663538634C7808EF5FA4D68F31179D0BCA9B72E';
wwv_flow_api.g_varchar2_table(48) := '699B9154D5E8EFD8ABB17CD6D188E2A431FAADF4CF089C8F4BC5F7B3DC8357977D995D83276D036F3B3E27E92992779F51D2FE3AF0DF32230F387E508EA69B6CB803E7A5C2AD20392BA0798A0A7CA8F2A006584B221C06B329CF7309382986748FC43DE2';
wwv_flow_api.g_varchar2_table(49) := 'C142004D19F6A612EA371CFF68B251079402BDCB1ACE02099ACBF1D3B2572D05DF67E8774CBDECF8BC3282FBD46915C7041529C498D6B867E5919B49AB22A05EA4BF4F766070BE968DBEA30A189BE9240593019ED74A37244977A4155D6A5E51403D2346';
wwv_flow_api.g_varchar2_table(50) := 'E28C067FC4B0138E4F19F6AFF25A37ACB8A56B3BFDCD20FB05C06B0A4F4A79CCC3861D483675A962A54A57D04957133D968F2D2A64D72EB3BC596F5DC00578DB456EE6A0D0B4EA572489C7A4A2DB128BB214D268027302FB820687F6619537E0D5AED312';
wwv_flow_api.g_varchar2_table(51) := '6D57EAAA423F497F77E02E9990A2B27021692D49EA5BE21FA7C47EC4DEFCF0DE5DCD67FE4645EA6180331561A61430966915A35438AF01ED76FC1E494430AD964E5C70399F0EFD0D6EAF565DFDCDC0D306B9BBB540E3CAA7EBC9E605704D4D7C5AB631DA';
wwv_flow_api.g_varchar2_table(52) := 'B92652409E9D544F19D2FCCDF2E7B5B64084A12C74484B2D3124B9E5619E7E47D0CBDACF70A7D4A19D292BE582630A0986EE74D7C6E2DD2935F2C4B785F76F481D63A3F1BC4E81989007B6142C87EDBBC6F2D11F6C047091F0C74A4CA630A564E5C14F2D';
wwv_flow_api.g_varchar2_table(53) := '0DF89454F110FDCEC849964F1A8CBC7845343EE45842BD8B54340F2F7D4DF1D9FB0A4F4A2DF84405E8DCC31C15FD351D9F316CD34D299544E29EF9B9603926E4DAAFAA98332D06E58018E568465E30EC927259BF49FDE0BAEABC36F0EE93B44717D56565';
wwv_flow_api.g_varchar2_table(54) := '37D392B205D9E7E89CF7B4ABDA52B6331468EB012E400A9B34216661A90A14AA48BF117941937957F4FA5E71FC7B1D6FEBBC91DE3A25EEAA16B1D078E2488D33690CBB649B23650C523252A98E2477E876FEA1CE1D19B00D72E9342F960F20F054888E16';
wwv_flow_api.g_varchar2_table(55) := '8BB60C6E50D8A332E8AB9EA67593B2E2B8C28E52EA38AFF746A741A6BDBDD255E092DA3939AF817BD93613B8B02B63A284724BBB57272FE98A4EA71E37393DF026C0E5F396EA897CAC0FE8BAB2C438F7B460F371D8DF7A80BBD56D47D1D1532A611E53E9';
wwv_flow_api.g_varchar2_table(56) := 'B0915A4383658DD357EB92D08139E090EF8EAD54CDF4FC2520227E1419D0356C41A0DDF2F1B71BB5492CA4A72BA6240E8DCA9E3778BB380074238AAD11D6D463A152AE191D463D05D8C1E0763662C21BBDBB2E5A071624054D5153F56C0313457FAB5799';
wwv_flow_api.g_varchar2_table(57) := 'F2D025C0F48E38D5B02D5274430E15DD2CE04285BAA2805A02704CEF8AFE93EE5A54650DB626DED3D0A20438DD748E5DB919BD2B9B7DF27404AAADC4E58DB0C63379D730E15EEA8CEFA914D8DA28755CEDFABF0100A16F6D639814B0B40000000049454E';
wwv_flow_api.g_varchar2_table(58) := '44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33060316647766774)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'images/m4.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000005A000000590806000000BE3C33AC000000097048597300000B1300000B1301009A9C18000001396943435050686F746F73686F70204943432070726F66696C65000078DAAD91B14AC3501486BF1B45C5A1';
wwv_flow_api.g_varchar2_table(2) := '5608E2E0702751506CD5C18C495B8A2058AB4392AD494395D224DCDCAA7D0847B70E2EEE3E8193A3E0A0F804BE81E2D4C121487012C16FFACECFE170E007A362D79D86518641AC55BBE948D7F3E5EC13334C014027CC52BBD53A00889338E227023E5F11';
wwv_flow_api.g_varchar2_table(3) := '00CF9B76DD69F037E6C3546960026C77A32C045101FA173AD520C68019F4530DE20E30D549BB06E20128F5727F014A41EE6F4049B99E0FE203307BAEE78331079841EE2B80A9A34B0D504BD2913AEB9D6A59B52C4BDADD2488E4F128D3D12093FB7198A8';
wwv_flow_api.g_varchar2_table(4) := '34511D1D7581FC3F0016F3C576D3916B55CBDA5BE79F713D5FE6F67E8400C4D2639115844375FEDD85B1F3FB5CDC182FC3E12D4C4F8A6CF70A6E3660E1BAC856AB50DE82FBF117C2B34FFE1C09B327000000206348524D00007A25000080830000F9FF00';
wwv_flow_api.g_varchar2_table(5) := '0080E8000052080001155800003A970000176FD75A1F90000018F84944415478DADC9D498C65E755C77FE7BEF7EAD5D05DD5F3E06EBB1D3B6DE221267642200E843823442890054220162C4062074B9691B262838412C48288880D20764880022603716C';
wwv_flow_api.g_varchar2_table(6) := '4C12EC38B6E3D84E3A3DB8BBDDF354E39B0E8BEFFFDD7BDEAD57DD55D5D5D5159EF454F5AADE9DCE3DDFFFFCCF78EDCB0CB8BD97E9A7AFF0F7512F1FB1AD8DFA5F0134C23FF5D91BC000E8810DC2867DFDFD26C7E126E7E9B7B81EBFC575ADFC6AB2755E';
wwv_flow_api.g_varchar2_table(7) := '0D9D4FB326E0225C78F86C48A85122F9F34042EFE9677F05296FDAEB6E09DA24C82CD0464DD0F9F34ACB21ABD64AEAD5AF09BA17847F5704BFD9822EF46E828D81B78031B046A591E5D2ED0F2F6D5B097F46E084136E56A1CF7DB02E7817E800DD0037FF';
wwv_flow_api.g_varchar2_table(8) := '6F045D002D1D6F4C422EC0243D77301F06C19B6267F86023B07868DB818E633A8716D87812B47725F0CE30B6FFEC09BA4882654C17D908C6CC83E40612A604E20116CC93C1F320751B54DFF1BC8FA2D25EF361CC767DB622C05643E7D44F822E85DEFB59';
wwv_flow_api.g_varchar2_table(9) := '1274C6DE36302E4117015F0735EDCDC2F59A41F38A5D94F09E977B5119461CAC19AE271B4D0BC78DF81EAF5FAB8C2EB0A47777A335BC7987843C0E4C69FF1696B057822DB5519F8D4ABB2C63683F6D57C7631F450D25542B84FD19FF5BE11C324459D0F8';
wwv_flow_api.g_varchar2_table(10) := '7CB3F38A9B00E681B98D14F6460BBA0D36912ED09B12A8B4C802707A164A4FCB762109D6BA35BA37A90BCFF013C96CFC99717621EDCBE6830237924D6002AC2DD8AA6BB70F5347269381F625607123184A7303B5B82DA18C0701D40C5CB98CB3C62EEA77';
wwv_flow_api.g_varchar2_table(11) := 'D7F6DBD3F69E6FD884FEDE0AFCDA4778113D19B7452DFD85F0735EC759D4CD6A079B518315CF2BAB19E866A16DFB775BD08504B23D50A94158CE56FB5B172C5FB849D3A6C17702BB8069ED2F636F36667E13AFD36AD88C6EE035E02AF8C5F4BB75805909';
wwv_flow_api.g_varchar2_table(12) := '7A429A6E354E1E94C3C6B4020ADDB0C17AB5FB7605DD10164FCAA25359788F17DF4F17E9F3D2B406D8147050EF2919447DDF3AC34BDA56110218FA3DEF6B066C06FC3E09EA02D859F0ABE9066481FBB8A0CC8351CE70D74CE7E70DE17677B305DD0ACBBB';
wwv_flow_api.g_varchar2_table(13) := '114E2E5F68A138C4BC967057C73B00EC4D9AEB53092AAC118CE540372B6A5A318CF143863152B940FF4C8AE01660A00DBE5B9A7E01FC0AD88D84E93E093E11D84A64460D9D27BA9ECE66093A63F2A4F6E123D4AA13B0B2007600BB25E89DD2A6413064A3';
wwv_flow_api.g_varchar2_table(14) := '82483948547F53838A48E51AB5D84776C14DF6635A10B523099B0BC07509B057A3A383C04CB2711E04977E2D82B6F50A3A50A66546AF23CBDF9171DB9F046CBB6584BA620756C18C051A086220326EDE1703E809A2225E3786E91C63E063D52AB3E8D4F4';
wwv_flow_api.g_varchar2_table(15) := 'C4742C09DAA7817DC069B077C0E7F4FFA96490DD2A8FD5A3576AEBD0E875617B3F69AB1515749461CDF9A421DE03DB0B1C06DBA38B37D1B948F71AD579D83CD815E00AF88D64B86C41372E9FEF36617E43376121ACCE4C07A7C176A695E3533A46E6E535';
wwv_flow_api.g_varchar2_table(16) := 'C5F06DC0FDD2F4B3E067D27E6D46FB8B4E91E8E3DAF9F57AA12353AA397D9E1216CE0AFF9A60F782DF03EC91E3E00A140DAAC0124D69ED05B08B5AC6F3D2D029B07D32B6E301AEA62430099A3969ED6CBAC1D605CE0327C52C7682EF4DE7E1DAD67254CF';
wwv_flow_api.g_varchar2_table(17) := '12DFCF1068E3328C6F2783697D609B8EBD108CA16F36EB88C22E801B12C661E0BE8AF2952EB4070C5ED48DB908BC23A18D8985ECD7CF03C2F51D15165B1196700E7936C27E668133090EB8029CD3FFF6A7B74D49EB9BC3F86D4D1D6B4AE77152ABD3C24A';
wwv_flow_api.g_varchar2_table(18) := 'EDAC5750CDE551B27509FB5A08D83C003CA8252A63B2CCF55E4ACB949F4A0B27C11F023E0076549AD51073292AEA182376435E266087C10F06589A4FFBF7578197811F839D06EE15DDDB2E56E4215C9A237C0F806D4BDBDAF5ADE682BBA0E24012942D55';
wwv_flow_api.g_varchar2_table(19) := '58E6456027A7813704313B814F823F9E382F3389621935973D1A3F1BB6BB96FF5F84B8368284871384F161E075E03BC09B60A78087C08F48D90601BFADA28176489ABDB4BEDC46259A8D8E752C68B94E869B9859C23509F994B0EFBDC013C0E309264CAE';
wwv_flow_api.g_varchar2_table(20) := 'B9F7A495D1F12846049B7D44D685101635C1C00E9D4B86A4578057811F09EA0EC968B6C44A9A3A8FCB8221BF831A6DEB8112072E8520FA41615D1FEC2AF82961E70CF00BE0BF0C7644DB860BB2422BA00E3D99737743425654AE8496BC6DA16BE88067C6';
wwv_flow_api.g_varchar2_table(21) := '3203FE11B0C7C09F039E4D50E28B8292DDDA8F8CA91D13B6737BDABC2AE8B075DC509B058E093B0F825D03DE022E03EF023E0DFE8160483DB8BE720CCC92805024CEB3E3734DFBE90926661237F79C3599AAA27458151675D76A430CE653C011E019E035';
wwv_flow_api.g_varchar2_table(22) := 'B03941C95E29CB31B04B1B21E00DC2681FF1BBBB96E43105743AD2B00F021F041E117EF645F7144FB00919A44B895ED931F0B7139FB6AE1C99CC3AA6AA489D351214794BAB65AF78F103E2EF4DC54E3AE13C9B32D80DD1BED780E3F2102F2A0EE21B25E4';
wwv_flow_api.g_varchar2_table(23) := '3B9DCABA2E48D806BC0FF8B80490F93621BBD113ACBC958C1557F5B7B63CB771ED675A98BB47DF392F9A7823C454DE064E08871FD02ABA4776A31356D238F01EDD9806F06D6DB7B84552596BC2EF81824F7BE4F20EE4E55985A5DC90907F9096B1CF25C1';
wwv_flow_api.g_varchar2_table(24) := 'D82FA555E00F80EF908027F59E49C120AE4B70D7B5128E83BD02FE8298CD71B0FBC1DF0F1C4D59142B741E5D19E569DDB8B6BCD1AD969C5D0D7E1BD2BCEF816F077B52466949DCF93AF03CF07569F907C17E03FC3169A2045052B71C1544AEF3A430F8A0';
wwv_flow_api.g_varchar2_table(25) := '6EEA13E04F83FD36F0A230F8BFC05E063EA255B54B02EE2786C32B60DF4D6C6935E1D87511854D2937E88BD6FDA796EED3D2EE9F005F4D9A6CF700BF0FFE6BC063C2D6C668ECB3C0A7A97F675C387D04FC68A290F6ABC03F005F4BCCC73E09FE648208FB';
wwv_flow_api.g_varchar2_table(26) := '1EF837C08F4BF8ABB0495BBB242C0BFB5961F26109FE07C0A3C01F039F53F87294B55DCFD5ED067E45EF23C05FE9F88BC2F3422BE9CDCD10807D792473B8995BBE16977D6411CCB43CC2536999F367609F088CC582B7C7CA01FF35ABDDABC017807F1543';
wwv_flow_api.g_varchar2_table(27) := '195768F416F7D26B50B9BEA2CE4D2C09B3C0467C11F813B0DF13DD63B9DB6D76BB07AA09EBE7C03E2F3BF025D1B97543C116828E152F600CF804F087E08FDC36F8AD5ECB5B29F6C17EC1D897C57836E5558C480BDDC90B6E0B33FF14ECE1108DBBC36A65';
wwv_flow_api.g_varchar2_table(28) := '31C1BB2B195E3E2BAAB8E9826ECA6AC71AE58D7E1D05FE4034CB96C3C566BC1C39507F043CA96BDE0C41BB62BA3EAEF4CD4CC551CBCC866D80E0C7C07F0BFC3377E826AE55C11E077E47C1AF3BF16A100A753246B718AEDE69C901E8289833296E9B6306';
wwv_flow_api.g_varchar2_table(29) := 'B92268B505DD6DE029E0332328DCDD7AED047E5D31EA0B212CB01E63D490875A2FA66F4A8E4BCD001BF9CBC80B2B946075390147B5D1825CDE6B7AC7744F2D0D5F52A3FDE09F03DEBD0504EC212B7308FC63F20EBFBF0AEA1E4B1AF2CF6DBAE60B525615';
wwv_flow_api.g_varchar2_table(30) := '77BA29ECDA0FACC3623D3255857C5995D3566ABEA3E4E54E795627C12FE8607B4499AE8D38C1FB138DB3E9F5B8AF1B6F183D2C6F7B544AF4FD556C9C3DCF9D49A0D656D1CD8514F52B333DCD50D36D600D95D57AB3828BD240B98AB395DAC95A9EA1C549';
wwv_flow_api.g_varchar2_table(31) := '614ECB51B0F72B207443073EA168DC76F02752BC97F626D1B9D53A354A77F913C037180EF4B7A992C4F3A2842DC555F6D560E28642BD3EBCA2CB92866633007751FB52CE68E4B2AF88C7FD109EDCAE00D0233A39D709FF4811B53D72B3F7B0F55EA6D5F8';
wwv_flow_api.g_varchar2_table(32) := '6E52C6FDAAAEE5806CC97E52AAEB84647123846C63665FF579CC53257987985D33D02BAF61546E61C8E9F9DC2FA2BA3453F18A1F4C6EB52DC950160AE2DF0FA6F0A6EFA72AD6F1CDA774A3E06308C26624D809E037810F29AB930DDC8214EABC8C66B796';
wwv_flow_api.g_varchar2_table(33) := 'D96F4AF8DA6639CE17A33973CC0AD7AB5A4DC58BAEF25B9B142D0CFBF05EBABBBEA4F0E8EECA69B8DB421EE9BDEE4A86D1DAD2DC055D5B57D73593CA8AAD9BB235E6A1B6241642BAAE7D5047C62294D7C6837BD5D2E093A90E6D59F4492556B4A4093140';
wwv_flow_api.g_varchar2_table(34) := 'EDA2827D05EC0FDC654CBED56BBF12B4B9763B9F7B5F2BBB2558EC2705F3FAAA544B860B7ECD47117767648F48F9B75C711FA0C507CAD3A95FC49B23C2A24BD2E2A9A4D5BE95053DA5A8624F38DC513CDC2ABB656A1719D99B987D0F5B29B259AC1C16CC';
wwv_flow_api.g_varchar2_table(35) := 'DA6DFD90DE271C7C40D54E5154D86BA625769DAA04CCD9D22FEB49711ACAFACC32D4E4E4A180D21AB5763CAAEF99AFB4706FA7C85177397B9365EF8EEAEA2CF3CA71B656CFF94DD89E114A1BAC1688AE5F3BB756D28D0B93F65670C39B622B16BEF333F2';
wwv_flow_api.g_varchar2_table(36) := 'B2DC741AD8D71023587741F97A02CB39D0B4A84A9F7E500017BDCB0670813BD48D7A07E8DE40583D5983CB5CA6DC0B4EC80AA2B2B50ABAA4D7B934200A32975E65377D30DC6483D5B225C5D6251D868CBAAAFB3DF7D6E402CD8698C65519CA5C265C878C';
wwv_flow_api.g_varchar2_table(37) := '9BC6F28BCAF75F364424CFC5C855F7D1B1913F5FC247AF8667856222CD1480F273322A0C5786DE756CCE7CF84272B1BD95B874AE4AF59A925876BB036E7BEE3ACB9D001678F690468FC2D818A1CABCB2DE67969B2373346F50DB3E37DD5C2115C86C65E6';
wwv_flow_api.g_varchar2_table(38) := '71466E762E42AF53D579BDF335DB88EF2C325C683F4AD09996786CFA2942FC6354F3756E73B82ED7741078B6C9CB92FF6F6793D66F35CFB0CCF29C576BC72E45E3E2AB93623676410CAB5D6D476CBD93327A4B6DD1A157C633FF75AF751C05B7D2675323';
wwv_flow_api.g_varchar2_table(39) := 'E65029AD2617F884FAF42ED5661B156A33BE47058A6F2508F2BA33749721237B707E4AFCF9905A2F621CA30FCCA57231578F8B376A7E5E2F71EF324C9A0D662E9AF7309D651933C8C1122D8BCC91CB03B464A16F90FA44EAFCB2ADA85847598CD3A1D172';
wwv_flow_api.g_varchar2_table(40) := '0B0495CA057A1CEC2595173FA8E0513FB08B01F835B0CB82C389400AF2B564E860D841339302F68A8031FDE5068F963E2F52D51767CF504D9ADE4BC17FBF5EDB47416A189A027E02FEA2C2905BE9B544AAFD7B53D1B7C31264B437F3B233F354430022F4';
wwv_flow_api.g_varchar2_table(41) := 'F6249F4115A01B5AB003A01B053D1881C32DA1C97CCA9C58B6C259ADB7EBC0578193A1163A43CC7412B6B58067C17F3A32B4B2E96E60790E17C19E5394F13D6A100A096B1CEC5CD266579A2ABBE025CCCE53D687587344C8C1C1FB458867F4C28A8E1988';
wwv_flow_api.g_varchar2_table(42) := 'DCCF371B703CD39829A575E6C15E13A71EAB0CA8B7D2057010EC5FD277EC2E234719DCEA264DF6AF2B00F6684D5B051BBC995889ED4A3722275CDD65B7E69212960810E6817821DC1ED2E85E2DF09F9746A6701729CB664B2EDC003B207EF95AE2A3DE0F';
wwv_flow_api.g_varchar2_table(43) := 'ADBD3DC1C77B75B3BE027C6B8BC0C61BE05F4AF6C58E0A9F2DD891CC248E91DA39F68900445FA010EBBA21056B8E58AE7D093A6FE8FD5A4C225BE409EDF8B204EE21BCDA2355CCEF1205FA81C8BF8A52AC239AF710A942E95BC0979261BCABC1FE8BC03F';
wwv_flow_api.g_varchar2_table(44) := '01FF0CF610F08B0916CAB1427915BF2567AB4D6AC128828C34EEC2AEA7D511475194DE71468A7E51977CA026B9C946135BBC27BC5A1416E9E6F8A49A6CC680EF821D4FB18E72892EA6D8817F545AF30CF0976A291E1DBCBD6374AE5CADFF08F677AACB7E';
wwv_flow_api.g_varchar2_table(45) := '0AFC906689A814C1C792A6DA37A95AE4A6057B83D0057659184D706462DC3E17BB5313B47782DB69E1EEB6854BA775A75B810F0F124EFBBD4953FCB5C442CA61509AE8657BC13FAB9BF237AAEC3C1DF0907073374AB83E4CE7AC0F7C11F80B09F053A975';
wwv_flow_api.g_varchar2_table(46) := '83A6B42F0B6C5ECD4A6F26A5B1039510DD159F2E8053C2E77615F1730FDDBE6AD7F32141674C1AD5B9AF1D714577B11340BFA3A0F811FD7C85D478D30F71811CF57A225D1CD3C0DF26CDE6F55B440A6F1B27F43A0DFCB5847C1AF890DEDBA87ABCF33CBC';
wwv_flow_api.g_varchar2_table(47) := '1F2696445F946F3755B37D6615B9ACA22F0A6B2382D3B9396959F44E46D1FB61990D0415E30A969C5357A9FA014B0632931C14BB0AF6ED6444BCA3A26F57FF779FD402F7BB12F6571266E79EEB4C9BFC362065488B5D81FC933AD69F27E7C33F01FE4979';
wwv_flow_api.g_varchar2_table(48) := 'B68A97E7D4959D057B3E79B31C4A8C290F2274D470349F9888676C1EAF4DA20CB3419263D3F82C9F8F31ED1CDED4B2B7E8BC8812D992E2CDBB2A0B5D364D6E97C1BCA026C9C33296FD603C8BE01C5C065E005ED252CBABA2AE94B6362D8E45EFFC37D817';
wwv_flow_api.g_varchar2_table(49) := '80BF079F013E4DEA0DDFA5889B667F98860CFA33C0F7D4CFFEB0B4B517C23DAD74DEF696B47C4A4544815BDB400D51D99161545235B78535C3CE5D146E8AAABF6F0FA91E42BEBE29A2E747B4645E151B51CCC317A43D5D41D1512DC3EF8A427D11FC7952';
wwv_flow_api.g_varchar2_table(50) := 'F7D4A3603F5FD98251F347B9892DF5B792B0780EEC3BC2D207C19ED214851D551C9D86E2CF57F4DD17648F1E9601B4A0206D79C067925F617996880F0F4BC42927E7AC9CCAD2D0BFA1ACAE87D0678BAA813ECFB98B746F17A9D6EE0DE07FF4BF8FCBB1D1';
wwv_flow_api.g_varchar2_table(51) := '981F7AFAFD11E1DF8BA4C6A1AF09E31F107E3EA6FD6DD34D6DB17CA6924B73AF6A859C506CE565C5603AA47AE80F8BD30FC4847A9403ADB8A61BF38C1C907709360621AC90057E863417A4A5D5D7A8D1E2D0B35E69C02841E7F94563D55CB878B77C5294';
wwv_flow_api.g_varchar2_table(52) := 'E6BC66D5A90ECD625C7BB7B8F38B2996E0E3499BD8A995A211C3F4C4583E02F638D8EBE02F01FF01FECD542A6CF782DFAF65BC43E716CFBF27EFED7561F1150588F6AB91539E2913F20007A14D390F687911F8A69C9787D2F1B27D2A4BBE06F215CE6A9B';
wwv_flow_api.g_varchar2_table(53) := '999ABB9D6791E4A15DFD7A1295D1C2A6CBB25A85928174D50C7F461ABDAB96CA6A80EF92B07F027C5D3CFC63299768D7C3A8887E0850BD37E1B4CD2683EBDF017B16EC7F55CDDA5A9E60B041D266B7245C9ED4CFBD82882919E47E68EECF1EEF523A065F';
wwv_flow_api.g_varchar2_table(54) := '4D3E020F91BA76759C3801D896C0CF4AE3958971AB452DB5AA7DD938A095B2E02A80A11D8A6362FC635C277E4ECB674A243F0EE61B937133F013F20A2F031F2535ED7443863CEF77A7B03FC3C19BE03F9461BD700B1BB85390F3948C9E0262B9D8874135';
wwv_flow_api.g_varchar2_table(55) := 'A0C55AA49EF11784CB9713ACF87D326C5ECD9DF646821F3BAF98479EB3D4A8C90539274BA3B2FECD95235CE5DCBA51B3ED7289D815E1D5840C5E8BE1B9A4E3F20627B4B49FA32C12649F584A5E9683E1E46EE9EEAFF6D5D4FE0E53CD3DAD976D0D74D3CE';
wwv_flow_api.g_varchar2_table(56) := 'CA7E3CAF9BFDA062E78DE0845908A05DD4BC9105CA5115CB58CE80E159ABAB12B436F439DDFDE608D3DF1617BE26D630A6D919ED9012EB504D7F992295F2BE9CC643D8D36A15DE5BCBA2E77AC0B7A475AB8B7CA6F8C5891046F0E161BA0C344BE438F8BF';
wwv_flow_api.g_varchar2_table(57) := '09D26692C13555BB5A48325B9EF7713D9D875F4A37D227AB04ACD579F38AA515B72AA019A41880E5D4D5A096FD9D9051BBA168D823AAE76854CBB5C4E0E944DB98067B1BF87735C3BF2F35D9DB2E41900A26EDDCADE162886B6B85F9BC8EA55977E5E0D7';
wwv_flow_api.g_varchar2_table(58) := '3792D1F31312DEA1C48E7C87667A0C6ADA2F1EEE3F167B916352AEEE88F7B902B57FB3E5B69A2C4478B244596D9A738ADBA52DD74993B896648C26187E524443542D4F8A3999B48B2BA46961FB6408EF13DE9FE2A6B33346FA3037B4CFC33AEF538289B3';
wwv_flow_api.g_varchar2_table(59) := '49DBFD8236BC5FF6637B758E4303B07A8961704AD058E8BB2D96C792731A6B919B0C1E6CAE6E5DFA6230828D1A8C8CC9BACF2A939C677CDE433902C2558169F35A19EF5690E9ACF8F8F7351B495AC684F8EA08C1DE14B66753FE8FB793D0ED98847C59FB';
wwv_flow_api.g_varchar2_table(60) := 'BC373092A6B4D043014C8EDD5C94017F47D7375305D696B54E2C8EA273EB11746621AAB0F4891A6FCEDAAAC08ACF26CDA6A3E539139C190B64BE2DADDA2F67E37A9A7ECB0B2145742B5C1EA1D1F692AC7F27C5687CA7C2A13BD4AC54840727E442FB50C3';
wwv_flow_api.g_varchar2_table(61) := 'E2EF68855DD34C91A98A565AAD5AC0960455DDD5586AD6266C33C59773E57FCCB64C5631683BAEA57C44AD156DB9A4DD30814637C8DAA2647B152739C98AF57A371DC8928773EF93C3D2D68D9E5478A011E02C7ABB3D19D333C263C5D0990CCF081884AC';
wwv_flow_api.g_varchar2_table(62) := '0A8A65CCC906F8460A3ABBE7735423826BF57625C56A6805BCA38B9FA79A76DE0E61D37E8D9AEDD5FFCFB3BE67A364E1E501E0F1A9158370DC6244B8F3B47039873DB7D5B685E1D1F973AC61FEFF7ACA7665C5AD9E5588F56693FA9F668FDA3505FCDF25';
wwv_flow_api.g_varchar2_table(63) := 'A7246B6751656ACC64C016B5F4D79900F022C09ACA0186667F844824F33278D9F0B635417D2CDCB8903129CF7196350EB95A6F7D7457B4AF503C24543C9513181B60B2D43EAF21249785C94794836B5404DF0B31168D5FBB99A0FD56E736ABB8C614C355';
wwv_flow_api.g_varchar2_table(64) := 'E60D51B96B12EE19552121DAD966685E6BD9AB12878FE7F1F96C86A01506C4A96636DBF27205CFCF35694803E6D205FAAC3467A78CD476393A735A2DB7534F9DFB5096640809C1A3F3E2DA7AC8429EF06B1315A3F21846880FE2E94A9397D8E4B1C651D8';
wwv_flow_api.g_varchar2_table(65) := '1EA8DCA80713E60B694B0897F49E9286CF08BF73EA7E709BE7958B5A26757397A88A312FD5ECC24490C388A76378BF82B4B25A8BCD1474C4ECCC3EC62A777D682E52AEF51076E707C9D882DC77246CD3DF6E3741BB94846AB3D2DC2BD2C81CEC9A0C3E81';
wwv_flow_api.g_varchar2_table(66) := '57E3EE4B1C8FB1650D035FFFECE88D12745EAE7ABE4916660E6196A4245F501E1BDCD277F57C2A9B1FE110DC8EA0CF85D595D367AD44D73C385D16A71D50955AD009CF8BB9ED1E9C8DEC96EA0737349786C512A9410D4E5AD543106C3C2CCD8D2837F070';
wwv_flow_api.g_varchar2_table(67) := '0EE3D5B9E447FB9541A7DA00F1F2DCF33C920D7B38D946B7A5E56C774754695CCE88FA3BCA87E244CD6D04B77E231F73175DE7F864B941B8D9B1A155017B5B0A6D121BF6BA53FD7F1EF2724BD2D876E83CB560D97390BDC3C6766FE5F84ABF2AA21F1AFE';
wwv_flow_api.g_varchar2_table(68) := '6D0126F26ACA89880D7F88E49D6EB4EC5569315FA41A29D466F86944D16B5B6D587495828E8FD6F3E8DD75AB890CDE5DDBF1B79EA0431E2D6B37632121D0AC321F6B7F5ACFAD63E9CBBAC5E2C37EF3138D36A50772B35B87072176DB0CDC7AC09A9EACB6';
wwv_flow_api.g_varchar2_table(69) := 'EA91CA828E5C2A606A40BDB3DA3BEAF57F0300BFB046A4513C75FF0000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33060781140766774)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'images/m5.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2F6A6B3634205265706F72744D61702076312E302E31204A756C20323031390D0A0D0A24282066756E6374696F6E2829207B0D0A2020242E7769646765742820226A6B36342E7265706F72746D6170222C207B0D0A202020200D0A202020202F2F2064';
wwv_flow_api.g_varchar2_table(2) := '656661756C74206F7074696F6E730D0A202020206F7074696F6E733A207B0D0A202020202020726567696F6E49643A22222C0D0A202020202020616A61784964656E7469666965723A22222C0D0A202020202020616A61784974656D733A22222C0D0A20';
wwv_flow_api.g_varchar2_table(3) := '2020202020706C7567696E46696C655072656669783A22222C0D0A202020202020657870656374446174613A747275652C0D0A202020202020696E697469616C43656E7465723A7B6C61743A302C6C6E673A307D2C0D0A2020202020206D696E5A6F6F6D';
wwv_flow_api.g_varchar2_table(4) := '3A312C0D0A2020202020206D61785A6F6F6D3A6E756C6C2C0D0A202020202020696E697469616C5A6F6F6D3A322C0D0A202020202020736F757468776573743A6E756C6C2C0D0A2020202020206E6F727468656173743A6E756C6C2C0D0A202020202020';
wwv_flow_api.g_varchar2_table(5) := '76697375616C69736174696F6E3A2270696E73222C0D0A2020202020206D6170547970653A22726F61646D6170222C0D0A202020202020636C69636B5A6F6F6D4C6576656C3A6E756C6C2C0D0A2020202020206973447261676761626C653A66616C7365';
wwv_flow_api.g_varchar2_table(6) := '2C0D0A202020202020686561746D61704469737369706174696E673A66616C73652C0D0A202020202020686561746D61704F7061636974793A302E362C0D0A202020202020686561746D61705261646975733A352C0D0A20202020202070616E4F6E436C';
wwv_flow_api.g_varchar2_table(7) := '69636B3A747275652C0D0A2020202020207265737472696374436F756E7472793A22222C0D0A2020202020206D61705374796C653A22222C0D0A20202020202074726176656C4D6F64653A2244524956494E47222C0D0A2020202020206F7074696D697A';
wwv_flow_api.g_varchar2_table(8) := '65576179706F696E74733A66616C73652C0D0A202020202020616C6C6F775A6F6F6D3A747275652C0D0A202020202020616C6C6F7750616E3A747275652C0D0A2020202020206765737475726548616E646C696E673A226175746F222C0D0A2020202020';
wwv_flow_api.g_varchar2_table(9) := '206E6F446174614D6573736167653A224E6F206461746120746F2073686F77222C0D0A2020202020206E6F41646472657373526573756C74733A2241646472657373206E6F7420666F756E64222C0D0A202020202020646972656374696F6E734E6F7446';
wwv_flow_api.g_varchar2_table(10) := '6F756E643A224174206C65617374206F6E65206F6620746865206F726967696E2C2064657374696E6174696F6E2C206F7220776179706F696E747320636F756C64206E6F742062652067656F636F6465642E222C0D0A202020202020646972656374696F';
wwv_flow_api.g_varchar2_table(11) := '6E735A65726F526573756C74733A224E6F20726F75746520636F756C6420626520666F756E64206265747765656E20746865206F726967696E20616E642064657374696E6174696F6E2E222C0D0A0D0A2020202020202F2F2043616C6C6261636B730D0A';
wwv_flow_api.g_varchar2_table(12) := '20202020202070617273654C61744C6E673A206E756C6C2C2020202020202F2F70617273652061206C61742C6C6E6720737472696E6720696E746F206120676F6F676C652E6D6170732E4C61744C6E670D0A202020202020636C69636B3A206E756C6C2C';
wwv_flow_api.g_varchar2_table(13) := '2020202020202020202020202F2F73696D756C617465206120636C69636B206F6E2061206D61726B65720D0A20202020202067656F6C6F636174653A206E756C6C2C20202020202020202F2F66696E64207468652075736572277320646576696365206C';
wwv_flow_api.g_varchar2_table(14) := '6F636174696F6E0D0A202020202020676F746F416464726573733A206E756C6C2C2020202020202F2F736561726368206279206164647265737320616E6420706C616365207468652070696E2074686572650D0A202020202020676F746F506F733A206E';
wwv_flow_api.g_varchar2_table(15) := '756C6C2C202020202020202020202F2F706C616365207468652070696E206174206120676976656E20706F736974696F6E207B6C61742C6C6E677D0D0A202020202020676F746F506F734279537472696E673A206E756C6C2C20202F2F706C6163652074';
wwv_flow_api.g_varchar2_table(16) := '68652070696E206174206120676976656E20706F736974696F6E20286C61742C6C6E672070726F7669646564206173206120737472696E67290D0A202020202020726566726573683A206E756C6C2C202020202020202020202F2F726566726573682074';
wwv_flow_api.g_varchar2_table(17) := '6865206D6170202872652D72756E20746865207175657279290D0A202020202020676574416464726573734279506F733A206E756C6C2C20202F2F67657420636C6F73657374206164647265737320746F2074686520676976656E206C6F636174696F6E';
wwv_flow_api.g_varchar2_table(18) := '0D0A20202020202073686F77446972656374696F6E733A206E756C6C202020202F2F73686F7720726F757465206265747765656E2074776F206C6F636174696F6E730D0A202020207D2C0D0A202020200D0A202020202F2F72657475726E20676F6F676C';
wwv_flow_api.g_varchar2_table(19) := '65206D617073204C61744C6E67206261736564206F6E2070617273696E672074686520676976656E20737472696E670D0A202020202F2F7468652064656C696D69746572206D6179206265206120737061636520282029206F7220612073656D69636F6C';
wwv_flow_api.g_varchar2_table(20) := '6F6E20283B29206F72206120636F6D6D6120282C292077697468206F6E6520657863657074696F6E3A0D0A202020202F2F69662074686520646563696D616C20706F696E7420697320696E64696361746564206279206120636F6D6D6120282C29207468';
wwv_flow_api.g_varchar2_table(21) := '6520736570617261746F72206D757374206265206120737061636520282029206F722073656D69636F6C6F6E20283B290D0A202020202F2F652E672E3A0D0A202020202F2F202020202D31372E39363039203132322E323132320D0A202020202F2F2020';
wwv_flow_api.g_varchar2_table(22) := '20202D31372E393630392C3132322E323132320D0A202020202F2F202020202D31372E393630393B3132322E323132320D0A202020202F2F202020202D31372C39363039203132322C323132320D0A202020202F2F202020202D31372C393630393B3132';
wwv_flow_api.g_varchar2_table(23) := '322C323132320D0A2020202070617273654C61744C6E673A2066756E6374696F6E20287629207B0D0A202020202020617065782E646562756728227265706F72746D61702E70617273654C61744C6E6720222B76293B0D0A20202020202076617220706F';
wwv_flow_api.g_varchar2_table(24) := '733B0D0A202020202020696620287620213D3D206E756C6C202626207620213D3D20756E646566696E656429207B0D0A202020202020202020766172206172723B0D0A20202020202020202069662028762E696E6465784F6628223B22293E2D3129207B';
wwv_flow_api.g_varchar2_table(25) := '0D0A2020202020202020202020617272203D20762E73706C697428223B22293B0D0A2020202020202020207D20656C73652069662028762E696E6465784F6628222022293E2D3129207B0D0A2020202020202020202020617272203D20762E73706C6974';
wwv_flow_api.g_varchar2_table(26) := '28222022293B0D0A2020202020202020207D20656C73652069662028762E696E6465784F6628222C22293E2D3129207B0D0A2020202020202020202020617272203D20762E73706C697428222C22293B0D0A2020202020202020207D0D0A202020202020';
wwv_flow_api.g_varchar2_table(27) := '20202069662028617272202626206172722E6C656E6774683D3D3229207B0D0A20202020202020202020202F2F636F6E7665727420746F2075736520706572696F6420282E2920666F7220646563696D616C20706F696E740D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(28) := '206172725B305D203D206172725B305D2E7265706C616365282F2C2F672C20222E22293B0D0A20202020202020202020206172725B315D203D206172725B315D2E7265706C616365282F2C2F672C20222E22293B0D0A2020202020202020202020617065';
wwv_flow_api.g_varchar2_table(29) := '782E6465627567282270617273656420222B6172725B305D2B2220222B6172725B315D293B0D0A2020202020202020202020706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67287061727365466C6F6174286172725B305D292C7061';
wwv_flow_api.g_varchar2_table(30) := '727365466C6F6174286172725B315D29293B0D0A2020202020202020207D20656C7365207B0D0A2020202020202020202020617065782E646562756728276E6F204C61744C6E6720666F756E6420696E2022272B762B272227293B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(31) := '20207D0D0A2020202020207D0D0A20202020202072657475726E20706F733B0D0A202020207D2C0D0A202020200D0A202020205F73686F774D6573736167653A2066756E6374696F6E20286D736729207B0D0A202020202020617065782E646562756728';
wwv_flow_api.g_varchar2_table(32) := '227265706F72746D61702E5F73686F774D6573736167652022293B0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020696620285F746869732E696E666F57696E646F7729207B0D0A20202020202020205F746869732E69';
wwv_flow_api.g_varchar2_table(33) := '6E666F57696E646F772E636C6F736528293B0D0A2020202020207D20656C7365207B0D0A20202020202020205F746869732E696E666F57696E646F77203D206E657720676F6F676C652E6D6170732E496E666F57696E646F77280D0A2020202020202020';
wwv_flow_api.g_varchar2_table(34) := '20207B0D0A202020202020202020202020636F6E74656E743A206D73672C0D0A202020202020202020202020706F736974696F6E3A205F746869732E6D61702E67657443656E74657228290D0A202020202020202020207D293B0D0A2020202020207D0D';
wwv_flow_api.g_varchar2_table(35) := '0A2020202020205F746869732E696E666F57696E646F772E6F70656E285F746869732E6D6170293B0D0A202020207D2C0D0A202020200D0A202020205F686964654D6573736167653A2066756E6374696F6E2829207B0D0A202020202020617065782E64';
wwv_flow_api.g_varchar2_table(36) := '6562756728227265706F72746D61702E5F686964654D6573736167652022293B0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020696620285F746869732E696E666F57696E646F7729207B0D0A20202020202020205F74';
wwv_flow_api.g_varchar2_table(37) := '6869732E696E666F57696E646F772E636C6F736528293B0D0A2020202020207D0D0A202020207D2C0D0A202020200D0A202020205F70696E446174613A2066756E6374696F6E202870446174612C20706F7329207B0D0A2020202020207661722064203D';
wwv_flow_api.g_varchar2_table(38) := '207B0D0A20202020202020206D61703A746869732E6D61702C0D0A202020202020202069643A70446174612E642C0D0A20202020202020206E616D653A70446174612E6E2C0D0A20202020202020206C61743A706F732E6C617428292C0D0A2020202020';
wwv_flow_api.g_varchar2_table(39) := '2020206C6E673A706F732E6C6E6728290D0A2020202020207D3B0D0A2020202020206966202870446174612E6629207B0D0A20202020202020206966202870446174612E662E613129207B20645B22617474723031225D203D2070446174612E662E6131';
wwv_flow_api.g_varchar2_table(40) := '3B207D0D0A20202020202020206966202870446174612E662E613229207B20645B22617474723032225D203D2070446174612E662E61323B207D0D0A20202020202020206966202870446174612E662E613329207B20645B22617474723033225D203D20';
wwv_flow_api.g_varchar2_table(41) := '70446174612E662E61333B207D0D0A20202020202020206966202870446174612E662E613429207B20645B22617474723034225D203D2070446174612E662E61343B207D0D0A20202020202020206966202870446174612E662E613529207B20645B2261';
wwv_flow_api.g_varchar2_table(42) := '7474723035225D203D2070446174612E662E61353B207D0D0A20202020202020206966202870446174612E662E613629207B20645B22617474723036225D203D2070446174612E662E61363B207D0D0A20202020202020206966202870446174612E662E';
wwv_flow_api.g_varchar2_table(43) := '613729207B20645B22617474723037225D203D2070446174612E662E61373B207D0D0A20202020202020206966202870446174612E662E613829207B20645B22617474723038225D203D2070446174612E662E61383B207D0D0A20202020202020206966';
wwv_flow_api.g_varchar2_table(44) := '202870446174612E662E613929207B20645B22617474723039225D203D2070446174612E662E61393B207D0D0A20202020202020206966202870446174612E662E61313029207B20645B22617474723130225D203D2070446174612E662E6131303B207D';
wwv_flow_api.g_varchar2_table(45) := '0D0A2020202020207D0D0A20202020202072657475726E20643B0D0A202020207D2C0D0A0D0A202020202F2F706C6163652061207265706F72742070696E206F6E20746865206D61700D0A202020205F72657050696E3A2066756E6374696F6E20287044';
wwv_flow_api.g_varchar2_table(46) := '61746129207B0D0A202020202020766172205F74686973203D20746869733B0D0A2020202020207661722072657070696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B0D0A2020202020202020202020206D61703A205F74686973';
wwv_flow_api.g_varchar2_table(47) := '2E6D61702C0D0A202020202020202020202020706F736974696F6E3A206E657720676F6F676C652E6D6170732E4C61744C6E672870446174612E782C2070446174612E79292C0D0A2020202020202020202020207469746C653A2070446174612E6E2C0D';
wwv_flow_api.g_varchar2_table(48) := '0A20202020202020202020202069636F6E3A2070446174612E632C0D0A2020202020202020202020206C6162656C3A2070446174612E6C2C0D0A202020202020202020202020647261676761626C653A205F746869732E6F7074696F6E732E6973447261';
wwv_flow_api.g_varchar2_table(49) := '676761626C652020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200D0A202020202020202020207D293B0D0A2020202020';
wwv_flow_api.g_varchar2_table(50) := '20676F6F676C652E6D6170732E6576656E742E6164644C697374656E65722872657070696E2C2022636C69636B222C2066756E6374696F6E202829207B0D0A2020202020202020617065782E6465627567282272657050696E20222B70446174612E642B';
wwv_flow_api.g_varchar2_table(51) := '2220636C69636B656422293B0D0A202020202020202076617220706F73203D20746869732E676574506F736974696F6E28293B0D0A20202020202020206966202870446174612E6929207B0D0A202020202020202020202F2F73686F7720696E666F2077';
wwv_flow_api.g_varchar2_table(52) := '696E646F7720666F7220746869732070696E0D0A20202020202020202020696620285F746869732E697729207B0D0A2020202020202020202020205F746869732E69772E636C6F736528293B0D0A202020202020202020207D20656C7365207B0D0A2020';
wwv_flow_api.g_varchar2_table(53) := '202020202020202020205F746869732E6977203D206E657720676F6F676C652E6D6170732E496E666F57696E646F7728293B0D0A202020202020202020207D0D0A202020202020202020202F2F756E657363617065207468652068746D6C20666F722074';
wwv_flow_api.g_varchar2_table(54) := '686520696E666F2077696E646F7720636F6E74656E74730D0A20202020202020202020766172206874203D206E657720444F4D50617273657228292E706172736546726F6D537472696E672870446174612E692C2022746578742F68746D6C22293B0D0A';
wwv_flow_api.g_varchar2_table(55) := '202020202020202020205F746869732E69772E7365744F7074696F6E73287B20636F6E74656E743A2068742E646F63756D656E74456C656D656E742E74657874436F6E74656E74207D293B0D0A202020202020202020205F746869732E69772E6F70656E';
wwv_flow_api.g_varchar2_table(56) := '285F746869732E6D61702C2074686973293B0D0A20202020202020207D0D0A2020202020202020696620285F746869732E6F7074696F6E732E70616E4F6E436C69636B29207B0D0A202020202020202020205F746869732E6D61702E70616E546F28706F';
wwv_flow_api.g_varchar2_table(57) := '73293B0D0A20202020202020207D0D0A2020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A202020202020202020205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F';
wwv_flow_api.g_varchar2_table(58) := '6E732E636C69636B5A6F6F6D4C6576656C293B0D0A20202020202020207D0D0A2020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B6572636C69636B';
wwv_flow_api.g_varchar2_table(59) := '222C205F746869732E5F70696E446174612870446174612C20706F7329293B090D0A2020202020207D293B0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E65722872657070696E2C202264726167656E64222C20';
wwv_flow_api.g_varchar2_table(60) := '66756E6374696F6E202829207B0D0A202020202020202076617220706F73203D20746869732E676574506F736974696F6E28293B0D0A2020202020202020617065782E6465627567282272657050696E20222B70446174612E642B22206D6F7665642074';
wwv_flow_api.g_varchar2_table(61) := '6F20706F736974696F6E2028222B706F732E6C617428292B222C222B706F732E6C6E6728292B222922293B0D0A2020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572';
wwv_flow_api.g_varchar2_table(62) := '28226D61726B657264726167222C205F746869732E5F70696E446174612870446174612C20706F7329293B0D0A2020202020207D293B0D0A20202020202069662028215F746869732E72657070696E29207B205F746869732E72657070696E3D5B5D3B20';
wwv_flow_api.g_varchar2_table(63) := '7D0D0A2020202020205F746869732E72657070696E2E70757368287B226964223A70446174612E642C226D61726B6572223A72657070696E7D293B0D0A20202020202072657475726E2072657070696E3B0D0A202020207D2C0D0A0D0A202020202F2F70';
wwv_flow_api.g_varchar2_table(64) := '757420616C6C20746865207265706F72742070696E73206F6E20746865206D61702C206F722073686F772074686520226E6F206461746120666F756E6422206D6573736167650D0A202020205F73686F77446174613A2066756E6374696F6E202829207B';
wwv_flow_api.g_varchar2_table(65) := '0D0A202020202020617065782E646562756728227265706F72746D61702E5F73686F774461746122293B0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020696620285F746869732E6D6170646174612E6C656E6774683E';
wwv_flow_api.g_varchar2_table(66) := '3029207B0D0A20202020202020205F746869732E5F686964654D65737361676528293B0D0A2020202020202020766172206D61726B65722C206D61726B657273203D205B5D3B0D0A2020202020202020666F7220287661722069203D20303B2069203C20';
wwv_flow_api.g_varchar2_table(67) := '5F746869732E6D6170646174612E6C656E6774683B20692B2B29207B0D0A20202020202020202020696620285F746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D22686561746D61702229207B0D0A2020202020202020202020202F';
wwv_flow_api.g_varchar2_table(68) := '2F2065616368206461746120706F696E7420697320616E206172726179205B782C792C7765696768745D0D0A2020202020202020202020206D61726B6572732E70757368287B0D0A20202020202020202020202020206C6F636174696F6E3A6E65772067';
wwv_flow_api.g_varchar2_table(69) := '6F6F676C652E6D6170732E4C61744C6E67285F746869732E6D6170646174615B695D5B305D2C205F746869732E6D6170646174615B695D5B315D292C0D0A20202020202020202020202020207765696768743A5F746869732E6D6170646174615B695D5B';
wwv_flow_api.g_varchar2_table(70) := '325D0D0A2020202020202020202020207D293B0D0A202020202020202020207D20656C7365207B0D0A2020202020202020202020202F2F2065616368206461746120706F696E7420697320612070696E20696E666F207374727563747572652077697468';
wwv_flow_api.g_varchar2_table(71) := '20782C20792C206574632E20617474726962757465730D0A2020202020202020202020206D61726B6572203D205F746869732E5F72657050696E285F746869732E6D6170646174615B695D293B0D0A202020202020202020202020696620285F74686973';
wwv_flow_api.g_varchar2_table(72) := '2E6F7074696F6E732E76697375616C69736174696F6E3D3D22636C75737465722229207B0D0A20202020202020202020202020206D61726B6572732E70757368286D61726B6572293B0D0A2020202020202020202020207D0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(73) := '7D0D0A20202020202020207D0D0A202020202020202073776974636820285F746869732E6F7074696F6E732E76697375616C69736174696F6E29207B0D0A20202020202020202020636173652022636C7573746572223A0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(74) := '202F2F204164642061206D61726B657220636C7573746572657220746F206D616E61676520746865206D61726B6572732E0D0A2020202020202020202020202F2F204D6F726520696E666F3A2068747470733A2F2F646576656C6F706572732E676F6F67';
wwv_flow_api.g_varchar2_table(75) := '6C652E636F6D2F6D6170732F646F63756D656E746174696F6E2F6A6176617363726970742F6D61726B65722D636C7573746572696E670D0A202020202020202020202020766172206D61726B6572436C7573746572203D206E6577204D61726B6572436C';
wwv_flow_api.g_varchar2_table(76) := '75737465726572285F746869732E6D61702C206D61726B6572732C7B696D616765506174683A5F746869732E696D6167655072656669787D293B0D0A202020202020202020202020627265616B3B0D0A2020202020202020202063617365202268656174';
wwv_flow_api.g_varchar2_table(77) := '6D6170223A0D0A202020202020202020202020696620285F746869732E686561746D61704C6179657229207B0D0A2020202020202020202020202020617065782E6465627567282272656D6F766520686561746D61704C6179657222293B0D0A20202020';
wwv_flow_api.g_varchar2_table(78) := '202020202020202020205F746869732E686561746D61704C617965722E7365744D6170286E756C6C293B0D0A20202020202020202020202020205F746869732E686561746D61704C617965722E64656C6574653B0D0A2020202020202020202020202020';
wwv_flow_api.g_varchar2_table(79) := '5F746869732E686561746D61704C61796572203D206E756C6C3B0D0A2020202020202020202020207D0D0A2020202020202020202020205F746869732E686561746D61704C61796572203D206E657720676F6F676C652E6D6170732E76697375616C697A';
wwv_flow_api.g_varchar2_table(80) := '6174696F6E2E486561746D61704C61796572287B0D0A2020202020202020202020202020646174613A206D61726B6572732C0D0A20202020202020202020202020206D61703A205F746869732E6D61702C0D0A2020202020202020202020202020646973';
wwv_flow_api.g_varchar2_table(81) := '7369706174696E673A205F746869732E6F7074696F6E732E686561746D61704469737369706174696E672C0D0A20202020202020202020202020206F7061636974793A205F746869732E6F7074696F6E732E686561746D61704F7061636974792C0D0A20';
wwv_flow_api.g_varchar2_table(82) := '202020202020202020202020207261646975733A205F746869732E6F7074696F6E732E686561746D61705261646975730D0A2020202020202020202020207D293B0D0A202020202020202020202020627265616B3B0D0A20202020202020207D0D0A2020';
wwv_flow_api.g_varchar2_table(83) := '202020207D20656C7365207B0D0A2020202020202020696620285F746869732E6F7074696F6E732E6E6F446174614D65737361676520213D3D20222229207B0D0A20202020202020202020617065782E6465627567282273686F77204E6F204461746120';
wwv_flow_api.g_varchar2_table(84) := '466F756E6420696E666F77696E646F7722293B0D0A202020202020202020205F746869732E5F73686F774D657373616765285F746869732E6F7074696F6E732E6E6F446174614D657373616765293B0D0A20202020202020207D0D0A2020202020207D0D';
wwv_flow_api.g_varchar2_table(85) := '0A202020207D2C0D0A0D0A202020205F72656D6F766550696E733A2066756E6374696F6E2829207B0D0A202020202020617065782E646562756728227265706F72746D61702E5F72656D6F766550696E7322293B0D0A202020202020766172205F746869';
wwv_flow_api.g_varchar2_table(86) := '73203D20746869733B0D0A202020202020696620285F746869732E72657070696E29207B0D0A2020202020202020666F7220287661722069203D20303B2069203C205F746869732E72657070696E2E6C656E6774683B20692B2B29207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(87) := '20202020205F746869732E72657070696E5B695D2E6D61726B65722E7365744D6170286E756C6C293B0D0A20202020202020207D0D0A20202020202020205F746869732E72657070696E2E64656C6574653B0D0A2020202020207D0D0A202020207D2C0D';
wwv_flow_api.g_varchar2_table(88) := '0A0D0A202020202F2F706C616365206F72206D6F76652074686520757365722070696E20746F2074686520676976656E206C6F636174696F6E0D0A20202020676F746F506F733A2066756E6374696F6E20286C61742C6C6E6729207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(89) := '617065782E646562756728227265706F72746D61702E676F746F506F7322293B0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020696620286C6174213D3D6E756C6C202626206C6E67213D3D6E756C6C29207B0D0A2020';
wwv_flow_api.g_varchar2_table(90) := '202020202020766172206F6C64706F73203D205F746869732E7573657270696E3F5F746869732E7573657270696E2E676574506F736974696F6E28293A286E657720676F6F676C652E6D6170732E4C61744C6E6728302C3029293B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(91) := '20696620286F6C64706F73202626206C61743D3D6F6C64706F732E6C61742829202626206C6E673D3D6F6C64706F732E6C6E67282929207B0D0A20202020202020202020617065782E646562756728227573657270696E206E6F74206368616E67656422';
wwv_flow_api.g_varchar2_table(92) := '293B0D0A20202020202020207D20656C7365207B0D0A2020202020202020202076617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A20202020202020202020696620285F746869732E75736572';
wwv_flow_api.g_varchar2_table(93) := '70696E29207B0D0A202020202020202020202020617065782E646562756728226D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B6C61742B222C222B6C6E67293B0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(94) := '20205F746869732E7573657270696E2E7365744D6170285F746869732E6D6170293B0D0A2020202020202020202020205F746869732E7573657270696E2E736574506F736974696F6E28706F73293B0D0A202020202020202020207D20656C7365207B0D';
wwv_flow_api.g_varchar2_table(95) := '0A202020202020202020202020617065782E64656275672822637265617465207573657270696E20222B6C61742B222C222B6C6E67293B0D0A2020202020202020202020205F746869732E7573657270696E203D206E657720676F6F676C652E6D617073';
wwv_flow_api.g_varchar2_table(96) := '2E4D61726B6572287B6D61703A205F746869732E6D61702C20706F736974696F6E3A20706F737D293B0D0A202020202020202020207D0D0A20202020202020207D0D0A2020202020207D20656C736520696620285F746869732E7573657270696E29207B';
wwv_flow_api.g_varchar2_table(97) := '0D0A2020202020202020617065782E646562756728226D6F7665206578697374696E672070696E206F666620746865206D617022293B0D0A20202020202020205F746869732E7573657270696E2E7365744D6170286E756C6C293B0D0A2020202020207D';
wwv_flow_api.g_varchar2_table(98) := '0D0A202020207D2C0D0A0D0A202020202F2F70617273652074686520676976656E20737472696E672061732061206C61742C6C6F6E6720706169722C2070757420612070696E2061742074686174206C6F636174696F6E0D0A20202020676F746F506F73';
wwv_flow_api.g_varchar2_table(99) := '4279537472696E673A2066756E6374696F6E20287629207B0D0A202020202020617065782E646562756728227265706F72746D61702E676F746F506F734279537472696E6722293B0D0A202020202020766172205F74686973203D20746869733B0D0A20';
wwv_flow_api.g_varchar2_table(100) := '2020202020766172206C61746C6E67203D205F746869732E70617273654C61744C6E672876293B0D0A202020202020696620286C61746C6E6729207B0D0A20202020202020205F746869732E676F746F506F73286C61746C6E672E6C617428292C6C6174';
wwv_flow_api.g_varchar2_table(101) := '6C6E672E6C6E672829293B0D0A2020202020207D0D0A202020207D2C0D0A0D0A202020202F2F73656172636820746865206D617020666F7220616E20616464726573733B20696620666F756E642C2070757420612070696E2061742074686174206C6F63';
wwv_flow_api.g_varchar2_table(102) := '6174696F6E20616E642072616973652061646472657373666F756E6420747269676765720D0A20202020676F746F416464726573733A2066756E6374696F6E2028616464726573735465787429207B0D0A202020202020617065782E6465627567282272';
wwv_flow_api.g_varchar2_table(103) := '65706F72746D61702E676F746F4164647265737322293B0D0A202020202020766172205F74686973203D20746869733B0D0A2020202020207661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F6465723B0D0A2020';
wwv_flow_api.g_varchar2_table(104) := '202020205F746869732E5F686964654D65737361676528293B0D0A20202020202067656F636F6465722E67656F636F6465280D0A20202020202020207B616464726573733A2061646472657373546578740D0A20202020202020202C636F6D706F6E656E';
wwv_flow_api.g_varchar2_table(105) := '745265737472696374696F6E733A205F746869732E6F7074696F6E732E7265737472696374436F756E747279213D3D22223F7B636F756E7472793A5F746869732E6F7074696F6E732E7265737472696374436F756E7472797D3A7B7D0D0A202020202020';
wwv_flow_api.g_varchar2_table(106) := '7D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A202020202020202069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A2020202020202020202076';
wwv_flow_api.g_varchar2_table(107) := '617220706F73203D20726573756C74735B305D2E67656F6D657472792E6C6F636174696F6E3B0D0A20202020202020202020617065782E6465627567282267656F636F6465206F6B22293B0D0A202020202020202020205F746869732E6D61702E736574';
wwv_flow_api.g_varchar2_table(108) := '43656E74657228706F73293B0D0A202020202020202020205F746869732E6D61702E70616E546F28706F73293B0D0A20202020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(109) := '2020202020205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A202020202020202020207D0D0A202020202020202020205F746869732E676F746F506F7328706F732E6C6174';
wwv_flow_api.g_varchar2_table(110) := '28292C20706F732E6C6E672829293B0D0A20202020202020202020617065782E6465627567282261646472657373666F756E642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(111) := '20617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A2020202020202020202020206D61703A5F746869732E6D61702C0D0A20202020';
wwv_flow_api.g_varchar2_table(112) := '20202020202020206C61743A706F732E6C617428292C0D0A2020202020202020202020206C6E673A706F732E6C6E6728292C0D0A202020202020202020202020726573756C743A726573756C74735B305D0D0A202020202020202020207D293B0D0A2020';
wwv_flow_api.g_varchar2_table(113) := '2020202020207D20656C7365207B0D0A20202020202020202020617065782E6465627567282247656F636F646572206661696C65643A20222B737461747573293B0D0A20202020202020207D0D0A2020202020207D293B0D0A202020207D2C0D0A0D0A20';
wwv_flow_api.g_varchar2_table(114) := '2020202F2F63616C6C207468697320746F2073696D756C6174652061206D6F75736520636C69636B206F6E20746865207265706F72742070696E20666F722074686520676976656E2069642076616C75650D0A202020202F2F652E672E20746869732077';
wwv_flow_api.g_varchar2_table(115) := '696C6C2073686F772074686520696E666F2077696E646F7720666F722074686520676976656E207265706F72742070696E20616E64207472696767657220746865206D61726B6572636C69636B206576656E740D0A20202020636C69636B3A2066756E63';
wwv_flow_api.g_varchar2_table(116) := '74696F6E2028696429207B0D0A202020202020617065782E646562756728227265706F72746D61702E636C69636B22293B0D0A202020202020766172205F74686973203D20746869733B0D0A20202020202076617220666F756E64203D2066616C73653B';
wwv_flow_api.g_varchar2_table(117) := '0D0A202020202020666F7220287661722069203D20303B2069203C205F746869732E72657070696E2E6C656E6774683B20692B2B29207B0D0A2020202020202020696620285F746869732E72657070696E5B695D2E69643D3D696429207B0D0A20202020';
wwv_flow_api.g_varchar2_table(118) := '2020202020206E657720676F6F676C652E6D6170732E6576656E742E74726967676572285F746869732E72657070696E5B695D2E6D61726B65722C22636C69636B22293B0D0A20202020202020202020666F756E64203D20747275653B0D0A2020202020';
wwv_flow_api.g_varchar2_table(119) := '2020202020627265616B3B0D0A20202020202020207D0D0A2020202020207D0D0A2020202020206966202821666F756E6429207B0D0A2020202020202020617065782E646562756728226964206E6F7420666F756E643A222B6964293B0D0A2020202020';
wwv_flow_api.g_varchar2_table(120) := '207D0D0A202020207D2C0D0A0D0A202020202F2F6765742074686520636C6F73657374206164647265737320746F206120676976656E206C6F636174696F6E206279206C61742F6C6F6E670D0A20202020676574416464726573734279506F733A206675';
wwv_flow_api.g_varchar2_table(121) := '6E6374696F6E20286C61742C6C6E6729207B0D0A202020202020617065782E646562756728227265706F72746D61702E676574416464726573734279506F7322293B0D0A202020202020766172205F74686973203D20746869733B0D0A20202020202076';
wwv_flow_api.g_varchar2_table(122) := '6172206C61746C6E67203D207B6C61743A206C61742C206C6E673A206C6E677D3B0D0A2020202020207661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F6465723B0D0A2020202020205F746869732E5F68696465';
wwv_flow_api.g_varchar2_table(123) := '4D65737361676528293B0D0A20202020202067656F636F6465722E67656F636F6465287B276C6F636174696F6E273A206C61746C6E677D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A2020202020202020696620287374';
wwv_flow_api.g_varchar2_table(124) := '61747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A2020202020202020202069662028726573756C74735B305D29207B0D0A202020202020202020202020617065782E6465627567282261646472';
wwv_flow_api.g_varchar2_table(125) := '657373666F756E642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A20202020202020202020202076617220636F6D706F6E656E7473203D20726573756C74735B305D2E616464726573735F636F6D70';
wwv_flow_api.g_varchar2_table(126) := '6F6E656E74733B0D0A202020202020202020202020666F722028693D303B20693C636F6D706F6E656E74732E6C656E6774683B20692B2B29207B0D0A2020202020202020202020202020617065782E64656275672822726573756C745B305D20222B636F';
wwv_flow_api.g_varchar2_table(127) := '6D706F6E656E74735B695D2E74797065732B223D222B636F6D706F6E656E74735B695D2E73686F72745F6E616D652B222028222B636F6D706F6E656E74735B695D2E6C6F6E675F6E616D652B222922293B0D0A2020202020202020202020207D0D0A2020';
wwv_flow_api.g_varchar2_table(128) := '20202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A20202020202020202020202020206D61703A5F74686973';
wwv_flow_api.g_varchar2_table(129) := '2E6D61702C0D0A20202020202020202020202020206C61743A6C61742C0D0A20202020202020202020202020206C6E673A6C6E672C0D0A2020202020202020202020202020726573756C743A726573756C74735B305D0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(130) := '7D293B0D0A202020202020202020207D20656C7365207B0D0A202020202020202020202020617065782E64656275672822676574416464726573734279506F733A204E6F20726573756C747320666F756E6422293B0D0A2020202020202020202020205F';
wwv_flow_api.g_varchar2_table(131) := '746869732E5F73686F774D657373616765285F746869732E6F7074696F6E732E6E6F41646472657373526573756C7473293B0D0A202020202020202020207D0D0A20202020202020207D20656C7365207B0D0A20202020202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(132) := '627567282247656F636F646572206661696C65643A2022202B20737461747573293B0D0A20202020202020207D0D0A2020202020207D293B0D0A202020207D2C0D0A0D0A202020202F2F73656172636820666F7220746865207573657220646576696365';
wwv_flow_api.g_varchar2_table(133) := '2773206C6F636174696F6E20696620706F737369626C650D0A2020202067656F6C6F636174653A2066756E6374696F6E202829207B0D0A202020202020617065782E646562756728227265706F72746D61702E67656F6C6F6361746522293B0D0A202020';
wwv_flow_api.g_varchar2_table(134) := '202020766172205F74686973203D20746869733B0D0A202020202020696620286E6176696761746F722E67656F6C6F636174696F6E29207B0D0A2020202020202020617065782E6465627567282267656F6C6F6361746522293B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(135) := '6E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E28706F736974696F6E29207B0D0A2020202020202020202076617220706F73203D207B0D0A2020202020202020202020206C61';
wwv_flow_api.g_varchar2_table(136) := '743A20706F736974696F6E2E636F6F7264732E6C617469747564652C0D0A2020202020202020202020206C6E673A20706F736974696F6E2E636F6F7264732E6C6F6E6769747564650D0A202020202020202020207D3B0D0A202020202020202020205F74';
wwv_flow_api.g_varchar2_table(137) := '6869732E6D61702E70616E546F28706F73293B0D0A20202020202020202020696620285F746869732E6F7074696F6E732E67656F6C6F636174655A6F6F6D29207B0D0A2020202020202020202020205F746869732E6D61702E7365745A6F6F6D285F7468';
wwv_flow_api.g_varchar2_table(138) := '69732E6F7074696F6E732E67656F6C6F636174655A6F6F6D293B0D0A202020202020202020207D0D0A20202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822';
wwv_flow_api.g_varchar2_table(139) := '67656F6C6F63617465222C207B6D61703A5F746869732E6D61702C206C61743A706F732E6C61742C206C6E673A706F732E6C6E677D293B0D0A20202020202020207D293B0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E64';
wwv_flow_api.g_varchar2_table(140) := '65627567282262726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22293B0D0A2020202020207D0D0A202020207D2C0D0A0D0A202020202F2F746869732069732063616C6C6564207768656E20646972656374696F';
wwv_flow_api.g_varchar2_table(141) := '6E7320617265207265717565737465640D0A202020205F646972656374696F6E73526573706F6E73653A2066756E6374696F6E2028726573706F6E73652C73746174757329207B0D0A202020202020617065782E646562756728227265706F72746D6170';
wwv_flow_api.g_varchar2_table(142) := '2E5F646972656374696F6E73526573706F6E736520222B737461747573293B0D0A202020202020766172205F74686973203D20746869733B0D0A20202020202069662028737461747573203D3D20676F6F676C652E6D6170732E446972656374696F6E73';
wwv_flow_api.g_varchar2_table(143) := '5374617475732E4F4B29207B0D0A20202020202020205F746869732E646972656374696F6E73446973706C61792E736574446972656374696F6E7328726573706F6E7365293B0D0A202020202020202076617220746F74616C44697374616E6365203D20';
wwv_flow_api.g_varchar2_table(144) := '302C20746F74616C4475726174696F6E203D20302C206C6567436F756E74203D20303B0D0A2020202020202020666F72202876617220693D303B2069203C20726573706F6E73652E726F757465732E6C656E6774683B20692B2B29207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(145) := '20202020206C6567436F756E74203D206C6567436F756E74202B20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B0D0A20202020202020202020666F722028766172206A3D303B206A203C20726573706F6E73652E726F75';
wwv_flow_api.g_varchar2_table(146) := '7465735B695D2E6C6567732E6C656E6774683B206A2B2B29207B0D0A202020202020202020202020766172206C6567203D20726573706F6E73652E726F757465735B695D2E6C6567735B6A5D3B0D0A202020202020202020202020746F74616C44697374';
wwv_flow_api.g_varchar2_table(147) := '616E6365203D20746F74616C44697374616E6365202B206C65672E64697374616E63652E76616C75653B0D0A202020202020202020202020746F74616C4475726174696F6E203D20746F74616C4475726174696F6E202B206C65672E6475726174696F6E';
wwv_flow_api.g_varchar2_table(148) := '2E76616C75653B0D0A202020202020202020207D0D0A20202020202020207D0D0A2020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822646972656374696F6E7322';
wwv_flow_api.g_varchar2_table(149) := '2C7B0D0A202020202020202020206D61703A5F746869732E6D61702C0D0A2020202020202020202064697374616E63653A746F74616C44697374616E63652C0D0A202020202020202020206475726174696F6E3A746F74616C4475726174696F6E2C0D0A';
wwv_flow_api.g_varchar2_table(150) := '202020202020202020206C6567733A6C6567436F756E740D0A20202020202020207D293B0D0A2020202020207D20656C73652069662028737461747573203D3D20676F6F676C652E6D6170732E446972656374696F6E735374617475732E4E4F545F464F';
wwv_flow_api.g_varchar2_table(151) := '554E4429207B0D0A20202020202020205F746869732E5F73686F774D657373616765285F746869732E6F7074696F6E732E646972656374696F6E734E6F74466F756E64293B0D0A2020202020207D20656C73652069662028737461747573203D3D20676F';
wwv_flow_api.g_varchar2_table(152) := '6F676C652E6D6170732E446972656374696F6E735374617475732E5A45524F5F524553554C545329207B0D0A20202020202020205F746869732E5F73686F774D657373616765285F746869732E6F7074696F6E732E646972656374696F6E735A65726F52';
wwv_flow_api.g_varchar2_table(153) := '6573756C7473293B0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E64656275672822446972656374696F6E732072657175657374206661696C65643A20222B737461747573293B0D0A2020202020207D0D0A202020207D2C';
wwv_flow_api.g_varchar2_table(154) := '0D0A202020200D0A202020202F2F73686F772073696D706C6520726F757465206265747765656E2074776F20706F696E74730D0A2020202073686F77446972656374696F6E733A2066756E6374696F6E20286F726967696E2C2064657374696E6174696F';
wwv_flow_api.g_varchar2_table(155) := '6E2C2074726176656C4D6F6465203D202244524956494E472229207B0D0A202020202020617065782E646562756728227265706F72746D61702E73686F77446972656374696F6E7322293B0D0A202020202020766172205F74686973203D20746869733B';
wwv_flow_api.g_varchar2_table(156) := '0D0A2020202020205F746869732E6F726967696E203D206F726967696E3B0D0A2020202020205F746869732E64657374696E6174696F6E203D2064657374696E6174696F6E3B0D0A2020202020205F746869732E5F686964654D65737361676528293B0D';
wwv_flow_api.g_varchar2_table(157) := '0A202020202020696620285F746869732E6F726967696E26265F746869732E64657374696E6174696F6E29207B0D0A202020202020202069662028215F746869732E646972656374696F6E73446973706C617929207B0D0A202020202020202020205F74';
wwv_flow_api.g_varchar2_table(158) := '6869732E646972656374696F6E73446973706C6179203D206E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265723B0D0A202020202020202020205F746869732E646972656374696F6E7353657276696365203D206E6577';
wwv_flow_api.g_varchar2_table(159) := '20676F6F676C652E6D6170732E446972656374696F6E73536572766963653B0D0A202020202020202020205F746869732E646972656374696F6E73446973706C61792E7365744D6170285F746869732E6D6170293B0D0A20202020202020207D0D0A2020';
wwv_flow_api.g_varchar2_table(160) := '2020202020202F2F73696D706C6520646972656374696F6E73206265747765656E2074776F206C6F636174696F6E730D0A20202020202020205F746869732E6F726967696E203D205F746869732E70617273654C61744C6E67285F746869732E6F726967';
wwv_flow_api.g_varchar2_table(161) := '696E297C7C5F746869732E6F726967696E3B0D0A20202020202020205F746869732E64657374696E6174696F6E203D205F746869732E70617273654C61744C6E67285F746869732E64657374696E6174696F6E297C7C5F746869732E64657374696E6174';
wwv_flow_api.g_varchar2_table(162) := '696F6E3B0D0A2020202020202020696620285F746869732E6F726967696E20213D3D202222202626205F746869732E64657374696E6174696F6E20213D3D20222229207B0D0A202020202020202020205F746869732E646972656374696F6E7353657276';
wwv_flow_api.g_varchar2_table(163) := '6963652E726F757465287B0D0A2020202020202020202020206F726967696E3A5F746869732E6F726967696E2C0D0A20202020202020202020202064657374696E6174696F6E3A5F746869732E64657374696E6174696F6E2C0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(164) := '20202074726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B74726176656C4D6F64655D0D0A202020202020202020207D2C2066756E6374696F6E28726573706F6E73652C737461747573297B5F746869732E5F64697265';
wwv_flow_api.g_varchar2_table(165) := '6374696F6E73526573706F6E736528726573706F6E73652C737461747573297D293B0D0A20202020202020207D20656C7365207B0D0A20202020202020202020617065782E646562756728224E6F20646972656374696F6E7320746F2073686F77202D20';
wwv_flow_api.g_varchar2_table(166) := '6E65656420626F7468206F726967696E20616E642064657374696E6174696F6E206C6F636174696F6E22293B0D0A20202020202020207D0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E64656275672822556E61626C6520';
wwv_flow_api.g_varchar2_table(167) := '746F2073686F7720646972656374696F6E733A206E6F20646174612C206E6F206F726967696E2F64657374696E6174696F6E22293B0D0A2020202020207D0D0A202020207D2C0D0A0D0A202020202F2F646972656374696F6E732076697375616C697361';
wwv_flow_api.g_varchar2_table(168) := '74696F6E206261736564206F6E20717565727920646174610D0A202020205F646972656374696F6E733A2066756E6374696F6E202829207B0D0A202020202020617065782E646562756728227265706F72746D61702E5F646972656374696F6E7322293B';
wwv_flow_api.g_varchar2_table(169) := '0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020696620285F746869732E6D61706461746129207B0D0A2020202020202020617065782E64656275672822726F75746520222B5F746869732E6D6170646174612E6C656E';
wwv_flow_api.g_varchar2_table(170) := '6774682B2220776179706F696E747322293B0D0A2020202020202020696620285F746869732E6D6170646174612E6C656E6774683E3129207B0D0A20202020202020202020766172206F726967696E0D0A202020202020202020202020202C646573743B';
wwv_flow_api.g_varchar2_table(171) := '0D0A2020202020202020202069662028215F746869732E646972656374696F6E73446973706C617929207B0D0A2020202020202020202020205F746869732E646972656374696F6E73446973706C6179203D206E657720676F6F676C652E6D6170732E44';
wwv_flow_api.g_varchar2_table(172) := '6972656374696F6E7352656E64657265723B0D0A2020202020202020202020205F746869732E646972656374696F6E7353657276696365203D206E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963653B0D0A202020202020';
wwv_flow_api.g_varchar2_table(173) := '2020202020205F746869732E646972656374696F6E73446973706C61792E7365744D6170285F746869732E6D6170293B0D0A202020202020202020207D0D0A2020202020202020202076617220776179706F696E7473203D205B5D2C206C61744C6E673B';
wwv_flow_api.g_varchar2_table(174) := '0D0A20202020202020202020666F7220287661722069203D20303B2069203C205F746869732E6D6170646174612E6C656E6774683B20692B2B29207B0D0A2020202020202020202020206C61744C6E67203D206E657720676F6F676C652E6D6170732E4C';
wwv_flow_api.g_varchar2_table(175) := '61744C6E67285F746869732E6D6170646174615B695D2E782C205F746869732E6D6170646174615B695D2E79293B0D0A2020202020202020202020206966202869203D3D203029207B0D0A20202020202020202020202020206F726967696E203D206C61';
wwv_flow_api.g_varchar2_table(176) := '744C6E673B0D0A2020202020202020202020207D20656C7365206966202869203D3D205F746869732E6D6170646174612E6C656E6774682D3129207B0D0A202020202020202020202020202064657374203D206C61744C6E673B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(177) := '202020207D20656C7365207B0D0A2020202020202020202020202020776179706F696E74732E70757368287B0D0A202020202020202020202020202020206C6F636174696F6E3A206C61744C6E672C0D0A2020202020202020202020202020202073746F';
wwv_flow_api.g_varchar2_table(178) := '706F7665723A20747275650D0A20202020202020202020202020207D293B0D0A2020202020202020202020207D0D0A202020202020202020207D0D0A20202020202020202020617065782E646562756728226F726967696E3D222B6F726967696E2B2220';
wwv_flow_api.g_varchar2_table(179) := '646573743D222B646573742B2220776179706F696E74733A222B776179706F696E74732E6C656E6774682B22207669613A222B5F746869732E6F7074696F6E732E74726176656C4D6F6465293B0D0A202020202020202020205F746869732E6469726563';
wwv_flow_api.g_varchar2_table(180) := '74696F6E73536572766963652E726F757465287B0D0A2020202020202020202020206F726967696E3A6F726967696E2C0D0A20202020202020202020202064657374696E6174696F6E3A646573742C0D0A202020202020202020202020776179706F696E';
wwv_flow_api.g_varchar2_table(181) := '74733A776179706F696E74732C0D0A2020202020202020202020206F7074696D697A65576179706F696E74733A5F746869732E6F7074696F6E732E6F7074696D697A65576179706F696E74732C0D0A20202020202020202020202074726176656C4D6F64';
wwv_flow_api.g_varchar2_table(182) := '653A676F6F676C652E6D6170732E54726176656C4D6F64655B5F746869732E6F7074696F6E732E74726176656C4D6F64655D0D0A202020202020202020207D2C2066756E6374696F6E28726573706F6E73652C737461747573297B5F746869732E5F6469';
wwv_flow_api.g_varchar2_table(183) := '72656374696F6E73526573706F6E736528726573706F6E73652C737461747573297D293B0D0A20202020202020207D20656C7365207B0D0A20202020202020202020617065782E646562756728226E6F7420656E6F75676820776179706F696E7473202D';
wwv_flow_api.g_varchar2_table(184) := '206E656564206174206C6561737420616E206F726967696E20616E6420612064657374696E6174696F6E20706F696E7422293B0D0A20202020202020207D0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E64656275672822';
wwv_flow_api.g_varchar2_table(185) := '556E61626C6520746F2073686F7720646972656374696F6E733A206E6F206461746122293B0D0A2020202020207D0D0A202020207D2C0D0A0D0A202020202F2F2054686520636F6E7374727563746F720D0A202020205F6372656174653A2066756E6374';
wwv_flow_api.g_varchar2_table(186) := '696F6E2829207B0D0A202020202020766172205F74686973203D20746869733B0D0A202020202020617065782E646562756728227265706F72746D61702E5F63726561746520222B5F746869732E656C656D656E742E70726F70282269642229293B0D0A';
wwv_flow_api.g_varchar2_table(187) := '202020202020617065782E646562756728226F7074696F6E733A20222B4A534F4E2E737472696E67696679285F746869732E6F7074696F6E7329293B0D0A2020202020202F2F20676574206162736F6C7574652055524C20666F72207468697320736974';
wwv_flow_api.g_varchar2_table(188) := '652C20696E636C7564696E67202F617065782F206F72202F6F7264732F20287468697320697320726571756972656420627920736F6D6520676F6F676C65206D6170732041504973290D0A2020202020207661722066696C6550617468203D2077696E64';
wwv_flow_api.g_varchar2_table(189) := '6F772E6C6F636174696F6E2E6F726967696E202B2077696E646F772E6C6F636174696F6E2E706174686E616D653B0D0A20202020202066696C6550617468203D2066696C65506174682E737562737472696E6728302C2066696C65506174682E6C617374';
wwv_flow_api.g_varchar2_table(190) := '496E6465784F6628222F2229293B0D0A2020202020205F746869732E696D616765507265666978203D2066696C6550617468202B20222F22202B205F746869732E6F7074696F6E732E706C7567696E46696C65507265666978202B2022696D616765732F';
wwv_flow_api.g_varchar2_table(191) := '6D223B0D0A202020202020617065782E646562756728275F746869732E696D6167655072656669783D22272B5F746869732E696D6167655072656669782B272227293B0D0A202020202020766172206D794F7074696F6E73203D207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(192) := '20206D696E5A6F6F6D3A205F746869732E6F7074696F6E732E6D696E5A6F6F6D2C0D0A20202020202020206D61785A6F6F6D3A205F746869732E6F7074696F6E732E6D61785A6F6F6D2C0D0A20202020202020207A6F6F6D3A205F746869732E6F707469';
wwv_flow_api.g_varchar2_table(193) := '6F6E732E696E697469616C5A6F6F6D2C0D0A202020202020202063656E7465723A205F746869732E6F7074696F6E732E696E697469616C43656E7465722C0D0A20202020202020206D61705479706549643A205F746869732E6F7074696F6E732E6D6170';
wwv_flow_api.g_varchar2_table(194) := '547970652C0D0A2020202020202020647261676761626C653A205F746869732E6F7074696F6E732E616C6C6F7750616E2C0D0A20202020202020207A6F6F6D436F6E74726F6C3A205F746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C0D0A2020';
wwv_flow_api.g_varchar2_table(195) := '2020202020207363726F6C6C776865656C3A205F746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C0D0A202020202020202064697361626C65446F75626C65436C69636B5A6F6F6D3A2021285F746869732E6F7074696F6E732E616C6C6F775A6F';
wwv_flow_api.g_varchar2_table(196) := '6F6D292C0D0A20202020202020206765737475726548616E646C696E673A205F746869732E6F7074696F6E732E6765737475726548616E646C696E670D0A2020202020207D3B0D0A202020202020696620285F746869732E6F7074696F6E732E6D617053';
wwv_flow_api.g_varchar2_table(197) := '74796C6529207B0D0A20202020202020206D794F7074696F6E735B227374796C6573225D203D205F746869732E6F7074696F6E732E6D61705374796C653B0D0A2020202020207D0D0A2020202020205F746869732E6D6170203D206E657720676F6F676C';
wwv_flow_api.g_varchar2_table(198) := '652E6D6170732E4D617028646F63756D656E742E676574456C656D656E7442794964285F746869732E656C656D656E742E70726F70282269642229292C6D794F7074696F6E73293B0D0A202020202020696620285F746869732E6F7074696F6E732E736F';
wwv_flow_api.g_varchar2_table(199) := '7574687765737426265F746869732E6F7074696F6E732E6E6F7274686561737429207B0D0A20202020202020205F746869732E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E6473285F746869732E';
wwv_flow_api.g_varchar2_table(200) := '6F7074696F6E732E736F757468776573742C5F746869732E6F7074696F6E732E6E6F7274686561737429293B0D0A2020202020207D0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572285F746869732E6D6170';
wwv_flow_api.g_varchar2_table(201) := '2C2022636C69636B222C2066756E6374696F6E20286576656E7429207B0D0A2020202020202020766172206C6174203D206576656E742E6C61744C6E672E6C617428290D0A20202020202020202020202C6C6E67203D206576656E742E6C61744C6E672E';
wwv_flow_api.g_varchar2_table(202) := '6C6E6728293B0D0A2020202020202020617065782E646562756728226D617020636C69636B656420222B6C61742B222C222B6C6E67293B0D0A2020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B';
wwv_flow_api.g_varchar2_table(203) := '0D0A20202020202020202020617065782E6465627567282270616E2B7A6F6F6D22293B0D0A20202020202020202020696620285F746869732E6F7074696F6E732E70616E4F6E436C69636B29207B0D0A2020202020202020202020205F746869732E6D61';
wwv_flow_api.g_varchar2_table(204) := '702E70616E546F286576656E742E6C61744C6E67293B0D0A202020202020202020207D0D0A202020202020202020205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A202020';
wwv_flow_api.g_varchar2_table(205) := '20202020207D0D0A2020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170636C69636B222C207B6D61703A5F746869732E6D61702C206C61743A6C61742C';
wwv_flow_api.g_varchar2_table(206) := '206C6E673A6C6E677D293B0D0A2020202020207D293B0D0A202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61706C6F61646564222C207B6D61703A5F746869';
wwv_flow_api.g_varchar2_table(207) := '732E6D61707D293B0D0A202020202020696620285F746869732E6F7074696F6E732E6578706563744461746129207B0D0A20202020202020205F746869732E7265667265736828293B0D0A2020202020207D0D0A202020202020617065782E6465627567';
wwv_flow_api.g_varchar2_table(208) := '28227265706F72746D61702E696E69742066696E697368656422293B0D0A202020207D2C0D0A202020200D0A202020202F2F2043616C6C6564207768656E20637265617465642C20616E64206C61746572207768656E206368616E67696E67206F707469';
wwv_flow_api.g_varchar2_table(209) := '6F6E730D0A20202020726566726573683A2066756E6374696F6E2829207B0D0A202020202020617065782E646562756728227265706F72746D61702E7265667265736822293B0D0A202020202020766172205F74686973203D20746869733B0D0A202020';
wwv_flow_api.g_varchar2_table(210) := '2020205F746869732E5F686964654D65737361676528293B0D0A202020202020696620285F746869732E6F7074696F6E732E6578706563744461746129207B0D0A2020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F';
wwv_flow_api.g_varchar2_table(211) := '6E732E726567696F6E4964292E747269676765722822617065786265666F72657265667265736822293B0D0A2020202020202020617065782E7365727665722E706C7567696E0D0A20202020202020202020285F746869732E6F7074696F6E732E616A61';
wwv_flow_api.g_varchar2_table(212) := '784964656E7469666965720D0A202020202020202020202C7B20706167654974656D733A205F746869732E6F7074696F6E732E616A61784974656D73207D0D0A202020202020202020202C7B2064617461547970653A20226A736F6E220D0A2020202020';
wwv_flow_api.g_varchar2_table(213) := '202020202020202C737563636573733A2066756E6374696F6E282070446174612029207B0D0A2020202020202020202020202020617065782E64656275672822737563636573732070446174613D222B70446174612E736F757468776573742E6C61742B';
wwv_flow_api.g_varchar2_table(214) := '222C222B70446174612E736F757468776573742E6C6E672B2220222B70446174612E6E6F727468656173742E6C61742B222C222B70446174612E6E6F727468656173742E6C6E67293B0D0A20202020202020202020202020206966202870446174612E73';
wwv_flow_api.g_varchar2_table(215) := '6F757468776573742E6C6174262670446174612E736F757468776573742E6C6E67262670446174612E6E6F727468656173742E6C6174262670446174612E6E6F727468656173742E6C6E6729207B0D0A202020202020202020202020202020205F746869';
wwv_flow_api.g_varchar2_table(216) := '732E6D61702E666974426F756E6473280D0A2020202020202020202020202020202020207B736F7574683A70446174612E736F757468776573742E6C61740D0A2020202020202020202020202020202020202C776573743A2070446174612E736F757468';
wwv_flow_api.g_varchar2_table(217) := '776573742E6C6E670D0A2020202020202020202020202020202020202C6E6F7274683A70446174612E6E6F727468656173742E6C61740D0A2020202020202020202020202020202020202C656173743A2070446174612E6E6F727468656173742E6C6E67';
wwv_flow_api.g_varchar2_table(218) := '7D293B0D0A20202020202020202020202020207D0D0A2020202020202020202020202020696620285F746869732E697729207B0D0A202020202020202020202020202020205F746869732E69772E636C6F736528293B0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(219) := '20207D0D0A20202020202020202020202020205F746869732E5F72656D6F766550696E7328293B0D0A2020202020202020202020202020617065782E6465627567282270446174612E6D6170646174612E6C656E6774683D222B70446174612E6D617064';
wwv_flow_api.g_varchar2_table(220) := '6174612E6C656E677468293B0D0A20202020202020202020202020205F746869732E6D617064617461203D2070446174612E6D6170646174613B0D0A2020202020202020202020202020696620285F746869732E6D61706461746129207B0D0A20202020';
wwv_flow_api.g_varchar2_table(221) := '2020202020202020202020205F746869732E5F73686F774461746128293B0D0A20202020202020202020202020207D0D0A2020202020202020202020202020696620285F746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D22646972';
wwv_flow_api.g_varchar2_table(222) := '656374696F6E732229207B0D0A202020202020202020202020202020205F746869732E5F646972656374696F6E7328293B0D0A20202020202020202020202020207D0D0A2020202020202020202020202020617065782E6A5175657279282223222B5F74';
wwv_flow_api.g_varchar2_table(223) := '6869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226170657861667465727265667265736822293B0D0A2020202020202020202020207D0D0A202020202020202020207D20293B0D0A2020202020207D0D0A2020202020206170';
wwv_flow_api.g_varchar2_table(224) := '65782E646562756728227265706F72746D61702E726566726573682066696E697368656422293B0D0A2020202020202F2F205472696767657220612063616C6C6261636B2F6576656E740D0A2020202020205F746869732E5F7472696767657228202263';
wwv_flow_api.g_varchar2_table(225) := '68616E67652220293B0D0A202020207D2C0D0A0D0A202020202F2F204576656E747320626F756E6420766961205F6F6E206172652072656D6F766564206175746F6D61746963616C6C790D0A202020202F2F20726576657274206F74686572206D6F6469';
wwv_flow_api.g_varchar2_table(226) := '6669636174696F6E7320686572650D0A202020205F64657374726F793A2066756E6374696F6E2829207B0D0A2020202020202F2F2072656D6F76652067656E65726174656420656C656D656E74730D0A202020202020766172205F74686973203D207468';
wwv_flow_api.g_varchar2_table(227) := '69733B0D0A202020202020696620285F746869732E686561746D61704C6179657229207B0D0A20202020202020205F746869732E686561746D61704C617965722E72656D6F766528293B0D0A2020202020207D0D0A202020202020696620285F74686973';
wwv_flow_api.g_varchar2_table(228) := '2E697729207B0D0A20202020202020205F746869732E69772E636C6F736528293B0D0A2020202020207D0D0A2020202020205F746869732E5F72656D6F766550696E7328293B0D0A2020202020205F746869732E6D61702E72656D6F766528293B0D0A20';
wwv_flow_api.g_varchar2_table(229) := '2020207D2C0D0A0D0A202020202F2F205F7365744F7074696F6E732069732063616C6C6564207769746820612068617368206F6620616C6C206F7074696F6E73207468617420617265206368616E67696E670D0A202020202F2F20616C77617973207265';
wwv_flow_api.g_varchar2_table(230) := '6672657368207768656E206368616E67696E67206F7074696F6E730D0A202020205F7365744F7074696F6E733A2066756E6374696F6E2829207B0D0A2020202020202F2F205F737570657220616E64205F73757065724170706C792068616E646C65206B';
wwv_flow_api.g_varchar2_table(231) := '656570696E672074686520726967687420746869732D636F6E746578740D0A202020202020746869732E5F73757065724170706C792820617267756D656E747320293B0D0A202020202020746869732E7265667265736828293B0D0A202020207D2C0D0A';
wwv_flow_api.g_varchar2_table(232) := '0D0A202020202F2F205F7365744F7074696F6E2069732063616C6C656420666F72206561636820696E646976696475616C206F7074696F6E2074686174206973206368616E67696E670D0A202020205F7365744F7074696F6E3A2066756E6374696F6E28';
wwv_flow_api.g_varchar2_table(233) := '206B65792C2076616C75652029207B0D0A202020202020746869732E5F737570657228206B65792C2076616C756520293B0D0A202020207D2020202020200D0A0D0A20207D293B0D0A7D293B';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33069303343035159)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'jk64reportmap_r1.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '242866756E6374696F6E28297B242E77696467657428226A6B36342E7265706F72746D6170222C7B6F7074696F6E733A7B726567696F6E49643A22222C616A61784964656E7469666965723A22222C616A61784974656D733A22222C706C7567696E4669';
wwv_flow_api.g_varchar2_table(2) := '6C655072656669783A22222C657870656374446174613A21302C696E697469616C43656E7465723A7B6C61743A302C6C6E673A307D2C6D696E5A6F6F6D3A312C6D61785A6F6F6D3A6E756C6C2C696E697469616C5A6F6F6D3A322C736F75746877657374';
wwv_flow_api.g_varchar2_table(3) := '3A6E756C6C2C6E6F727468656173743A6E756C6C2C76697375616C69736174696F6E3A2270696E73222C6D6170547970653A22726F61646D6170222C636C69636B5A6F6F6D4C6576656C3A6E756C6C2C6973447261676761626C653A21312C686561746D';
wwv_flow_api.g_varchar2_table(4) := '61704469737369706174696E673A21312C686561746D61704F7061636974793A2E362C686561746D61705261646975733A352C70616E4F6E436C69636B3A21302C7265737472696374436F756E7472793A22222C6D61705374796C653A22222C74726176';
wwv_flow_api.g_varchar2_table(5) := '656C4D6F64653A2244524956494E47222C6F7074696D697A65576179706F696E74733A21312C616C6C6F775A6F6F6D3A21302C616C6C6F7750616E3A21302C6765737475726548616E646C696E673A226175746F222C6E6F446174614D6573736167653A';
wwv_flow_api.g_varchar2_table(6) := '224E6F206461746120746F2073686F77222C6E6F41646472657373526573756C74733A2241646472657373206E6F7420666F756E64222C646972656374696F6E734E6F74466F756E643A224174206C65617374206F6E65206F6620746865206F72696769';
wwv_flow_api.g_varchar2_table(7) := '6E2C2064657374696E6174696F6E2C206F7220776179706F696E747320636F756C64206E6F742062652067656F636F6465642E222C646972656374696F6E735A65726F526573756C74733A224E6F20726F75746520636F756C6420626520666F756E6420';
wwv_flow_api.g_varchar2_table(8) := '6265747765656E20746865206F726967696E20616E642064657374696E6174696F6E2E222C70617273654C61744C6E673A6E756C6C2C636C69636B3A6E756C6C2C67656F6C6F636174653A6E756C6C2C676F746F416464726573733A6E756C6C2C676F74';
wwv_flow_api.g_varchar2_table(9) := '6F506F733A6E756C6C2C676F746F506F734279537472696E673A6E756C6C2C726566726573683A6E756C6C2C676574416464726573734279506F733A6E756C6C2C73686F77446972656374696F6E733A6E756C6C7D2C70617273654C61744C6E673A6675';
wwv_flow_api.g_varchar2_table(10) := '6E6374696F6E2865297B766172206F2C743B28617065782E646562756728227265706F72746D61702E70617273654C61744C6E6720222B65292C6E756C6C213D6529262628652E696E6465784F6628223B22293E2D313F743D652E73706C697428223B22';
wwv_flow_api.g_varchar2_table(11) := '293A652E696E6465784F6628222022293E2D313F743D652E73706C697428222022293A652E696E6465784F6628222C22293E2D31262628743D652E73706C697428222C2229292C742626323D3D742E6C656E6774683F28745B305D3D745B305D2E726570';
wwv_flow_api.g_varchar2_table(12) := '6C616365282F2C2F672C222E22292C745B315D3D745B315D2E7265706C616365282F2C2F672C222E22292C617065782E6465627567282270617273656420222B745B305D2B2220222B745B315D292C6F3D6E657720676F6F676C652E6D6170732E4C6174';
wwv_flow_api.g_varchar2_table(13) := '4C6E67287061727365466C6F617428745B305D292C7061727365466C6F617428745B315D2929293A617065782E646562756728276E6F204C61744C6E6720666F756E6420696E2022272B652B27222729293B72657475726E206F7D2C5F73686F774D6573';
wwv_flow_api.g_varchar2_table(14) := '736167653A66756E6374696F6E2865297B617065782E646562756728227265706F72746D61702E5F73686F774D6573736167652022293B746869732E696E666F57696E646F773F746869732E696E666F57696E646F772E636C6F736528293A746869732E';
wwv_flow_api.g_varchar2_table(15) := '696E666F57696E646F773D6E657720676F6F676C652E6D6170732E496E666F57696E646F77287B636F6E74656E743A652C706F736974696F6E3A746869732E6D61702E67657443656E74657228297D292C746869732E696E666F57696E646F772E6F7065';
wwv_flow_api.g_varchar2_table(16) := '6E28746869732E6D6170297D2C5F686964654D6573736167653A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F686964654D6573736167652022293B746869732E696E666F57696E646F772626746869732E696E66';
wwv_flow_api.g_varchar2_table(17) := '6F57696E646F772E636C6F736528297D2C5F70696E446174613A66756E6374696F6E28652C6F297B76617220743D7B6D61703A746869732E6D61702C69643A652E642C6E616D653A652E6E2C6C61743A6F2E6C617428292C6C6E673A6F2E6C6E6728297D';
wwv_flow_api.g_varchar2_table(18) := '3B72657475726E20652E66262628652E662E6131262628742E6174747230313D652E662E6131292C652E662E6132262628742E6174747230323D652E662E6132292C652E662E6133262628742E6174747230333D652E662E6133292C652E662E61342626';
wwv_flow_api.g_varchar2_table(19) := '28742E6174747230343D652E662E6134292C652E662E6135262628742E6174747230353D652E662E6135292C652E662E6136262628742E6174747230363D652E662E6136292C652E662E6137262628742E6174747230373D652E662E6137292C652E662E';
wwv_flow_api.g_varchar2_table(20) := '6138262628742E6174747230383D652E662E6138292C652E662E6139262628742E6174747230393D652E662E6139292C652E662E613130262628742E6174747231303D652E662E61313029292C747D2C5F72657050696E3A66756E6374696F6E2865297B';
wwv_flow_api.g_varchar2_table(21) := '766172206F3D746869732C743D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A6F2E6D61702C706F736974696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728652E782C652E79292C7469746C653A652E6E2C6963';
wwv_flow_api.g_varchar2_table(22) := '6F6E3A652E632C6C6162656C3A652E6C2C647261676761626C653A6F2E6F7074696F6E732E6973447261676761626C657D293B72657475726E20676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228742C22636C69636B222C6675';
wwv_flow_api.g_varchar2_table(23) := '6E6374696F6E28297B617065782E6465627567282272657050696E20222B652E642B2220636C69636B656422293B76617220743D746869732E676574506F736974696F6E28293B696628652E69297B6F2E69773F6F2E69772E636C6F736528293A6F2E69';
wwv_flow_api.g_varchar2_table(24) := '773D6E657720676F6F676C652E6D6170732E496E666F57696E646F773B76617220613D286E657720444F4D506172736572292E706172736546726F6D537472696E6728652E692C22746578742F68746D6C22293B6F2E69772E7365744F7074696F6E7328';
wwv_flow_api.g_varchar2_table(25) := '7B636F6E74656E743A612E646F63756D656E74456C656D656E742E74657874436F6E74656E747D292C6F2E69772E6F70656E286F2E6D61702C74686973297D6F2E6F7074696F6E732E70616E4F6E436C69636B26266F2E6D61702E70616E546F2874292C';
wwv_flow_api.g_varchar2_table(26) := '6F2E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C26266F2E6D61702E7365745A6F6F6D286F2E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C292C617065782E6A5175657279282223222B6F2E6F7074696F6E732E726567696F6E4964';
wwv_flow_api.g_varchar2_table(27) := '292E7472696767657228226D61726B6572636C69636B222C6F2E5F70696E4461746128652C7429297D292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228742C2264726167656E64222C66756E6374696F6E28297B76617220';
wwv_flow_api.g_varchar2_table(28) := '743D746869732E676574506F736974696F6E28293B617065782E6465627567282272657050696E20222B652E642B22206D6F76656420746F20706F736974696F6E2028222B742E6C617428292B222C222B742E6C6E6728292B222922292C617065782E6A';
wwv_flow_api.g_varchar2_table(29) := '5175657279282223222B6F2E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B657264726167222C6F2E5F70696E4461746128652C7429297D292C6F2E72657070696E7C7C286F2E72657070696E3D5B5D292C6F2E72657070';
wwv_flow_api.g_varchar2_table(30) := '696E2E70757368287B69643A652E642C6D61726B65723A747D292C747D2C5F73686F77446174613A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F73686F774461746122293B696628746869732E6D617064617461';
wwv_flow_api.g_varchar2_table(31) := '2E6C656E6774683E30297B746869732E5F686964654D65737361676528293B666F722876617220652C6F3D5B5D2C743D303B743C746869732E6D6170646174612E6C656E6774683B742B2B2922686561746D6170223D3D746869732E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(32) := '76697375616C69736174696F6E3F6F2E70757368287B6C6F636174696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728746869732E6D6170646174615B745D5B305D2C746869732E6D6170646174615B745D5B315D292C7765696768743A';
wwv_flow_api.g_varchar2_table(33) := '746869732E6D6170646174615B745D5B325D7D293A28653D746869732E5F72657050696E28746869732E6D6170646174615B745D292C22636C7573746572223D3D746869732E6F7074696F6E732E76697375616C69736174696F6E26266F2E7075736828';
wwv_flow_api.g_varchar2_table(34) := '6529293B73776974636828746869732E6F7074696F6E732E76697375616C69736174696F6E297B6361736522636C7573746572223A6E6577204D61726B6572436C7573746572657228746869732E6D61702C6F2C7B696D616765506174683A746869732E';
wwv_flow_api.g_varchar2_table(35) := '696D6167655072656669787D293B627265616B3B6361736522686561746D6170223A746869732E686561746D61704C61796572262628617065782E6465627567282272656D6F766520686561746D61704C6179657222292C746869732E686561746D6170';
wwv_flow_api.g_varchar2_table(36) := '4C617965722E7365744D6170286E756C6C292C746869732E686561746D61704C617965722E64656C6574652C746869732E686561746D61704C617965723D6E756C6C292C746869732E686561746D61704C617965723D6E657720676F6F676C652E6D6170';
wwv_flow_api.g_varchar2_table(37) := '732E76697375616C697A6174696F6E2E486561746D61704C61796572287B646174613A6F2C6D61703A746869732E6D61702C6469737369706174696E673A746869732E6F7074696F6E732E686561746D61704469737369706174696E672C6F7061636974';
wwv_flow_api.g_varchar2_table(38) := '793A746869732E6F7074696F6E732E686561746D61704F7061636974792C7261646975733A746869732E6F7074696F6E732E686561746D61705261646975737D297D7D656C73652222213D3D746869732E6F7074696F6E732E6E6F446174614D65737361';
wwv_flow_api.g_varchar2_table(39) := '6765262628617065782E6465627567282273686F77204E6F204461746120466F756E6420696E666F77696E646F7722292C746869732E5F73686F774D65737361676528746869732E6F7074696F6E732E6E6F446174614D65737361676529297D2C5F7265';
wwv_flow_api.g_varchar2_table(40) := '6D6F766550696E733A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F72656D6F766550696E7322293B696628746869732E72657070696E297B666F722876617220653D303B653C746869732E72657070696E2E6C65';
wwv_flow_api.g_varchar2_table(41) := '6E6774683B652B2B29746869732E72657070696E5B655D2E6D61726B65722E7365744D6170286E756C6C293B746869732E72657070696E2E64656C6574657D7D2C676F746F506F733A66756E6374696F6E28652C6F297B617065782E6465627567282272';
wwv_flow_api.g_varchar2_table(42) := '65706F72746D61702E676F746F506F7322293B6966286E756C6C213D3D6526266E756C6C213D3D6F297B76617220743D746869732E7573657270696E3F746869732E7573657270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(43) := '6170732E4C61744C6E6728302C30293B696628742626653D3D742E6C6174282926266F3D3D742E6C6E67282929617065782E646562756728227573657270696E206E6F74206368616E67656422293B656C73657B76617220613D6E657720676F6F676C65';
wwv_flow_api.g_varchar2_table(44) := '2E6D6170732E4C61744C6E6728652C6F293B746869732E7573657270696E3F28617065782E646562756728226D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B652B222C222B6F292C74686973';
wwv_flow_api.g_varchar2_table(45) := '2E7573657270696E2E7365744D617028746869732E6D6170292C746869732E7573657270696E2E736574506F736974696F6E286129293A28617065782E64656275672822637265617465207573657270696E20222B652B222C222B6F292C746869732E75';
wwv_flow_api.g_varchar2_table(46) := '73657270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A746869732E6D61702C706F736974696F6E3A617D29297D7D656C736520746869732E7573657270696E262628617065782E646562756728226D6F76652065786973';
wwv_flow_api.g_varchar2_table(47) := '74696E672070696E206F666620746865206D617022292C746869732E7573657270696E2E7365744D6170286E756C6C29297D2C676F746F506F734279537472696E673A66756E6374696F6E2865297B617065782E646562756728227265706F72746D6170';
wwv_flow_api.g_varchar2_table(48) := '2E676F746F506F734279537472696E6722293B766172206F3D746869732E70617273654C61744C6E672865293B6F2626746869732E676F746F506F73286F2E6C617428292C6F2E6C6E672829297D2C676F746F416464726573733A66756E6374696F6E28';
wwv_flow_api.g_varchar2_table(49) := '65297B617065782E646562756728227265706F72746D61702E676F746F4164647265737322293B766172206F3D746869732C743D6E657720676F6F676C652E6D6170732E47656F636F6465723B6F2E5F686964654D65737361676528292C742E67656F63';
wwv_flow_api.g_varchar2_table(50) := '6F6465287B616464726573733A652C636F6D706F6E656E745265737472696374696F6E733A2222213D3D6F2E6F7074696F6E732E7265737472696374436F756E7472793F7B636F756E7472793A6F2E6F7074696F6E732E7265737472696374436F756E74';
wwv_flow_api.g_varchar2_table(51) := '72797D3A7B7D7D2C66756E6374696F6E28652C74297B696628743D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B297B76617220613D655B305D2E67656F6D657472792E6C6F636174696F6E3B617065782E646562756728';
wwv_flow_api.g_varchar2_table(52) := '2267656F636F6465206F6B22292C6F2E6D61702E73657443656E7465722861292C6F2E6D61702E70616E546F2861292C6F2E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C26266F2E6D61702E7365745A6F6F6D286F2E6F7074696F6E732E636C';
wwv_flow_api.g_varchar2_table(53) := '69636B5A6F6F6D4C6576656C292C6F2E676F746F506F7328612E6C617428292C612E6C6E672829292C617065782E6465627567282261646472657373666F756E642027222B655B305D2E666F726D61747465645F616464726573732B222722292C617065';
wwv_flow_api.g_varchar2_table(54) := '782E6A5175657279282223222B6F2E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A6F2E6D61702C6C61743A612E6C617428292C6C6E673A612E6C6E6728292C726573756C743A655B';
wwv_flow_api.g_varchar2_table(55) := '305D7D297D656C736520617065782E6465627567282247656F636F646572206661696C65643A20222B74297D297D2C636C69636B3A66756E6374696F6E2865297B617065782E646562756728227265706F72746D61702E636C69636B22293B666F722876';
wwv_flow_api.g_varchar2_table(56) := '6172206F3D21312C743D303B743C746869732E72657070696E2E6C656E6774683B742B2B29696628746869732E72657070696E5B745D2E69643D3D65297B6E657720676F6F676C652E6D6170732E6576656E742E7472696767657228746869732E726570';
wwv_flow_api.g_varchar2_table(57) := '70696E5B745D2E6D61726B65722C22636C69636B22292C6F3D21303B627265616B7D6F7C7C617065782E646562756728226964206E6F7420666F756E643A222B65297D2C676574416464726573734279506F733A66756E6374696F6E28652C6F297B6170';
wwv_flow_api.g_varchar2_table(58) := '65782E646562756728227265706F72746D61702E676574416464726573734279506F7322293B76617220743D746869732C613D7B6C61743A652C6C6E673A6F7D2C6E3D6E657720676F6F676C652E6D6170732E47656F636F6465723B742E5F686964654D';
wwv_flow_api.g_varchar2_table(59) := '65737361676528292C6E2E67656F636F6465287B6C6F636174696F6E3A617D2C66756E6374696F6E28612C6E297B6966286E3D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29696628615B305D297B617065782E646562';
wwv_flow_api.g_varchar2_table(60) := '7567282261646472657373666F756E642027222B615B305D2E666F726D61747465645F616464726573732B222722293B76617220733D615B305D2E616464726573735F636F6D706F6E656E74733B666F7228693D303B693C732E6C656E6774683B692B2B';
wwv_flow_api.g_varchar2_table(61) := '29617065782E64656275672822726573756C745B305D20222B735B695D2E74797065732B223D222B735B695D2E73686F72745F6E616D652B222028222B735B695D2E6C6F6E675F6E616D652B222922293B617065782E6A5175657279282223222B742E6F';
wwv_flow_api.g_varchar2_table(62) := '7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A742E6D61702C6C61743A652C6C6E673A6F2C726573756C743A615B305D7D297D656C736520617065782E64656275672822676574416464';
wwv_flow_api.g_varchar2_table(63) := '726573734279506F733A204E6F20726573756C747320666F756E6422292C742E5F73686F774D65737361676528742E6F7074696F6E732E6E6F41646472657373526573756C7473293B656C736520617065782E6465627567282247656F636F6465722066';
wwv_flow_api.g_varchar2_table(64) := '61696C65643A20222B6E297D297D2C67656F6C6F636174653A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E67656F6C6F6361746522293B76617220653D746869733B6E6176696761746F722E67656F6C6F63617469';
wwv_flow_api.g_varchar2_table(65) := '6F6E3F28617065782E6465627567282267656F6C6F6361746522292C6E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E286F297B76617220743D7B6C61743A6F2E636F6F726473';
wwv_flow_api.g_varchar2_table(66) := '2E6C617469747564652C6C6E673A6F2E636F6F7264732E6C6F6E6769747564657D3B652E6D61702E70616E546F2874292C652E6F7074696F6E732E67656F6C6F636174655A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6F7074696F6E732E6765';
wwv_flow_api.g_varchar2_table(67) := '6F6C6F636174655A6F6F6D292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E74726967676572282267656F6C6F63617465222C7B6D61703A652E6D61702C6C61743A742E6C61742C6C6E673A742E6C6E677D';
wwv_flow_api.g_varchar2_table(68) := '297D29293A617065782E6465627567282262726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22297D2C5F646972656374696F6E73526573706F6E73653A66756E6374696F6E28652C6F297B617065782E64656275';
wwv_flow_api.g_varchar2_table(69) := '6728227265706F72746D61702E5F646972656374696F6E73526573706F6E736520222B6F293B6966286F3D3D676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B297B746869732E646972656374696F6E73446973706C61792E';
wwv_flow_api.g_varchar2_table(70) := '736574446972656374696F6E732865293B666F722876617220743D302C613D302C693D302C6E3D303B6E3C652E726F757465732E6C656E6774683B6E2B2B297B692B3D652E726F757465735B6E5D2E6C6567732E6C656E6774683B666F72287661722073';
wwv_flow_api.g_varchar2_table(71) := '3D303B733C652E726F757465735B6E5D2E6C6567732E6C656E6774683B732B2B297B76617220723D652E726F757465735B6E5D2E6C6567735B735D3B742B3D722E64697374616E63652E76616C75652C612B3D722E6475726174696F6E2E76616C75657D';
wwv_flow_api.g_varchar2_table(72) := '7D617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822646972656374696F6E73222C7B6D61703A746869732E6D61702C64697374616E63653A742C6475726174696F6E3A612C6C6567';
wwv_flow_api.g_varchar2_table(73) := '733A697D297D656C7365206F3D3D676F6F676C652E6D6170732E446972656374696F6E735374617475732E4E4F545F464F554E443F746869732E5F73686F774D65737361676528746869732E6F7074696F6E732E646972656374696F6E734E6F74466F75';
wwv_flow_api.g_varchar2_table(74) := '6E64293A6F3D3D676F6F676C652E6D6170732E446972656374696F6E735374617475732E5A45524F5F524553554C54533F746869732E5F73686F774D65737361676528746869732E6F7074696F6E732E646972656374696F6E735A65726F526573756C74';
wwv_flow_api.g_varchar2_table(75) := '73293A617065782E64656275672822446972656374696F6E732072657175657374206661696C65643A20222B6F297D2C73686F77446972656374696F6E733A66756E6374696F6E28652C6F2C743D2244524956494E4722297B617065782E646562756728';
wwv_flow_api.g_varchar2_table(76) := '227265706F72746D61702E73686F77446972656374696F6E7322293B76617220613D746869733B612E6F726967696E3D652C612E64657374696E6174696F6E3D6F2C612E5F686964654D65737361676528292C612E6F726967696E2626612E6465737469';
wwv_flow_api.g_varchar2_table(77) := '6E6174696F6E3F28612E646972656374696F6E73446973706C61797C7C28612E646972656374696F6E73446973706C61793D6E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265722C612E646972656374696F6E73536572';
wwv_flow_api.g_varchar2_table(78) := '766963653D6E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963652C612E646972656374696F6E73446973706C61792E7365744D617028612E6D617029292C612E6F726967696E3D612E70617273654C61744C6E6728612E6F';
wwv_flow_api.g_varchar2_table(79) := '726967696E297C7C612E6F726967696E2C612E64657374696E6174696F6E3D612E70617273654C61744C6E6728612E64657374696E6174696F6E297C7C612E64657374696E6174696F6E2C2222213D3D612E6F726967696E26262222213D3D612E646573';
wwv_flow_api.g_varchar2_table(80) := '74696E6174696F6E3F612E646972656374696F6E73536572766963652E726F757465287B6F726967696E3A612E6F726967696E2C64657374696E6174696F6E3A612E64657374696E6174696F6E2C74726176656C4D6F64653A676F6F676C652E6D617073';
wwv_flow_api.g_varchar2_table(81) := '2E54726176656C4D6F64655B745D7D2C66756E6374696F6E28652C6F297B612E5F646972656374696F6E73526573706F6E736528652C6F297D293A617065782E646562756728224E6F20646972656374696F6E7320746F2073686F77202D206E65656420';
wwv_flow_api.g_varchar2_table(82) := '626F7468206F726967696E20616E642064657374696E6174696F6E206C6F636174696F6E2229293A617065782E64656275672822556E61626C6520746F2073686F7720646972656374696F6E733A206E6F20646174612C206E6F206F726967696E2F6465';
wwv_flow_api.g_varchar2_table(83) := '7374696E6174696F6E22297D2C5F646972656374696F6E733A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F646972656374696F6E7322293B76617220653D746869733B696628652E6D6170646174612969662861';
wwv_flow_api.g_varchar2_table(84) := '7065782E64656275672822726F75746520222B652E6D6170646174612E6C656E6774682B2220776179706F696E747322292C652E6D6170646174612E6C656E6774683E31297B766172206F2C743B652E646972656374696F6E73446973706C61797C7C28';
wwv_flow_api.g_varchar2_table(85) := '652E646972656374696F6E73446973706C61793D6E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265722C652E646972656374696F6E73536572766963653D6E657720676F6F676C652E6D6170732E446972656374696F6E';
wwv_flow_api.g_varchar2_table(86) := '73536572766963652C652E646972656374696F6E73446973706C61792E7365744D617028652E6D617029293B666F722876617220612C693D5B5D2C6E3D303B6E3C652E6D6170646174612E6C656E6774683B6E2B2B29613D6E657720676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(87) := '6170732E4C61744C6E6728652E6D6170646174615B6E5D2E782C652E6D6170646174615B6E5D2E79292C303D3D6E3F6F3D613A6E3D3D652E6D6170646174612E6C656E6774682D313F743D613A692E70757368287B6C6F636174696F6E3A612C73746F70';
wwv_flow_api.g_varchar2_table(88) := '6F7665723A21307D293B617065782E646562756728226F726967696E3D222B6F2B2220646573743D222B742B2220776179706F696E74733A222B692E6C656E6774682B22207669613A222B652E6F7074696F6E732E74726176656C4D6F6465292C652E64';
wwv_flow_api.g_varchar2_table(89) := '6972656374696F6E73536572766963652E726F757465287B6F726967696E3A6F2C64657374696E6174696F6E3A742C776179706F696E74733A692C6F7074696D697A65576179706F696E74733A652E6F7074696F6E732E6F7074696D697A65576179706F';
wwv_flow_api.g_varchar2_table(90) := '696E74732C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B652E6F7074696F6E732E74726176656C4D6F64655D7D2C66756E6374696F6E286F2C74297B652E5F646972656374696F6E73526573706F6E7365286F2C';
wwv_flow_api.g_varchar2_table(91) := '74297D297D656C736520617065782E646562756728226E6F7420656E6F75676820776179706F696E7473202D206E656564206174206C6561737420616E206F726967696E20616E6420612064657374696E6174696F6E20706F696E7422293B656C736520';
wwv_flow_api.g_varchar2_table(92) := '617065782E64656275672822556E61626C6520746F2073686F7720646972656374696F6E733A206E6F206461746122297D2C5F6372656174653A66756E6374696F6E28297B76617220653D746869733B617065782E646562756728227265706F72746D61';
wwv_flow_api.g_varchar2_table(93) := '702E5F63726561746520222B652E656C656D656E742E70726F70282269642229292C617065782E646562756728226F7074696F6E733A20222B4A534F4E2E737472696E6769667928652E6F7074696F6E7329293B766172206F3D77696E646F772E6C6F63';
wwv_flow_api.g_varchar2_table(94) := '6174696F6E2E6F726967696E2B77696E646F772E6C6F636174696F6E2E706174686E616D653B6F3D6F2E737562737472696E6728302C6F2E6C617374496E6465784F6628222F2229292C652E696D6167655072656669783D6F2B222F222B652E6F707469';
wwv_flow_api.g_varchar2_table(95) := '6F6E732E706C7567696E46696C655072656669782B22696D616765732F6D222C617065782E646562756728275F746869732E696D6167655072656669783D22272B652E696D6167655072656669782B272227293B76617220743D7B6D696E5A6F6F6D3A65';
wwv_flow_api.g_varchar2_table(96) := '2E6F7074696F6E732E6D696E5A6F6F6D2C6D61785A6F6F6D3A652E6F7074696F6E732E6D61785A6F6F6D2C7A6F6F6D3A652E6F7074696F6E732E696E697469616C5A6F6F6D2C63656E7465723A652E6F7074696F6E732E696E697469616C43656E746572';
wwv_flow_api.g_varchar2_table(97) := '2C6D61705479706549643A652E6F7074696F6E732E6D6170547970652C647261676761626C653A652E6F7074696F6E732E616C6C6F7750616E2C7A6F6F6D436F6E74726F6C3A652E6F7074696F6E732E616C6C6F775A6F6F6D2C7363726F6C6C77686565';
wwv_flow_api.g_varchar2_table(98) := '6C3A652E6F7074696F6E732E616C6C6F775A6F6F6D2C64697361626C65446F75626C65436C69636B5A6F6F6D3A21652E6F7074696F6E732E616C6C6F775A6F6F6D2C6765737475726548616E646C696E673A652E6F7074696F6E732E6765737475726548';
wwv_flow_api.g_varchar2_table(99) := '616E646C696E677D3B652E6F7074696F6E732E6D61705374796C65262628742E7374796C65733D652E6F7074696F6E732E6D61705374796C65292C652E6D61703D6E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C65';
wwv_flow_api.g_varchar2_table(100) := '6D656E744279496428652E656C656D656E742E70726F70282269642229292C74292C652E6F7074696F6E732E736F757468776573742626652E6F7074696F6E732E6E6F727468656173742626652E6D61702E666974426F756E6473286E657720676F6F67';
wwv_flow_api.g_varchar2_table(101) := '6C652E6D6170732E4C61744C6E67426F756E647328652E6F7074696F6E732E736F757468776573742C652E6F7074696F6E732E6E6F7274686561737429292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C22';
wwv_flow_api.g_varchar2_table(102) := '636C69636B222C66756E6374696F6E286F297B76617220743D6F2E6C61744C6E672E6C617428292C613D6F2E6C61744C6E672E6C6E6728293B617065782E646562756728226D617020636C69636B656420222B742B222C222B61292C652E6F7074696F6E';
wwv_flow_api.g_varchar2_table(103) := '732E636C69636B5A6F6F6D4C6576656C262628617065782E6465627567282270616E2B7A6F6F6D22292C652E6F7074696F6E732E70616E4F6E436C69636B2626652E6D61702E70616E546F286F2E6C61744C6E67292C652E6D61702E7365745A6F6F6D28';
wwv_flow_api.g_varchar2_table(104) := '652E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170636C69636B222C7B6D61703A652E6D61702C6C61743A742C6C';
wwv_flow_api.g_varchar2_table(105) := '6E673A617D297D292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61706C6F61646564222C7B6D61703A652E6D61707D292C652E6F7074696F6E732E657870656374446174612626';
wwv_flow_api.g_varchar2_table(106) := '652E7265667265736828292C617065782E646562756728227265706F72746D61702E696E69742066696E697368656422297D2C726566726573683A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E7265667265736822';
wwv_flow_api.g_varchar2_table(107) := '293B76617220653D746869733B652E5F686964654D65737361676528292C652E6F7074696F6E732E65787065637444617461262628617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226170';
wwv_flow_api.g_varchar2_table(108) := '65786265666F72657265667265736822292C617065782E7365727665722E706C7567696E28652E6F7074696F6E732E616A61784964656E7469666965722C7B706167654974656D733A652E6F7074696F6E732E616A61784974656D737D2C7B6461746154';
wwv_flow_api.g_varchar2_table(109) := '7970653A226A736F6E222C737563636573733A66756E6374696F6E286F297B617065782E64656275672822737563636573732070446174613D222B6F2E736F757468776573742E6C61742B222C222B6F2E736F757468776573742E6C6E672B2220222B6F';
wwv_flow_api.g_varchar2_table(110) := '2E6E6F727468656173742E6C61742B222C222B6F2E6E6F727468656173742E6C6E67292C6F2E736F757468776573742E6C617426266F2E736F757468776573742E6C6E6726266F2E6E6F727468656173742E6C617426266F2E6E6F727468656173742E6C';
wwv_flow_api.g_varchar2_table(111) := '6E672626652E6D61702E666974426F756E6473287B736F7574683A6F2E736F757468776573742E6C61742C776573743A6F2E736F757468776573742E6C6E672C6E6F7274683A6F2E6E6F727468656173742E6C61742C656173743A6F2E6E6F7274686561';
wwv_flow_api.g_varchar2_table(112) := '73742E6C6E677D292C652E69772626652E69772E636C6F736528292C652E5F72656D6F766550696E7328292C617065782E6465627567282270446174612E6D6170646174612E6C656E6774683D222B6F2E6D6170646174612E6C656E677468292C652E6D';
wwv_flow_api.g_varchar2_table(113) := '6170646174613D6F2E6D6170646174612C652E6D6170646174612626652E5F73686F774461746128292C22646972656374696F6E73223D3D652E6F7074696F6E732E76697375616C69736174696F6E2626652E5F646972656374696F6E7328292C617065';
wwv_flow_api.g_varchar2_table(114) := '782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226170657861667465727265667265736822297D7D29292C617065782E646562756728227265706F72746D61702E726566726573682066696E6973';
wwv_flow_api.g_varchar2_table(115) := '68656422292C652E5F7472696767657228226368616E676522297D2C5F64657374726F793A66756E6374696F6E28297B746869732E686561746D61704C617965722626746869732E686561746D61704C617965722E72656D6F766528292C746869732E69';
wwv_flow_api.g_varchar2_table(116) := '772626746869732E69772E636C6F736528292C746869732E5F72656D6F766550696E7328292C746869732E6D61702E72656D6F766528297D2C5F7365744F7074696F6E733A66756E6374696F6E28297B746869732E5F73757065724170706C7928617267';
wwv_flow_api.g_varchar2_table(117) := '756D656E7473292C746869732E7265667265736828297D2C5F7365744F7074696F6E3A66756E6374696F6E28652C6F297B746869732E5F737570657228652C6F297D7D297D293B';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(33415861613131570)
,p_plugin_id=>wwv_flow_api.id(33032154349766695)
,p_file_name=>'jk64reportmap_r1.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false), p_is_component_import => true);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
