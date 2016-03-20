# Report Google Map region plugin for Oracle Application Express. #

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify. 

![plugin-reportmap-preview.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/plugin-reportmap-preview.png)

The user can click any marker to see a popup info window for it. You can have the region synchronize the map with an item you nominate - if so, the corresponding ID for the marker they click will be copied to the item.

## DEMO ##

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## INSTALLATION INSTRUCTIONS ##

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map.sql**
3. *(optional)* Supply your **Google API Key** (NOTE: the plugin is usable without one)
4. Add a region to the page, select type **JK64 Report Google Map [Plug-In]**
5. For **SQL Source**, enter a query with at least 5 columns (see example below)

**Sample query**

```sql
SELECT lat, lng, name, id, info FROM mydata
```

For more info including version history and plugin references, refer to the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).
