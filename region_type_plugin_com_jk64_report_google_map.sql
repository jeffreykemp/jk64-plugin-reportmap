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
prompt --application/shared_components/plugins/region_type/com_jk64_report_google_map
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(727724993790194482)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP'
,p_display_name=>'JK64 Report Google Map'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'#PLUGIN_FILES#jk64reportmap#MIN#.js'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- jk64 ReportMap v1.0 Jul 2019',
'',
'g_num_format    constant varchar2(100) := ''99999999999999.999999999999999999999999999999'';',
'g_tochar_format constant varchar2(100) := ''fm99999999999990.099999999999999999999999999999'';',
'',
'procedure set_map_extents',
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
'end set_map_extents;',
'',
'function latlng2ch (lat in number, lng in number) return varchar2 is',
'begin',
'  return ''"lat":''',
'      || to_char(lat, g_tochar_format)',
'      || '',"lng":''',
'      || to_char(lng, g_tochar_format);',
'end latlng2ch;',
'',
'function get_markers',
'    (p_region     in apex_plugin.t_region',
'    ,p_lat_min    in out number',
'    ,p_lat_max    in out number',
'    ,p_lng_min    in out number',
'    ,p_lng_max    in out number',
'    ) return apex_application_global.vc_arr2 is',
'    ',
'    l_data           apex_application_global.vc_arr2;',
'    l_lat            number;',
'    l_lng            number;',
'    l_info           varchar2(4000);',
'    l_icon           varchar2(4000);',
'    l_marker_label   varchar2(1);',
'     ',
'    l_column_value_list  apex_plugin_util.t_column_value_list;',
'',
'begin',
'',
'/* Column list is as follows:',
'',
'   lat,  - required',
'   lng,  - required',
'   name, - required',
'   id,   - required',
'   info, - optional',
'   icon, - optional',
'   label - optional',
'',
'*/',
'',
'    l_column_value_list := apex_plugin_util.get_data',
'        (p_sql_statement  => p_region.source',
'        ,p_min_columns    => 4',
'        ,p_max_columns    => 7',
'        ,p_component_name => p_region.name',
'        ,p_max_rows       => p_region.fetched_rows);',
'    ',
'    for i in 1..l_column_value_list(1).count loop',
'    ',
'        if not l_column_value_list.exists(1)',
'        or not l_column_value_list.exists(2)',
'        or not l_column_value_list.exists(3)',
'        or not l_column_value_list.exists(4) then',
'            raise_application_error(-20000, ''Report Map Query must have at least 4 columns (lat, lng, name, id)'');',
'        end if;',
'  ',
'        l_lat  := to_number(l_column_value_list(1)(i),g_num_format);',
'        l_lng  := to_number(l_column_value_list(2)(i),g_num_format);',
'        ',
'        -- default values if not supplied in query',
'        l_info         := null;',
'        l_icon         := null;',
'        l_marker_label := null;',
'        ',
'        if l_column_value_list.exists(5) then',
'          l_info := l_column_value_list(5)(i);',
'          if l_column_value_list.exists(6) then',
'            l_icon := l_column_value_list(6)(i);',
'            if l_column_value_list.exists(7) then',
'              l_marker_label := substr(l_column_value_list(7)(i),1,1);',
'            end if;',
'          end if;',
'        end if;',
'		',
'        l_data(nvl(l_data.last,0)+1) :=',
'               ''{"id":''  || apex_escape.js_literal(l_column_value_list(4)(i),''"'')',
'            || '',"name":''|| apex_escape.js_literal(l_column_value_list(3)(i),''"'')',
'            || '',''       || latlng2ch(l_lat,l_lng)',
'            || case when l_info is not null then',
'               '',"info":''|| apex_escape.js_literal(l_info,''"'')',
'               end',
'            || '',"icon":''|| apex_escape.js_literal(l_icon,''"'')',
'            || '',"label":''|| apex_escape.js_literal(l_marker_label,''"'') ',
'            || ''}'';',
'    ',
'        set_map_extents',
'            (p_lat     => l_lat',
'            ,p_lng     => l_lng',
'            ,p_lat_min => p_lat_min',
'            ,p_lat_max => p_lat_max',
'            ,p_lng_min => p_lng_min',
'            ,p_lng_max => p_lng_max',
'            );',
'      ',
'    end loop;',
'',
'    return l_data;',
'end get_markers;',
'',
'procedure htp_arr (arr in apex_application_global.vc_arr2) is',
'begin',
'    for i in 1..arr.count loop',
'        -- use prn to avoid loading a whole lot of unnecessary \n characters',
'        sys.htp.prn(case when i > 1 then '','' end || arr(i));',
'    end loop;',
'end htp_arr;',
'',
'function render',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ,p_is_printer_friendly in boolean',
'    ) return apex_plugin.t_region_render_result is',
'',
'    subtype plugin_attr is varchar2(32767);',
'    ',
'    l_result       apex_plugin.t_region_render_result;',
'',
'    l_lat          number;',
'    l_lng          number;',
'    l_region       varchar2(100);',
'    l_script       varchar2(32767);',
'    l_data         apex_application_global.vc_arr2;',
'    l_lat_min      number;',
'    l_lat_max      number;',
'    l_lng_min      number;',
'    l_lng_max      number;',
'    l_zoom_enabled varchar2(10) := ''true'';',
'    l_pan_enabled  varchar2(10) := ''true'';',
'',
'    -- Plugin attributes (application level)',
'    l_api_key           plugin_attr := p_plugin.attribute_01;',
'',
'    -- Component attributes',
'    l_map_height        plugin_attr := p_region.attribute_01;',
'    l_click_zoom        plugin_attr := p_region.attribute_03;',
'    l_latlong           plugin_attr := p_region.attribute_06;',
'    l_pan_on_click      plugin_attr := p_region.attribute_08;',
'    l_country           plugin_attr := p_region.attribute_10;',
'    l_mapstyle          plugin_attr := p_region.attribute_11;',
'    l_directions        plugin_attr := p_region.attribute_15;',
'    l_origin_item       plugin_attr := p_region.attribute_16;',
'    l_dest_item         plugin_attr := p_region.attribute_17;',
'    l_optimizewaypoints plugin_attr := p_region.attribute_21;',
'    l_maptype           plugin_attr := p_region.attribute_22;',
'    l_zoom_expr         plugin_attr := p_region.attribute_23;',
'    l_pan_expr          plugin_attr := p_region.attribute_24;',
'    l_gesture_handling  plugin_attr := p_region.attribute_25;',
'    ',
'begin',
'    -- debug information will be included',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region',
'            (p_plugin => p_plugin',
'            ,p_region => p_region',
'            ,p_is_printer_friendly => p_is_printer_friendly);',
'    end if;',
'    ',
'    if l_zoom_expr is not null then',
'        l_zoom_enabled := apex_plugin_util.get_plsql_expression_result (',
'               ''case when (''',
'            || l_zoom_expr',
'            || '') then ''''true'''' else ''''false'''' end'');',
'        if l_zoom_enabled not in (''true'',''false'') then',
'            raise_application_error(-20000, ''Zoom attribute must evaluate to true or false.'');',
'        end if;',
'    end if;',
'',
'    if l_pan_expr is not null then',
'        l_pan_enabled := apex_plugin_util.get_plsql_expression_result (',
'               ''case when (''',
'            || l_pan_expr',
'            || '') then ''''true'''' else ''''false'''' end'');',
'        if l_pan_enabled not in (''true'',''false'') then',
'            raise_application_error(-20000, ''Pan attribute must evaluate to true or false.'');',
'        end if;',
'    end if;',
'',
'    apex_javascript.add_library',
'        (p_name           => ''js?key='' || l_api_key',
'        ,p_directory      => ''https://maps.googleapis.com/maps/api/''',
'        ,p_skip_extension => true);',
'',
'    l_region := case',
'                when p_region.static_id is not null',
'                then p_region.static_id',
'                else ''R''||p_region.id',
'                end;',
'    ',
'    if p_region.source is not null then',
'',
'        l_data := get_markers',
'            (p_region     => p_region',
'            ,p_lat_min    => l_lat_min',
'            ,p_lat_max    => l_lat_max',
'            ,p_lng_min    => l_lng_min',
'            ,p_lng_max    => l_lng_max',
'            );',
'        ',
'    end if;',
'    ',
'    if l_latlong is not null then',
'        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,'','')-1),g_num_format);',
'        l_lng := to_number(substr(l_latlong,instr(l_latlong,'','')+1),g_num_format);',
'    end if;',
'    ',
'    if l_lat is not null and l_data.count > 0 then',
'',
'        set_map_extents',
'            (p_lat     => l_lat',
'            ,p_lng     => l_lng',
'            ,p_lat_min => l_lat_min',
'            ,p_lat_max => l_lat_max',
'            ,p_lng_min => l_lng_min',
'            ,p_lng_max => l_lng_max',
'            );',
'',
'    elsif l_data.count = 0 and l_lat is not null then',
'',
'        l_lat_min := greatest(l_lat - 10, -80);',
'        l_lat_max := least(l_lat + 10, 80);',
'        l_lng_min := greatest(l_lng - 10, -180);',
'        l_lng_max := least(l_lng + 10, 180);',
'',
'    -- show entire map if no points to show',
'    elsif l_data.count = 0 then',
'',
'        l_latlong := ''0,0'';',
'        l_lat_min := -90;',
'        l_lat_max := 90;',
'        l_lng_min := -180;',
'        l_lng_max := 180;',
'',
'    end if;',
'        ',
'    l_script := ''<script>',
'var opt_#REGION#=',
'{container:"map_#REGION#_container"',
',regionId:"#REGION#"',
',ajaxIdentifier:"'' || apex_plugin.get_ajax_identifier || ''"',
',ajaxItems:"'' || apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit) || ''"',
',maptype:"'' || lower(l_maptype) || ''"',
',latlng:"'' || l_latlong || ''"',
',markerZoom:'' || nvl(l_click_zoom,''null'') || ''',
',markerPan:'' || case l_pan_on_click when ''N'' then ''false'' else ''true'' end || ''',
',country:"'' || l_country || ''"',
',southwest:{'' || latlng2ch(l_lat_min,l_lng_min) || ''}',
',northeast:{'' || latlng2ch(l_lat_max,l_lng_max) || ''}''',
'||   case when l_mapstyle is not null then ''',
',mapstyle:'' || l_mapstyle',
'     end',
'|| ''',
',noDataMessage:"'' || p_region.no_data_found_message || ''"',
',expectData:'' || case when p_region.source is not null then ''true'' else ''false'' end ||',
'     case when l_directions is not null then ''',
',directions:"'' || l_directions || ''"',
',optimizeWaypoints:'' || case when l_optimizewaypoints=''Y'' then ''true'' else ''false'' end',
'     end',
'||   case when l_origin_item is not null then ''',
',originItem:"'' || l_origin_item || ''"''',
'     end',
'||   case when l_dest_item is not null then ''',
',destItem:"'' || l_dest_item || ''"''',
'     end || ''',
',zoom:'' || l_zoom_enabled || ''',
',pan:'' || l_pan_enabled || ''',
',gestureHandling:"'' || nvl(l_gesture_handling,''auto'') || ''"',
'};',
'function click_#REGION#(id){reportmap.click(opt_#REGION#,id);}',
'function getAddress_#REGION#(lat,lng){reportmap.getAddress(opt_#REGION#,lat,lng);}',
'function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}',
'r_#REGION#(function(){',
'opt_#REGION#.mapdata = ['';',
'--note: the "function click_#REGION#" is only kept for backwards compatibility, normally apps can just call routines',
'--      such as reportmap.gotoAddress directly.',
'',
'    sys.htp.p(replace(l_script,''#REGION#'',l_region));',
'    ',
'    htp_arr(l_data);',
'',
'    l_script := ''];',
'reportmap.init(opt_#REGION#);',
'apex.jQuery("##REGION#").bind("apexrefresh", function(){reportmap.refresh(opt_#REGION#);});',
'});</script>',
'<div id="map_#REGION#_container" style="min-height:'' || l_map_height || ''px"></div>'';',
'',
'    sys.htp.p(replace(l_script,''#REGION#'',l_region));',
'  ',
'    return l_result;',
'end render;',
'',
'function ajax',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ) return apex_plugin.t_region_ajax_result is',
'',
'    subtype plugin_attr is varchar2(32767);',
'',
'    l_result apex_plugin.t_region_ajax_result;',
'',
'    l_lat          number;',
'    l_lng          number;',
'    l_data         apex_application_global.vc_arr2;',
'    l_lat_min      number;',
'    l_lat_max      number;',
'    l_lng_min      number;',
'    l_lng_max      number;',
'',
'    -- Component attributes',
'    l_latlong      plugin_attr := p_region.attribute_06;',
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
'            (p_region     => p_region',
'            ,p_lat_min    => l_lat_min',
'            ,p_lat_max    => l_lat_max',
'            ,p_lng_min    => l_lng_min',
'            ,p_lng_max    => l_lng_max',
'            );',
'        ',
'    end if;',
'        ',
'    if l_latlong is not null then',
'        l_lat := to_number(substr(l_latlong,1,instr(l_latlong,'','')-1),g_num_format);',
'        l_lng := to_number(substr(l_latlong,instr(l_latlong,'','')+1),g_num_format);',
'    end if;',
'    ',
'    if l_lat is not null and l_data.count > 0 then',
'        set_map_extents',
'            (p_lat     => l_lat',
'            ,p_lng     => l_lng',
'            ,p_lat_min => l_lat_min',
'            ,p_lat_max => l_lat_max',
'            ,p_lng_min => l_lng_min',
'            ,p_lng_max => l_lng_max',
'            );',
'',
'    elsif l_data.count = 0 and l_lat is not null then',
'        l_lat_min := greatest(l_lat - 10, -180);',
'        l_lat_max := least(l_lat + 10, 80);',
'        l_lng_min := greatest(l_lng - 10, -180);',
'        l_lng_max := least(l_lng + 10, 180);',
'',
'    -- show entire map if no points to show',
'    elsif l_data.count = 0 then',
'        l_lat_min := -90;',
'        l_lat_max := 90;',
'        l_lng_min := -180;',
'        l_lng_max := 180;',
'',
'    end if;',
'',
'    sys.owa_util.mime_header(''text/plain'', false);',
'    sys.htp.p(''Cache-Control: no-cache'');',
'    sys.htp.p(''Pragma: no-cache'');',
'    sys.owa_util.http_header_close;',
'',
'    apex_debug.message(''l_lat_min=''||l_lat_min||'' data=''||l_data.count);',
'    ',
'    sys.htp.p(',
'           ''{"southwest":{''',
'        || latlng2ch(l_lat_min,l_lng_min)',
'        || ''},"northeast":{''',
'        || latlng2ch(l_lat_max,l_lng_max)',
'        || ''},"mapdata":['');',
'',
'    htp_arr(l_data);',
'',
'    sys.htp.p('']}'');',
'',
'    apex_debug.message(''ajax finished'');',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        sys.htp.p(''{"error":"''||sqlerrm||''"}'');',
'end ajax;',
''))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT:FETCHED_ROWS:NO_DATA_FOUND_MESSAGE'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id (returned to an item you specify, if required), and Info.',
'<p>',
'<strong>Don''t forget to set <em>Number of Rows</em> to a larger number than the default, this is the maximum number of records the report will fetch from your query.</strong>',
'<p>',
'Refer to the wiki for documentation and examples:',
'<p>',
'<strong><a href="https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki" target=_blank>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki</a></strong>'))
,p_version_identifier=>'1.0'
,p_about_url=>'https://github.com/jeffreykemp/jk64-plugin-reportmap'
,p_files_version=>98
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(584339936190849504)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
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
 p_id=>wwv_flow_api.id(727725786003202006)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Min. Map Height'
