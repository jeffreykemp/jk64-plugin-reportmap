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
prompt --application/shared_components/plugins/dynamic_action/com_jk64_report_google_map_da_r1
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(57800177599111254)
,p_plugin_type=>'DYNAMIC ACTION'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP_DA_R1'
,p_display_name=>'JK64 Report Google Map R1 Action'
,p_category=>'EXECUTE'
,p_supported_ui_types=>'DESKTOP'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- jk64 ReportMap Action v1.0 May 2020',
'-- https://github.com/jeffreykemp/jk64-plugin-reportmap',
'-- Copyright (c) 2020 Jeffrey Kemp',
'-- Released under the MIT licence: http://opensource.org/licenses/mit-license',
'',
'subtype plugin_attr is varchar2(32767);',
'',
'function render ',
'    ( p_dynamic_action apex_plugin.t_dynamic_action',
'    , p_plugin         apex_plugin.t_plugin ',
'    ) return apex_plugin.t_dynamic_action_render_result is',
'',
'    l_action         plugin_attr := p_dynamic_action.attribute_01;',
'    l_source_type    plugin_attr := p_dynamic_action.attribute_02;',
'    l_page_item      plugin_attr := p_dynamic_action.attribute_03;',
'    l_selector       plugin_attr := p_dynamic_action.attribute_04;',
'    l_static_value   plugin_attr := p_dynamic_action.attribute_05;',
'    l_js_expression  plugin_attr := p_dynamic_action.attribute_06;',
'    ',
'    l_action_js      varchar2(1000);',
'    l_val_js         varchar2(1000);',
'    l_result         apex_plugin.t_dynamic_action_render_result;',
'',
'begin',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_dynamic_action',
'            (p_plugin         => p_plugin',
'            ,p_dynamic_action => p_dynamic_action);',
'    end if;',
'    ',
'    l_action_js := case l_action',
'        when ''deleteAllFeatures'' then',
'            ''$("#map_"+e.id).reportmap("deleteAllFeatures");''',
'        when ''deleteSelectedFeatures'' then',
'            ''$("#map_"+e.id).reportmap("deleteSelectedFeatures");''',
'        when ''fitBounds'' then',
'            ''$("#map_"+e.id).reportmap("fitBounds",#VAL#);''',
'        when ''geolocate'' then',
'            ''$("#map_"+e.id).reportmap("geolocate");''',
'        when ''getAddressByPos'' then',
'            ''var pos = $("#map_"+e.id).reportmap("instance").parseLatLng(#VAL#);''',
'         || ''$("#map_"+e.id).reportmap("getAddressByPos",pos.lat(),pos.lng());''',
'        when ''gotoAddress'' then',
'            ''$("#map_"+e.id).reportmap("gotoAddress",#VAL#);''',
'        when ''gotoPosByString'' then',
'            ''$("#map_"+e.id).reportmap("gotoPosByString",#VAL#);''',
'        when ''hideMessage'' then',
'            ''$("#map_"+e.id).reportmap("hideMessage");''',
'        when ''loadGeoJsonString'' then',
'            ''$("#map_"+e.id).reportmap("loadGeoJsonString",#VAL#);''',
'        when ''panTo'' then',
'            ''var r = $("#map_"+e.id).reportmap("instance");''',
'         || ''r.map.panTo(r.parseLatLng(#VAL#));''',
'        when ''setMapType'' then',
'            ''$("#map_"+e.id).reportmap("instance").map.setMapTypeId(#VAL#);''',
'        when ''setTilt'' then',
'            ''$("#map_"+e.id).reportmap("instance").map.setTilt(parseInt(#VAL#));''',
'        when ''setZoom'' then',
'            ''$("#map_"+e.id).reportmap("instance").map.setZoom(parseInt(#VAL#));''',
'        when ''showMessage'' then',
'            ''$("#map_"+e.id).reportmap("showMessage",#VAL#);''',
'        end;',
'    ',
'    if l_action_js is null then',
'        raise_application_error(-20000, ''Plugin error: unrecognised action ('' || l_action || '')'');',
'    end if;',
'    ',
'    if instr(l_action_js,''#VAL#'') > 0 then',
'    ',
'        l_action_js := replace(l_action_js, ''#VAL#'', ''val'');',
'        ',
'        l_val_js :=    ',
'            case l_source_type',
'            when ''triggeringElement'' then',
'                ''var val=$v(this.triggeringElement);''',
'            when ''pageItem'' then',
'                ''var val=$v("'' || apex_javascript.escape(l_page_item) || ''");''',
'            when ''jquerySelector'' then',
'                ''var val=$("'' || apex_javascript.escape(l_selector) || ''").val();''',
'            when ''javascriptExpression'' then',
'                ''var val='' || l_js_expression || '';''',
'            when ''static'' then',
'                ''var val="'' || apex_javascript.escape(l_static_value) || ''";''',
'            end;',
'        ',
'        if l_val_js is null then',
'            raise_application_error(-20000, ''Plugin error: unrecognised source type ('' || l_source_type || '')'');',
'        end if;',
'',
'    end if;',
'',
'    l_result.javascript_function',
'        := ''function(){''',
'        ||     ''apex.debug("ReportMap Action:","''|| l_action || ''");''',
'        ||     l_val_js',
'        ||     ''this.affectedElements.each(function(i,e){''',
'        ||         l_action_js',
'        ||     ''});''',
'        || ''}'';',
'',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        raise;',
'end render;'))
,p_api_version=>2
,p_render_function=>'render'
,p_standard_attributes=>'REGION:REQUIRED'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>',
'Use this to perform the selected action on a map region. This plugin is to be used in conjunction with a <strong>JK64 Report Google Map R1</strong> region on the page.',
'</p><p>',
'Refer to the wiki for documentation: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki</strong>.',
'</p><p>',
'Please raise any bugs or enhancements on GitHub: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/issues</strong>.',
'</p>'))
,p_version_identifier=>'1.0'
,p_about_url=>'https://jeffreykemp.github.io/jk64-plugin-reportmap/'
,p_plugin_comment=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Copyright (c) 2020 Jeffrey Kemp',
'Released under the MIT licence: http://opensource.org/licenses/mit-license'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57802829130296320)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Action'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'gotoAddress'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Select the action to execute for the selected map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57803536830299272)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>10
,p_display_value=>'Search map by Address'
,p_return_value=>'gotoAddress'
,p_help_text=>'Search the map for the given address (e.g. "Koombana Drive, Bunbury, Western Australia"), point of interest ("Fern Pool, Karijini, Western Australia"), or lat/long (e.g. "-33.64392 115.34432").'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(58152257519322076)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>20
,p_display_value=>'Get Address at Location'
,p_return_value=>'getAddressByPos'
,p_help_text=>'Find the closest address to a given location by lat/long. When this action is executed, the address is returned via the addressFound event.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57814589884382172)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>25
,p_display_value=>'Place Marker'
,p_return_value=>'gotoPosByString'
,p_help_text=>'Move or place the marker at a given position (lat, long). Position may be provided as a LatLngLiteral, e.g. {"lat":-34, "lng":151}'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57816364090492387)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>30
,p_display_value=>'Go to Device Location'
,p_return_value=>'geolocate'
,p_help_text=>'Search for the user device''s location using navigator.geolocation.getCurrentPosition, if possible (and allowed by the user).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57816771575497485)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>40
,p_display_value=>'Set the Zoom level'
,p_return_value=>'setZoom'
,p_help_text=>'Zoom the map to a particular level (0..23)'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57894251405928111)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>50
,p_display_value=>'Pan To'
,p_return_value=>'panTo'
,p_help_text=>'Move the map centered on the given point. Value must be a Lat,Long (e.g. "27.1751448 78.0421422").'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(58093029966826147)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>60
,p_display_value=>'Fit Bounds'
,p_return_value=>'fitBounds'
,p_help_text=>'Pan/Zoom the map so that it fits the specified bounds. The value must be provided as a LatLngBounds object or a LatLngBoundsLiteral, e.g. {"south":-37.71010, "west":87.56120, "north":-9.95828, "east":150.66667}'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57907078940170846)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>80
,p_display_value=>'Set Map Type'
,p_return_value=>'setMapType'
,p_help_text=>'Set the map type. Value must be one of ''hybrid'', ''roadmap'', ''satellite'' or ''terrain''.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57817147523510779)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>90
,p_display_value=>'Set the map Tilt'
,p_return_value=>'setTilt'
,p_help_text=>unistr('Controls the automatic switching behavior for the angle of incidence of the map. The only allowed values are 0 and 45. setTilt(0) causes the map to always use a 0\00B0 overhead view regardless of the zoom level and viewport. setTilt(45) causes the tilt a')
||unistr('ngle to automatically switch to 45 whenever 45\00B0 imagery is available for the current zoom level and viewport, and switch back to 0 whenever 45\00B0 imagery is not available (this is the default behavior). 45\00B0 imagery is only available for satellite and h')
||'ybrid map types, within some locations, and at some zoom levels.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(58065082370762244)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>100
,p_display_value=>'Load GeoJSON'
,p_return_value=>'loadGeoJsonString'
,p_help_text=>'Load one or more features specified in a GeoJSON document.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(58127610056506475)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>110
,p_display_value=>'Delete All Features'
,p_return_value=>'deleteAllFeatures'
,p_help_text=>'Remove all features (e.g. those loaded via GeoJson, or drawn by the user).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(58128069027507644)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>120
,p_display_value=>'Delete Selected Features'
,p_return_value=>'deleteSelectedFeatures'
,p_help_text=>'Remove selected features (e.g. those loaded via GeoJson, or drawn by the user).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57817500656515247)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>200
,p_display_value=>'Show Message'
,p_return_value=>'showMessage'
,p_help_text=>'Show a Warning/Error message. The message is shown in a light yellow box centered left in the viewing window.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57817916181517142)
,p_plugin_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_display_sequence=>210
,p_display_value=>'Hide Message'
,p_return_value=>'hideMessage'
,p_help_text=>'Hide the Warning/Error message.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57805029860565721)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Source Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'triggeringElement'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(57802829130296320)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'fitBounds,getAddressByPos,gotoAddress,gotoPosByString,loadGeoJsonString,panTo,setMapType,setTilt,setZoom,showMessage'
,p_lov_type=>'STATIC'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57805748501569480)
,p_plugin_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_display_sequence=>10
,p_display_value=>'Triggering Element'
,p_return_value=>'triggeringElement'
,p_help_text=>'Get the value from the item that the Dynamic Action is on.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57808035065593405)
,p_plugin_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_display_sequence=>30
,p_display_value=>'Page Item'
,p_return_value=>'pageItem'
,p_help_text=>'Specify an item on the page to provide the source value for the action.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57806470419573588)
,p_plugin_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_display_sequence=>40
,p_display_value=>'jQuery Selector'
,p_return_value=>'jquerySelector'
,p_help_text=>'Specify a jQuery Selector to provide the source value for the action'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57867355839554570)
,p_plugin_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_display_sequence=>50
,p_display_value=>'JavaScript Expression'
,p_return_value=>'javascriptExpression'
,p_help_text=>'Set the value using a JavaScript expression.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(57821955593589586)
,p_plugin_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_display_sequence=>60
,p_display_value=>'Static Value'
,p_return_value=>'static'
,p_help_text=>'Set a single static value.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57806872806581651)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Page Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'pageItem'
,p_help_text=>'Specify the page item to provide the source value for the action.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57808436234603804)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'jQuery Selector'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'jquerySelector'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Specify the jQuery selector to identify the source value for the action.',
'',
'e.g.',
'<code>',
'#itemId',
'</code>'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57824565559596809)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Value'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'static'
,p_help_text=>'Enter the value to be used. Substitution syntax allowed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(57875320723568809)
,p_plugin_id=>wwv_flow_api.id(57800177599111254)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'JavaScript Expression'
,p_attribute_type=>'JAVASCRIPT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(57805029860565721)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'javascriptExpression'
,p_help_text=>'Specify the JavaScript expression to use to set the value for the action.'
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
