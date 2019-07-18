# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 18.2](https://github.com/Dani3lSun/apex-github-badges/blob/master/badges/apex-18_2-badge.svg)

### A region plugin for Oracle Application Express

**Leverage the power of Google Maps in your APEX application.** This plugin allows you to add one or more Google Map regions to any page, showing a number of markers (pins) retrieved from a query or other data source you specify.

The plugin provides a rich array of built-in declarative features, dynamic actions and associated API routines, and it also giving you access to the underlying Google Maps object so you can customise it with any other behaviour you need.

Full documentation is provided in the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).

![plugin-reportmap-markers.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-markers.png)

The user can click any marker to see a popup info window for it.

### Visualisation: Marker Clustering

![plugin-reportmap-clustering.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-clustering.png)

If many pins are too close together, Marker Clustering merges them into a single cluster; the number indicates how many pins are at that location. As the user zooms in or out, the clusters will split up or merge as needed.

### Visualisation: Heatmap

![plugin-reportmap-heatmap.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-heatmap.png)

This is suitable for a large volume of data points. Each data point can have a "weight" which indicates the magnitude of some measure.

### Visualisation: Directions

![plugin-reportmap-route.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-route.png)

Up to 10 points (origin, destination, plus up to 8 waypoints) may be supplied to derive a route. Google Maps can generate a route for Driving, Walking, Bicycling, or Transit (public transport). The plugin can also get the calculated total Distance and Time for the route.

## DEMO

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES

* Oracle Application Express **18.2** or later
* Your **[Google Maps API Key](https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key)**

## INSTALLATION INSTRUCTIONS

**Warning:** if you are upgrading to v1.0 from any prior version, this is NOT a drop-in replacement; some changes may be required to your application to support it as a number of attributes have been removed. Also, the minimum requirement has changed to APEX 18.2.

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map_r1.sql**
3. Supply your public **Google API Key** (Component Settings)
4. Add a region to the page, select type **JK64 Report Google Map R1 [Plug-In]**
5. For **SQL Source**, enter a query with at least 4 columns (see example below)

**IF YOU ARE UPGRADING** from an earlier release, refer to the **[Upgrade Notes](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki/Upgrading)**.

**Sample query**

```sql
SELECT lat, lng, name, id FROM mydata
```

## SUPPORT

* In APEX, select any attribute and view the **Help** for more information and helpful tips.

* Refer to the **[WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki)** for sample queries, plugin attributes, triggers, API references, and other tips & tricks.

* If you encounter a bug or have a great idea for enhancement, please raise an **[Issue](https://github.com/jeffreykemp/jk64-plugin-reportmap/issues)**. I will endeavour to respond to each issue as quickly as possible. When reporting an issue, make sure to provide as much detail as possible:
    
    - Steps to reproduce the issue
    - A concise description of the Expected, and Actual behaviour
    - Version numbers for Oracle APEX and Oracle database
    - Version number of the Report Map plugin
    - The plugin SQL query, region static ID, and attribute values (you can get these by running the page in Debug mode, the attributes will be written to the browser console log)
    - Any other information you feel may be relevant (e.g. sample data)

* **FREE UPGRADE SUPPORT** *(terms & conditions apply)* - if you are upgrading to Release 1.0 from an earlier (beta) version of the plugin, at any time from now until Friday 20 December 2019  I will personally provide issue resolution support at no cost. If you encounter a problem, email me at jeff@jk64.com. My aim whenever possible is to provide 24-hour turnaround time for any bug fixes required. This free offer is subject to the following conditions:

  * You must be upgrading from a prior Release of this plugin (0.1 to 0.10) in an environment where the plugin was previously working correctly.
  * You must be on a supported environment, including (but not limited to) Oracle Database, and Oracle Application Express.
  * You have taken reasonable steps to mitigate against any loss - including taking a backup of your application prior to commencing any upgrade.
  * You must notify me of your issue, including as much detail as possible, before the end of the free support period (20 December 2019).
  * There will be a few times when I will be temporarily unavailable (no longer than 4 days duration, typically on a weekend).
  * Support is provided "as is" with no warranty of suitability for any purpose. No responsibility is accepted for loss or damage to systems or data.
