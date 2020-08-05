-- jk64 ReportMap Action v1.0 Aug 2020
-- https://github.com/jeffreykemp/jk64-plugin-reportmap
-- Copyright (c) 2020 Jeffrey Kemp
-- Released under the MIT licence: http://opensource.org/licenses/mit-license

subtype plugin_attr is varchar2(32767);

function render 
    ( p_dynamic_action apex_plugin.t_dynamic_action
    , p_plugin         apex_plugin.t_plugin 
    ) return apex_plugin.t_dynamic_action_render_result is

    l_action         plugin_attr := p_dynamic_action.attribute_01;
    l_source_type    plugin_attr := p_dynamic_action.attribute_02;
    l_page_item      plugin_attr := p_dynamic_action.attribute_03;
    l_selector       plugin_attr := p_dynamic_action.attribute_04;
    l_static_value   plugin_attr := p_dynamic_action.attribute_05;
    l_js_expression  plugin_attr := p_dynamic_action.attribute_06;
    l_option         plugin_attr := p_dynamic_action.attribute_07;
    
    l_action_js      varchar2(32767);
    l_val_js         varchar2(32767);
    l_result         apex_plugin.t_dynamic_action_render_result;

begin
    if apex_application.g_debug then
        apex_plugin_util.debug_dynamic_action
            (p_plugin         => p_plugin
            ,p_dynamic_action => p_dynamic_action);
    end if;
    
    l_action_js := case l_action
        when 'deleteAllFeatures' then
            '$("#map_"+e.id).reportmap("deleteAllFeatures");'
        when 'deleteSelectedFeatures' then
            '$("#map_"+e.id).reportmap("deleteSelectedFeatures");'
        when 'fitBounds' then
            '$("#map_"+e.id).reportmap("fitBounds",#VAL#);'
        when 'geolocate' then
            '$("#map_"+e.id).reportmap("geolocate");'
        when 'getAddressByPos' then
            'var pos = $("#map_"+e.id).reportmap("instance").parseLatLng(#VAL#);'
         || '$("#map_"+e.id).reportmap("getAddressByPos",pos.lat(),pos.lng());'
        when 'gotoAddress' then
            '$("#map_"+e.id).reportmap("gotoAddress",#VAL#);'
        when 'gotoPosByString' then
            '$("#map_"+e.id).reportmap("gotoPosByString",#VAL#);'
        when 'hideMessage' then
            '$("#map_"+e.id).reportmap("hideMessage");'
        when 'loadGeoJsonString' then
            '$("#map_"+e.id).reportmap("loadGeoJsonString",#VAL#);'
        when 'panTo' then
            '$("#map_"+e.id).reportmap("panToByString",#VAL#);'
        when 'restrictTo' then
            '$("#map_"+e.id).reportmap("instance").map.setOptions({restriction:{latLngBounds:#VAL#}});'        
        when 'restrictToStrict' then
            '$("#map_"+e.id).reportmap("instance").map.setOptions({restriction:{latLngBounds:#VAL#,strictBounds:true}});'  
        when 'setOption' then
            '$("#map_"+e.id).reportmap("option","' || l_option || '",#VAL#);'
        when 'showMessage' then
            '$("#map_"+e.id).reportmap("showMessage",#VAL#);'
        end;
    
    if l_action_js is null then
        raise_application_error(-20000, 'Plugin error: unrecognised action (' || l_action || ')');
    end if;
    
    if instr(l_action_js,'#VAL#') > 0 then
    
        l_action_js := replace(l_action_js, '#VAL#', 'val');
        
        l_val_js :=    
            case l_source_type
            when 'triggeringElement' then
                'var val=$v(this.triggeringElement);'
            when 'pageItem' then
                'var val=$v("' || apex_javascript.escape(l_page_item) || '");'
            when 'jquerySelector' then
                'var val=$("' || apex_javascript.escape(l_selector) || '").val();'
            when 'javascriptExpression' then
                'var val=' || l_js_expression || ';'
            when 'static' then
                'var val="' || apex_javascript.escape(l_static_value) || '";'
            end;
        
        if l_val_js is null then
            raise_application_error(-20000, 'Plugin error: unrecognised source type (' || l_source_type || ')');
        end if;

    end if;

    l_result.javascript_function
        := 'function(){'
        ||     'apex.debug("ReportMap Action:","'|| l_action || '");'
        ||     l_val_js
        ||     'this.affectedElements.each(function(i,e){'
        ||         l_action_js
        ||     '});'
        || '}';

    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        raise;
end render;