,p_attribute_type=>'NUMBER'
,p_is_required=>true
,p_default_value=>'400'
,p_unit=>'pixels'
,p_is_translatable=>false
,p_help_text=>'Desired height (in pixels) of the map region. Note: the width will adjust according to the available area of the containing window.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(727726468047210752)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Zoom Level on Click'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_default_value=>'13'
,p_unit=>'(0-23)'
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, or adds a new marker, zoom the map to this level. Set to blank to not zoom on click.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(732820826898447698)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Initial Map Position'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_unit=>'lat,long'
,p_is_translatable=>false
,p_help_text=>'Set the latitude and longitude as a pair of numbers to be used to position the map on page load, if no pin coordinates have been provided by the page item.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169085740658866881)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Pan on click'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'If set on, when the user clicks on a pin the map will pan so the pin will be visible. Set off to stop this behaviour. NOTE: if you switch this off, you will almost certainly want to clear out Zoom Level on Click - otherwise when the user clicks a pin'
||' the map will zoom but not pan.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(584351872403748090)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>10
,p_max_length=>40
,p_is_translatable=>false
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'NOT_NULL'
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to 2-character country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country. You can set this to a subst'
||'ition variable (e.g. &P1_COUNTRY.) but note that this will only apply if the page is refreshed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(433843752009760657)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Map Style'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>false
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
 p_id=>wwv_flow_api.id(440447910310706885)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>15
,p_display_sequence=>150
,p_prompt=>'Directions'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_null_text=>'(none)'
,p_help_text=>'Show travel directions. The locations can be simple - between two locations according to two items on the page - or via the route indicated by waypoints from the report query. Google API Key required.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142722350940095898)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>10
,p_display_value=>'Driving (route)'
,p_return_value=>'DRIVING-ROUTE'
,p_help_text=>'Get driving directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142729937917102025)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>20
,p_display_value=>'Walking (route)'
,p_return_value=>'WALKING-ROUTE'
,p_help_text=>'Get walking directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142730320440103434)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>30
,p_display_value=>'Bicycling (route)'
,p_return_value=>'BICYCLING-ROUTE'
,p_help_text=>'Get bicycling directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142730705638105048)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>40
,p_display_value=>'Transit (route)'
,p_return_value=>'TRANSIT-ROUTE'
,p_help_text=>'Get public transit directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(440450259607708234)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>50
,p_display_value=>'Driving (simple)'
,p_return_value=>'DRIVING'
,p_is_quick_pick=>true
,p_help_text=>'Get driving directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(440450652218709008)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>60
,p_display_value=>'Walking (simple)'
,p_return_value=>'WALKING'
,p_help_text=>'Get walking directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(440451023110710177)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>70
,p_display_value=>'Bicycling (simple)'
,p_return_value=>'BICYCLING'
,p_help_text=>'Get bicycling directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(440451421865711255)
,p_plugin_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_display_sequence=>80
,p_display_value=>'Transit (simple)'
,p_return_value=>'TRANSIT'
,p_is_quick_pick=>true
,p_help_text=>'Get public transit directions between two locations.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(440454067912736990)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>16
,p_display_sequence=>160
,p_prompt=>'Directions Origin Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING,WALKING,BICYCLING,TRANSIT'
,p_help_text=>'Item that describes the origin location for directions. May be expressed as a lat,lng pair or as an address or place name.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(440456300290741328)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>17
,p_display_sequence=>170
,p_prompt=>'Directions Destination Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING,WALKING,BICYCLING,TRANSIT'
,p_help_text=>'Item that describes the destination location for directions. May be expressed as a lat,lng pair or as an address or place name.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(142769110818434038)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
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
,p_depending_on_attribute_id=>wwv_flow_api.id(440447910310706885)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING-ROUTE,WALKING-ROUTE,BICYCLING-ROUTE,TRANSIT-ROUTE'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'If set to true, the Directions service will attempt to re-order the supplied intermediate waypoints to minimize overall cost of the route.',
'',
'Note: the first and last points supplied by the report query are always used as the starting and ending points for the journey.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(142780652824608766)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>22
,p_display_sequence=>220
,p_prompt=>'Default Map Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_is_common=>false
,p_default_value=>'ROADMAP'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Default map type to show on page load. The user may change the map type if they wish to show a different type.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142784508696610924)
,p_plugin_attribute_id=>wwv_flow_api.id(142780652824608766)
,p_display_sequence=>10
,p_display_value=>'Roadmap'
,p_return_value=>'ROADMAP'
,p_is_quick_pick=>true
,p_help_text=>'(default) This map type displays a normal street map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142784863824612270)
,p_plugin_attribute_id=>wwv_flow_api.id(142780652824608766)
,p_display_sequence=>20
,p_display_value=>'Satellite'
,p_return_value=>'SATELLITE'
,p_help_text=>'This map type displays satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142785265632613635)
,p_plugin_attribute_id=>wwv_flow_api.id(142780652824608766)
,p_display_sequence=>30
,p_display_value=>'Hybrid'
,p_return_value=>'HYBRID'
,p_help_text=>'This map type displays a transparent layer of major streets on satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(142785743722614809)
,p_plugin_attribute_id=>wwv_flow_api.id(142780652824608766)
,p_display_sequence=>40
,p_display_value=>'Terrain'
,p_return_value=>'TERRAIN'
,p_help_text=>'This map type displays maps with physical features such as terrain and vegetation.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169065488845626414)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>23
,p_display_sequence=>230
,p_prompt=>'Zoom enabled'
,p_attribute_type=>'PLSQL EXPRESSION BOOLEAN'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<code>true</code>',
'<p>',
'<code>:P1_ITEM IS NOT NULL</code>'))
,p_help_text=>'If this evaluates to true, the Zoom controls will be enabled. If no expression is supplied, the default is true (enabled).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169069296750629599)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>24
,p_display_sequence=>240
,p_prompt=>'Pan enabled'
,p_attribute_type=>'PLSQL EXPRESSION BOOLEAN'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<code>true</code>',
'<p>',
'<code>:P1_ITEM IS NOT NULL</code>'))
,p_help_text=>'If this evaluates to true, the Pan controls will be enabled. If no expression is supplied, the default is true (enabled).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169073072816632490)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
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
 p_id=>wwv_flow_api.id(169076786148634381)
