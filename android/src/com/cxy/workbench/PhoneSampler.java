package com.cxy.workbench;

import android.app.ActivityManager;
import android.content.*;
import android.net.*;
import android.os.*;
import android.os.storage.*;
import org.json.*;
import java.io.File;
import java.util.*;

/** One sampler, invoked only inside Store's serialized active refresh cycle. */
final class PhoneSampler {
 static JSONObject sample(Context c)throws JSONException {
  JSONObject out=new JSONObject();out.put("id","phone");out.put("host",Build.MODEL==null?"Android":Build.MODEL);
  Intent battery=c.registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
  if(battery!=null){int level=battery.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=battery.getIntExtra(BatteryManager.EXTRA_SCALE,-1),status=battery.getIntExtra(BatteryManager.EXTRA_STATUS,-1),plugged=battery.getIntExtra(BatteryManager.EXTRA_PLUGGED,0);
   if(level>=0&&scale>0)out.put("batteryPercent",Math.max(0,Math.min(100,100.0*level/scale)));
   out.put("batteryCharging",status==BatteryManager.BATTERY_STATUS_CHARGING);out.put("onACPower",plugged!=0);
  }
  ActivityManager manager=(ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);ActivityManager.MemoryInfo memory=new ActivityManager.MemoryInfo();manager.getMemoryInfo(memory);
  if(memory.totalMem>0&&memory.availMem>=0){out.put("memoryTotal",memory.totalMem);out.put("memoryUsed",Math.max(0,memory.totalMem-memory.availMem));}
  JSONArray disks=new JSONArray();Set<String> seen=new HashSet<>();
  addDisk(disks,seen,"内部存储",c.getFilesDir());
  StorageManager storage=(StorageManager)c.getSystemService(Context.STORAGE_SERVICE);
  for(StorageVolume volume:storage.getStorageVolumes()){if(volume.isPrimary())continue;File dir=volume.getDirectory();if(dir!=null&&Environment.MEDIA_MOUNTED.equals(volume.getState()))addDisk(disks,seen,volume.getDescription(c),dir);}
  out.put("disks",disks);out.put("networkType",network(c));
  // CPU/GPU and whole-device network throughput have no reliable supported source.
  // privateLink is exclusively derived by the server, never supplied by this client.
  return out;
 }
 static void addDisk(JSONArray disks,Set<String> seen,String name,File path){try{String device=String.valueOf(android.system.Os.stat(path.getAbsolutePath()).st_dev);if(!seen.add(device))return;StatFs fs=new StatFs(path.getAbsolutePath());long total=fs.getTotalBytes(),used=total-fs.getAvailableBytes();if(total>0&&used>=0){JSONObject d=new JSONObject();d.put("name",name);d.put("total",total);d.put("used",Math.min(total,used));disks.put(d);}}catch(Exception e){/* An inaccessible optional volume is not a measured disk. */}}
 static String network(Context c){ConnectivityManager m=(ConnectivityManager)c.getSystemService(Context.CONNECTIVITY_SERVICE);Network active=m.getActiveNetwork();if(active==null)return "none";NetworkCapabilities cap=m.getNetworkCapabilities(active);if(cap==null)return "unknown";if(cap.hasTransport(NetworkCapabilities.TRANSPORT_VPN))return "vpn";if(cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI))return "wifi";if(cap.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR))return "mobile";if(cap.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))return "ethernet";return "unknown";}
}