,p_plugin_attribute_id=>wwv_flow_api.id(169073072816632490)
,p_display_sequence=>10
,p_display_value=>'cooperative'
,p_return_value=>'cooperative'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
unistr('Scroll events and one-finger touch gestures scroll the page, and do not zoom or pan the map. Two-finger touch gestures pan and zoom the map. Scroll events with a ctrl key or \2318 key pressed zoom the map.'),
'In this mode the map cooperates with the page.'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169077180902635184)
,p_plugin_attribute_id=>wwv_flow_api.id(169073072816632490)
,p_display_sequence=>20
,p_display_value=>'greedy'
,p_return_value=>'greedy'
,p_help_text=>'All touch gestures and scroll events pan or zoom the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169077641062636041)
,p_plugin_attribute_id=>wwv_flow_api.id(169073072816632490)
,p_display_sequence=>30
,p_display_value=>'none'
,p_return_value=>'none'
,p_help_text=>'The map cannot be panned or zoomed by user gestures.'
);
end;
/
begin
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169077969935636835)
,p_plugin_attribute_id=>wwv_flow_api.id(169073072816632490)
,p_display_sequence=>40
,p_display_value=>'auto'
,p_return_value=>'auto'
,p_help_text=>'(default) Gesture handling is either cooperative or greedy, depending on whether the page is scrollable.'
);
wwv_flow_api.create_plugin_std_attribute(
 p_id=>wwv_flow_api.id(32106871809256143)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'SOURCE_SQL'
,p_is_required=>false
,p_sql_min_column_count=>4
,p_sql_max_column_count=>19
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
'<em>Population map (show circles instead of pins):</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       radius_km, ''#cc0000'' AS color, ''0.05'' as transparency',
'FROM mydata;',
'</pre>',
'</p><p>',
'<em>Marker labels:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       '''' as radius_km, '''' AS color, '''' as transparency, label as label',
'FROM mydata;',
'</pre>',
'</p><p>',
'<em>Up to 10 additional flex fields may be added:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon, '''' AS radius_km, '''' AS color, '''' as transparency,',
'       col1, col2, col3, ... col10',
'FROM mydata;',
'</pre>',
'The extra columns will be accessible from Dynamic Actions, e.g. <code>this.data.attr01</code>',
'</p>'))
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(358366640980426519)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'addressfound'
,p_display_name=>'addressFound'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(32110242951268829)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'directions'
,p_display_name=>'directions'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(440414414890416510)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'geolocate'
,p_display_name=>'geolocate'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(727725310362197765)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(584344552999219411)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(734441889640213881)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '766172207265706F72746D61703D7B70617273654C61744C6E673A66756E6374696F6E2865297B766172206F2C613B28617065782E646562756728227265706F72746D61702E70617273654C61744C6E6720222B65292C6E756C6C213D6529262628652E';
wwv_flow_api.g_varchar2_table(2) := '696E6465784F6628223B22293E2D313F613D652E73706C697428223B22293A652E696E6465784F6628222022293E2D313F613D652E73706C697428222022293A652E696E6465784F6628222C22293E2D31262628613D652E73706C697428222C2229292C';
wwv_flow_api.g_varchar2_table(3) := '612626323D3D612E6C656E6774683F28615B305D3D615B305D2E7265706C616365282F2C2F672C222E22292C615B315D3D615B315D2E7265706C616365282F2C2F672C222E22292C617065782E6465627567282270617273656420222B615B305D2B2220';
wwv_flow_api.g_varchar2_table(4) := '222B615B315D292C6F3D6E657720676F6F676C652E6D6170732E4C61744C6E67287061727365466C6F617428615B305D292C7061727365466C6F617428615B315D2929293A617065782E646562756728276E6F204C61744C6E6720666F756E6420696E20';
wwv_flow_api.g_varchar2_table(5) := '22272B652B27222729293B72657475726E206F7D2C676F746F416464726573733A66756E6374696F6E28652C6F297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E676F746F4164647265737322292C286E657720';
wwv_flow_api.g_varchar2_table(6) := '676F6F676C652E6D6170732E47656F636F646572292E67656F636F6465287B616464726573733A6F2C636F6D706F6E656E745265737472696374696F6E733A2222213D3D652E636F756E7472793F7B636F756E7472793A652E636F756E7472797D3A7B7D';
wwv_flow_api.g_varchar2_table(7) := '7D2C66756E6374696F6E286F2C61297B696628613D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B297B766172206E3D6F5B305D2E67656F6D657472792E6C6F636174696F6E3B617065782E646562756728652E72656769';
wwv_flow_api.g_varchar2_table(8) := '6F6E49642B222067656F636F6465206F6B22292C652E6D61726B657250616E262628652E6D61702E73657443656E746572286E292C652E6D61702E70616E546F286E29292C652E6D61726B65725A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6D';
wwv_flow_api.g_varchar2_table(9) := '61726B65725A6F6F6D292C7265706F72746D61702E7573657250696E28652C6E2E6C617428292C6E2E6C6E672829292C617065782E646562756728652E726567696F6E49642B222061646472657373666F756E642027222B6F5B305D2E666F726D617474';
wwv_flow_api.g_varchar2_table(10) := '65645F616464726573732B222722292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A652E6D61702C6C61743A6E2E6C617428292C6C6E673A6E2E6C6E6728';
wwv_flow_api.g_varchar2_table(11) := '292C726573756C743A6F5B305D7D297D656C736520617065782E646562756728652E726567696F6E49642B222067656F636F64652077617320756E7375636365737366756C20666F722074686520666F6C6C6F77696E6720726561736F6E3A20222B6129';
wwv_flow_api.g_varchar2_table(12) := '7D297D2C6D61726B6572636C69636B3A66756E6374696F6E28652C6F297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E6D61726B6572636C69636B22292C617065782E6A5175657279282223222B652E72656769';
wwv_flow_api.g_varchar2_table(13) := '6F6E4964292E7472696767657228226D61726B6572636C69636B222C7B6D61703A652E6D61702C69643A6F2E69642C6E616D653A6F2E6E616D652C6C61743A6F2E6C61742C6C6E673A6F2E6C6E677D297D2C72657050696E3A66756E6374696F6E28652C';
wwv_flow_api.g_varchar2_table(14) := '6F297B76617220613D6E657720676F6F676C652E6D6170732E4C61744C6E67286F2E6C61742C6F2E6C6E67292C6E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F6E3A612C7469746C653A6F2E';
wwv_flow_api.g_varchar2_table(15) := '6E616D652C69636F6E3A6F2E69636F6E2C6C6162656C3A6F2E6C6162656C7D293B676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286E2C22636C69636B222C66756E6374696F6E28297B617065782E646562756728652E726567';
wwv_flow_api.g_varchar2_table(16) := '696F6E49642B222072657050696E20636C69636B656420222B6F2E6964292C6F2E696E666F262628652E69773F652E69772E636C6F736528293A652E69773D6E657720676F6F676C652E6D6170732E496E666F57696E646F772C652E69772E7365744F70';
wwv_flow_api.g_varchar2_table(17) := '74696F6E73287B636F6E74656E743A6F2E696E666F7D292C652E69772E6F70656E28652E6D61702C7468697329292C652E6D61726B657250616E2626652E6D61702E70616E546F28746869732E676574506F736974696F6E2829292C652E6D61726B6572';
wwv_flow_api.g_varchar2_table(18) := '5A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D292C7265706F72746D61702E6D61726B6572636C69636B28652C6F297D292C652E72657070696E7C7C28652E72657070696E3D5B5D292C652E72657070696E2E70757368';
wwv_flow_api.g_varchar2_table(19) := '287B69643A6F2E69642C6D61726B65723A6E7D297D2C72657050696E733A66756E6374696F6E2865297B696628617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E72657050696E7322292C652E6D6170646174612E6C';
wwv_flow_api.g_varchar2_table(20) := '656E6774683E30297B652E696E666F4E6F44617461466F756E64262628617065782E646562756728652E726567696F6E49642B222068696465204E6F204461746120466F756E6420696E666F77696E646F7722292C652E696E666F4E6F44617461466F75';
wwv_flow_api.g_varchar2_table(21) := '6E642E636C6F73652829293B666F7228766172206F3D303B6F3C652E6D6170646174612E6C656E6774683B6F2B2B297265706F72746D61702E72657050696E28652C652E6D6170646174615B6F5D297D656C73652222213D3D652E6E6F446174614D6573';
wwv_flow_api.g_varchar2_table(22) := '73616765262628617065782E646562756728652E726567696F6E49642B222073686F77204E6F204461746120466F756E6420696E666F77696E646F7722292C652E696E666F4E6F44617461466F756E643F652E696E666F4E6F44617461466F756E642E63';
wwv_flow_api.g_varchar2_table(23) := '6C6F736528293A652E696E666F4E6F44617461466F756E643D6E657720676F6F676C652E6D6170732E496E666F57696E646F77287B636F6E74656E743A652E6E6F446174614D6573736167652C706F736974696F6E3A7265706F72746D61702E70617273';
wwv_flow_api.g_varchar2_table(24) := '654C61744C6E6728652E6C61746C6E67297D292C652E696E666F4E6F44617461466F756E642E6F70656E28652E6D617029297D2C636C69636B3A66756E6374696F6E28652C6F297B617065782E646562756728652E726567696F6E49642B22207265706F';
wwv_flow_api.g_varchar2_table(25) := '72746D61702E636C69636B22293B666F722876617220613D21312C6E3D303B6E3C652E72657070696E2E6C656E6774683B6E2B2B29696628652E72657070696E5B6E5D2E69643D3D6F297B6E657720676F6F676C652E6D6170732E6576656E742E747269';
wwv_flow_api.g_varchar2_table(26) := '6767657228652E72657070696E5B6E5D2E6D61726B65722C22636C69636B22292C613D21303B627265616B7D617C7C617065782E646562756728652E726567696F6E49642B22206964206E6F7420666F756E643A222B6F297D2C676F746F506F73427953';
wwv_flow_api.g_varchar2_table(27) := '7472696E673A66756E6374696F6E28652C6F297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E676F746F506F7322293B76617220613D70617273654C61744C6E67286F293B61262628617065782E646562756728';
wwv_flow_api.g_varchar2_table(28) := '652E726567696F6E49642B22206974656D206368616E67656420222B612E6C617428292B2220222B612E6C6E672829292C7265706F72746D61702E7573657250696E28652C612E6C617428292C612E6C6E67282929297D2C676F746F506F733A66756E63';
wwv_flow_api.g_varchar2_table(29) := '74696F6E28652C6F2C61297B696628617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E7573657250696E22292C6E756C6C213D3D6F26266E756C6C213D3D61297B766172206E3D652E7573657270696E3F652E757365';
wwv_flow_api.g_varchar2_table(30) := '7270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D6170732E4C61744C6E6728302C30293B6966286E26266F3D3D6E2E6C617428292626613D3D6E2E6C6E67282929617065782E646562756728652E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(31) := '7573657270696E206E6F74206368616E67656422293B656C73657B76617220723D6E657720676F6F676C652E6D6170732E4C61744C6E67286F2C61293B652E7573657270696E3F28617065782E646562756728652E726567696F6E49642B22206D6F7665';
wwv_flow_api.g_varchar2_table(32) := '206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B6F2B222C222B61292C652E7573657270696E2E7365744D617028652E6D6170292C652E7573657270696E2E736574506F736974696F6E287229293A2861';
wwv_flow_api.g_varchar2_table(33) := '7065782E646562756728652E726567696F6E49642B2220637265617465207573657270696E20222B6F2B222C222B61292C652E7573657270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F';
wwv_flow_api.g_varchar2_table(34) := '6E3A722C69636F6E3A652E69636F6E7D29297D7D656C736520652E7573657270696E262628617065782E646562756728652E726567696F6E49642B22206D6F7665206578697374696E672070696E206F666620746865206D617022292C652E7573657270';
wwv_flow_api.g_varchar2_table(35) := '696E2E7365744D6170286E756C6C292C652E64697374636972636C65262628617065782E646562756728652E726567696F6E49642B22206D6F76652064697374636972636C65206F666620746865206D617022292C652E64697374636972636C652E7365';
wwv_flow_api.g_varchar2_table(36) := '744D6170286E756C6C2929297D2C736561726368416464726573733A66756E6374696F6E28652C6F2C61297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E7365617263684164647265737322293B766172206E3D';
wwv_flow_api.g_varchar2_table(37) := '7B6C61743A6F2C6C6E673A617D3B286E657720676F6F676C652E6D6170732E47656F636F646572292E67656F636F6465287B6C6F636174696F6E3A6E7D2C66756E6374696F6E286E2C72297B696628723D3D3D676F6F676C652E6D6170732E47656F636F';
wwv_flow_api.g_varchar2_table(38) := '6465725374617475732E4F4B296966286E5B305D297B617065782E646562756728652E726567696F6E49642B222061646472657373666F756E642027222B6E5B305D2E666F726D61747465645F616464726573732B222722293B76617220743D6E5B305D';
wwv_flow_api.g_varchar2_table(39) := '2E616464726573735F636F6D706F6E656E74733B666F7228693D303B693C742E6C656E6774683B692B2B29617065782E646562756728652E726567696F6E49642B2220726573756C745B305D20222B745B695D2E74797065732B223D222B745B695D2E73';
wwv_flow_api.g_varchar2_table(40) := '686F72745F6E616D652B222028222B745B695D2E6C6F6E675F6E616D652B222922293B617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A652E6D61702C6C6174';
wwv_flow_api.g_varchar2_table(41) := '3A6F2C6C6E673A612C726573756C743A6E5B305D7D297D656C736520617065782E646562756728652E726567696F6E49642B2220736561726368416464726573733A204E6F20726573756C747320666F756E6422292C77696E646F772E616C6572742822';
wwv_flow_api.g_varchar2_table(42) := '4E6F20726573756C747320666F756E6422293B656C736520617065782E646562756728652E726567696F6E49642B222047656F636F646572206661696C65642064756520746F3A20222B72292C77696E646F772E616C657274282247656F636F64657220';
wwv_flow_api.g_varchar2_table(43) := '6661696C65642064756520746F3A20222B72297D297D2C67656F6C6F636174653A66756E6374696F6E2865297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E67656F6C6F6361746522292C6E6176696761746F72';
wwv_flow_api.g_varchar2_table(44) := '2E67656F6C6F636174696F6E3F28617065782E646562756728652E726567696F6E49642B222067656F6C6F6361746522292C6E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E28';
wwv_flow_api.g_varchar2_table(45) := '6F297B76617220613D7B6C61743A6F2E636F6F7264732E6C617469747564652C6C6E673A6F2E636F6F7264732E6C6F6E6769747564657D3B652E6D61702E70616E546F2861292C652E67656F6C6F636174655A6F6F6D2626652E6D61702E7365745A6F6F';
wwv_flow_api.g_varchar2_table(46) := '6D28652E67656F6C6F636174655A6F6F6D292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282267656F6C6F63617465222C7B6D61703A652E6D61702C6C61743A612E6C61742C6C6E673A612E6C6E677D297D';
wwv_flow_api.g_varchar2_table(47) := '29293A617065782E646562756728652E726567696F6E49642B222062726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22297D2C646972656374696F6E73726573703A66756E6374696F6E28652C6F2C61297B6966';
wwv_flow_api.g_varchar2_table(48) := '28617065782E646562756728612E726567696F6E49642B22207265706F72746D61702E646972656374696F6E737265737022292C6F3D3D676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B297B612E646972656374696F6E73';
wwv_flow_api.g_varchar2_table(49) := '446973706C61792E736574446972656374696F6E732865293B666F7228766172206E3D302C723D302C743D302C693D303B693C652E726F757465732E6C656E6774683B692B2B297B742B3D652E726F757465735B695D2E6C6567732E6C656E6774683B66';
wwv_flow_api.g_varchar2_table(50) := '6F722876617220703D303B703C652E726F757465735B695D2E6C6567732E6C656E6774683B702B2B297B76617220673D652E726F757465735B695D2E6C6567735B705D3B6E2B3D672E64697374616E63652E76616C75652C722B3D672E6475726174696F';
wwv_flow_api.g_varchar2_table(51) := '6E2E76616C75657D7D617065782E6A5175657279282223222B612E726567696F6E4964292E747269676765722822646972656374696F6E73222C7B6D61703A612E6D61702C64697374616E63653A6E2C6475726174696F6E3A722C6C6567733A747D297D';
wwv_flow_api.g_varchar2_table(52) := '656C736520617065782E646562756728612E726567696F6E49642B2220446972656374696F6E732072657175657374206661696C65642064756520746F20222B6F292C77696E646F772E616C6572742822446972656374696F6E73207265717565737420';
wwv_flow_api.g_varchar2_table(53) := '6661696C65642064756520746F20222B6F297D2C646972656374696F6E733A66756E6374696F6E2865297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E646972656374696F6E7320222B652E646972656374696F';
wwv_flow_api.g_varchar2_table(54) := '6E73293B766172206F2C612C6E2C723D652E646972656374696F6E732E696E6465784F6628222D524F55544522293B696628723C30296F3D247628652E6F726967696E4974656D292C613D247628652E646573744974656D292C6F3D7265706F72746D61';
wwv_flow_api.g_varchar2_table(55) := '702E70617273654C61744C6E67286F297C7C6F2C613D7265706F72746D61702E70617273654C61744C6E672861297C7C612C2222213D3D6F26262222213D3D612626286E3D652E646972656374696F6E732C652E646972656374696F6E73536572766963';
wwv_flow_api.g_varchar2_table(56) := '652E726F757465287B6F726967696E3A6F2C64657374696E6174696F6E3A612C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B6E5D7D2C66756E6374696F6E286F2C61297B7265706F72746D61702E646972656374';
wwv_flow_api.g_varchar2_table(57) := '696F6E7372657370286F2C612C65297D29293B656C73657B6E3D652E646972656374696F6E732E736C69636528302C72292C617065782E646562756728652E726567696F6E49642B2220726F7574652076696120222B6E2B22207769746820222B652E6D';
wwv_flow_api.g_varchar2_table(58) := '6170646174612E6C656E6774682B2220776179706F696E747322293B666F722876617220743D5B5D2C693D303B693C652E6D6170646174612E6C656E6774683B692B2B29303D3D693F6F3D6E657720676F6F676C652E6D6170732E4C61744C6E6728652E';
wwv_flow_api.g_varchar2_table(59) := '6D6170646174615B695D2E6C61742C652E6D6170646174615B695D2E6C6E67293A693D3D652E6D6170646174612E6C656E6774682D313F613D6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6D6170646174615B695D2E6C61742C652E6D';
wwv_flow_api.g_varchar2_table(60) := '6170646174615B695D2E6C6E67293A742E70757368287B6C6F636174696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6D6170646174615B695D2E6C61742C652E6D6170646174615B695D2E6C6E67292C73746F706F7665723A21';
wwv_flow_api.g_varchar2_table(61) := '307D293B617065782E646562756728652E726567696F6E49642B22206F726967696E3D222B6F292C617065782E646562756728652E726567696F6E49642B2220646573743D222B61292C617065782E646562756728652E726567696F6E49642B22207761';
wwv_flow_api.g_varchar2_table(62) := '79706F696E74733A222B742E6C656E677468292C652E646972656374696F6E73536572766963652E726F757465287B6F726967696E3A6F2C64657374696E6174696F6E3A612C776179706F696E74733A742C6F7074696D697A65576179706F696E74733A';
wwv_flow_api.g_varchar2_table(63) := '652E6F7074696D697A65576179706F696E74732C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B6E5D7D2C66756E6374696F6E286F2C61297B7265706F72746D61702E646972656374696F6E7372657370286F2C61';
wwv_flow_api.g_varchar2_table(64) := '2C65297D297D7D2C696E69743A66756E6374696F6E2865297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E696E697420222B652E6D617074797065293B766172206F3D7B7A6F6F6D3A312C63656E7465723A7265';
wwv_flow_api.g_varchar2_table(65) := '706F72746D61702E70617273654C61744C6E6728652E6C61746C6E67292C6D61705479706549643A652E6D6170747970657D3B652E6D61703D6E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E7442794964';
wwv_flow_api.g_varchar2_table(66) := '28652E636F6E7461696E6572292C6F292C652E6D61702E7365744F7074696F6E73287B647261676761626C653A652E70616E2C7A6F6F6D436F6E74726F6C3A652E7A6F6F6D2C7363726F6C6C776865656C3A652E7A6F6F6D2C64697361626C65446F7562';
wwv_flow_api.g_varchar2_table(67) := '6C65436C69636B5A6F6F6D3A21652E7A6F6F6D2C6765737475726548616E646C696E673A652E6765737475726548616E646C696E677D292C652E6D61707374796C652626652E6D61702E7365744F7074696F6E73287B7374796C65733A652E6D61707374';
wwv_flow_api.g_varchar2_table(68) := '796C657D292C652E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E647328652E736F757468776573742C652E6E6F7274686561737429292C652E6578706563744461746126267265706F72746D6170';
wwv_flow_api.g_varchar2_table(69) := '2E72657050696E732865292C652E646972656374696F6E73262628652E646972656374696F6E73446973706C61793D6E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265722C652E646972656374696F6E73536572766963';
wwv_flow_api.g_varchar2_table(70) := '653D6E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963652C652E646972656374696F6E73446973706C61792E7365744D617028652E6D6170292C7265706F72746D61702E646972656374696F6E732865292C652E64697265';
wwv_flow_api.g_varchar2_table(71) := '6374696F6E732E696E6465784F6628222D524F55544522293C3026262824282223222B652E6F726967696E4974656D292E6368616E67652866756E6374696F6E28297B7265706F72746D61702E646972656374696F6E732865297D292C24282223222B65';
wwv_flow_api.g_varchar2_table(72) := '2E646573744974656D292E6368616E67652866756E6374696F6E28297B7265706F72746D61702E646972656374696F6E732865297D2929292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C22636C69636B22';
wwv_flow_api.g_varchar2_table(73) := '2C66756E6374696F6E286F297B76617220613D6F2E6C61744C6E672E6C617428292C6E3D6F2E6C61744C6E672E6C6E6728293B617065782E646562756728652E726567696F6E49642B22206D617020636C69636B656420222B612B222C222B6E292C652E';
wwv_flow_api.g_varchar2_table(74) := '6D61726B65725A6F6F6D262628617065782E646562756728652E726567696F6E49642B222070616E2B7A6F6F6D22292C652E6D61726B657250616E2626652E6D61702E70616E546F286F2E6C61744C6E67292C652E6D61702E7365745A6F6F6D28652E6D';
wwv_flow_api.g_varchar2_table(75) := '61726B65725A6F6F6D29292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D6170636C69636B222C7B6D61703A652E6D61702C6C61743A612C6C6E673A6E7D297D292C617065782E646562756728652E72';
wwv_flow_api.g_varchar2_table(76) := '6567696F6E49642B22207265706F72746D61702E696E69742066696E697368656422292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D61706C6F61646564222C7B6D61703A652E6D61707D297D2C7265';
wwv_flow_api.g_varchar2_table(77) := '66726573683A66756E6374696F6E2865297B617065782E646562756728652E726567696F6E49642B22207265706F72746D61702E7265667265736822292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282261';
wwv_flow_api.g_varchar2_table(78) := '7065786265666F72657265667265736822292C617065782E7365727665722E706C7567696E28652E616A61784964656E7469666965722C7B706167654974656D733A652E616A61784974656D737D2C7B64617461547970653A226A736F6E222C73756363';
wwv_flow_api.g_varchar2_table(79) := '6573733A66756E6374696F6E286F297B696628617065782E646562756728652E726567696F6E49642B2220737563636573732070446174613D222B6F2E736F757468776573742E6C61742B222C222B6F2E736F757468776573742E6C6E672B2220222B6F';
wwv_flow_api.g_varchar2_table(80) := '2E6E6F727468656173742E6C61742B222C222B6F2E6E6F727468656173742E6C6E67292C652E6D61702E666974426F756E6473287B736F7574683A6F2E736F757468776573742E6C61742C776573743A6F2E736F757468776573742E6C6E672C6E6F7274';
wwv_flow_api.g_varchar2_table(81) := '683A6F2E6E6F727468656173742E6C61742C656173743A6F2E6E6F727468656173742E6C6E677D292C652E69772626652E69772E636C6F736528292C652E72657070696E297B617065782E646562756728652E726567696F6E49642B222072656D6F7665';
wwv_flow_api.g_varchar2_table(82) := '20616C6C207265706F72742070696E7322293B666F722876617220613D303B613C652E72657070696E2E6C656E6774683B612B2B29652E72657070696E5B615D2E6D61726B65722E7365744D6170286E756C6C293B652E72657070696E2E64656C657465';
wwv_flow_api.g_varchar2_table(83) := '7D617065782E646562756728652E726567696F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B6F2E6D6170646174612E6C656E677468292C652E6D6170646174613D6F2E6D6170646174612C652E657870656374446174612626';
wwv_flow_api.g_varchar2_table(84) := '7265706F72746D61702E72657050696E732865292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226170657861667465727265667265736822297D7D292C617065782E646562756728652E726567696F6E49';
wwv_flow_api.g_varchar2_table(85) := '642B22207265706F72746D61702E726566726573682066696E697368656422297D7D3B';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(32184985140595696)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_file_name=>'jk64reportmap.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '766172207265706F72746D6170203D207B0D0A2F2F6A6B3634205265706F72744D61702076312E30204A756C20323031390D0A0D0A2F2F72657475726E20676F6F676C65206D617073204C61744C6E67206261736564206F6E2070617273696E67207468';
wwv_flow_api.g_varchar2_table(2) := '6520676976656E20737472696E670D0A2F2F7468652064656C696D69746572206D6179206265206120737061636520282029206F7220612073656D69636F6C6F6E20283B29206F72206120636F6D6D6120282C292077697468206F6E6520657863657074';
wwv_flow_api.g_varchar2_table(3) := '696F6E3A0D0A2F2F69662074686520646563696D616C20706F696E7420697320696E64696361746564206279206120636F6D6D6120282C292074686520736570617261746F72206D757374206265206120737061636520282029206F722073656D69636F';
wwv_flow_api.g_varchar2_table(4) := '6C6F6E20283B290D0A2F2F652E672E3A0D0A2F2F202020202D31372E39363039203132322E323132320D0A2F2F202020202D31372E393630392C3132322E323132320D0A2F2F202020202D31372E393630393B3132322E323132320D0A2F2F202020202D';
wwv_flow_api.g_varchar2_table(5) := '31372C39363039203132322C323132320D0A2F2F202020202D31372C393630393B3132322C323132320D0A70617273654C61744C6E67203A2066756E6374696F6E20287629207B0D0A2020617065782E646562756728227265706F72746D61702E706172';
wwv_flow_api.g_varchar2_table(6) := '73654C61744C6E6720222B76293B0D0A202076617220706F733B0D0A2020696620287620213D3D206E756C6C202626207620213D3D20756E646566696E656429207B0D0A2020202020766172206172723B0D0A202020202069662028762E696E6465784F';
wwv_flow_api.g_varchar2_table(7) := '6628223B22293E2D3129207B0D0A20202020202020617272203D20762E73706C697428223B22293B0D0A20202020207D20656C73652069662028762E696E6465784F6628222022293E2D3129207B0D0A20202020202020617272203D20762E73706C6974';
wwv_flow_api.g_varchar2_table(8) := '28222022293B0D0A20202020207D20656C73652069662028762E696E6465784F6628222C22293E2D3129207B0D0A20202020202020617272203D20762E73706C697428222C22293B0D0A20202020207D0D0A202020202069662028617272202626206172';
wwv_flow_api.g_varchar2_table(9) := '722E6C656E6774683D3D3229207B0D0A202020202020202F2F636F6E7665727420746F2075736520706572696F6420282E2920666F7220646563696D616C20706F696E740D0A202020202020206172725B305D203D206172725B305D2E7265706C616365';
wwv_flow_api.g_varchar2_table(10) := '282F2C2F672C20222E22293B0D0A202020202020206172725B315D203D206172725B315D2E7265706C616365282F2C2F672C20222E22293B0D0A20202020202020617065782E6465627567282270617273656420222B6172725B305D2B2220222B617272';
wwv_flow_api.g_varchar2_table(11) := '5B315D293B0D0A20202020202020706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67287061727365466C6F6174286172725B305D292C7061727365466C6F6174286172725B315D29293B0D0A20202020207D20656C7365207B0D0A20';
wwv_flow_api.g_varchar2_table(12) := '202020202020617065782E646562756728276E6F204C61744C6E6720666F756E6420696E2022272B762B272227293B0D0A20202020207D0D0A20207D0D0A202072657475726E20706F733B0D0A7D2C0D0A0D0A2F2F73656172636820746865206D617020';
wwv_flow_api.g_varchar2_table(13) := '666F7220616E20616464726573733B20696620666F756E642C2070757420612070696E2061742074686174206C6F636174696F6E20616E642072616973652061646472657373666F756E6420747269676765720D0A676F746F41646472657373203A2066';
wwv_flow_api.g_varchar2_table(14) := '756E6374696F6E20286F70742C616464726573735465787429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E676F746F4164647265737322293B0D0A20207661722067656F636F646572203D206E';
wwv_flow_api.g_varchar2_table(15) := '657720676F6F676C652E6D6170732E47656F636F6465723B0D0A202067656F636F6465722E67656F636F6465280D0A202020207B616464726573733A2061646472657373546578740D0A202020202C636F6D706F6E656E745265737472696374696F6E73';
wwv_flow_api.g_varchar2_table(16) := '3A206F70742E636F756E747279213D3D22223F7B636F756E7472793A6F70742E636F756E7472797D3A7B7D0D0A20207D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A2020202069662028737461747573203D3D3D20676F';
wwv_flow_api.g_varchar2_table(17) := '6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A20202020202076617220706F73203D20726573756C74735B305D2E67656F6D657472792E6C6F636174696F6E3B0D0A202020202020617065782E6465627567286F70742E';
wwv_flow_api.g_varchar2_table(18) := '726567696F6E49642B222067656F636F6465206F6B22293B0D0A202020202020696620286F70742E6D61726B657250616E29207B0D0A20202020202020206F70742E6D61702E73657443656E74657228706F73293B0D0A20202020202020206F70742E6D';
wwv_flow_api.g_varchar2_table(19) := '61702E70616E546F28706F73293B0D0A2020202020207D0D0A202020202020696620286F70742E6D61726B65725A6F6F6D29207B0D0A20202020202020206F70742E6D61702E7365745A6F6F6D286F70742E6D61726B65725A6F6F6D293B0D0A20202020';
wwv_flow_api.g_varchar2_table(20) := '20207D0D0A2020202020207265706F72746D61702E7573657250696E286F70742C706F732E6C617428292C20706F732E6C6E672829293B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B222061646472657373666F756E';
wwv_flow_api.g_varchar2_table(21) := '642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A202020202020617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282261646472657373666F756E64222C';
wwv_flow_api.g_varchar2_table(22) := '207B0D0A20202020202020206D61703A6F70742E6D61702C0D0A20202020202020206C61743A706F732E6C617428292C0D0A20202020202020206C6E673A706F732E6C6E6728292C0D0A2020202020202020726573756C743A726573756C74735B305D0D';
wwv_flow_api.g_varchar2_table(23) := '0A2020202020207D293B0D0A202020207D20656C7365207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B222067656F636F64652077617320756E7375636365737366756C20666F722074686520666F6C6C6F77696E67';
wwv_flow_api.g_varchar2_table(24) := '20726561736F6E3A20222B737461747573293B0D0A202020207D0D0A20207D293B0D0A7D2C0D0A0D0A2F2F746869732069732063616C6C6564207768656E20746865207573657220636C69636B732061207265706F7274206D61726B65720D0A6D61726B';
wwv_flow_api.g_varchar2_table(25) := '6572636C69636B203A2066756E6374696F6E20286F70742C704461746129207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E6D61726B6572636C69636B22293B0D0A09617065782E6A517565727928';
wwv_flow_api.g_varchar2_table(26) := '2223222B6F70742E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C207B0D0A09096D61703A6F70742E6D61702C0D0A090969643A70446174612E69642C0D0A09096E616D653A70446174612E6E616D652C0D0A09096C61';
wwv_flow_api.g_varchar2_table(27) := '743A70446174612E6C61742C0D0A09096C6E673A70446174612E6C6E670D0A097D293B090D0A7D2C0D0A0D0A2F2F706C6163652061207265706F72742070696E206F6E20746865206D61700D0A72657050696E203A2066756E6374696F6E20286F70742C';
wwv_flow_api.g_varchar2_table(28) := '704461746129207B0D0A0976617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E672870446174612E6C61742C2070446174612E6C6E67293B0D0A20207661722072657070696E203D206E657720676F6F676C652E6D6170732E4D';
wwv_flow_api.g_varchar2_table(29) := '61726B6572287B0D0A2020202020202020206D61703A206F70742E6D61702C0D0A202020202020202020706F736974696F6E3A20706F732C0D0A2020202020202020207469746C653A2070446174612E6E616D652C0D0A20202020202020202069636F6E';
wwv_flow_api.g_varchar2_table(30) := '3A2070446174612E69636F6E2C0D0A2020202020202020206C6162656C3A2070446174612E6C6162656C202020202020202020202020202020202020202020202020202020202020202020202020202020200D0A2020202020202020207D293B0D0A2020';
wwv_flow_api.g_varchar2_table(31) := '676F6F676C652E6D6170732E6576656E742E6164644C697374656E65722872657070696E2C2022636C69636B222C2066756E6374696F6E202829207B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B222072657050696E2063';
wwv_flow_api.g_varchar2_table(32) := '6C69636B656420222B70446174612E6964293B0D0A202020206966202870446174612E696E666F29207B0D0A202020202020696620286F70742E697729207B0D0A20202020202020206F70742E69772E636C6F736528293B0D0A2020202020207D20656C';
wwv_flow_api.g_varchar2_table(33) := '7365207B0D0A20202020202020206F70742E6977203D206E657720676F6F676C652E6D6170732E496E666F57696E646F7728293B0D0A2020202020207D0D0A2020202020206F70742E69772E7365744F7074696F6E73287B0D0A20202020202020202063';
wwv_flow_api.g_varchar2_table(34) := '6F6E74656E743A2070446174612E696E666F0D0A20202020202020207D293B0D0A2020202020206F70742E69772E6F70656E286F70742E6D61702C2074686973293B0D0A202020207D0D0A20202020696620286F70742E6D61726B657250616E29207B0D';
wwv_flow_api.g_varchar2_table(35) := '0A2020202020206F70742E6D61702E70616E546F28746869732E676574506F736974696F6E2829293B0D0A202020207D0D0A20202020696620286F70742E6D61726B65725A6F6F6D29207B0D0A2020202020206F70742E6D61702E7365745A6F6F6D286F';
wwv_flow_api.g_varchar2_table(36) := '70742E6D61726B65725A6F6F6D293B0D0A202020207D0D0A202020207265706F72746D61702E6D61726B6572636C69636B286F70742C7044617461293B0D0A20207D293B0D0A202069662028216F70742E72657070696E29207B206F70742E7265707069';
wwv_flow_api.g_varchar2_table(37) := '6E3D5B5D3B207D0D0A20206F70742E72657070696E2E70757368287B226964223A70446174612E69642C226D61726B6572223A72657070696E7D293B0D0A7D2C0D0A0D0A2F2F70757420616C6C20746865207265706F72742070696E73206F6E20746865';
wwv_flow_api.g_varchar2_table(38) := '206D61702C206F722073686F772074686520226E6F206461746120666F756E6422206D6573736167650D0A72657050696E73203A2066756E6374696F6E20286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265';
wwv_flow_api.g_varchar2_table(39) := '706F72746D61702E72657050696E7322293B0D0A09696620286F70742E6D6170646174612E6C656E6774683E3029207B0D0A0909696620286F70742E696E666F4E6F44617461466F756E6429207B0D0A090909617065782E6465627567286F70742E7265';
wwv_flow_api.g_varchar2_table(40) := '67696F6E49642B222068696465204E6F204461746120466F756E6420696E666F77696E646F7722293B0D0A0909096F70742E696E666F4E6F44617461466F756E642E636C6F736528293B0D0A09097D0D0A0909666F7220287661722069203D20303B2069';
wwv_flow_api.g_varchar2_table(41) := '203C206F70742E6D6170646174612E6C656E6774683B20692B2B29207B0D0A0909097265706F72746D61702E72657050696E286F70742C6F70742E6D6170646174615B695D293B0D0A09097D0D0A097D20656C7365207B0D0A0909696620286F70742E6E';
wwv_flow_api.g_varchar2_table(42) := '6F446174614D65737361676520213D3D20222229207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222073686F77204E6F204461746120466F756E6420696E666F77696E646F7722293B0D0A090909696620286F70742E696E';
wwv_flow_api.g_varchar2_table(43) := '666F4E6F44617461466F756E6429207B0D0A090909096F70742E696E666F4E6F44617461466F756E642E636C6F736528293B0D0A0909097D20656C7365207B0D0A090909096F70742E696E666F4E6F44617461466F756E64203D206E657720676F6F676C';
wwv_flow_api.g_varchar2_table(44) := '652E6D6170732E496E666F57696E646F77280D0A09090909097B0D0A090909090909636F6E74656E743A206F70742E6E6F446174614D6573736167652C0D0A090909090909706F736974696F6E3A207265706F72746D61702E70617273654C61744C6E67';
wwv_flow_api.g_varchar2_table(45) := '286F70742E6C61746C6E67290D0A09090909097D293B0D0A0909097D0D0A0909096F70742E696E666F4E6F44617461466F756E642E6F70656E286F70742E6D6170293B0D0A09097D0D0A097D0D0A7D2C0D0A0D0A2F2F63616C6C207468697320746F2073';
wwv_flow_api.g_varchar2_table(46) := '696D756C6174652061206D6F75736520636C69636B206F6E20746865207265706F72742070696E20666F722074686520676976656E2069642076616C75650D0A2F2F652E672E20746869732077696C6C2073686F772074686520696E666F2077696E646F';
wwv_flow_api.g_varchar2_table(47) := '7720666F722074686520676976656E207265706F72742070696E20616E64207472696767657220746865206D61726B6572636C69636B206576656E740D0A636C69636B203A2066756E6374696F6E20286F70742C696429207B0D0A09617065782E646562';
wwv_flow_api.g_varchar2_table(48) := '7567286F70742E726567696F6E49642B22207265706F72746D61702E636C69636B22293B0D0A202076617220666F756E64203D2066616C73653B0D0A2020666F7220287661722069203D20303B2069203C206F70742E72657070696E2E6C656E6774683B';
wwv_flow_api.g_varchar2_table(49) := '20692B2B29207B0D0A20202020696620286F70742E72657070696E5B695D2E69643D3D696429207B0D0A2020202020206E657720676F6F676C652E6D6170732E6576656E742E74726967676572286F70742E72657070696E5B695D2E6D61726B65722C22';
wwv_flow_api.g_varchar2_table(50) := '636C69636B22293B0D0A202020202020666F756E64203D20747275653B0D0A202020202020627265616B3B0D0A202020207D0D0A20207D0D0A20206966202821666F756E6429207B0D0A20202020617065782E6465627567286F70742E726567696F6E49';
wwv_flow_api.g_varchar2_table(51) := '642B22206964206E6F7420666F756E643A222B6964293B0D0A20207D0D0A7D2C0D0A0D0A2F2F70617273652074686520676976656E20737472696E672061732061206C61742C6C6F6E6720706169722C2070757420612070696E2061742074686174206C';
wwv_flow_api.g_varchar2_table(52) := '6F636174696F6E0D0A676F746F506F734279537472696E67203A2066756E6374696F6E20286F70742C7629207B0D0A2020617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E676F746F506F7322293B0D0A202076';
wwv_flow_api.g_varchar2_table(53) := '6172206C61746C6E67203D2070617273654C61744C6E672876293B0D0A2020696620286C61746C6E6729207B0D0A0909617065782E6465627567286F70742E726567696F6E49642B22206974656D206368616E67656420222B6C61746C6E672E6C617428';
wwv_flow_api.g_varchar2_table(54) := '292B2220222B6C61746C6E672E6C6E672829293B0D0A09097265706F72746D61702E7573657250696E286F70742C6C61746C6E672E6C617428292C6C61746C6E672E6C6E672829293B0D0A097D0D0A7D2C0D0A0D0A2F2F706C616365206F72206D6F7665';
wwv_flow_api.g_varchar2_table(55) := '2074686520757365722070696E20746F2074686520676976656E206C6F636174696F6E0D0A676F746F506F73203A2066756E6374696F6E20286F70742C6C61742C6C6E6729207B0D0A09617065782E6465627567286F70742E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(56) := '7265706F72746D61702E7573657250696E22293B0D0A2020696620286C6174213D3D6E756C6C202626206C6E67213D3D6E756C6C29207B0D0A20202020766172206F6C64706F73203D206F70742E7573657270696E3F6F70742E7573657270696E2E6765';
wwv_flow_api.g_varchar2_table(57) := '74506F736974696F6E28293A286E657720676F6F676C652E6D6170732E4C61744C6E6728302C3029293B0D0A20202020696620286F6C64706F73202626206C61743D3D6F6C64706F732E6C61742829202626206C6E673D3D6F6C64706F732E6C6E672829';
wwv_flow_api.g_varchar2_table(58) := '29207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B22207573657270696E206E6F74206368616E67656422293B0D0A202020207D20656C7365207B0D0A20202020202076617220706F73203D206E657720676F6F676C';
wwv_flow_api.g_varchar2_table(59) := '652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A202020202020696620286F70742E7573657270696E29207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B22206D6F7665206578697374696E672070';
wwv_flow_api.g_varchar2_table(60) := '696E20746F206E657720706F736974696F6E206F6E206D617020222B6C61742B222C222B6C6E67293B0D0A20202020202020206F70742E7573657270696E2E7365744D6170286F70742E6D6170293B0D0A20202020202020206F70742E7573657270696E';
wwv_flow_api.g_varchar2_table(61) := '2E736574506F736974696F6E28706F73293B0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B2220637265617465207573657270696E20222B6C61742B222C222B6C6E67293B';
wwv_flow_api.g_varchar2_table(62) := '0D0A20202020202020206F70742E7573657270696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A206F70742E6D61702C20706F736974696F6E3A20706F732C2069636F6E3A206F70742E69636F6E7D293B0D0A20202020';
wwv_flow_api.g_varchar2_table(63) := '20207D0D0A202020207D0D0A20207D20656C736520696620286F70742E7573657270696E29207B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B22206D6F7665206578697374696E672070696E206F666620746865206D6170';
wwv_flow_api.g_varchar2_table(64) := '22293B0D0A202020206F70742E7573657270696E2E7365744D6170286E756C6C293B0D0A20202020696620286F70742E64697374636972636C6529207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B22206D6F766520';
wwv_flow_api.g_varchar2_table(65) := '64697374636972636C65206F666620746865206D617022293B0D0A2020202020206F70742E64697374636972636C652E7365744D6170286E756C6C293B0D0A202020207D0D0A20207D0D0A7D2C0D0A0D0A2F2F73656172636820666F7220746865206164';
wwv_flow_api.g_varchar2_table(66) := '6472657373206174206120676976656E206C6F636174696F6E206279206C61742F6C6F6E670D0A73656172636841646472657373203A2066756E6374696F6E20286F70742C6C61742C6C6E6729207B0D0A09617065782E6465627567286F70742E726567';
wwv_flow_api.g_varchar2_table(67) := '696F6E49642B22207265706F72746D61702E7365617263684164647265737322293B0D0A09766172206C61746C6E67203D207B6C61743A206C61742C206C6E673A206C6E677D3B0D0A20207661722067656F636F646572203D206E657720676F6F676C65';
wwv_flow_api.g_varchar2_table(68) := '2E6D6170732E47656F636F6465723B0D0A0967656F636F6465722E67656F636F6465287B276C6F636174696F6E273A206C61746C6E677D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A090969662028737461747573203D';
wwv_flow_api.g_varchar2_table(69) := '3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A09090969662028726573756C74735B305D29207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B222061646472657373';
wwv_flow_api.g_varchar2_table(70) := '666F756E642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A202020202020202076617220636F6D706F6E656E7473203D20726573756C74735B305D2E616464726573735F636F6D706F6E656E74733B';
wwv_flow_api.g_varchar2_table(71) := '0D0A2020202020202020666F722028693D303B20693C636F6D706F6E656E74732E6C656E6774683B20692B2B29207B0D0A20202020202020202020617065782E6465627567286F70742E726567696F6E49642B2220726573756C745B305D20222B636F6D';
wwv_flow_api.g_varchar2_table(72) := '706F6E656E74735B695D2E74797065732B223D222B636F6D706F6E656E74735B695D2E73686F72745F6E616D652B222028222B636F6D706F6E656E74735B695D2E6C6F6E675F6E616D652B222922293B0D0A20202020202020207D0D0A20202020202020';
wwv_flow_api.g_varchar2_table(73) := '20617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A202020202020202020206D61703A6F70742E6D61702C0D0A202020202020202020206C61743A6C61742C';
wwv_flow_api.g_varchar2_table(74) := '0D0A202020202020202020206C6E673A6C6E672C0D0A20202020202020202020726573756C743A726573756C74735B305D0D0A20202020202020207D293B0D0A0909097D20656C7365207B0D0A2020202020202020617065782E6465627567286F70742E';
wwv_flow_api.g_varchar2_table(75) := '726567696F6E49642B2220736561726368416464726573733A204E6F20726573756C747320666F756E6422293B0D0A0909090977696E646F772E616C65727428274E6F20726573756C747320666F756E6427293B0D0A0909097D0D0A09097D20656C7365';
wwv_flow_api.g_varchar2_table(76) := '207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B272047656F636F646572206661696C65642064756520746F3A2027202B20737461747573293B0D0A09090977696E646F772E616C657274282747656F636F64657220';
wwv_flow_api.g_varchar2_table(77) := '6661696C65642064756520746F3A2027202B20737461747573293B0D0A09097D0D0A097D293B0D0A7D2C0D0A0D0A2F2F73656172636820666F72207468652075736572206465766963652773206C6F636174696F6E20696620706F737369626C650D0A67';
wwv_flow_api.g_varchar2_table(78) := '656F6C6F63617465203A2066756E6374696F6E20286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E67656F6C6F6361746522293B0D0A09696620286E6176696761746F722E67656F6C6F';
wwv_flow_api.g_varchar2_table(79) := '636174696F6E29207B0D0A0909617065782E6465627567286F70742E726567696F6E49642B222067656F6C6F6361746522293B0D0A09096E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E63';
wwv_flow_api.g_varchar2_table(80) := '74696F6E28706F736974696F6E29207B0D0A09090976617220706F73203D207B0D0A090909096C61743A20706F736974696F6E2E636F6F7264732E6C617469747564652C0D0A090909096C6E673A20706F736974696F6E2E636F6F7264732E6C6F6E6769';
wwv_flow_api.g_varchar2_table(81) := '747564650D0A0909097D3B0D0A0909096F70742E6D61702E70616E546F28706F73293B0D0A090909696620286F70742E67656F6C6F636174655A6F6F6D29207B0D0A09090920206F70742E6D61702E7365745A6F6F6D286F70742E67656F6C6F63617465';
wwv_flow_api.g_varchar2_table(82) := '5A6F6F6D293B0D0A0909097D0D0A090909617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282267656F6C6F63617465222C207B6D61703A6F70742E6D61702C206C61743A706F732E6C61742C206C6E673A70';
wwv_flow_api.g_varchar2_table(83) := '6F732E6C6E677D293B0D0A09097D293B0D0A097D20656C7365207B0D0A0909617065782E6465627567286F70742E726567696F6E49642B222062726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22293B0D0A097D';
wwv_flow_api.g_varchar2_table(84) := '0D0A7D2C0D0A0D0A2F2F746869732069732063616C6C6564207768656E20646972656374696F6E7320617265207265717565737465640D0A646972656374696F6E7372657370203A2066756E6374696F6E2028726573706F6E73652C7374617475732C6F';
wwv_flow_api.g_varchar2_table(85) := '707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E646972656374696F6E737265737022293B0D0A202069662028737461747573203D3D20676F6F676C652E6D6170732E446972656374696F6E';
wwv_flow_api.g_varchar2_table(86) := '735374617475732E4F4B29207B0D0A202020206F70742E646972656374696F6E73446973706C61792E736574446972656374696F6E7328726573706F6E7365293B0D0A2020202076617220746F74616C44697374616E6365203D20302C20746F74616C44';
wwv_flow_api.g_varchar2_table(87) := '75726174696F6E203D20302C206C6567436F756E74203D20303B0D0A20202020666F72202876617220693D303B2069203C20726573706F6E73652E726F757465732E6C656E6774683B20692B2B29207B0D0A2020202020206C6567436F756E74203D206C';
wwv_flow_api.g_varchar2_table(88) := '6567436F756E74202B20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B0D0A202020202020666F722028766172206A3D303B206A203C20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B206A';
wwv_flow_api.g_varchar2_table(89) := '2B2B29207B0D0A2020202020202020766172206C6567203D20726573706F6E73652E726F757465735B695D2E6C6567735B6A5D3B0D0A2020202020202020746F74616C44697374616E6365203D20746F74616C44697374616E6365202B206C65672E6469';
wwv_flow_api.g_varchar2_table(90) := '7374616E63652E76616C75653B0D0A2020202020202020746F74616C4475726174696F6E203D20746F74616C4475726174696F6E202B206C65672E6475726174696F6E2E76616C75653B0D0A2020202020207D0D0A202020207D0D0A2020202061706578';
wwv_flow_api.g_varchar2_table(91) := '2E6A5175657279282223222B6F70742E726567696F6E4964292E747269676765722822646972656374696F6E73222C7B0D0A2020202020206D61703A6F70742E6D61702C0D0A20202020202064697374616E63653A746F74616C44697374616E63652C0D';
wwv_flow_api.g_varchar2_table(92) := '0A2020202020206475726174696F6E3A746F74616C4475726174696F6E2C0D0A2020202020206C6567733A6C6567436F756E740D0A202020207D293B0D0A20207D20656C7365207B0D0A20202020617065782E6465627567286F70742E726567696F6E49';
wwv_flow_api.g_varchar2_table(93) := '642B2720446972656374696F6E732072657175657374206661696C65642064756520746F2027202B20737461747573293B0D0A2020202077696E646F772E616C6572742827446972656374696F6E732072657175657374206661696C6564206475652074';
wwv_flow_api.g_varchar2_table(94) := '6F2027202B20737461747573293B0D0A20207D0D0A7D2C0D0A0D0A2F2F73686F7720646972656374696F6E73206F6E20746865206D61700D0A646972656374696F6E73203A2066756E6374696F6E20286F707429207B0D0A09617065782E646562756728';
wwv_flow_api.g_varchar2_table(95) := '6F70742E726567696F6E49642B22207265706F72746D61702E646972656374696F6E7320222B6F70742E646972656374696F6E73293B0D0A09766172206F726967696E0D0A092020202C646573740D0A20202020202C726F757465696E646578203D206F';
wwv_flow_api.g_varchar2_table(96) := '70742E646972656374696F6E732E696E6465784F6628222D524F55544522290D0A20202020202C74726176656C6D6F64653B0D0A0969662028726F757465696E6465783C3029207B0D0A202020202F2F73696D706C6520646972656374696F6E73206265';
wwv_flow_api.g_varchar2_table(97) := '747765656E2074776F206974656D730D0A202020206F726967696E203D202476286F70742E6F726967696E4974656D293B0D0A20202020646573742020203D202476286F70742E646573744974656D293B0D0A202020206F726967696E203D207265706F';
wwv_flow_api.g_varchar2_table(98) := '72746D61702E70617273654C61744C6E67286F726967696E297C7C6F726967696E3B0D0A20202020646573742020203D207265706F72746D61702E70617273654C61744C6E672864657374297C7C646573743B0D0A20202020696620286F726967696E20';
wwv_flow_api.g_varchar2_table(99) := '213D3D202222202626206465737420213D3D20222229207B0D0A20202020202074726176656C6D6F6465203D206F70742E646972656374696F6E733B0D0A092020096F70742E646972656374696F6E73536572766963652E726F757465287B0D0A090920';
wwv_flow_api.g_varchar2_table(100) := '20096F726967696E3A6F726967696E2C0D0A090909202064657374696E6174696F6E3A646573742C0D0A090909202074726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B74726176656C6D6F64655D0D0A090920207D2C';
wwv_flow_api.g_varchar2_table(101) := '2066756E6374696F6E28726573706F6E73652C737461747573297B7265706F72746D61702E646972656374696F6E737265737028726573706F6E73652C7374617475732C6F7074297D293B0D0A202020207D0D0A20207D20656C7365207B0D0A20202020';
wwv_flow_api.g_varchar2_table(102) := '2F2F726F7574652076696120776179706F696E74730D0A2020202074726176656C6D6F6465203D206F70742E646972656374696F6E732E736C69636528302C726F757465696E646578293B0D0A20202020617065782E6465627567286F70742E72656769';
wwv_flow_api.g_varchar2_table(103) := '6F6E49642B2220726F7574652076696120222B74726176656C6D6F64652B22207769746820222B6F70742E6D6170646174612E6C656E6774682B2220776179706F696E747322293B0D0A2020202076617220776179706F696E7473203D205B5D3B0D0A20';
wwv_flow_api.g_varchar2_table(104) := '0909666F7220287661722069203D20303B2069203C206F70742E6D6170646174612E6C656E6774683B20692B2B29207B0D0A2020202020206966202869203D3D203029207B0D0A20202020202020206F726967696E203D206E657720676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(105) := '6170732E4C61744C6E67286F70742E6D6170646174615B695D2E6C61742C206F70742E6D6170646174615B695D2E6C6E67293B0D0A2020202020207D20656C7365206966202869203D3D206F70742E6D6170646174612E6C656E6774682D3129207B0D0A';
wwv_flow_api.g_varchar2_table(106) := '202020202020202064657374203D206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6D6170646174615B695D2E6C61742C206F70742E6D6170646174615B695D2E6C6E67293B0D0A2020202020207D20656C7365207B0D0A20202020';
wwv_flow_api.g_varchar2_table(107) := '20202020776179706F696E74732E70757368287B0D0A202020202020202020206C6F636174696F6E3A206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6D6170646174615B695D2E6C61742C206F70742E6D6170646174615B695D2E';
wwv_flow_api.g_varchar2_table(108) := '6C6E67292C0D0A2020202020202020202073746F706F7665723A20747275650D0A20202020202020207D293B0D0A2020202020207D0D0A09097D0D0A20202020617065782E6465627567286F70742E726567696F6E49642B22206F726967696E3D222B6F';
wwv_flow_api.g_varchar2_table(109) := '726967696E293B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B2220646573743D222B64657374293B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B2220776179706F696E74733A222B77617970';
wwv_flow_api.g_varchar2_table(110) := '6F696E74732E6C656E677468293B0D0A09096F70742E646972656374696F6E73536572766963652E726F757465287B0D0A0909096F726967696E3A6F726967696E2C0D0A09090964657374696E6174696F6E3A646573742C0D0A20202020202077617970';
wwv_flow_api.g_varchar2_table(111) := '6F696E74733A776179706F696E74732C0D0A2020202020206F7074696D697A65576179706F696E74733A6F70742E6F7074696D697A65576179706F696E74732C0D0A09090974726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F';
wwv_flow_api.g_varchar2_table(112) := '64655B74726176656C6D6F64655D0D0A09097D2C2066756E6374696F6E28726573706F6E73652C737461747573297B7265706F72746D61702E646972656374696F6E737265737028726573706F6E73652C7374617475732C6F7074297D293B0D0A097D0D';
wwv_flow_api.g_varchar2_table(113) := '0A7D2C0D0A0D0A2F2F696E697469616C69736520746865206D61702061667465722070616765206C6F61640D0A696E6974203A2066756E6374696F6E20286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B2220726570';
wwv_flow_api.g_varchar2_table(114) := '6F72746D61702E696E697420222B6F70742E6D617074797065293B0D0A09766172206D794F7074696F6E73203D207B0D0A09097A6F6F6D3A20312C0D0A090963656E7465723A207265706F72746D61702E70617273654C61744C6E67286F70742E6C6174';
wwv_flow_api.g_varchar2_table(115) := '6C6E67292C0D0A09096D61705479706549643A206F70742E6D6170747970650D0A097D3B0D0A096F70742E6D6170203D206E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E7442794964286F70742E636F6E';
wwv_flow_api.g_varchar2_table(116) := '7461696E6572292C6D794F7074696F6E73293B0D0A20206F70742E6D61702E7365744F7074696F6E73287B0D0A20202020202020647261676761626C653A206F70742E70616E0D0A2020202020202C7A6F6F6D436F6E74726F6C3A206F70742E7A6F6F6D';
wwv_flow_api.g_varchar2_table(117) := '0D0A2020202020202C7363726F6C6C776865656C3A206F70742E7A6F6F6D0D0A2020202020202C64697361626C65446F75626C65436C69636B5A6F6F6D3A2021286F70742E7A6F6F6D290D0A2020202020202C6765737475726548616E646C696E673A20';
wwv_flow_api.g_varchar2_table(118) := '6F70742E6765737475726548616E646C696E670D0A202020207D293B0D0A09696620286F70742E6D61707374796C6529207B0D0A09096F70742E6D61702E7365744F7074696F6E73287B7374796C65733A206F70742E6D61707374796C657D293B0D0A09';
wwv_flow_api.g_varchar2_table(119) := '7D0D0A096F70742E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E6473286F70742E736F757468776573742C6F70742E6E6F7274686561737429293B0D0A09696620286F70742E6578706563744461';
wwv_flow_api.g_varchar2_table(120) := '746129207B0D0A09097265706F72746D61702E72657050696E73286F7074293B0D0A097D0D0A09696620286F70742E646972656374696F6E7329207B0D0A202020202F2F646972656374696F6E732069732044524956494E472D524F5554452C2057414C';
wwv_flow_api.g_varchar2_table(121) := '4B494E472D524F5554452C2042494359434C494E472D524F5554452C205452414E5349542D524F5554452C0D0A202020202F2F202020202020202020202020202044524956494E472C2057414C4B494E472C2042494359434C494E472C206F7220545241';
wwv_flow_api.g_varchar2_table(122) := '4E5349540D0A09096F70742E646972656374696F6E73446973706C6179203D206E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265723B0D0A202020206F70742E646972656374696F6E7353657276696365203D206E6577';
wwv_flow_api.g_varchar2_table(123) := '20676F6F676C652E6D6170732E446972656374696F6E73536572766963653B0D0A09096F70742E646972656374696F6E73446973706C61792E7365744D6170286F70742E6D6170293B0D0A09097265706F72746D61702E646972656374696F6E73286F70';
wwv_flow_api.g_varchar2_table(124) := '74293B0D0A09092F2F696620746865206F726967696E206F722064657374206974656D206973206368616E67656420666F722073696D706C6520646972656374696F6E732C20726563616C632074686520646972656374696F6E730D0A20202020696620';
wwv_flow_api.g_varchar2_table(125) := '286F70742E646972656374696F6E732E696E6465784F6628222D524F55544522293C3029207B0D0A2020090924282223222B6F70742E6F726967696E4974656D292E6368616E67652866756E6374696F6E28297B0D0A09202009097265706F72746D6170';
wwv_flow_api.g_varchar2_table(126) := '2E646972656374696F6E73286F7074293B0D0A090920207D293B0D0A0909202024282223222B6F70742E646573744974656D292E6368616E67652866756E6374696F6E28297B0D0A09090920207265706F72746D61702E646972656374696F6E73286F70';
wwv_flow_api.g_varchar2_table(127) := '74293B0D0A092020097D293B0D0A202020207D0D0A097D0D0A09676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E6D61702C2022636C69636B222C2066756E6374696F6E20286576656E7429207B0D0A090976617220';
wwv_flow_api.g_varchar2_table(128) := '6C6174203D206576656E742E6C61744C6E672E6C617428290D0A09092020202C6C6E67203D206576656E742E6C61744C6E672E6C6E6728293B0D0A0909617065782E6465627567286F70742E726567696F6E49642B22206D617020636C69636B65642022';
wwv_flow_api.g_varchar2_table(129) := '2B6C61742B222C222B6C6E67293B0D0A20202020696620286F70742E6D61726B65725A6F6F6D29207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222070616E2B7A6F6F6D22293B0D0A202020202020696620286F70742E6D';
wwv_flow_api.g_varchar2_table(130) := '61726B657250616E29207B0D0A09090920206F70742E6D61702E70616E546F286576656E742E6C61744C6E67293B0D0A2020202020207D0D0A0909096F70742E6D61702E7365745A6F6F6D286F70742E6D61726B65725A6F6F6D293B0D0A09097D0D0A09';
wwv_flow_api.g_varchar2_table(131) := '09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D6170636C69636B222C207B6D61703A6F70742E6D61702C206C61743A6C61742C206C6E673A6C6E677D293B0D0A097D293B0D0A09617065782E6465';
wwv_flow_api.g_varchar2_table(132) := '627567286F70742E726567696F6E49642B22207265706F72746D61702E696E69742066696E697368656422293B0D0A09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D61706C6F61646564222C207B';
wwv_flow_api.g_varchar2_table(133) := '6D61703A6F70742E6D61707D293B0D0A7D2C0D0A0D0A2F2F72656672657368207468652070696E73206F6E20746865206D6170206261736564206F6E207468652053514C2071756572790D0A72656672657368203A2066756E6374696F6E20286F707429';
wwv_flow_api.g_varchar2_table(134) := '207B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61702E7265667265736822293B0D0A09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282261706578626566';
wwv_flow_api.g_varchar2_table(135) := '6F72657265667265736822293B0D0A09617065782E7365727665722E706C7567696E0D0A0909286F70742E616A61784964656E7469666965720D0A09092C7B20706167654974656D733A206F70742E616A61784974656D73207D0D0A09092C7B20646174';
wwv_flow_api.g_varchar2_table(136) := '61547970653A20226A736F6E220D0A0909092C737563636573733A2066756E6374696F6E282070446174612029207B0D0A09090909617065782E6465627567286F70742E726567696F6E49642B2220737563636573732070446174613D222B7044617461';
wwv_flow_api.g_varchar2_table(137) := '2E736F757468776573742E6C61742B222C222B70446174612E736F757468776573742E6C6E672B2220222B70446174612E6E6F727468656173742E6C61742B222C222B70446174612E6E6F727468656173742E6C6E67293B0D0A090909096F70742E6D61';
wwv_flow_api.g_varchar2_table(138) := '702E666974426F756E6473280D0A09090909097B736F7574683A70446174612E736F757468776573742E6C61740D0A09090909092C776573743A2070446174612E736F757468776573742E6C6E670D0A09090909092C6E6F7274683A70446174612E6E6F';
wwv_flow_api.g_varchar2_table(139) := '727468656173742E6C61740D0A09090909092C656173743A2070446174612E6E6F727468656173742E6C6E677D293B0D0A09090909696620286F70742E697729207B0D0A09090909096F70742E69772E636C6F736528293B0D0A090909097D0D0A090909';
wwv_flow_api.g_varchar2_table(140) := '09696620286F70742E72657070696E29207B0D0A0909090909617065782E6465627567286F70742E726567696F6E49642B222072656D6F766520616C6C207265706F72742070696E7322293B0D0A0909090909666F7220287661722069203D20303B2069';
wwv_flow_api.g_varchar2_table(141) := '203C206F70742E72657070696E2E6C656E6774683B20692B2B29207B0D0A0909090909096F70742E72657070696E5B695D2E6D61726B65722E7365744D6170286E756C6C293B0D0A09090909097D0D0A09090909096F70742E72657070696E2E64656C65';
wwv_flow_api.g_varchar2_table(142) := '74653B0D0A090909097D0D0A09090909617065782E6465627567286F70742E726567696F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B70446174612E6D6170646174612E6C656E677468293B0D0A090909096F70742E6D6170';
wwv_flow_api.g_varchar2_table(143) := '64617461203D2070446174612E6D6170646174613B0D0A09090909696620286F70742E6578706563744461746129207B0D0A09090909097265706F72746D61702E72657050696E73286F7074293B0D0A090909097D0D0A09090909617065782E6A517565';
wwv_flow_api.g_varchar2_table(144) := '7279282223222B6F70742E726567696F6E4964292E7472696767657228226170657861667465727265667265736822293B0D0A0909097D0D0A09097D20293B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265706F72746D61';
wwv_flow_api.g_varchar2_table(145) := '702E726566726573682066696E697368656422293B0D0A7D0D0A0D0A7D';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(142772961944482405)
,p_plugin_id=>wwv_flow_api.id(727724993790194482)
,p_file_name=>'jk64reportmap.js'
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
